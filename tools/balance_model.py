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

The two balancing levers, both parsed and writeable:
  * LEVER 1 - building costs   (Catalog.gd)      : BUILD_COST_MULT / --apply
  * LEVER 2 - research costs    (Workshop.gd)     : RESEARCH_COST_MULT
(Per-building throughput upgrades -- the unwired work_scale/yield_scale
scaffolding -- are a FUTURE lever; not modelled until the game defines them.)

Model simplifications: travel = 0 (job system = <=12 concurrent tasks solved by
the LP); production is continuous flow between investment events (piecewise-linear
exact timings); cutscenes run in parallel and only gate story triggers.

Usage:
  python balance_model.py [--good JELLY_STANDEES] [--amount 50]
  python balance_model.py --balance 30 [--apply]     # tune build costs to 30 min
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


def _parse_float_const(text, cname, default):
    m = re.search(r"const\s+" + cname + r"\s*:\s*\w+\s*=\s*([\d.]+)", text)
    return float(m.group(1)) if m else default


def _parse_automation_cost(text):
    return {m.group(1): int(m.group(2)) for m in re.finditer(
        r"automation\.cost\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", text)}


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
                skipped=skipped)


G = load_game()
ITEMS, RECIPES, BUILDINGS, CATALOG = G["items"], G["recipes"], G["buildings"], G["catalog"]
RECIPE_BUILDING, RAW_SOURCE, BUILD_COST = G["recipe_building"], G["raw_source"], G["build_cost"]
RAWS, GOODS, FINISHED = G["raws"], G["goods"], G["finished"]
CAP_COST, CAP_PREREQ, BASE_CAPS = G["cap_cost"], G["cap_prereq"], G["base_caps"]
ALL_CAPS = BASE_CAPS | set(CAP_COST)
FACTORY_SPEEDUP = G["factory_speedup"]        # FactoryBuilding.BASE_WORK_SPEEDUP
EXTRACTION_SPEEDUP = G["extraction_speedup"]  # ExtractionBuilding.BASE_WORK_SPEEDUP
AUTOMATION_COST = G["automation_cost"]        # per-building Automation research cost

BUILDING_TYPES = sorted(set(RAW_SOURCE.values()) | set(RECIPE_BUILDING.values()))
CATALOG_BUILDINGS = [c for c in CATALOG if c != "Warehouse"]
_GOOD_INDEX = {g: i for i, g in enumerate(GOODS)}


def name(item):
    return ITEMS.get(item, item)


def bname(cls):
    b = BUILDINGS.get(cls)
    return b.display_name if b else cls


# ===========================================================================
# 3. LEVERS
# ===========================================================================
BUILD_COST_MULT = 1.0          # LEVER 1 (Catalog.gd)
RESEARCH_COST_MULT = 1.0       # LEVER 2 (Workshop.gd research)


# ===========================================================================
# 4. THE ALLOCATION LP  (max sustainable rate given buildings + workshop caps)
#    A recipe can run in the Workshop iff its capabilities are researched, or in
#    its factory building (which embodies the capability) once built.
# ===========================================================================
def _activities(caps):
    acts = []
    for r in RAWS:
        acts.append((f"manual:{r}", HARVEST_DURATION / HARVEST_AMOUNT, {r: 1.0}, "worker_only"))
        bt = RAW_SOURCE.get(r)
        if bt is not None:
            acts.append((f"extract:{r}", (HARVEST_DURATION / EXTRACTION_SPEEDUP),
                         {r: float(HARVEST_AMOUNT)}, ("building", bt)))
    for key, (inp, out, work, rcaps) in RECIPES.items():
        net = {g: float(out.get(g, 0) - inp.get(g, 0)) for g in set(inp) | set(out)}
        if rcaps <= caps:
            acts.append((f"workshop:{key}", work, net, "workshop"))
        bt = RECIPE_BUILDING.get(key)
        if bt is not None:
            acts.append((f"factory:{key}", work / FACTORY_SPEEDUP, net, ("building", bt)))
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
    return c, np.array(rows), labels, is_cap, cap_b, brow, supply0


_template_cache = {}
def _template(caps, auto):
    key = (frozenset(caps), frozenset(auto))
    if key not in _template_cache:
        _template_cache[key] = _build_template(_activities(caps), auto)
    return _template_cache[key]


def max_bundle_rate(target, buildings, caps, auto=frozenset()):
    c, A0, labels, is_cap, cap_b, brow, supply0 = _template(caps, auto)
    A = A0.copy()
    b = np.zeros(A.shape[0])
    b[0] = WORKERS; b[1] = WORKSHOPS
    for bt, ridx in brow.items():
        b[ridx] = float(buildings.get(bt, 0))
    for g, q in target.items():
        A[supply0 + _GOOD_INDEX[g], -1] = float(q)
    res = linprog(c, A_ub=A, b_ub=b, bounds=[(0, None)] * len(c), method="highs")
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


# ===========================================================================
# 5. THE OPTIMAL PLAYER  (greedy rollout over BUILD and RESEARCH investments;
#    a producibility pass researches the capabilities a goal actually requires)
# ===========================================================================
GOAL_GOOD = "PC_PC"            # build one Personal Computer (the endgame goal)
GOAL_AMOUNT = 1
FORCED_FIRST = ["Warehouse"]
STORY_GATE = "MechanicalComponentFactory"      # gates Jelly's debut + merch
COPY_CAP = 8

ACTIVE_CANDIDATES = list(CATALOG_BUILDINGS)
RELEVANT_CAPS = set()
RELEVANT_ITEMS = set()


def _relevant(good):
    """Closure of items on the way to `good` (including the build-cost chains of
    the buildings involved, the story gate, and the Warehouse). Returns:
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

    goal_items = closure({good} | set(BUILD_COST.get("Warehouse", {}))
                         | set(BUILD_COST.get(STORY_GATE, {})))
    items = closure(goal_items | set(AUTOMATION_COST))     # + automation chain

    cands = set()
    mand = set()
    for key, (_i, out, _w, rc) in RECIPES.items():
        if not any(o in items for o in out):
            continue
        if key in RECIPE_BUILDING:
            cands.add(RECIPE_BUILDING[key])
        else:
            mand |= rc                              # workshop-only -> must research
    for r in items:
        if r in RAW_SOURCE:
            cands.add(RAW_SOURCE[r])
    cands.add(STORY_GATE); cands.discard("Warehouse")

    caps, frontier = set(mand), set(mand)           # close research caps under prereqs
    while frontier:
        for p in CAP_PREREQ.get(frontier.pop(), ()):
            if p not in caps:
                caps.add(p); frontier.add(p)
    return ([c for c in CATALOG_BUILDINGS if c in cands], goal_items, caps - BASE_CAPS)


# The player's STATE is (buildings, caps, auto): building counts, the Workshop's
# researched capabilities, and the set of building TYPES that are automated.
def _skey(bs, caps, auto):
    return (tuple(sorted((k, v) for k, v in bs.items() if v > 0)),
            frozenset(caps), frozenset(auto))


def _addb(bs, k):
    out = dict(bs); out[k] = out.get(k, 0) + 1; return out


_rate_cache = {}
def rate(bs, caps, auto, good):
    key = (_skey(bs, caps, auto), good)
    if key not in _rate_cache:
        _rate_cache[key] = max_bundle_rate({good: 1.0}, bs, caps, auto)[0]
    return _rate_cache[key]


_afford_cache = {}
def afford_time(cost, bs, caps, auto):
    key = (_skey(bs, caps, auto), tuple(sorted(cost.items())))
    if key not in _afford_cache:
        lam, _b = max_bundle_rate(cost, bs, caps, auto)
        _afford_cache[key] = np.inf if lam <= 0 else 1.0 / lam
    return _afford_cache[key]


def _cap_cost(c):
    return {g: v * RESEARCH_COST_MULT for g, v in CAP_COST[c].items()}


def _auto_cost():
    return {g: v * RESEARCH_COST_MULT for g, v in AUTOMATION_COST.items()}


def _bcost(b):
    return {g: v * BUILD_COST_MULT for g, v in BUILD_COST[b].items()}


def _actions(bs, caps, auto):
    """Yield (kind, typ, nbs, ncaps, nauto, cost, action_time)."""
    for b in ACTIVE_CANDIDATES:
        if bs.get(b, 0) < COPY_CAP:
            yield ("build", b, _addb(bs, b), caps, auto, _bcost(b), CONSTRUCTION_TIME)
    for c in RELEVANT_CAPS:
        if c not in caps and CAP_PREREQ.get(c, set()) <= caps:
            yield ("research", c, bs, caps | {c}, auto, _cap_cost(c), RESEARCH_WORK)
    for bt in ACTIVE_CANDIDATES:                    # automate a built factory/extractor
        if bt in BUILDING_TYPES and bs.get(bt, 0) > 0 and bt not in auto:
            yield ("automate", bt, bs, caps, auto | {bt}, _auto_cost(), RESEARCH_WORK)


def make_produce_goal(good, amount):
    def finish(bs, caps, auto):
        r = rate(bs, caps, auto, good)
        return np.inf if r <= 0 else amount / r
    return finish


def remaining(bs, caps, auto, finish, memo):
    key = _skey(bs, caps, auto)
    if key in memo:
        return memo[key]
    best, best_step = finish(bs, caps, auto), None
    for kind, typ, nbs, ncaps, nauto, cost, atime in _actions(bs, caps, auto):
        aff = afford_time(cost, bs, caps, auto)
        if not np.isfinite(aff):
            continue
        val = aff + atime + finish(nbs, ncaps, nauto)
        if val < best - 1e-9:
            best, best_step = val, (nbs, ncaps, nauto, aff + atime)
    if best_step is None:
        memo[key] = finish(bs, caps, auto)
        return memo[key]
    nbs, ncaps, nauto, dt = best_step
    res = min(finish(bs, caps, auto), dt + remaining(nbs, ncaps, nauto, finish, memo))
    memo[key] = res
    return res


def greedy(finish, bs, caps, auto, t, steps):
    memo = {}
    while True:
        best_total, best = t + finish(bs, caps, auto), None
        for kind, typ, nbs, ncaps, nauto, cost, atime in _actions(bs, caps, auto):
            aff = afford_time(cost, bs, caps, auto)
            if not np.isfinite(aff):
                continue
            total = t + aff + atime + remaining(nbs, ncaps, nauto, finish, memo)
            if total < best_total - 1e-6:
                best_total, best = total, (kind, typ, nbs, ncaps, nauto, aff + atime)
        if best is None:
            return bs, caps, auto, t
        kind, typ, nbs, ncaps, nauto, dt = best
        bs, caps, auto, t = nbs, ncaps, nauto, t + dt
        steps.append((kind, typ, t))


def ensure_producible(good, bs, caps, auto, t, steps):
    """Make `good` producible at all by acquiring, cheapest-first, the unlocks
    that increase how many relevant items can be produced -- building a factory
    for recipes that have one, researching a capability for the workshop-only
    ones. (Automation never changes producibility, so it is skipped here.)"""
    def pcount(bs, caps):
        return sum(1 for it in RELEVANT_ITEMS if rate(bs, caps, auto, it) > 1e-9)

    while rate(bs, caps, auto, good) <= 1e-9:
        cur = pcount(bs, caps)
        best = fallback = None
        for kind, typ, nbs, ncaps, nauto, cost, atime in _actions(bs, caps, auto):
            if kind == "automate":
                continue
            aff = afford_time(cost, bs, caps, auto)
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
    return bs, caps, auto, t


def plan(good, amount):
    global ACTIVE_CANDIDATES, RELEVANT_CAPS, RELEVANT_ITEMS
    ACTIVE_CANDIDATES, RELEVANT_ITEMS, RELEVANT_CAPS = _relevant(good)

    bs, caps, auto, t, steps = {}, set(BASE_CAPS), set(), 0.0, []
    for b in FORCED_FIRST:
        t += afford_time(_bcost(b), bs, caps, auto) + CONSTRUCTION_TIME
        bs = _addb(bs, b); steps.append(("build", b, t))

    # Phase 1: race to the story gate.
    def gate_finish(bs, caps, auto):
        return afford_time(_bcost(STORY_GATE), bs, caps, auto) + CONSTRUCTION_TIME
    bs, caps, auto, t = greedy(gate_finish, bs, caps, auto, t, steps)
    if bs.get(STORY_GATE, 0) == 0:
        t += afford_time(_bcost(STORY_GATE), bs, caps, auto) + CONSTRUCTION_TIME
        bs = _addb(bs, STORY_GATE); steps.append(("build", STORY_GATE, t))

    # Phase 2: bootstrap producibility, then optimise (builds + automation).
    bs, caps, auto, t = ensure_producible(good, bs, caps, auto, t, steps)
    bs, caps, auto, t = greedy(make_produce_goal(good, amount), bs, caps, auto, t, steps)
    t += amount / rate(bs, caps, auto, good)
    return steps, bs, caps, auto, t


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
# 7. AUTONOMOUS BALANCER
# ===========================================================================
def evaluate(good, amount, build_cost_mult=1.0, research_cost_mult=1.0):
    global BUILD_COST_MULT, RESEARCH_COST_MULT
    save = (BUILD_COST_MULT, RESEARCH_COST_MULT)
    BUILD_COST_MULT, RESEARCH_COST_MULT = build_cost_mult, research_cost_mult
    try:
        steps, bs, caps, auto, total = plan(good, amount)
    finally:
        BUILD_COST_MULT, RESEARCH_COST_MULT = save
    gate = next((t for k, ty, t in steps if ty == STORY_GATE), np.nan)
    return dict(steps=steps, buildings=bs, caps=caps, auto=auto, total=total, gate=gate)


def balance_cost(good, amount, target_minutes):
    """Find the build-cost multiplier landing the goal at target_minutes.
    Total is ~affine in the multiplier -> fit two points, refine once."""
    target = target_minutes * 60.0
    y0 = evaluate(good, amount, 1.0)["total"]
    y1 = evaluate(good, amount, 2.0)["total"]
    slope = y1 - y0
    guess = max(0.05, 1.0 + (target - y0) / slope) if slope > 1e-9 else 1.0
    got = evaluate(good, amount, guess)["total"]
    if abs(got - target) > 5.0 and slope > 1e-9:
        guess = max(0.05, guess + (target - got) / slope)
        got = evaluate(good, amount, guess)["total"]
    return guess, got


def rewrite_catalog(mult, apply):
    path = GAME_ROOT / "scripts/globals/Catalog.gd"
    text = path.read_text(encoding="utf-8")
    changes = []

    def repl(m):
        new = max(1, round(int(m.group(3)) * mult))
        changes.append((m.group(2), int(m.group(3)), new))
        return f"{m.group(1)}{m.group(2)}] = {new}"

    new = re.sub(r"(\.cost\[Stockpile\.ItemType\.)(\w+)\]\s*=\s*(\d+)", repl, text)
    if apply:
        path.write_text(new, encoding="utf-8")
    return changes


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
    if kind == "research":
        return f"~research {typ}"
    if kind == "automate":
        return f"* automate {bname(typ)}"
    return typ


def report(good, amount):
    print("=" * 78)
    print("  12 STINKY STARKNIGHTS  --  pacing model (parsed from game source)")
    print("=" * 78)
    print(f"  {len(RECIPES)} recipes | {len(BUILDING_TYPES)} producing buildings | "
          f"{len(CAP_COST)} researchable capabilities | {len(FINISHED)} finished goods")
    if G["skipped"]:
        print(f"  skipped {len(G['skipped'])} incomplete recipe(s): "
              f"{', '.join(G['skipped'])}  (no work/outputs yet)")
    print(f"  Goal: {amount} x {name(good)}   (story gate: {bname(STORY_GATE)})")
    print()

    try:
        res = evaluate(good, amount)
    except RuntimeError as e:
        print(f"  !! {e}")
        return None, None
    steps, bs, total = res["steps"], res["buildings"], res["total"]
    build_times = {ty: t for k, ty, t in steps if k == "build"}
    fires = cutscene_timeline(build_times)

    print("-" * 78)
    print("  DISCOVERED OPTIMAL PLAN  (builds + research + automation)")
    print("-" * 78)
    for kind, typ, t in steps:
        tag = "   <- Jelly debut + merch challenge" if typ == STORY_GATE else ""
        print(f"    {_label(kind, typ):<36} @ {fmt(t)}{tag}")
    print(f"    {'PRODUCE ' + str(amount) + ' ' + name(good):<36} @ {fmt(total)}")
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
    all_auto = frozenset(BUILDING_TYPES)
    print("-" * 78)
    print("  STEADY-STATE THROUGHPUT per finished good  (2x every building, all caps)")
    print(f"  {'':30}{'manual (12 workers)':>22}{'fully automated':>20}")
    print("-" * 78)
    for g in FINISHED:
        man, bm = max_bundle_rate({g: 1.0}, loadout, full_caps)
        aut, ba = max_bundle_rate({g: 1.0}, loadout, full_caps, all_auto)
        m = f"{man*60:8.3f}/min" if man > 1e-9 else " (no producer)"
        a = f"{aut*60:8.3f}/min" if aut > 1e-9 else " (no producer)"
        print(f"    {name(g):<28}{m:>20}{a:>20}   [auto: {ba}]")
    print("=" * 78)
    return res, fires


def make_plots(good, amount, res, fires):
    steps, total = res["steps"], res["total"]
    palette = {"build": "#23deff", "research": "#b060e0", "automate": "#40c060",
               "goal": "#e0a030"}

    # One ROW PER type (a deep goal builds a type many times); a dot marks each
    # event along the row, so ~25 readable labels instead of ~150 overlapping.
    order, events = [], {}
    for k, ty, t in steps:
        lab = (f"research {ty}" if k == "research"
               else f"automate {bname(ty)}" if k == "automate" else bname(ty))
        if lab not in events:
            events[lab] = []; order.append(lab)
        events[lab].append((t, k))
    goal_lab = f"▶ {amount} {name(good)}"
    order.append(goal_lab); events[goal_lab] = [(total, "goal")]

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
    ax1.set_title(f"Optimal path to {amount} {name(good)} "
                  "(blue=build, purple=research, green=automate, orange=goal)")
    ax1.margins(x=0.02)
    ax1.grid(True, axis="x", alpha=0.3)

    mults = [0.5, 1.0, 2.0]      # kept short: a plan for a deep goal (PC) is slow
    ys2 = [evaluate(good, amount, m)["total"] / 60.0 for m in mults]
    ax2.plot(mults, ys2, "o-", color="#23deff", lw=2, label="time to goal")
    ax2.axhspan(60, 120, color="#23deff", alpha=0.12, label="target 1-2 h")
    ax2.set_xscale("log"); ax2.set_xlabel("build-cost multiplier (lever 1)")
    ax2.set_ylabel(f"time to {amount} {name(good)} (min)")
    ax2.set_title("Build-cost lever vs pacing")
    ax2.legend(fontsize=8); ax2.grid(True, alpha=0.3)
    fig.tight_layout()
    out = Path(__file__).with_name("balance_model.png")
    fig.savefig(out, dpi=120)
    print(f"  wrote {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--good", default=GOAL_GOOD)
    ap.add_argument("--amount", type=int, default=GOAL_AMOUNT)
    ap.add_argument("--balance", type=float, metavar="MIN")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    good = args.good.upper()
    if good not in GOODS:
        print(f"unknown good '{good}'. finished: {', '.join(FINISHED)}", file=sys.stderr)
        return 1

    if args.balance is not None:
        mult, got = balance_cost(good, args.amount, args.balance)
        print(f"To land {args.amount} x {name(good)} at ~{args.balance:.0f} min: "
              f"build-cost multiplier = {mult:.3f} (model: {got/60:.1f} min)")
        changes = rewrite_catalog(mult, apply=args.apply)
        preview = ", ".join(f"{name(i)} {o}->{n}" for i, o, n in changes[:5])
        print(f"  {len(changes)} catalog costs change: {preview} ...")
        print("  APPLIED to Catalog.gd" if args.apply else
              "  (dry run -- add --apply to write Catalog.gd)")
        return 0

    res, fires = report(good, args.amount)
    if res and not args.no_plots:
        make_plots(good, args.amount, res, fires)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
