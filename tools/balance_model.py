#!/usr/bin/env python
"""
Continuous-time economy / pacing model + autonomous balancer for 12 Stinky
Starknights.

A "number go up" game (~1-2 h, PACED BY CUTSCENES). The whole recipe tree, build
costs, deposits, and the Workshop research tree are PARSED from the Godot source
every run (via production_graph.py), so the model tracks the game as it grows.

The spine of the game is the single Workshop: it starts with FURNACE + WORKBENCH
and researches a capability tech-tree (Lathe -> CNC -> Assembly Station; Refinery;
Injection Molding; Wire Mill -> Soldering -> Cleanroom -> Lithography). Each
unlock lets the one workshop craft the recipes that need that capability (slowly,
one order at a time). Factory buildings are the parallel/fast alternative for the
recipes that have one. Recipes 16-26 (the PC chain, steam engine) have no factory,
so they are workshop-only and gated purely by research.

Balancing happens through the RESEARCH / UPGRADE tree (Workshop capabilities,
per-building throughput upgrades, automation). The build-cost lever was removed.

The model measures PLAYER ACTIVITY = density of player actions over time
(building, research, and workshop craft orders). Design goal: high early density
(busy = fun) tapering to a calm late game where the player only hand-crafts the
workshop-only PC parts.

Model simplifications: travel = 0 (job system = <=12 concurrent tasks solved by
the LP); production is continuous flow between investment events (piecewise-linear
exact timings); cutscenes run in parallel and only gate story triggers.

Usage:
  python balance_model.py [--good JELLY_STANDEES] [--amount 50] [--no-plots]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import linprog
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

sys.path.insert(0, str(Path(__file__).resolve().parent))
import production_graph as pg


# ===========================================================================
# 1. ENGINE CONSTANTS  (stable scalars, kept with source; the TREE is parsed)
# ===========================================================================
WORKERS = 12                 # Starknights (world.tscn)
WORKSHOPS = 1                # one Workshop; ONE order at a time
HARVEST_DURATION = 1.0       # HexTile.HARVEST_DURATION
HARVEST_AMOUNT = 1           # HexTile.HARVEST_AMOUNT
CONSTRUCTION_TIME = 10.0     # Building.start_construction duration
RESEARCH_WORK = 60.0         # ResearchItem default work
# EXTRACTION_SPEEDUP / FACTORY_SPEEDUP / AUTOMATION_COST are parsed from source
# (BASE_WORK_SPEEDUP and the per-building Automation research) -- see load_game.

GAME_ROOT = Path(__file__).resolve().parent.parent


# ===========================================================================
# 2. LOAD THE GAME  (recipes / costs / buildings / deposits / research)
# ===========================================================================
def _parse_work_constants(text):
    ns = {}
    for m in re.finditer(r"const\s+(WORK_\w+)\s*:?=\s*(.+)", text):
        ns[m.group(1)] = float(eval(m.group(2).split("#")[0].strip(),
                                    {"__builtins__": {}}, ns))
    return ns


def _parse_workshop_research(text):
    """capability -> {cost, prereqs(caps), base}.  Parsed from Workshop.gd."""
    blocks, cur = {}, None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0]
        m = re.search(r"var\s+(\w+)\s*:=\s*ResearchItem\.new\(\)", line)
        if m:
            cur = m.group(1)
            blocks[cur] = dict(cap=None, cost={}, prereqs=[], base=False)
            continue
        if cur is None:
            continue
        m = re.search(r"\.cost\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", line)
        if m:
            blocks[cur]["cost"][m.group(1)] = int(m.group(2))
        m = re.search(r"\.prerequisites\.append\((\w+)\)", line)
        if m:
            blocks[cur]["prereqs"].append(m.group(1))
        if re.search(r"\.state\s*=\s*ResearchItem\.State\.COMPLETED", line):
            blocks[cur]["base"] = True
        m = re.search(r"Workshop\.capabilities\.append\(Crafting\.Capabilities\.(\w+)\)", line)
        if m:
            blocks[cur]["cap"] = m.group(1)
    for name, b in blocks.items():                 # base items grant their named cap
        if b["cap"] is None and b["base"]:
            b["cap"] = name.upper()
    var2cap = {n: b["cap"] for n, b in blocks.items()}

    cap_cost, cap_prereq, base_caps = {}, {}, set()
    for b in blocks.values():
        cap = b["cap"]
        if cap is None:
            continue
        if b["base"]:
            base_caps.add(cap)
        else:
            cap_cost[cap] = dict(b["cost"])
            cap_prereq[cap] = {var2cap.get(p, p) for p in b["prereqs"]}
    return cap_cost, cap_prereq, base_caps


def _parse_research_items(text):
    """Generic ResearchItem parser (display_name / cost / prerequisites), used
    for per-building research chains like the Warehouse Starknight-speed tree."""
    blocks, order, cur = {}, [], None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0]
        m = re.search(r"var\s+(\w+)\s*:=\s*ResearchItem\.new\(\)", line)
        if m:
            cur = m.group(1)
            blocks[cur] = dict(var=cur, display="", cost={}, prereqs=[])
            order.append(cur); continue
        if cur is None:
            continue
        m = re.search(r'\.display_name\s*=\s*"([^"]*)"', line)
        if m:
            blocks[cur]["display"] = m.group(1)
        m = re.search(r"\.cost\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", line)
        if m:
            blocks[cur]["cost"][m.group(1)] = int(m.group(2))
        m = re.search(r"\.prerequisites\.append\((\w+)\)", line)
        if m:
            blocks[cur]["prereqs"].append(m.group(1))
    var2disp = {v: blocks[v]["display"] for v in order}
    return {blocks[v]["display"]: dict(cost=blocks[v]["cost"],
            prereqs=[var2disp.get(p, p) for p in blocks[v]["prereqs"]]) for v in order}


def _parse_float_const(text, cname, default):
    m = re.search(r"const\s+" + cname + r"\s*:\s*\w+\s*=\s*([\d.]+)", text)
    return float(m.group(1)) if m else default


def _parse_automation_cost(text):
    return {m.group(1): int(m.group(2)) for m in re.finditer(
        r"automation\.cost\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", text)}


def _split_call_args(text, start):
    """Given `text` and the index just AFTER a call's opening '(', return the
    list of top-level argument substrings (comma-split, but respecting nested
    (), [], {} and skipping string literals)."""
    depth, args, cur, i = 0, [], [], start
    while i < len(text):
        ch = text[i]
        if ch in "([{":
            depth += 1; cur.append(ch)
        elif ch in ")]}":
            if depth == 0:
                break                              # the call's closing ')'
            depth -= 1; cur.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(cur).strip()); cur = []
        elif ch == '"':
            cur.append(ch); i += 1
            while i < len(text) and text[i] != '"':
                cur.append(text[i]); i += 1
            if i < len(text):
                cur.append(text[i])
        else:
            cur.append(ch)
        i += 1
    if "".join(cur).strip():
        args.append("".join(cur).strip())
    return args


def _parse_building_upgrades(building_dir):
    """Per-building throughput upgrades declared in each building's
    _upgrade_research() via FactoryBuilding's _output_upgrade()/_speed_upgrade()
    helpers. Returns {building_cls: [dict(var, kind, display, scale, cost,
    prereqs=[var,...])]}.  kind 'output' -> production_scale (bigger batch);
    'speed' -> work_scale (faster runs). Both multiply a building's net
    throughput per instance in this continuous model (see _tmul).

    Helper signature: _<k>_upgrade(slot, name, description, scale, cost, prereq?).
    Factories use _output_upgrade (production_scale) / _speed_upgrade (work_scale);
    extraction sites use _yield_upgrade (yield_scale). yield and output both scale a
    building's net rate identically (kind 'output'); speed divides its duration."""
    upgrades = {}
    for path in sorted(Path(building_dir).glob("*.gd")):
        text = pg.read(path)
        m = re.search(r"class_name\s+(\w+)", text)
        cls = m.group(1) if m else path.stem
        items = []
        # Match a helper call, optionally preceded by its `var NAME [: Type] =` (or
        # `:=`) binding and an opening `[` (a typed list literal wraps single ones).
        for c in re.finditer(
                r"(?:var\s+(\w+)\s*(?::\s*[\w\[\]]+)?\s*:?=\s*\[?\s*)?"
                r"(_output_upgrade|_speed_upgrade|_yield_upgrade)\s*\(", text):
            args = _split_call_args(text, c.end())
            if len(args) < 5:
                continue
            kind = "speed" if c.group(2) == "_speed_upgrade" else "output"
            scale = float(eval(args[3].split("#")[0].strip(), {"__builtins__": {}}, {}))
            cost = {cm.group(1): int(cm.group(2)) for cm in re.finditer(
                r"Stockpile\.ItemType\.(\w+)\s*:\s*(\d+)", args[4])}
            prereqs = []
            if len(args) >= 6 and re.fullmatch(r"\w+", args[5].strip()):
                prereqs.append(args[5].strip())
            display = args[1].strip().strip('"')
            var = c.group(1) or f"slot{args[0].strip()}"   # id; fall back to slot
            items.append(dict(var=var, kind=kind, display=display,
                              scale=scale, cost=cost, prereqs=prereqs))
        if items:
            upgrades[cls] = items
    return upgrades


def load_game():
    stock = pg.read(GAME_ROOT / "scripts/globals/Stockpile.gd")
    craft = pg.read(GAME_ROOT / "scripts/globals/Crafting.gd")
    cat = pg.read(GAME_ROOT / "scripts/globals/Catalog.gd")
    wshop = pg.read(GAME_ROOT / "objects/buildings/Workshop.gd")
    factory_src = pg.read(GAME_ROOT / "scripts/FactoryBuilding.gd")
    extract_src = pg.read(GAME_ROOT / "scripts/ExtractionBuilding.gd")

    items = pg.parse_items(stock)
    raw_recipes = pg.parse_recipes(craft)
    buildings = pg.parse_buildings(GAME_ROOT / "objects/buildings")
    catalog = pg.parse_catalog(cat)
    workconsts = _parse_work_constants(craft)
    cap_cost, cap_prereq, base_caps = _parse_workshop_research(wshop)
    warehouse_research = _parse_research_items(
        pg.read(GAME_ROOT / "objects/buildings/Warehouse.gd"))
    building_upgrades = _parse_building_upgrades(GAME_ROOT / "objects/buildings")

    recipes = {}                                   # key -> (in, out, work, caps)
    skipped = []
    for r in raw_recipes.values():
        try:                                       # WIP recipes may lack work/outputs
            work = float(eval(r.work, {"__builtins__": {}}, workconsts))
        except (SyntaxError, NameError, TypeError):
            work = 0.0
        if work <= 0 or not r.outputs:
            skipped.append(r.key); continue
        recipes[r.key] = (dict(r.inputs), dict(r.outputs), work, set(r.capabilities))

    recipe_building = {}
    for cls, b in buildings.items():
        if b.base == "FactoryBuilding" and b.recipe_index in raw_recipes:
            recipe_building[raw_recipes[b.recipe_index].key] = cls

    raw_source = {}
    for cls, info in catalog.items():
        for dep in info["deposits"]:
            raw_source.setdefault(dep, cls)
    for cls, b in buildings.items():
        if b.base == "ExtractionBuilding":
            for it in b.harvest_override:
                raw_source.setdefault(it, cls)

    build_cost = {cls: dict(info["cost"]) for cls, info in catalog.items()}
    challenge_items = set(re.findall(r"_challenges\[ItemType\.(\w+)\]", stock))
    produced = {g for (_i, o, _w, _c) in recipes.values() for g in o}
    consumed = {g for (i, _o, _w, _c) in recipes.values() for g in i}
    all_items = produced | consumed
    raws = sorted(all_items - produced)
    cost_items = {g for c in build_cost.values() for g in c}
    finished = sorted(produced - consumed - cost_items)

    return dict(items=items, recipes=recipes, buildings=buildings, catalog=catalog,
                recipe_building=recipe_building, raw_source=raw_source,
                build_cost=build_cost, raws=raws, goods=sorted(all_items),
                finished=finished, cap_cost=cap_cost, cap_prereq=cap_prereq,
                base_caps=base_caps,
                factory_speedup=_parse_float_const(factory_src, "BASE_WORK_SPEEDUP", 10.0),
                extraction_speedup=_parse_float_const(extract_src, "BASE_WORK_SPEEDUP", 10.0),
                automation_cost=(_parse_automation_cost(factory_src)
                                 or {"INDUSTRIAL_CONTROLLERS": 10}),
                warehouse_research=warehouse_research,
                building_upgrades=building_upgrades,
                challenge_items=challenge_items, skipped=skipped)


G = load_game()
ITEMS, RECIPES, BUILDINGS, CATALOG = G["items"], G["recipes"], G["buildings"], G["catalog"]
RECIPE_BUILDING, RAW_SOURCE, BUILD_COST = G["recipe_building"], G["raw_source"], G["build_cost"]
RAWS, GOODS, FINISHED = G["raws"], G["goods"], G["finished"]
CAP_COST, CAP_PREREQ, BASE_CAPS = G["cap_cost"], G["cap_prereq"], G["base_caps"]
ALL_CAPS = BASE_CAPS | set(CAP_COST)
FACTORY_SPEEDUP = G["factory_speedup"]        # FactoryBuilding.BASE_WORK_SPEEDUP
EXTRACTION_SPEEDUP = G["extraction_speedup"]  # ExtractionBuilding.BASE_WORK_SPEEDUP
AUTOMATION_COST = G["automation_cost"]        # per-building Automation research cost
CHALLENGE_ITEMS = G["challenge_items"]        # merch/PC goods; need the Warehouse
WAREHOUSE_RESEARCH = G["warehouse_research"]  # display -> {cost, prereqs} (speed tree)
BUILDING_UPGRADES = G["building_upgrades"]    # bt -> [upgrade dicts] (throughput tree)

# Flat id map: uid=(building_type, var) -> upgrade info (incl. prereq uids).
UPGRADES = {}
for _bt, _lst in BUILDING_UPGRADES.items():
    for _u in _lst:
        UPGRADES[(_bt, _u["var"])] = dict(
            bt=_bt, var=_u["var"], kind=_u["kind"], display=_u["display"],
            scale=_u["scale"], cost=_u["cost"],
            prereq_ids=[(_bt, _p) for _p in _u["prereqs"]])


def _tmul(ups):
    """Per-building-type throughput multiplier from a set of researched upgrade
    ids. An 'output' upgrade (production_scale) and a 'speed' upgrade (work_scale)
    each multiply a building's net output rate per instance, at no extra worker or
    building cost, so a building's total multiplier is production_scale x work_scale.
    Tiers set an ABSOLUTE scale and chain by prerequisite, so the effective value
    of each kind is the max scale among that building's completed upgrades."""
    by_bt = {}
    for uid in ups:
        u = UPGRADES[uid]
        pair = by_bt.setdefault(u["bt"], [1.0, 1.0])   # [output, speed]
        idx = 0 if u["kind"] == "output" else 1
        pair[idx] = max(pair[idx], u["scale"])
    return {bt: pair[0] * pair[1] for bt, pair in by_bt.items()}


def research_chain(display):
    """Ordered prerequisite chain of a Warehouse research, target last."""
    chain, seen = [], set()
    def visit(d):
        if d in seen or d not in WAREHOUSE_RESEARCH:
            return
        seen.add(d)
        for p in WAREHOUSE_RESEARCH[d]["prereqs"]:
            visit(p)
        chain.append(d)
    visit(display)
    return chain

BUILDING_TYPES = sorted(set(RAW_SOURCE.values()) | set(RECIPE_BUILDING.values()))
FACTORY_BUILDINGS = set(RECIPE_BUILDING.values())
CATALOG_BUILDINGS = [c for c in CATALOG if c != "Warehouse"]
_GOOD_INDEX = {g: i for i, g in enumerate(GOODS)}


def name(item):
    return ITEMS.get(item, item)


def bname(cls):
    b = BUILDINGS.get(cls)
    return b.display_name if b else cls


# ===========================================================================
# 3. LEVER: research / upgrade costs (Workshop.gd + per-building research).
#    (The build-cost lever was removed -- balancing now happens through the
#    upgrade tree and its activity effects, not by scaling Catalog.gd.)
# ===========================================================================
RESEARCH_COST_MULT = 1.0


# ===========================================================================
# 4. THE ALLOCATION LP  (max sustainable rate given buildings + workshop caps)
#    A recipe can run in the Workshop iff its capabilities are researched, or in
#    its factory building (which embodies the capability) once built.
# ===========================================================================
def _activities(caps, warehouse, tmul):
    acts = []
    for r in RAWS:
        acts.append((f"manual:{r}", HARVEST_DURATION / HARVEST_AMOUNT, {r: 1.0}, "worker_only"))
        bt = RAW_SOURCE.get(r)
        if bt is not None:
            m = tmul.get(bt, 1.0)               # per-site yield upgrade
            acts.append((f"extract:{r}", (HARVEST_DURATION / EXTRACTION_SPEEDUP),
                         {r: float(HARVEST_AMOUNT) * m}, ("building", bt)))
    for key, (inp, out, work, rcaps) in RECIPES.items():
        # challenge goods (merch / PC parts) can't be made until the Warehouse exists
        if not warehouse and any(o in CHALLENGE_ITEMS for o in out):
            continue
        net = {g: float(out.get(g, 0) - inp.get(g, 0)) for g in set(inp) | set(out)}
        if rcaps <= caps:
            acts.append((f"workshop:{key}", work, net, "workshop"))
        bt = RECIPE_BUILDING.get(key)
        if bt is not None:
            m = tmul.get(bt, 1.0)               # per-building throughput upgrades
            fnet = net if m == 1.0 else {g: v * m for g, v in net.items()}
            acts.append((f"factory:{key}", work / FACTORY_SPEEDUP, fnet, ("building", bt)))
    return acts


def _build_template(acts, auto):
    """`auto` = set of building types that are AUTOMATED. An automated building's
    runs post no Job, so they cost NO worker -- their coefficient in the worker
    constraint is 0 (they are still capped by building count / concurrency)."""
    n = len(acts)
    c = np.zeros(n + 1); c[-1] = -1.0
    rows, labels, is_cap, cap_b = [], [], [], []

    def add(row, label, cap, bt=None):
        rows.append(row); labels.append(label); is_cap.append(cap); cap_b.append(bt)

    row = np.zeros(n + 1)                     # worker constraint
    for i, (nm, dur, net, cap) in enumerate(acts):
        automated = isinstance(cap, tuple) and cap[1] in auto
        row[i] = 0.0 if automated else 1.0
    add(row, "workers", True)
    row = np.zeros(n + 1)
    for i, (nm, *_ ) in enumerate(acts):
        if nm.startswith("workshop:"):
            row[i] = 1.0
    add(row, "workshop", True)
    brow = {}
    for bt in BUILDING_TYPES:
        row = np.zeros(n + 1); used = False
        for i, (nm, dur, net, cap) in enumerate(acts):
            if isinstance(cap, tuple) and cap[1] == bt:
                row[i] = 1.0; used = True
        if used:
            brow[bt] = len(rows); add(row, bt, True, bt)
    supply0 = len(rows)
    for g in GOODS:
        row = np.zeros(n + 1)
        for i, (nm, dur, net, cap) in enumerate(acts):
            if g in net:
                row[i] = -net[g] / dur
        add(row, f"supply:{g}", False)
    return acts, c, np.array(rows), labels, is_cap, cap_b, brow, supply0


_template_cache = {}
def _template(caps, auto, warehouse, tmul):
    key = (frozenset(caps), frozenset(auto), warehouse, tuple(sorted(tmul.items())))
    if key not in _template_cache:
        _template_cache[key] = _build_template(_activities(caps, warehouse, tmul), auto)
    return _template_cache[key]


def _solve(target, buildings, caps, auto, ups):
    """Solve the LP; return (linprog result, acts, labels, is_cap, cap_b, b)."""
    warehouse = buildings.get("Warehouse", 0) > 0
    acts, c, A0, labels, is_cap, cap_b, brow, supply0 = _template(
        caps, auto, warehouse, _tmul(ups))
    A = A0.copy()
    b = np.zeros(A.shape[0])
    b[0] = WORKERS; b[1] = WORKSHOPS
    for bt, ridx in brow.items():
        b[ridx] = float(buildings.get(bt, 0))
    for g, q in target.items():
        A[supply0 + _GOOD_INDEX[g], -1] = float(q)
    res = linprog(c, A_ub=A, b_ub=b, bounds=[(0, None)] * len(c), method="highs")
    return res, acts, labels, is_cap, cap_b, b


def max_bundle_rate(target, buildings, caps, auto=frozenset(), ups=frozenset()):
    res, acts, labels, is_cap, cap_b, b = _solve(target, buildings, caps, auto, ups)
    if not res.success:
        return 0.0, "infeasible"
    lam = res.x[-1]
    marg = res.ineqlin.marginals
    binding, best = "unconstrained", 0.0
    for j in range(len(labels)):
        if is_cap[j] and marg[j] < best - 1e-9 and b[j] > 0:
            bt = cap_b[j]
            binding = labels[j] if bt is None else f"{bt} x{int(b[j])}"
            best = marg[j]
    return lam, binding


# good -> the recipe that produces it (primary); building -> its recipe outputs.
GOOD_RECIPE = {}
for _k, (_i, _o, _w, _c) in RECIPES.items():
    for _g in _o:
        GOOD_RECIPE.setdefault(_g, _k)
BUILDING_OUTPUTS = {}
for _k, _bt in RECIPE_BUILDING.items():
    BUILDING_OUTPUTS.setdefault(_bt, set()).update(RECIPES[_k][1])


# ===========================================================================
# 5. THE OPTIMAL PLAYER  (greedy rollout over BUILD and RESEARCH investments;
#    a producibility pass researches the capabilities a goal actually requires)
# ===========================================================================
GOAL_GOOD = "PC_PC"            # build one Personal Computer (the endgame goal)
GOAL_AMOUNT = 1
# The Warehouse is a prerequisite for any recipe that makes a CHALLENGE good
# (merch / PC parts) -- modelled in the LP. Story goals (cutscene gates) are
# ignored by the optimizer for now; STORY_GATE is kept only to annotate the
# cutscene-floor overlay.
STORY_GATE = "MechanicalComponentFactory"
COPY_CAP = 8

ACTIVE_CANDIDATES = list(CATALOG_BUILDINGS)
RELEVANT_CAPS = set()
RELEVANT_ITEMS = set()


def _relevant(good):
    return _relevant_seed({good})


def _relevant_seed(seed_items):
    """Closure of items on the way to the `seed_items` (a good, or a set of
    research-cost items), including build-cost chains and the Warehouse. Returns:
      cands  - the catalog buildings worth considering,
      items  - the relevant item set (producibility gradient),
      caps   - MANDATORY research caps = caps of relevant recipes that have NO
               factory (must be workshop-crafted), closed under prerequisites.
    Recipes that DO have a factory need no research -- you build the factory.

    `goal_items` (the producibility gradient) covers only the goal's own chain.
    The candidate/research sets additionally cover the Automation cost chain
    (Industrial Computer Modules) so the optimiser can weigh automating -- but
    that chain is kept OUT of the producibility gradient so the bootstrap does
    not detour through it."""
    def closure(seed):
        items = set(seed)
        changed = True
        while changed:
            changed = False
            for g in list(items):
                for (inp, out, _w, _c) in RECIPES.values():
                    if g in out:
                        for ing in inp:
                            if ing not in items:
                                items.add(ing); changed = True
                if g in RAW_SOURCE:
                    for ci in BUILD_COST.get(RAW_SOURCE[g], {}):
                        if ci not in items:
                            items.add(ci); changed = True
            for key, (_i, out, _w, _c) in RECIPES.items():
                if key in RECIPE_BUILDING and any(o in items for o in out):
                    for ci in BUILD_COST.get(RECIPE_BUILDING[key], {}):
                        if ci not in items:
                            items.add(ci); changed = True
        return items

    goal_items = closure(set(seed_items) | set(BUILD_COST.get("Warehouse", {})))

    def derive(items):
        cands, mand = set(), set()
        for key, (_i, out, _w, rc) in RECIPES.items():
            if not any(o in items for o in out):
                continue
            if key in RECIPE_BUILDING:
                cands.add(RECIPE_BUILDING[key])
            else:
                mand |= rc                          # workshop-only -> must research
        for r in items:
            if r in RAW_SOURCE:
                cands.add(RAW_SOURCE[r])
        cands.discard("Warehouse")
        caps, frontier = set(mand), set(mand)       # close research caps under prereqs
        while frontier:
            for p in CAP_PREREQ.get(frontier.pop(), ()):
                if p not in caps:
                    caps.add(p); frontier.add(p)
        return cands, caps - BASE_CAPS

    # Fold in the automation chain AND the research-cost chains of the caps the
    # goal needs, iterating to a fixpoint, so factory-able research/automation
    # inputs get their factory built rather than being hand-crafted avoidably.
    items = closure(set(goal_items) | set(AUTOMATION_COST))
    cands, caps = derive(items)
    for _ in range(8):
        seed = set(items)
        for c in caps:
            seed |= set(CAP_COST.get(c, {}))
        new_items = closure(seed)
        if new_items == items:
            break
        items = new_items
        cands, caps = derive(items)
    return ([c for c in CATALOG_BUILDINGS if c in cands], goal_items, caps)


# The player's STATE is (buildings, caps, auto): building counts, the Workshop's
# researched capabilities, and the set of building TYPES that are automated.
def _skey(bs, caps, auto, ups):
    return (tuple(sorted((k, v) for k, v in bs.items() if v > 0)),
            frozenset(caps), frozenset(auto), frozenset(ups))


def _addb(bs, k):
    out = dict(bs); out[k] = out.get(k, 0) + 1; return out


_rate_cache = {}
def rate(bs, caps, auto, ups, good):
    key = (_skey(bs, caps, auto, ups), good)
    if key not in _rate_cache:
        _rate_cache[key] = max_bundle_rate({good: 1.0}, bs, caps, auto, ups)[0]
    return _rate_cache[key]


_afford_cache = {}
def afford_time(cost, bs, caps, auto, ups):
    key = (_skey(bs, caps, auto, ups), tuple(sorted(cost.items())))
    if key not in _afford_cache:
        lam, _b = max_bundle_rate(cost, bs, caps, auto, ups)
        _afford_cache[key] = np.inf if lam <= 0 else 1.0 / lam
    return _afford_cache[key]


def _cap_cost(c):
    return {g: v * RESEARCH_COST_MULT for g, v in CAP_COST[c].items()}


def _auto_cost():
    return {g: v * RESEARCH_COST_MULT for g, v in AUTOMATION_COST.items()}


def _upgrade_cost(uid):
    return {g: v * RESEARCH_COST_MULT for g, v in UPGRADES[uid]["cost"].items()}


def _bcost(b):
    return dict(BUILD_COST[b])


def _actions(bs, caps, auto, ups):
    """Yield (kind, typ, nbs, ncaps, nauto, nups, cost, action_time)."""
    for b in ACTIVE_CANDIDATES:
        if bs.get(b, 0) < COPY_CAP:
            yield ("build", b, _addb(bs, b), caps, auto, ups, _bcost(b), CONSTRUCTION_TIME)
    for c in RELEVANT_CAPS:
        if c not in caps and CAP_PREREQ.get(c, set()) <= caps:
            yield ("research", c, bs, caps | {c}, auto, ups, _cap_cost(c), RESEARCH_WORK)
    for bt in ACTIVE_CANDIDATES:                    # automate a built factory/extractor
        if bt in BUILDING_TYPES and bs.get(bt, 0) > 0 and bt not in auto:
            yield ("automate", bt, bs, caps, auto | {bt}, ups, _auto_cost(), RESEARCH_WORK)
    for bt in ACTIVE_CANDIDATES:                    # per-building throughput upgrade
        if bs.get(bt, 0) <= 0:
            continue
        for u in BUILDING_UPGRADES.get(bt, ()):
            uid = (bt, u["var"])
            if uid in ups:
                continue
            if all((bt, p) in ups for p in u["prereqs"]):
                yield ("upgrade", uid, bs, caps, auto, ups | {uid},
                       _upgrade_cost(uid), RESEARCH_WORK)


def make_produce_goal(good, amount):
    def finish(bs, caps, auto, ups):
        r = rate(bs, caps, auto, ups, good)
        return np.inf if r <= 0 else amount / r
    return finish


def remaining(bs, caps, auto, ups, finish, memo):
    key = _skey(bs, caps, auto, ups)
    if key in memo:
        return memo[key]
    best, best_step = finish(bs, caps, auto, ups), None
    for kind, typ, nbs, ncaps, nauto, nups, cost, atime in _actions(bs, caps, auto, ups):
        aff = afford_time(cost, bs, caps, auto, ups)
        if not np.isfinite(aff):
            continue
        val = aff + atime + finish(nbs, ncaps, nauto, nups)
        if val < best - 1e-9:
            best, best_step = val, (nbs, ncaps, nauto, nups, aff + atime)
    if best_step is None:
        memo[key] = finish(bs, caps, auto, ups)
        return memo[key]
    nbs, ncaps, nauto, nups, dt = best_step
    res = min(finish(bs, caps, auto, ups),
              dt + remaining(nbs, ncaps, nauto, nups, finish, memo))
    memo[key] = res
    return res


def greedy(finish, bs, caps, auto, ups, t, steps):
    memo = {}
    while True:
        best_total, best = t + finish(bs, caps, auto, ups), None
        for kind, typ, nbs, ncaps, nauto, nups, cost, atime in _actions(bs, caps, auto, ups):
            aff = afford_time(cost, bs, caps, auto, ups)
            if not np.isfinite(aff):
                continue
            total = t + aff + atime + remaining(nbs, ncaps, nauto, nups, finish, memo)
            if total < best_total - 1e-6:
                best_total, best = total, (kind, typ, nbs, ncaps, nauto, nups, aff + atime)
        if best is None:
            return bs, caps, auto, ups, t
        kind, typ, nbs, ncaps, nauto, nups, dt = best
        bs, caps, auto, ups, t = nbs, ncaps, nauto, nups, t + dt
        steps.append((kind, typ, t))


def ensure_producible(good, bs, caps, auto, ups, t, steps):
    """Make `good` producible at all by acquiring, cheapest-first, the unlocks
    that increase how many relevant items can be produced -- building a factory
    for recipes that have one, researching a capability for the workshop-only
    ones. (Automation and throughput upgrades never change producibility, so they
    are skipped here.)"""
    def pcount(bs, caps):
        return sum(1 for it in RELEVANT_ITEMS if rate(bs, caps, auto, ups, it) > 1e-9)

    while rate(bs, caps, auto, ups, good) <= 1e-9:
        cur = pcount(bs, caps)
        best = fallback = None
        for kind, typ, nbs, ncaps, nauto, nups, cost, atime in _actions(bs, caps, auto, ups):
            if kind in ("automate", "upgrade"):
                continue
            aff = afford_time(cost, bs, caps, auto, ups)
            if not np.isfinite(aff):
                continue
            key = aff + atime
            if fallback is None or key < fallback[0]:
                fallback = (key, kind, typ, nbs, ncaps)
            if pcount(nbs, ncaps) > cur and (best is None or key < best[0]):
                best = (key, kind, typ, nbs, ncaps)
        pick = best or fallback
        if pick is None:
            raise RuntimeError(f"{name(good)} is not reachable (missing recipe/deposit?)")
        dt, kind, typ, nbs, ncaps = pick
        bs, caps, t = nbs, ncaps, t + dt
        steps.append((kind, typ, t))
    return bs, caps, auto, ups, t


def _toposort(nodes, deps_fn):
    order, seen, temp = [], set(), set()
    def visit(n):
        if n in seen or n in temp:
            return
        temp.add(n)
        for d in deps_fn(n):
            if d in nodes:
                visit(d)
        temp.discard(n); seen.add(n); order.append(n)
    for n in nodes:
        visit(n)
    return order


def build_factory_tree(bs, caps, auto, ups, t, steps):
    """Build one of every relevant factory in DEPENDENCY ORDER, so each factory's
    construction inputs are already factory-supplied. This minimises hand-crafting
    to the true bootstrap (the first Brickworks' bricks, the first Mech-Comp
    Factory's components, ...) instead of, say, hand-crafting 800 bricks."""
    good_factory = {g: bt for k, bt in RECIPE_BUILDING.items() for g in RECIPES[k][1]}
    factories = [c for c in ACTIVE_CANDIDATES if c in FACTORY_BUILDINGS]

    def deps(f):
        return {good_factory[g] for g in BUILD_COST[f]
                if g in good_factory and good_factory[g] != f}

    for f in _toposort(factories, deps):
        aff = afford_time(_bcost(f), bs, caps, auto, ups)
        if not np.isfinite(aff):
            continue
        t += aff + CONSTRUCTION_TIME
        bs = _addb(bs, f); steps.append(("build", f, t))
    return bs, caps, auto, ups, t


def plan(good, amount):
    global ACTIVE_CANDIDATES, RELEVANT_CAPS, RELEVANT_ITEMS
    ACTIVE_CANDIDATES, RELEVANT_ITEMS, RELEVANT_CAPS = _relevant(good)

    bs, caps, auto, ups, t, steps = {}, set(BASE_CAPS), set(), frozenset(), 0.0, []

    # The Warehouse gates every challenge recipe, so build it first whenever a
    # challenge good is anywhere on the goal's chain (e.g. any PC part).
    if any(g in CHALLENGE_ITEMS for g in RELEVANT_ITEMS):
        t += afford_time(_bcost("Warehouse"), bs, caps, auto, ups) + CONSTRUCTION_TIME
        bs = _addb(bs, "Warehouse"); steps.append(("build", "Warehouse", t))

    # Stand up the factory tree first (craft-minimal), research any workshop-only
    # capabilities the goal needs, then optimise throughput (copies + upgrades +
    # automation).
    bs, caps, auto, ups, t = build_factory_tree(bs, caps, auto, ups, t, steps)
    bs, caps, auto, ups, t = ensure_producible(good, bs, caps, auto, ups, t, steps)
    bs, caps, auto, ups, t = greedy(
        make_produce_goal(good, amount), bs, caps, auto, ups, t, steps)
    t += amount / rate(bs, caps, auto, ups, good)
    return steps, bs, caps, auto, ups, t


def _research_all_caps(needed, bs, caps, auto, ups, t, steps):
    """Research every capability in `needed` (closed under prereqs), each in
    prerequisite order, cheapest affordable first."""
    remaining = {c for c in needed if c not in caps}
    while remaining:
        avail = [c for c in remaining if CAP_PREREQ.get(c, set()) <= caps]
        avail = [c for c in avail if np.isfinite(afford_time(_cap_cost(c), bs, caps, auto, ups))]
        if not avail:
            break
        c = min(avail, key=lambda x: afford_time(_cap_cost(x), bs, caps, auto, ups))
        t += afford_time(_cap_cost(c), bs, caps, auto, ups) + RESEARCH_WORK
        caps = caps | {c}; remaining.discard(c)
        steps.append(("research", c, t))
    return caps, t


def plan_research(target):
    """Benchmark reaching a WAREHOUSE research (e.g. 'Meka Suit Integration'):
    build the economy, then research its prerequisite chain in order, producing
    each research's cost bundle. Returns the same shape as plan()."""
    global ACTIVE_CANDIDATES, RELEVANT_CAPS, RELEVANT_ITEMS
    chain = research_chain(target)
    cost_items = {g for d in chain for g in WAREHOUSE_RESEARCH[d]["cost"]}
    ACTIVE_CANDIDATES, RELEVANT_ITEMS, RELEVANT_CAPS = _relevant_seed(cost_items)

    bs, caps, auto, ups, t, steps = {}, set(BASE_CAPS), set(), frozenset(), 0.0, []
    # The research is at the Warehouse (and Jelly Coffee etc. are challenge goods).
    t += afford_time(_bcost("Warehouse"), bs, caps, auto, ups) + CONSTRUCTION_TIME
    bs = _addb(bs, "Warehouse"); steps.append(("build", "Warehouse", t))

    bs, caps, auto, ups, t = build_factory_tree(bs, caps, auto, ups, t, steps)
    caps, t = _research_all_caps(RELEVANT_CAPS, bs, caps, auto, ups, t, steps)

    # Optimise the building set for the whole chain's cost, then research in order.
    def finish(bs, caps, auto, ups):
        return sum(afford_time({g: v * WAREHOUSE_COST_MULT for g, v in
                                WAREHOUSE_RESEARCH[d]["cost"].items()}, bs, caps, auto, ups)
                   + RESEARCH_WORK for d in chain)
    bs, caps, auto, ups, t = greedy(finish, bs, caps, auto, ups, t, steps)
    for d in chain:
        cost = {g: v * WAREHOUSE_COST_MULT for g, v in WAREHOUSE_RESEARCH[d]["cost"].items()}
        t += afford_time(cost, bs, caps, auto, ups) + RESEARCH_WORK
        steps.append(("wresearch", d, t))
    return steps, bs, caps, auto, ups, t


WAREHOUSE_COST_MULT = 1.0


# ===========================================================================
# 6. CUTSCENE FLOOR  (source: Story.gd; parallel with the sim, gates story)
# ===========================================================================
CUTSCENE_GAP = 3.0
CUTSCENES = [
    ("Intro (Sakana)",       None,       20.0),
    ("Tutorial (Aiko)",      None,       16.0),
    ("Debut tease (Sakana)", STORY_GATE,  4.0),
    ("JELLY DEBUT video",    STORY_GATE, 73.55),
    ("Make merch (Sakana)",  STORY_GATE,  8.0),
    ("Merch targets (Aiko)", STORY_GATE,  6.0),
]


def cutscene_timeline(build_times):
    fires, clock = [], 0.0
    for label, trig, dur in CUTSCENES:
        ready = 0.0 if trig is None else build_times.get(trig, np.inf)
        start = max(clock, ready) + CUTSCENE_GAP
        fires.append((label, start, start + dur)); clock = start + dur
    return fires


# ===========================================================================
# 7. EVALUATE + ACTIVITY
#    "Activity" = density of PLAYER ACTIONS over time. Player actions are:
#    building constructions, research, and WORKSHOP CRAFT ORDERS (each good the
#    player hand-crafts in a phase). The design goal is high early density
#    (busy = fun) tapering to a calm late game (manual PC-part crafting only).
# ===========================================================================
def evaluate(good, amount):
    steps, bs, caps, auto, ups, total = plan(good, amount)
    gate = next((s[2] for s in steps if s[1] == STORY_GATE), np.nan)
    sched = crafting_schedule(steps, good, amount, total)
    return dict(steps=steps, buildings=bs, caps=caps, auto=auto, ups=ups, total=total,
                gate=gate, crafts=sched, good=good, amount=amount,
                goal_row=f"▶ {amount} {name(good)}", label=f"{amount} x {name(good)}")


def evaluate_research(target):
    steps, bs, caps, auto, ups, total = plan_research(target)
    sched = crafting_schedule(steps, None, 0, total)
    return dict(steps=steps, buildings=bs, caps=caps, auto=auto, ups=ups, total=total,
                gate=np.nan, crafts=sched, good=None, amount=0,
                goal_row=f"▶ {target}", label=f"{target} (research)")


def crafting_schedule(steps, good, amount, total):
    """The MINIMAL, explicit workshop crafts a near-optimal player must make.

    A good is hand-crafted only to BOOTSTRAP -- when it is needed for a build /
    research cost (or the final goal) and no factory for it exists YET. Once its
    factory is built it is factory-supplied and never hand-crafted again. Crafts
    cascade to a recipe's inputs only if those, too, lack a factory. Returns an
    ordered list of (time, good, qty, why)."""
    have = set()                       # goods a built factory now supplies
    caps = set(BASE_CAPS)
    orders = []

    def craft_for(g, qty, t, why):
        if g in RAWS or g in have:
            return                     # harvested / factory-supplied -> no craft
        key = GOOD_RECIPE.get(g)
        if key is None:
            return
        inp, out, work, rcaps = RECIPES[key]
        if not rcaps <= caps:
            return                     # not workshop-craftable yet (factory-only)
        orders.append((t, g, qty, why))
        runs = -(-qty // out[g])       # integer ceil
        for h, amt in inp.items():
            craft_for(h, amt * runs, t, why)

    for kind, typ, t in steps:
        if kind == "build":
            for g, q in BUILD_COST[typ].items():
                craft_for(g, q, t, f"build {bname(typ)}")
            have |= BUILDING_OUTPUTS.get(typ, set())
        elif kind == "research":
            for g, q in CAP_COST.get(typ, {}).items():
                craft_for(g, q, t, f"research {typ}")
            caps.add(typ)
        elif kind == "wresearch":
            for g, q in WAREHOUSE_RESEARCH.get(typ, {}).get("cost", {}).items():
                craft_for(g, q, t, f"research {typ}")
        elif kind == "automate":
            for g, q in AUTOMATION_COST.items():
                craft_for(g, q, t, f"automate {bname(typ)}")
        elif kind == "upgrade":
            for g, q in UPGRADES[typ]["cost"].items():
                craft_for(g, q, t, f"upgrade {bname(typ[0])}")
    if good is not None:
        craft_for(good, amount, total, "assemble goal")     # final manual assembly

    # aggregate: one order per good per phase (the player batches a repeat count)
    agg = {}
    for t, g, qty, why in orders:
        k = (round(t, 3), g)
        agg[k] = (t, g, agg[k][2] + qty, agg[k][3]) if k in agg else (t, g, qty, why)
    # attach the workshop time each order costs: runs x work, serial through the
    # single workshop (this time is already inside the plan's total, via
    # afford_time for builds/research and amount/rate for the final assembly).
    out = []
    for t, g, qty, why in agg.values():
        inp, outs, work, _c = RECIPES[GOOD_RECIPE[g]]
        dur = -(-qty // outs[g]) * work
        out.append((t, g, qty, why, dur))
    return sorted(out, key=lambda o: (o[0], -o[4]))


def activity_density(steps, crafts, total, split=0.5):
    """Player actions per minute, early vs late half. Actions = builds +
    research + automations + workshop craft orders."""
    times = [s[2] for s in steps] + [c[0] for c in crafts]
    cut = total * split
    early = sum(1 for tt in times if tt < cut)
    em = (cut / 60.0) or 1e-9
    lm = ((total - cut) / 60.0) or 1e-9
    return early / em, (len(times) - early) / lm, len(times)


# ===========================================================================
# 8. REPORT + PLOTS
# ===========================================================================
def fmt(sec):
    if not np.isfinite(sec):
        return "   n/a   "
    m = sec / 60.0
    return f"{m:6.1f} min" if m < 60 else f"{m/60:5.2f} h ({m:5.0f}m)"


def _label(kind, typ):
    if kind == "build":
        return bname(typ)
    if kind in ("research", "wresearch"):
        return f"~research {typ}"
    if kind == "automate":
        return f"* automate {bname(typ)}"
    if kind == "upgrade":
        return f"^ upgrade {bname(typ[0])}: {UPGRADES[typ]['display']}"
    return typ


def report(res):
    steps, bs, total, crafts = res["steps"], res["buildings"], res["total"], res["crafts"]
    print("=" * 78)
    print("  12 STINKY STARKNIGHTS  --  pacing model (parsed from game source)")
    print("=" * 78)
    print(f"  {len(RECIPES)} recipes | {len(BUILDING_TYPES)} producing buildings | "
          f"{len(CAP_COST)} researchable capabilities | {len(FINISHED)} finished goods")
    if G["skipped"]:
        print(f"  skipped {len(G['skipped'])} incomplete recipe(s): "
              f"{', '.join(G['skipped'])}  (no work/outputs yet)")
    print(f"  Goal: {res['label']}")
    print()

    build_times = {s[1]: s[2] for s in steps if s[0] == "build"}
    fires = cutscene_timeline(build_times)

    print("-" * 78)
    print("  DISCOVERED OPTIMAL PLAN  (builds + research + automation)")
    print("-" * 78)
    for kind, typ, t in steps:
        tag = "   <- Jelly debut + merch challenge" if typ == STORY_GATE else ""
        print(f"    {_label(kind, typ):<36} @ {fmt(t)}{tag}")
    goal_line = (f"ASSEMBLE {res['amount']} {name(res['good'])}"
                 if res["good"] is not None else f"COMPLETE {res['label']}")
    print(f"    {goal_line:<36} @ {fmt(total)}")
    print()

    print("-" * 78)
    print("  WORKSHOP CRAFTING SCHEDULE  (the only items the player hand-crafts)")
    print("-" * 78)
    for t, g, qty, why, dur in crafts:
        print(f"    craft {qty:>4}x {name(g):<26} @ {fmt(t)}   "
              f"{dur/60:5.1f} min at bench   ({why})")
    if not crafts:
        print("    (none)")
    else:
        tot = sum(c[4] for c in crafts)
        print(f"    {'':>36}   total {tot/60:5.1f} min of workshop crafting "
              f"(serial; {tot/max(total,1)*100:.0f}% of the run)")
    print()

    early, late, n = activity_density(steps, crafts, total)
    n_build = sum(1 for s in steps if s[0] == "build")
    n_res = sum(1 for s in steps if s[0] == "research")
    n_auto = sum(1 for s in steps if s[0] == "automate")
    n_up = sum(1 for s in steps if s[0] == "upgrade")
    print("-" * 78)
    print("  PLAYER ACTIVITY  (density of actions = fun; want early >> late)")
    print("-" * 78)
    print(f"    {n_build} builds, {n_res} research, {n_up} upgrades, {n_auto} automations, "
          f"{len(crafts)} workshop crafts  ({n} actions total)")
    print(f"    density: early half {early:5.2f}/min   ->   late half {late:5.2f}/min")
    print()

    print("-" * 78)
    print("  CUTSCENE FLOOR  (parallel; gates story, does not pause the sim)")
    print("-" * 78)
    for label, s, e in fires:
        print(f"    {label:<24} {fmt(s)} -> {fmt(e)}")
    print()

    # Automation removes the worker cost, so the 12-worker cap stops binding:
    # show manual (worker-bound) vs fully-automated (idle-endgame) throughput.
    full_caps = set(ALL_CAPS)
    loadout = {c: 2 for c in BUILDING_TYPES}
    loadout["Warehouse"] = 1                 # required to make any challenge good
    all_auto = frozenset(BUILDING_TYPES)
    full_ups = frozenset(UPGRADES)           # every throughput upgrade researched
    print("-" * 78)
    print("  STEADY-STATE THROUGHPUT per finished good  (2x every building, all caps + upgrades)")
    print(f"  {'':30}{'manual (12 workers)':>22}{'fully automated':>20}")
    print("-" * 78)
    for g in FINISHED:
        man, bm = max_bundle_rate({g: 1.0}, loadout, full_caps, ups=full_ups)
        aut, ba = max_bundle_rate({g: 1.0}, loadout, full_caps, all_auto, full_ups)
        m = f"{man*60:8.3f}/min" if man > 1e-9 else " (no producer)"
        a = f"{aut*60:8.3f}/min" if aut > 1e-9 else " (no producer)"
        print(f"    {name(g):<28}{m:>20}{a:>20}   [auto: {ba}]")
    print("=" * 78)
    return fires


def make_plots(res, fires):
    steps, total, crafts = res["steps"], res["total"], res["crafts"]
    palette = {"build": "#23deff", "research": "#b060e0", "wresearch": "#b060e0",
               "automate": "#40c060", "goal": "#e0a030", "craft": "#e0782a",
               "upgrade": "#d8b020"}

    # One ROW PER type; a dot marks each event. Workshop CRAFT orders are folded
    # into the same timeline (orange) and rows are ordered by first-occurrence
    # TIME, so builds, research and hand-crafts interleave chronologically.
    events = {}
    def add_event(lab, t, kind):
        events.setdefault(lab, []).append((t, kind))
    for k, ty, t in steps:
        if k in ("research", "wresearch"):
            lab = f"research {ty}"
        elif k == "automate":
            lab = f"automate {bname(ty)}"
        elif k == "upgrade":
            lab = f"↑ {bname(ty[0])}: {UPGRADES[ty]['display']}"
        else:
            lab = bname(ty)
        add_event(lab, t, k)
    for t, g, qty, why, dur in crafts:
        add_event(f"⚒ craft {name(g)}", t, "craft")
    add_event(res["goal_row"], total, "goal")

    # Order rows by first-occurrence time. At equal times a craft precedes the
    # build/research it feeds (you craft the inputs, THEN the job completes), and
    # the goal marker stays last.
    def _rank(lab):
        kinds = {k for _, k in events[lab]}
        return 0 if "craft" in kinds else (2 if "goal" in kinds else 1)
    order = sorted(events, key=lambda lab: (min(t for t, _ in events[lab]),
                                            _rank(lab), lab))

    n = len(order)
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, max(5.0, 0.34 * n + 4.0)),
                                   gridspec_kw={"height_ratios": [3, 2]})
    yof = {lab: n - 1 - i for i, lab in enumerate(order)}   # first event at top
    for lab in order:
        evs = events[lab]
        y = yof[lab]
        xs = [t / 60.0 for t, _ in evs]
        if len(xs) > 1:
            ax1.hlines(y, min(xs), max(xs), color="#dddddd", lw=1, zorder=1)
        for t, k in evs:
            ax1.scatter(t / 60.0, y, color=palette[k], s=34, zorder=3)
    labels = [f"{lab}  ×{len(events[lab])}" if len(events[lab]) > 1 else lab
              for lab in order]
    ax1.set_yticks(list(yof.values())); ax1.set_yticklabels(labels, fontsize=8)
    ax1.set_ylim(-0.6, n - 0.4)
    d = [(s, e) for l, s, e in fires if "DEBUT" in l]
    if d:
        ax1.axvspan(d[0][0] / 60.0, d[0][1] / 60.0, color="#e0a030", alpha=0.15,
                    label="Jelly debut")
    ax1.set_xlabel("wall-clock minutes")
    ax1.set_title(f"Optimal path to {res['label']}")
    legend_handles = [Line2D([0], [0], marker="o", linestyle="none",
                             markerfacecolor=palette[k], markeredgecolor="none",
                             markersize=7, label=lab)
                      for k, lab in [("build", "build"), ("research", "research"),
                                     ("upgrade", "upgrade"), ("automate", "automate"),
                                     ("craft", "craft"), ("goal", "goal")]]
    ax1.legend(handles=legend_handles, fontsize=7, loc="upper right",
               ncol=6, framealpha=0.9)
    ax1.margins(x=0.02)
    ax1.grid(True, axis="x", alpha=0.3)

    # Panel 2: player-action density over time (builds + research + crafts / min).
    # The design goal is early-heavy (busy start) tapering to a calm late game.
    allt = sorted([s[2] for s in steps] + [c[0] for c in crafts])
    nb = 24
    edges = np.linspace(0, max(total, 1.0), nb + 1)
    counts, _ = np.histogram(allt, bins=edges)
    wmin = (total / nb) / 60.0 or 1e-9
    centers = ((edges[:-1] + edges[1:]) / 2) / 60.0
    ax2.bar(centers, counts / wmin, width=(total / nb) / 60.0 * 0.9,
            color="#6aa9c9", edgecolor="none")
    d = [(s, e) for l, s, e in fires if "DEBUT" in l]
    if d:
        ax2.axvspan(d[0][0] / 60.0, d[0][1] / 60.0, color="#e0a030", alpha=0.15)
    ax2.set_xlabel("wall-clock minutes"); ax2.set_ylabel("player actions / min")
    ax2.set_title("Player-action density over time (design goal: early-heavy)")
    ax2.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    out = Path(__file__).with_name("balance_model.png")
    fig.savefig(out, dpi=120)
    print(f"  wrote {out}")


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")     # item names may be non-ASCII
    except Exception:
        pass
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--good", default=GOAL_GOOD)
    ap.add_argument("--amount", type=int, default=GOAL_AMOUNT)
    ap.add_argument("--research", metavar="NAME",
                    help="benchmark reaching a Warehouse research, e.g. 'Meka Suit Integration'")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    if args.research:
        match = next((d for d in WAREHOUSE_RESEARCH
                      if d.lower() == args.research.lower()), None)
        if match is None:
            print(f"unknown research '{args.research}'. available: "
                  f"{', '.join(WAREHOUSE_RESEARCH)}", file=sys.stderr)
            return 1
        res = evaluate_research(match)
    else:
        good = args.good.upper()
        if good not in GOODS:
            print(f"unknown good '{good}'. finished: {', '.join(FINISHED)}", file=sys.stderr)
            return 1
        try:
            res = evaluate(good, args.amount)
        except RuntimeError as e:
            print(f"  !! {e}"); return 1

    fires = report(res)
    if not args.no_plots:
        make_plots(res, fires)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
