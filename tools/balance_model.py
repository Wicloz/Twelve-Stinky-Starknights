#!/usr/bin/env python
"""
Continuous-time economy / pacing model + autonomous balancer for 12 Stinky
Starknights.

A "number go up" game (~1-2 h, PACED BY CUTSCENES). The whole recipe tree, build
costs, deposits, the research trees, the challenge/cutscene story AND THE MAP
ITSELF (world.tscn: every tile, deposit and Starknight) are PARSED from the Godot
source every run, so the model tracks the game as it grows.

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

EVERY action and constraint of a real playthrough is modelled (see the notes on
each section):
  * TRAVEL -- every Job is done by a Starknight who must WALK to the tile. Job
    stickiness is read straight off the source: manual harvest and Workshop
    orders re-post their job from INSIDE on_complete (the same knight keeps it,
    zero travel), while factories/extractors re-post a frame later (the knight
    has already reported idle and is re-assigned, so it pays travel every cycle
    whenever another job is waiting). See TRAVEL MODEL.
  * MAP -- tiles, deposits and placement rules from world.tscn + CatalogItem.
    allowed_deposits. Buildings compete for a finite number of sites; extractors
    are bound to their deposit's tiles (1 Hoshiumium tile, 2 Petrochemicals...);
    manual harvest only works on `workable` tiles and only where no building
    stands.
  * WORKER COST OF INVESTMENTS -- construction and research are Jobs too. They
    take a Starknight (travel + work) away from production, and they run in
    PARALLEL across buildings rather than one at a time.
  * STORY -- challenge goods (merch / steam engine / paint / PC parts) cannot be
    made until their cutscene chain has fired, and the buildings that make them
    are not even in the catalog until then. Cutscene durations/queueing come
    from Story.gd.
  * STARKNIGHT SPEED -- the Warehouse move-speed tree is a first-class action
    (it divides every travel time).

Remaining simplifications: production is continuous flow between investment
events (piecewise-linear exact timings); job PRIORITIES are not simulated (the
LP just prices worker-seconds); one representative travel time per building type
per colony size rather than a per-trip simulation.

Usage:
  python balance_model.py [--good JELLY_STANDEES] [--amount 50] [--no-plots]
                          [--travel-mode auto|churn|parked] [--no-story] [--passes N]
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
WORKSHOPS = 1                # one Workshop; ONE order at a time
HARVEST_DURATION = 1.0       # HexTile.HARVEST_DURATION
HARVEST_AMOUNT = 1           # HexTile.HARVEST_AMOUNT
RESEARCH_WORK = 60.0         # ResearchItem default work
CUTSCENE_GAP = 3.0           # Story.DELAY_BETWEEN_CUTSCENES
CUTSCENE_POLL = 1.0          # Story.CONDITION_POLL_INTERVAL (mean wait ~half)
TYPING_SPEED = 30.0          # Cutscene.typing_speed
MIN_CUTSCENE = 3.0           # Cutscene.min_duration default
# WORKERS, worker speeds, the map, construction work, EXTRACTION_SPEEDUP /
# FACTORY_SPEEDUP and AUTOMATION_COST are all parsed from source -- see load_game.

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
    """Per-building upgrades declared in each building's _upgrade_research() via
    FactoryBuilding's _output_upgrade()/_speed_upgrade()/_efficiency_upgrade()
    helpers. Returns {building_cls: [dict(var, kind, display, scale, cost,
    prereqs=[var,...])]}.  kind 'output' -> production_scale (bigger batch, x rate);
    'speed' -> work_scale (faster runs, x rate); 'efficiency' -> efficiency_scale
    (less input per batch). Effects multiply across tiers/chains (see _umul).

    Helper signature: _<k>_upgrade(slot, name, description, factor, cost, prereq?).
    Effects MULTIPLY (successive tiers and parallel chains stack)."""
    kinds = {"_output_upgrade": "output", "_speed_upgrade": "speed",
             "_efficiency_upgrade": "efficiency", "_yield_upgrade": "yield"}
    upgrades = {}
    for path in sorted(Path(building_dir).glob("*.gd")):
        text = pg.read(path)
        m = re.search(r"class_name\s+(\w+)", text)
        cls = m.group(1) if m else path.stem
        items = []
        for c in re.finditer(
                r"var\s+(\w+)\s*:=\s*(" + "|".join(kinds) + r")\s*\(", text):
            args = _split_call_args(text, c.end())
            if len(args) < 5:
                continue
            kind = kinds[c.group(2)]
            scale = float(eval(args[3].split("#")[0].strip(), {"__builtins__": {}}, {}))
            cost = {cm.group(1): int(cm.group(2)) for cm in re.finditer(
                r"Stockpile\.ItemType\.(\w+)\s*:\s*(\d+)", args[4])}
            # prereq arg (if any) is a var name or an array literal of var names
            prereqs = re.findall(r"\w+", args[5]) if len(args) >= 6 else []
            display = args[1].strip().strip('"')
            items.append(dict(var=c.group(1), kind=kind, display=display,
                              scale=scale, cost=cost, prereqs=prereqs))
        if items:
            upgrades[cls] = items
    return upgrades


def _parse_catalog_placement(text):
    """The placement fields production_graph drops: `work` (construction job
    duration), the FULL allowed_deposits list (NONE included -- it means "a plain
    tile"), and always_unlocked. building class -> dict."""
    out = {}
    for block in text.split("item = CatalogItem.new()"):
        scene = re.search(r'preload\("res://objects/buildings/(\w+)\.tscn"\)', block)
        if not scene:
            continue
        dep = re.search(r"allowed_deposits\s*=\s*\[([^\]]*)\]", block, re.S)
        work = re.search(r"item\.work\s*=\s*([\d.]+)", block)
        out[scene.group(1)] = dict(
            deposits=re.findall(r"ItemType\.(\w+)", dep.group(1)) if dep else [],
            work=float(work.group(1)) if work else 10.0,   # CatalogItem.work default
            always_unlocked=bool(re.search(r"always_unlocked\s*=\s*true", block)))
    return out


def _parse_challenges(stock_text):
    """Stockpile._register_challenges -> item -> dict(limit=int|None, shown=bool).

    A challenge item can only be produced while its challenge is ACTIVE: it is
    LOCKED until a cutscene calls start_challenge(), and goes COMPLETED (locked
    again) the moment cumulative production reaches `limit`.  Both states make
    Stockpile.is_unavailable_story_item() true, which pulls the item's recipes out
    of the Workshop and its buildings out of the catalog."""
    out = {}
    body = re.search(r"func _register_challenges\(\).*?(?=\nfunc )", stock_text, re.S)
    src = body.group(0) if body else stock_text
    for m in re.finditer(r"_challenges\[ItemType\.(\w+)\]\s*=\s*Challenge\.new\(([^)]*)\)", src):
        args = [a.strip() for a in m.group(2).split(",") if a.strip()]
        limit = None
        if args and args[0] not in ("false",):
            limit = int(args[0])
        out[m.group(1)] = dict(limit=limit,
                               shown=(len(args) < 2 or args[1] != "false"))
    return out


def _parse_cutscenes(story_text):
    """Story._define_cutscenes -> ordered list of dicts describing the cutscene
    DAG: var name, `after` predecessors, the trigger CONDITION (as a structured
    tuple we can evaluate against a plan), the on-screen DURATION, and any
    challenges the cutscene starts.

    Cutscenes are automatic: no player input ends them.  Story polls conditions
    every CONDITION_POLL_INTERVAL, waits DELAY_BETWEEN_CUTSCENES, then plays ONE
    at a time; a scene lasts max(text_chars / typing_speed, min_duration).  They
    do not pause the sim, but they gate every challenge, so they sit on the
    critical path of anything merch/PC related."""
    body = re.search(r"func _define_cutscenes\(\).*?(?=\nconst SAKANA)", story_text, re.S)
    src = body.group(0) if body else story_text
    scenes, order, cur = {}, [], None
    for raw in src.splitlines():
        line = raw.split("#", 1)[0]
        m = re.search(r"var\s+(\w+)\s*:=\s*Cutscene\.new\(\)", line)
        if m:
            cur = m.group(1)
            scenes[cur] = dict(var=cur, after=[], cond=None, min_duration=MIN_CUTSCENE,
                               chars=0, starts=[], unparsed=None)
            order.append(cur)
            continue
        if cur is None:
            continue
        s = scenes[cur]
        m = re.search(r"\.after\s*=\s*\[([^\]]*)\]", line)
        if m:
            s["after"] = re.findall(r"\w+", m.group(1))
        m = re.search(r"\.min_duration\s*=\s*(.+)", line)
        if m:
            try:
                s["min_duration"] = float(eval(m.group(1).strip(), {"__builtins__": {}}, {}))
            except Exception:
                pass
        # typing time counts the VISIBLE characters of every say() on the line
        # (speaker prefix + spoken line; the bbcode tags themselves don't count)
        for who, said in re.findall(r'say\([^,]+,\s*"([^"]*)",\s*"((?:[^"\\]|\\.)*)"', line):
            s["chars"] += len(who) + 2 + len(re.sub(r"\[/?[^\]]*\]", "", said))
        s["starts"] += re.findall(r"start_challenge\(Stockpile\.ItemType\.(\w+)\)", line)
        # conditions -- the handful of forms Story.gd actually uses
        m = re.search(r"Catalog\.has_finished_construction\((\w+)\)", line)
        if m:
            s["cond"] = ("built", m.group(1))
        m = re.search(r"Workshop\.has_capability\(Crafting\.Capabilities\.(\w+)\)", line)
        if m:
            s["cond"] = ("cap", m.group(1))
        m = re.search(r"Stockpile\.is_seen\(Stockpile\.ItemType\.(\w+)\)", line)
        if m:
            s["cond"] = ("seen", m.group(1))
        m = re.search(r"Stockpile\.get_cumulative\(Stockpile\.ItemType\.(\w+)\)\s*>=\s*(\d+)", line)
        if m:
            s["cond"] = ("cumulative", m.group(1), int(m.group(2)))
        m = re.search(r"Stockpile\.is_challenge_completed\(Stockpile\.ItemType\.(\w+)\)", line)
        if m:
            s["cond"] = ("challenge_done", m.group(1))
        # "have N of X (and M of Y ...) in the stockpile right now"
        held = re.findall(
            r"Stockpile\.get_amount\(Stockpile\.ItemType\.(\w+)\)\s*>=\s*(\d+)", line)
        if held:
            s["cond"] = ("hold", tuple((g, int(n)) for g, n in held))
        # anything else on a `return ...` line is a condition we cannot read; record
        # it so the model complains instead of silently treating it as "always true"
        if s["cond"] is None and line.strip().startswith("return "):
            s["unparsed"] = line.strip()
    for s in scenes.values():
        s["duration"] = max(s["chars"] / TYPING_SPEED, s["min_duration"])
    return [scenes[v] for v in order]


def _parse_world(path, item_enum):
    """world.tscn -> the actual MAP and crew: every tile (axial coords, pixel
    position, walkable/workable, deposit), the Starknights (count + individual
    move_speed) and the Workshop's tile.  Everything about placement caps and
    travel distance is derived from this."""
    text = pg.read(path)
    tiles, speeds, workshop = [], [], None
    for block in text.split("\n[node ")[1:]:
        head, _, body = block.partition("\n")
        if head.startswith('name="Tile='):
            def num(k, d=0.0):
                m = re.search(r"^" + k + r"\s*=\s*(-?[\d.]+)", body, re.M)
                return float(m.group(1)) if m else d
            def flag(k, d):
                m = re.search(r"^" + k + r"\s*=\s*(true|false)", body, re.M)
                return (m.group(1) == "true") if m else d
            p = re.search(r"^position\s*=\s*Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)", body, re.M)
            dep = int(num("deposit"))
            t = dict(q=int(num("q")), r=int(num("r")),
                     pos=(float(p.group(1)), float(p.group(2))) if p else (0.0, 0.0),
                     walkable=flag("walkable", True), workable=flag("workable", False),
                     deposit=item_enum[dep] if 0 <= dep < len(item_enum) else "NONE",
                     occupied=bool(re.search(r"^building\s*=\s*NodePath", body, re.M)))
            tiles.append(t)
            if re.search(r'^building\s*=\s*NodePath\("Workshop"\)', body, re.M):
                workshop = (t["q"], t["r"])
        elif head.startswith('name="Starknight'):
            m = re.search(r"^move_speed\s*=\s*([\d.]+)", body, re.M)
            if m:
                speeds.append(float(m.group(1)))
    return dict(tiles=tiles, speeds=speeds, workshop=workshop)


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
    placement = _parse_catalog_placement(cat)
    workconsts = _parse_work_constants(craft)
    cap_cost, cap_prereq, base_caps = _parse_workshop_research(wshop)
    warehouse_research = _parse_research_items(
        pg.read(GAME_ROOT / "objects/buildings/Warehouse.gd"))
    building_upgrades = _parse_building_upgrades(GAME_ROOT / "objects/buildings")
    challenges = _parse_challenges(stock)
    cutscenes = _parse_cutscenes(pg.read(GAME_ROOT / "scripts/globals/Story.gd"))
    world = _parse_world(GAME_ROOT / "world.tscn", pg.parse_enum(stock, "ItemType"))

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
    challenge_items = set(challenges)
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
                # factories and extraction sites charge DIFFERENT bills to automate
                automation_cost_by_base={
                    "FactoryBuilding": _parse_automation_cost(factory_src),
                    "ExtractionBuilding": _parse_automation_cost(extract_src)},
                warehouse_research=warehouse_research,
                building_upgrades=building_upgrades,
                challenge_items=challenge_items, challenges=challenges,
                cutscenes=cutscenes, placement=placement, world=world,
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
AUTOMATION_COST_BY_BASE = {k: v for k, v in G["automation_cost_by_base"].items() if v}
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


CHALLENGES = G["challenges"]                  # item -> {limit, shown}
CUTSCENES = G["cutscenes"]                    # the Story.gd cutscene DAG
PLACEMENT = G["placement"]                    # building -> {deposits, work, always_unlocked}
WORLD = G["world"]


# ===========================================================================
# 2b. THE MAP  (world.tscn): placement caps + travel times
#
# Every Job is done by a Starknight who WALKS to the tile, so the map is a hard
# constraint on both how many of a building can exist and how much worker time a
# job really costs.
#   * a building may only stand on a tile whose deposit is in its
#     allowed_deposits (CatalogItem.can_place_on), the tile must be walkable and
#     empty -- so extractors are capped by their deposit's tile count and every
#     plain factory competes for the same pool of blank tiles;
#   * an extractor yields ITS TILE's deposit (ExtractionBuilding.get_base_yield_
#     types), so a Pitmine on clay is a different producer from a Pitmine on sand
#     -- they are modelled as separate per-deposit variants sharing a tile pool;
#   * manual harvesting needs tile.workable and is switched off the moment a
#     building is placed there (CatalogItem.try_place_on), so hand-harvest and
#     extractors compete for the same tiles -- and deposits with no workable tile
#     (water, petrochemicals, hoshiumium) can NOT be hand-harvested at all.
# ===========================================================================
TILES = WORLD["tiles"]
WORKER_SPEEDS = WORLD["speeds"]
WORKERS = len(WORKER_SPEEDS) or 12
MEAN_SPEED = (sum(WORKER_SPEEDS) / len(WORKER_SPEEDS)) if WORKER_SPEEDS else 100.0
_TILE_AT = {(t["q"], t["r"]): t for t in TILES}
WORKSHOP_TILE = WORLD["workshop"]

_HEX_NEIGHBORS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]


def _walk_distances(source):
    """Dijkstra over WALKABLE tiles from `source`, in pixels -- exactly the cost
    Starknight.travel_time() measures (it sums the pixel length of the A* path
    and divides by speed)."""
    import heapq
    dist = {source: 0.0}
    pq = [(0.0, source)]
    while pq:
        d, cur = heapq.heappop(pq)
        if d > dist.get(cur, np.inf) + 1e-9:
            continue
        cx, cy = _TILE_AT[cur]["pos"]
        for dq, dr in _HEX_NEIGHBORS:
            nb = (cur[0] + dq, cur[1] + dr)
            t = _TILE_AT.get(nb)
            if t is None or not t["walkable"]:
                continue
            nd = d + ((t["pos"][0] - cx) ** 2 + (t["pos"][1] - cy) ** 2) ** 0.5
            if nd < dist.get(nb, np.inf) - 1e-9:
                dist[nb] = nd
                heapq.heappush(pq, (nd, nb))
    return dist


_FROM_WORKSHOP = _walk_distances(WORKSHOP_TILE) if WORKSHOP_TILE else {}
_PAIR_DIST = {}                                 # lazily filled per source tile


def _pair_dist(a, b):
    if a not in _PAIR_DIST:
        _PAIR_DIST[a] = _walk_distances(a)
    return _PAIR_DIST[a].get(b, np.inf)


def _usable(t):
    return t["walkable"] and not t["occupied"]


# Candidate sites, nearest to the Workshop first: a real player clusters the
# colony around the workshop, and the JobManager always hands a job to the
# CLOSEST idle Starknight, so nearest-first is also the optimistic ordering.
def _sites_for(deposit):
    ts = [(_FROM_WORKSHOP.get((t["q"], t["r"]), np.inf), (t["q"], t["r"]))
          for t in TILES if _usable(t) and t["deposit"] == deposit]
    return [c for d, c in sorted(ts) if np.isfinite(d)]


DEPOSIT_SITES = {}                              # deposit item -> [tile coords]
for _t in TILES:
    DEPOSIT_SITES.setdefault(_t["deposit"], None)
for _d in list(DEPOSIT_SITES):
    DEPOSIT_SITES[_d] = _sites_for(_d)
BLANK_SITES = DEPOSIT_SITES.get("NONE", [])     # plain tiles: the factory pool
WORKABLE_TILES = {}                             # deposit -> hand-harvestable tiles
for _t in TILES:
    if _t["workable"] and _usable(_t):
        WORKABLE_TILES[_t["deposit"]] = WORKABLE_TILES.get(_t["deposit"], 0) + 1

# Which deposits a building may stand on (NONE = a plain tile).
BUILDING_DEPOSITS = {cls: (p["deposits"] or ["NONE"]) for cls, p in PLACEMENT.items()}
CONSTRUCTION_WORK = {cls: p["work"] for cls, p in PLACEMENT.items()}


def site_cap(cls):
    """How many copies of `cls` the map can physically hold."""
    return sum(len(DEPOSIT_SITES.get(d, [])) for d in BUILDING_DEPOSITS.get(cls, ["NONE"]))


# --- TRAVEL MODEL ----------------------------------------------------------
# A Starknight is occupied for travel + duration, and the building it serves is
# blocked for the same stretch (_has_active_job spans the whole job).  Whether a
# recurring job actually costs travel is decided by WHERE the re-post happens:
#
#   * HexTile._on_harvested and Workshop._on_craft_complete re-post from INSIDE
#     the completion handler, i.e. during JobManager.complete(), BEFORE the
#     Starknight calls report_idle().  It is standing on the tile, travel_time is
#     0, and _fill_tier explicitly keeps a knight that is already on the job's
#     tile.  => manual harvest and Workshop orders are STICKY: no travel.
#   * FactoryBuilding/ExtractionBuilding only clear _has_active_job and re-post
#     on the NEXT _process frame.  By then the knight has already reported idle
#     and, if any other job is waiting, been sent off to it.  => building jobs
#     pay travel EVERY cycle once there is competition for workers ("churn"),
#     and pay nothing when the colony has idle knights to spare ("parked").
#
# Both regimes are real, so `--travel-mode auto` picks per solve: parked while
# the worker cap has slack, churn once it binds (which is the whole mid/late
# game).  Travel for a job at `site` is the mean walk from the rest of the
# colony, since the knight comes from wherever it last worked.
TRAVEL_MODE = "auto"


def _colony(nsites):
    """The tiles a colony of `nsites` buildings occupies: the workshop plus the
    nearest usable tiles (any kind) to it."""
    ts = sorted(((_FROM_WORKSHOP.get((t["q"], t["r"]), np.inf), (t["q"], t["r"]))
                 for t in TILES if _usable(t)), key=lambda x: x[0])
    out = [WORKSHOP_TILE] if WORKSHOP_TILE else []
    return out + [c for d, c in ts[:max(nsites, 1)] if np.isfinite(d)]


_travel_cache = {}
def travel_seconds(cls, copies, nsites, speed_scale):
    """Seconds of walking to reach a job at the `copies` nearest sites of `cls`.

    NOT the colony average: JobManager._fill_tier hands each job to its CLOSEST
    idle Starknight, and travel is only charged at all in the churn regime -- which
    is precisely when many jobs are posted and knights are circulating inside a
    dense cluster.  The knight who takes a job therefore comes from a NEIGHBOURING
    tile, so the honest cost is the hop from the nearest other occupied site.  A
    genuinely remote site (the lone hoshiumium tile) still prices as remote,
    because its nearest neighbour is far."""
    # bucket both axes: travel changes slowly with colony size, and a key per
    # exact building multiset would give the LP template cache a fresh entry for
    # every state the planner touches
    copies = next(c for c in (1, 2, 4, 8, 16) if copies <= c or c == 16)
    nsites = next(nn for nn in (4, 8, 16, 32, 64) if nsites <= nn or nn == 64)
    key = (cls, copies, nsites)
    if key not in _travel_cache:
        colony = _colony(nsites)
        if cls == "Workshop":
            sites = [WORKSHOP_TILE] if WORKSHOP_TILE else []
        else:
            sites = []
            for d in BUILDING_DEPOSITS.get(cls, ["NONE"]):
                sites += DEPOSIT_SITES.get(d, [])
        sites = sorted(sites, key=lambda c: _FROM_WORKSHOP.get(c, np.inf))[:max(copies, 1)]
        if not sites or not colony:
            _travel_cache[key] = 0.0
        else:
            hops = []
            for b in sites:
                near = [_pair_dist(a, b) for a in colony
                        if a != b and np.isfinite(_pair_dist(a, b))]
                if near:
                    hops.append(min(near))
            _travel_cache[key] = (sum(hops) / len(hops) / MEAN_SPEED) if hops else 0.0
    return _travel_cache[key] / max(speed_scale, 1e-9)


# The Warehouse move-speed tree is the only lever on travel, so it is a
# first-class action.  display name -> the speed_scale it sets.
SPEED_RESEARCH = {}
_wh_src = pg.read(GAME_ROOT / "objects/buildings/Warehouse.gd")
for _m in re.finditer(r"var\s+(\w+)\s*:=\s*ResearchItem\.new\(\)", _wh_src):
    _blk = _wh_src[_m.end():]
    _nxt = re.search(r"var\s+\w+\s*:=\s*ResearchItem\.new\(\)", _blk)
    _blk = _blk[:_nxt.start()] if _nxt else _blk
    _disp = re.search(r'\.display_name\s*=\s*"([^"]*)"', _blk)
    _scale = re.search(r"Starknight\.speed_scale\s*=\s*([\d.]+)", _blk)
    if _disp and _scale:
        SPEED_RESEARCH[_disp.group(1)] = float(_scale.group(1))


def speed_scale_of(spd):
    """speed_scale after completing the set `spd` of Warehouse speed researches
    (they overwrite rather than multiply, so the best one wins)."""
    return max([1.0] + [SPEED_RESEARCH[d] for d in spd if d in SPEED_RESEARCH])


def _umul(ups):
    """Per-building-type upgrade multipliers from a set of researched upgrade ids,
    as {bt: (production, work, efficiency)}. Each upgrade MULTIPLIES its lever, so
    a lever's value is the product of that building's completed upgrades of that
    kind. production (bigger batch) and work (faster) both scale the building's net
    output rate per instance at no extra worker/building cost; efficiency divides
    only the INPUT a batch consumes (relieving upstream), so it is applied to the
    input side of the net vector, not to output (see _activities)."""
    by_bt = {}
    for uid in ups:
        u = UPGRADES[uid]
        m = by_bt.setdefault(u["bt"], [1.0, 1.0, 1.0])   # [production/yield, work, efficiency]
        # extractor 'yield' scales harvest amount, i.e. output -> same slot as 'output'
        idx = {"output": 0, "yield": 0, "speed": 1, "efficiency": 2}[u["kind"]]
        m[idx] *= u["scale"]
    return {bt: (m[0], m[1], m[2]) for bt, m in by_bt.items()}


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

# --- BUILDING VARIANTS -----------------------------------------------------
# An extractor yields its TILE's deposit, so one class can be several different
# producers.  A variant key is "Class" for a factory and "Class@DEPOSIT" for an
# extractor; upgrades, automation and construction cost stay per CLASS.
EXTRACTOR_CLASSES = sorted(cls for cls, b in BUILDINGS.items()
                           if b.base == "ExtractionBuilding" and cls in CATALOG)
VARIANT_YIELD = {}                      # variant -> harvested item
VARIANT_DEPOSIT = {}                    # variant -> the deposit tile it sits on
for _cls in EXTRACTOR_CLASSES:
    _over = BUILDINGS[_cls].harvest_override
    for _d in BUILDING_DEPOSITS.get(_cls, ["NONE"]):
        if not DEPOSIT_SITES.get(_d):
            continue                    # the map has no such tile -> impossible
        _item = _over[0] if _over else _d
        if _item == "NONE":
            continue
        _v = f"{_cls}@{_d}"
        VARIANT_YIELD[_v] = _item
        VARIANT_DEPOSIT[_v] = _d


def vclass(v):
    """The building class behind a variant key."""
    return v.split("@", 1)[0]


def vdeposit(v):
    return VARIANT_DEPOSIT.get(v, "NONE")


RAW_SOURCE = {}                          # item -> [variants that produce it]
for _v, _item in VARIANT_YIELD.items():
    RAW_SOURCE.setdefault(_item, []).append(_v)

BUILDING_TYPES = sorted(set(VARIANT_YIELD) | set(RECIPE_BUILDING.values()))
FACTORY_BUILDINGS = set(RECIPE_BUILDING.values())
CATALOG_BUILDINGS = [v for v in BUILDING_TYPES if v != "Warehouse"]
_GOOD_INDEX = {g: i for i, g in enumerate(GOODS)}
# Deposits with no workable tile can never be hand-harvested -- water,
# petrochemicals and hoshiumium need their building or they do not exist.
HAND_HARVESTABLE = {d for d, n in WORKABLE_TILES.items() if n > 0}


def name(item):
    return ITEMS.get(item, item)


def bname(v):
    b = BUILDINGS.get(vclass(v))
    disp = b.display_name if b else vclass(v)
    return f"{disp} ({name(vdeposit(v))})" if "@" in v and \
        len(BUILDING_DEPOSITS.get(vclass(v), [])) > 1 else disp


def site_pool_free(bs, v):
    """Copies of variant `v` the map can still take, given what is already built:
    every building standing on a deposit competes for that deposit's tiles."""
    d = vdeposit(v)
    used = sum(n for k, n in bs.items() if vdeposit(k) == d)
    return max(0, len(DEPOSIT_SITES.get(d, [])) - used)


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
def _activities(caps, unlocked, umul, auto, travel):
    """One activity per way of doing work.  The LP variable is OCCUPANCY (how many
    workers/buildings are continuously devoted to it), so an activity's `dur` is
    its full CYCLE time -- travel included -- and its rate is net/dur.

    `unlocked` = the challenge items whose challenge is currently ACTIVE.  Any
    recipe that touches a challenge item outside that set does not exist yet
    (Workshop._on_challenge_updated / Catalog.get_unlocked_buildings).
    `travel` = {variant: seconds}, already 0 for the sticky/automated cases."""
    def gated(inp, out):
        return any(g in CHALLENGE_ITEMS and g not in unlocked
                   for g in set(inp) | set(out))

    acts = []
    for r in RAWS:
        # hand-harvest: HexTile._on_harvested re-posts the job from inside the
        # completion handler, so the same Starknight keeps the tile -- no travel.
        if r in HAND_HARVESTABLE:
            acts.append((f"manual:{r}", HARVEST_DURATION / HARVEST_AMOUNT,
                         {r: 1.0}, ("tile", r)))
        for v in RAW_SOURCE.get(r, ()):
            cls = vclass(v)
            yld, wmul, _e = umul.get(cls, (1.0, 1.0, 1.0))   # yield x amount; speed / dur
            dur = (HARVEST_DURATION / EXTRACTION_SPEEDUP) / wmul + travel.get(v, 0.0)
            acts.append((f"extract:{v}", dur,
                         {r: float(HARVEST_AMOUNT) * yld}, ("building", v)))
    for key, (inp, out, work, rcaps) in RECIPES.items():
        if gated(inp, out):
            continue
        net = {g: float(out.get(g, 0) - inp.get(g, 0)) for g in set(inp) | set(out)}
        if rcaps <= caps:
            # Workshop._on_craft_complete re-posts too -> a repeat order is sticky.
            acts.append((f"workshop:{key}", work, net, "workshop"))
        bt = RECIPE_BUILDING.get(key)
        if bt is not None:
            prod, wmul, eff = umul.get(bt, (1.0, 1.0, 1.0))   # per-building upgrades
            if prod == 1.0 and eff == 1.0:
                fnet = net
            else:                               # output x prod; input x prod / eff
                # FactoryBuilding._try_consume uses ceili() on the input
                fnet = {g: out.get(g, 0) * prod - np.ceil(inp.get(g, 0) * prod / eff)
                        for g in set(inp) | set(out)}
            dur = work / FACTORY_SPEEDUP / wmul + travel.get(bt, 0.0)
            acts.append((f"factory:{key}", dur, fnet, ("building", bt)))
    return acts


def _build_template(acts, auto):
    """`auto` = set of building types that are AUTOMATED. An automated building's
    runs post no Job, so they cost NO worker -- their coefficient in the worker
    constraint is 0 (they are still capped by building count / concurrency).

    Rows come back with a b-vector filled in by _solve: worker cap, the single
    Workshop, one row per building variant (its copies), one per hand-harvestable
    deposit (its free WORKABLE tiles), then the goods balance."""
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
            if isinstance(cap, tuple) and cap[0] == "building" and cap[1] == bt:
                row[i] = 1.0; used = True
        if used:
            brow[bt] = len(rows); add(row, bt, True, bt)
    # hand-harvest is capped by free WORKABLE tiles: one job per tile, and a tile
    # under a building is not harvestable at all (CatalogItem.try_place_on).
    trow = {}
    for r in sorted(HAND_HARVESTABLE):
        row = np.zeros(n + 1); used = False
        for i, (nm, dur, net, cap) in enumerate(acts):
            if isinstance(cap, tuple) and cap[0] == "tile" and cap[1] == r:
                row[i] = 1.0; used = True
        if used:
            trow[r] = len(rows); add(row, f"workable:{name(r)}", True, None)
    supply0 = len(rows)
    for g in GOODS:
        row = np.zeros(n + 1)
        for i, (nm, dur, net, cap) in enumerate(acts):
            if g in net:
                row[i] = -net[g] / dur
        add(row, f"supply:{g}", False)
    return acts, c, np.array(rows), labels, is_cap, cap_b, brow, trow, supply0


_template_cache = {}
def _template(caps, auto, unlocked, umul, travel):
    key = (frozenset(caps), frozenset(auto), frozenset(unlocked),
           tuple(sorted(umul.items())), tuple(sorted(travel.items())))
    if key not in _template_cache:
        _template_cache[key] = _build_template(
            _activities(caps, unlocked, umul, auto, travel), auto)
    return _template_cache[key]


# Worker-seconds per second that construction and research Jobs are eating out of
# the crew.  Solved for as a fixed point over the whole plan (see run_plan): those
# Jobs are real Jobs with real Starknights, so production has to make do with what
# is left.
OVERHEAD_WORKERS = 0.0


def _travel_map(buildings, spd, auto):
    """Seconds of walking per job, per building variant.  0 for automated
    buildings (their runs are timers, no Job at all) and 0 in the `parked`
    regime, where idle knights let a building's own worker re-take its post."""
    if TRAVEL_MODE == "parked":
        return {}
    nsites = max(1, sum(buildings.values()))
    scale = speed_scale_of(spd)
    out = {}
    for v, count in buildings.items():
        if count <= 0 or v in auto or vclass(v) in auto:
            continue
        t = travel_seconds(vclass(v), count, nsites, scale)
        if t > 0:
            out[v] = round(t, 1)
    return out


def _tile_caps(buildings):
    """Workable tiles still free for hand-harvest, per raw: buildings standing on
    a deposit take those tiles out of the pool."""
    caps = {}
    for r, total in WORKABLE_TILES.items():
        used = sum(n for k, n in buildings.items() if vdeposit(k) == r)
        caps[r] = float(max(0, total - used))
    return caps


def _solve(target, buildings, caps, auto, ups, spd=frozenset(), unlocked=None):
    """Solve the LP; return (linprog result, acts, labels, is_cap, cap_b, b)."""
    if unlocked is None:
        unlocked = CHALLENGE_ITEMS            # story ignored (--no-story)
    travel = _travel_map(buildings, spd, auto)
    acts, c, A0, labels, is_cap, cap_b, brow, trow, supply0 = _template(
        caps, auto, unlocked, _umul(ups), travel)
    A = A0.copy()
    b = np.zeros(A.shape[0])
    b[0] = max(1.0, WORKERS - OVERHEAD_WORKERS); b[1] = WORKSHOPS
    for bt, ridx in brow.items():
        b[ridx] = float(buildings.get(bt, 0))
    tc = _tile_caps(buildings)
    for r, ridx in trow.items():
        b[ridx] = tc.get(r, 0.0)
    for g, q in target.items():
        A[supply0 + _GOOD_INDEX[g], -1] = float(q)
    res = linprog(c, A_ub=A, b_ub=b, bounds=[(0, None)] * len(c), method="highs")

    # TRAVEL REGIME.  Building jobs only lose their worker (and so pay travel) when
    # somebody else is waiting for one.  In `auto` mode, solve with travel charged
    # and fall back to the parked (travel-free) solve when the crew still has
    # slack -- i.e. when nobody was competing for the knight in the first place.
    if TRAVEL_MODE == "auto" and travel and res.success:
        used = float(A0[0][:-1] @ res.x[:-1])
        if used < b[0] - 1e-6:
            acts2, c2, A2, labels2, is_cap2, cap_b2, brow2, trow2, supply2 = _template(
                caps, auto, unlocked, _umul(ups), {})
            A2 = A2.copy()
            b2 = np.zeros(A2.shape[0])
            b2[0] = b[0]; b2[1] = WORKSHOPS
            for bt, ridx in brow2.items():
                b2[ridx] = float(buildings.get(bt, 0))
            for r, ridx in trow2.items():
                b2[ridx] = tc.get(r, 0.0)
            for g, q in target.items():
                A2[supply2 + _GOOD_INDEX[g], -1] = float(q)
            res2 = linprog(c2, A_ub=A2, b_ub=b2, bounds=[(0, None)] * len(c2),
                           method="highs")
            if res2.success and float(A2[0][:-1] @ res2.x[:-1]) < b2[0] - 1e-6:
                return res2, acts2, labels2, is_cap2, cap_b2, b2
    return res, acts, labels, is_cap, cap_b, b


def max_bundle_rate(target, buildings, caps, auto=frozenset(), ups=frozenset(),
                    spd=frozenset(), unlocked=None):
    res, acts, labels, is_cap, cap_b, b = _solve(target, buildings, caps, auto,
                                                 ups, spd, unlocked)
    if not res.success:
        return 0.0, "infeasible"
    lam = res.x[-1]
    marg = res.ineqlin.marginals
    binding, best = "unconstrained", 0.0
    for j in range(len(labels)):
        if is_cap[j] and marg[j] < best - 1e-9 and b[j] > 0:
            bt = cap_b[j]
            binding = labels[j] if bt is None else f"{bname(bt)} x{int(b[j])}"
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
STORY_GATE = "MechanicalComponentFactory"      # the build that triggers the debut

ACTIVE_CANDIDATES = list(CATALOG_BUILDINGS)
RELEVANT_CAPS = set()
RELEVANT_ITEMS = set()

# item -> the wall-clock second its challenge goes ACTIVE (np.inf = never).
# Recomputed from the plan's own event times by run_plan()'s fixed point.
STORY_UNLOCK = {}
USE_STORY = True
# Each pass re-plans from scratch (the LP caches depend on both feedbacks), so
# this is the model's main runtime knob.  2 already gets the story clock and the
# overhead in; 3-4 only polishes them.
MAX_FIXED_POINT_PASSES = 5


def variant_items(v):
    """Every item a building type produces or consumes -- what Catalog checks
    against the story lock before it will even show the building."""
    if v in VARIANT_YIELD:
        return {VARIANT_YIELD[v]}
    out = set()
    for key, bt in RECIPE_BUILDING.items():
        if bt == v:
            inp, o, _w, _c = RECIPES[key]
            out |= set(inp) | set(o)
    return out


def story_floor(items):
    """The earliest second at which every challenge item in `items` is ACTIVE."""
    if not USE_STORY:
        return 0.0
    ts = [STORY_UNLOCK.get(g, np.inf) for g in items if g in CHALLENGE_ITEMS]
    return max(ts) if ts else 0.0


def story_prerequisites(items):
    """Items and buildings the STORY needs before `items` can be made at all.

    Walking the cutscene DAG backwards from whichever scene calls start_challenge
    for a challenge item picks up its conditions -- and those conditions are real
    production goals: the coffee challenge only starts after a Jelly Standee has
    been SEEN, so a coffee run has to stand up the standee line even though
    standees are nowhere in coffee's recipe tree."""
    by_var = {c["var"]: c for c in CUTSCENES}
    want = {v for c in CUTSCENES for i in c["starts"] if i in items for v in (c["var"],)}
    seen_v, need_items, need_built, need_caps = set(), set(), set(), set()
    while want:
        v = want.pop()
        if v in seen_v or v not in by_var:
            continue
        seen_v.add(v)
        cs = by_var[v]
        want |= set(cs["after"])
        cond = cs["cond"]
        if not cond:
            continue
        if cond[0] in ("seen", "cumulative", "challenge_done"):
            need_items.add(cond[1])
        elif cond[0] == "hold":
            need_items |= {g for g, _n in cond[1]}
        elif cond[0] == "built":
            need_built.add(cond[1])
        elif cond[0] == "cap":
            need_caps.add(cond[1])
    return need_items, need_built, need_caps


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
                for v in RAW_SOURCE.get(g, ()):
                    for ci in BUILD_COST.get(vclass(v), {}):
                        if ci not in items:
                            items.add(ci); changed = True
            for key, (_i, out, _w, _c) in RECIPES.items():
                if key in RECIPE_BUILDING and any(o in items for o in out):
                    for ci in BUILD_COST.get(RECIPE_BUILDING[key], {}):
                        if ci not in items:
                            items.add(ci); changed = True
        return items

    seed_items = set(seed_items)
    if USE_STORY:                       # the story's own preconditions are goals too
        for _ in range(4):
            need_items, need_built, _need_caps = story_prerequisites(seed_items)
            grown = seed_items | need_items
            for cls in need_built:
                grown |= set(BUILD_COST.get(cls, {}))
                for key, bt in RECIPE_BUILDING.items():
                    if bt == cls:
                        grown |= set(RECIPES[key][1])
            if grown == seed_items:
                break
            seed_items = grown
    goal_items = closure(seed_items | set(BUILD_COST.get("Warehouse", {})))

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
            cands |= set(RAW_SOURCE.get(r, ()))
        cands.discard("Warehouse")
        caps, frontier = set(mand), set(mand)       # close research caps under prereqs
        while frontier:
            for p in CAP_PREREQ.get(frontier.pop(), ()):
                if p not in caps:
                    caps.add(p); frontier.add(p)
        return cands, caps - BASE_CAPS

    # Fold in the automation chain, the research-cost chains of the caps the goal
    # needs, AND the per-building UPGRADE costs, iterating to a fixpoint, so
    # factory-able research/automation/upgrade inputs get their factory built
    # rather than being hand-crafted avoidably. Without the upgrade costs, a
    # narrow goal leaves late materials (power cells, actuators) unreachable and
    # every capstone silently unaffordable -- so the optimiser never sees them.
    auto_items = (set().union(*AUTOMATION_COST_BY_BASE.values())
                  if AUTOMATION_COST_BY_BASE else set(AUTOMATION_COST))
    items = closure(set(goal_items) | auto_items)
    cands, caps = derive(items)
    for _ in range(8):
        seed = set(items)
        for c in caps:
            seed |= set(CAP_COST.get(c, {}))
        for bt in cands:
            for u in BUILDING_UPGRADES.get(vclass(bt), ()):
                seed |= set(u["cost"])
        for d in SPEED_RESEARCH:                # the move-speed tree is on the table
            seed |= set(WAREHOUSE_RESEARCH.get(d, {}).get("cost", {}))
        new_items = closure(seed)
        if new_items == items:
            break
        items = new_items
        cands, caps = derive(items)
    return ([c for c in CATALOG_BUILDINGS if c in cands], goal_items, caps)


# The player's STATE is (buildings, caps, auto, ups, spd): building counts, the
# Workshop's researched capabilities, the automated building types, the completed
# per-building upgrades, and the completed Warehouse move-speed researches.
def _skey(bs, caps, auto, ups, spd):
    return (tuple(sorted((k, v) for k, v in bs.items() if v > 0)),
            frozenset(caps), frozenset(auto), frozenset(ups), frozenset(spd))


def _addb(bs, k):
    out = dict(bs); out[k] = out.get(k, 0) + 1; return out


_rate_cache = {}
def rate(bs, caps, auto, ups, spd, good):
    key = (_skey(bs, caps, auto, ups, spd), good)
    if key not in _rate_cache:
        _rate_cache[key] = max_bundle_rate({good: 1.0}, bs, caps, auto, ups, spd)[0]
    return _rate_cache[key]


_afford_cache = {}
def afford_time(cost, bs, caps, auto, ups, spd):
    key = (_skey(bs, caps, auto, ups, spd), tuple(sorted(cost.items())))
    if key not in _afford_cache:
        lam, _b = max_bundle_rate(cost, bs, caps, auto, ups, spd)
        _afford_cache[key] = np.inf if lam <= 0 else 1.0 / lam
    return _afford_cache[key]


def _cap_cost(c):
    return {g: v * RESEARCH_COST_MULT for g, v in CAP_COST[c].items()}


def _auto_cost(v):
    """Automation cost: FactoryBuilding and ExtractionBuilding charge different
    bills for it, so read the one that belongs to this building's base class."""
    src = AUTOMATION_COST_BY_BASE.get(BUILDINGS[vclass(v)].base if vclass(v) in BUILDINGS
                                      else "FactoryBuilding", AUTOMATION_COST)
    return {g: n * RESEARCH_COST_MULT for g, n in src.items()}


def _upgrade_cost(uid):
    return {g: v * RESEARCH_COST_MULT for g, v in UPGRADES[uid]["cost"].items()}


def _wcost(d):
    return {g: v * RESEARCH_COST_MULT
            for g, v in WAREHOUSE_RESEARCH[d]["cost"].items()}


def _bcost(b):
    return dict(BUILD_COST[vclass(b)])


def _job_time(kind, typ, bs, spd):
    """Wall-clock of the JOB an investment posts: a Starknight has to walk there
    and then work.  Construction work comes from CatalogItem.work (the Starfall
    Site is 60s, everything else 10s); research is ResearchItem.work."""
    nsites = max(1, sum(bs.values()))
    scale = speed_scale_of(spd)
    if kind == "build":
        walk = travel_seconds(vclass(typ), bs.get(typ, 0) + 1, nsites, scale)
        return CONSTRUCTION_WORK.get(vclass(typ), 10.0) + walk
    site = {"upgrade": lambda: typ[0], "automate": lambda: vclass(typ),
            "research": lambda: "Workshop"}.get(kind, lambda: "Warehouse")()
    walk = travel_seconds(site, 1, nsites, scale)
    return RESEARCH_WORK + walk


def _actions(bs, caps, auto, ups, spd):
    """Yield (kind, typ, nbs, ncaps, nauto, nups, nspd, cost, job_time).

    Copy counts are capped by the MAP, not by an arbitrary number: a variant can
    only be built while its deposit still has a free tile, and every plain
    factory competes for the same pool of blank tiles."""
    for b in ACTIVE_CANDIDATES:
        if site_pool_free(bs, b) > 0:
            yield ("build", b, _addb(bs, b), caps, auto, ups, spd, _bcost(b),
                   _job_time("build", b, bs, spd))
    for c in RELEVANT_CAPS:
        if c not in caps and CAP_PREREQ.get(c, set()) <= caps:
            yield ("research", c, bs, caps | {c}, auto, ups, spd, _cap_cost(c),
                   _job_time("research", c, bs, spd))
    for bt in ACTIVE_CANDIDATES:                    # automate a built factory/extractor
        if bs.get(bt, 0) > 0 and bt not in auto:
            yield ("automate", bt, bs, caps, auto | {bt}, ups, spd, _auto_cost(bt),
                   _job_time("automate", bt, bs, spd))
    for bt in ACTIVE_CANDIDATES:                    # per-building throughput upgrade
        if bs.get(bt, 0) <= 0:
            continue
        cls = vclass(bt)
        for u in BUILDING_UPGRADES.get(cls, ()):
            uid = (cls, u["var"])
            if uid in ups:
                continue
            if all((cls, p) in ups for p in u["prereqs"]):
                yield ("upgrade", uid, bs, caps, auto, ups | {uid}, spd,
                       _upgrade_cost(uid), _job_time("upgrade", uid, bs, spd))
    # the Warehouse move-speed tree: the only thing that shortens TRAVEL, which is
    # most of a job's cost once the crew is busy
    if bs.get("Warehouse", 0) > 0:
        for d, scale in SPEED_RESEARCH.items():
            if d in spd:
                continue
            if all(p in spd for p in WAREHOUSE_RESEARCH[d]["prereqs"]):
                yield ("speed", d, bs, caps, auto, ups, spd | {d}, _wcost(d),
                       _job_time("speed", d, bs, spd))


def make_produce_goal(good, amount):
    def finish(bs, caps, auto, ups, spd):
        r = rate(bs, caps, auto, ups, spd, good)
        return np.inf if r <= 0 else amount / r
    return finish


def _step_time(kind, typ, aff, jt, t):
    """When an investment lands.

    Materials accumulate (aff), then the Job runs (jt).  Crucially the Job does NOT
    serialise the plan: construction (priority 12) and research (11) each post
    their own Job, so up to WORKERS of them are in flight at once and one more
    costs only jt/WORKERS of wall clock at the margin.  The worker time itself is
    charged separately through OVERHEAD_WORKERS.  Serialising jt here was adding
    ~10s + travel per building to the clock -- half an hour of phantom time across
    a map-filling plan.  A story-locked build still cannot start before its
    cutscene has fired."""
    at = t + max(aff, jt / max(WORKERS, 1))
    if kind == "build":
        at = max(at, story_floor(variant_items(typ)) + jt)
    return at


def remaining(bs, caps, auto, ups, spd, finish, memo):
    key = _skey(bs, caps, auto, ups, spd)
    if key in memo:
        return memo[key]
    best, best_step = finish(bs, caps, auto, ups, spd), None
    for kind, typ, nbs, ncaps, nauto, nups, nspd, cost, jt in _actions(
            bs, caps, auto, ups, spd):
        aff = afford_time(cost, bs, caps, auto, ups, spd)
        if not np.isfinite(aff):
            continue
        if kind == "build" and not np.isfinite(story_floor(variant_items(typ))):
            continue
        dt = max(aff, jt)
        val = dt + finish(nbs, ncaps, nauto, nups, nspd)
        if val < best - 1e-9:
            best, best_step = val, (nbs, ncaps, nauto, nups, nspd, dt)
    if best_step is None:
        memo[key] = finish(bs, caps, auto, ups, spd)
        return memo[key]
    nbs, ncaps, nauto, nups, nspd, dt = best_step
    res = min(finish(bs, caps, auto, ups, spd),
              dt + remaining(nbs, ncaps, nauto, nups, nspd, finish, memo))
    memo[key] = res
    return res


# An investment is only worth making if it actually buys time.  Without a real
# threshold the greedy pockets rounding-level gains and keeps building until the
# map runs out -- which is pointless past the crew size, since only WORKERS
# buildings can be manned at once.
MIN_GAIN_FRAC = 0.005
MIN_GAIN_SECS = 5.0


def greedy(finish, bs, caps, auto, ups, spd, t, steps, jobs):
    memo = {}
    while True:
        best_total, best = t + finish(bs, caps, auto, ups, spd), None
        floor = best_total - max(MIN_GAIN_SECS, MIN_GAIN_FRAC * (best_total - t))
        for kind, typ, nbs, ncaps, nauto, nups, nspd, cost, jt in _actions(
                bs, caps, auto, ups, spd):
            aff = afford_time(cost, bs, caps, auto, ups, spd)
            if not np.isfinite(aff):
                continue
            at = _step_time(kind, typ, aff, jt, t)
            if not np.isfinite(at):
                continue
            total = at + remaining(nbs, ncaps, nauto, nups, nspd, finish, memo)
            if total < min(best_total, floor) - 1e-6:
                best_total, best = total, (kind, typ, nbs, ncaps, nauto, nups, nspd, at, jt)
        if best is None:
            return bs, caps, auto, ups, spd, t
        kind, typ, nbs, ncaps, nauto, nups, nspd, at, jt = best
        bs, caps, auto, ups, spd, t = nbs, ncaps, nauto, nups, nspd, at
        steps.append((kind, typ, t))
        jobs.append(jt)


def ensure_producible(good, bs, caps, auto, ups, spd, t, steps, jobs):
    """Make `good` producible at all by acquiring, cheapest-first, the unlocks
    that increase how many relevant items can be produced -- building a factory
    for recipes that have one, researching a capability for the workshop-only
    ones. (Automation, upgrades and move speed never change producibility, so they
    are skipped here.)"""
    def pcount(bs, caps):
        return sum(1 for it in RELEVANT_ITEMS
                   if rate(bs, caps, auto, ups, spd, it) > 1e-9)

    while rate(bs, caps, auto, ups, spd, good) <= 1e-9:
        cur = pcount(bs, caps)
        best = fallback = None
        for kind, typ, nbs, ncaps, nauto, nups, nspd, cost, jt in _actions(
                bs, caps, auto, ups, spd):
            if kind in ("automate", "upgrade", "speed"):
                continue
            aff = afford_time(cost, bs, caps, auto, ups, spd)
            if not np.isfinite(aff):
                continue
            key = _step_time(kind, typ, aff, jt, t)
            if not np.isfinite(key):
                continue
            if fallback is None or key < fallback[0]:
                fallback = (key, kind, typ, nbs, ncaps, jt)
            if pcount(nbs, ncaps) > cur and (best is None or key < best[0]):
                best = (key, kind, typ, nbs, ncaps, jt)
        pick = best or fallback
        if pick is None:
            raise RuntimeError(f"{name(good)} is not reachable (missing recipe/deposit?)")
        at, kind, typ, nbs, ncaps, jt = pick
        bs, caps, t = nbs, ncaps, at
        steps.append((kind, typ, t)); jobs.append(jt)
    return bs, caps, auto, ups, spd, t


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


def build_factory_tree(bs, caps, auto, ups, spd, t, steps, jobs):
    """Build one of every relevant producer in DEPENDENCY ORDER, so each one's
    construction inputs are already supplied by something upstream. This minimises
    hand-crafting to the true bootstrap (the first Brickworks' bricks, the first
    Mech-Comp Factory's components, ...) instead of, say, hand-crafting 800 bricks.

    EXTRACTORS BELONG HERE TOO. Leaving them to the later optimisation pass meant
    the whole build-up ran on hand-harvesting -- 4 titanium/s from 4 workable tiles
    -- while the game's own tutorial tells you to drop a pitmine on a deposit
    immediately. A raw's extractor is therefore ordered ahead of the factories that
    consume that raw."""
    good_factory = {g: bt for k, bt in RECIPE_BUILDING.items() for g in RECIPES[k][1]}
    # Only the GOAL's own chain gets stood up unconditionally.  ACTIVE_CANDIDATES
    # is deliberately wider (it also closes over automation and upgrade costs) so
    # the optimiser can reach for those, but building all of them up front would
    # charge the goal for a semiconductor foundry it never uses.
    on_chain = {bt for g in RELEVANT_ITEMS for bt in (good_factory.get(g),) if bt}
    extractors = [v for g in RELEVANT_ITEMS for v in RAW_SOURCE.get(g, ())
                  if v in ACTIVE_CANDIDATES]
    factories = [c for c in ACTIVE_CANDIDATES
                 if c in FACTORY_BUILDINGS and c in on_chain]

    # what a factory eats, so its supplier is built first
    consumes = {}
    for key, bt in RECIPE_BUILDING.items():
        consumes.setdefault(bt, set()).update(RECIPES[key][0])

    def deps(f):
        # material dependencies: build the factory that supplies my build cost first
        out = {good_factory[g] for g in BUILD_COST[vclass(f)]
               if g in good_factory and good_factory[g] != f}
        # STORY dependencies: if my output is challenge-gated, whatever the cutscene
        # chain wants produced first has to be standing before me.  Without this the
        # toposort happily places the Coffee Brewery ahead of the Standee Line that
        # unlocks coffee, and the story fixed point chases its own tail.
        if USE_STORY:
            need_items, need_built, _caps = story_prerequisites(variant_items(f))
            for g in need_items:
                producers = set(RAW_SOURCE.get(g, ()))
                if g in good_factory:
                    producers.add(good_factory[g])
                out |= producers - {f}
            out |= set(need_built) - {f}
        return out

    # Toposort the FACTORIES on build-cost dependencies only -- that graph is
    # acyclic and gives the sane bootstrap order. Extractors cannot join it: a
    # Pitmine costs mechanical components while the Mech-Comp Factory eats
    # titanium, so they form a cycle and the tie-break is arbitrary (it put the
    # Mech-Comp Factory first and cost an hour of hand-harvesting). Instead each
    # extractor is INTERLEAVED just ahead of the first factory that consumes its
    # raw, which is the order a player actually plays.
    sequence, placed = [], set()
    for f in _toposort(factories, deps):
        for g in sorted(consumes.get(f, ())):
            for v in RAW_SOURCE.get(g, ()):
                if v in extractors and v not in placed:
                    sequence.append(v); placed.add(v)
        sequence.append(f); placed.add(f)
    for v in extractors:                       # raws nothing on-chain consumes yet
        if v not in placed:
            sequence.append(v); placed.add(v)

    for f in sequence:
        if site_pool_free(bs, f) <= 0:
            continue
        aff = afford_time(_bcost(f), bs, caps, auto, ups, spd)
        if not np.isfinite(aff):
            continue
        jt = _job_time("build", f, bs, spd)
        at = _step_time("build", f, aff, jt, t)
        if not np.isfinite(at):
            continue          # story-locked: its challenge never goes ACTIVE here
        t = at
        bs = _addb(bs, f); steps.append(("build", f, t)); jobs.append(jt)
    return bs, caps, auto, ups, spd, t


def plan(good, amount):
    global ACTIVE_CANDIDATES, RELEVANT_CAPS, RELEVANT_ITEMS
    ACTIVE_CANDIDATES, RELEVANT_ITEMS, RELEVANT_CAPS = _relevant(good)

    bs, caps, auto, ups, spd = {}, set(BASE_CAPS), set(), frozenset(), frozenset()
    t, steps, jobs = 0.0, [], []

    # The Warehouse is where the crew's move-speed research lives (and the story
    # nags for it from the first cutscene), so it goes up first.
    aff = afford_time(_bcost("Warehouse"), bs, caps, auto, ups, spd)
    jt = _job_time("build", "Warehouse", bs, spd)
    t = _step_time("build", "Warehouse", aff, jt, t)
    bs = _addb(bs, "Warehouse"); steps.append(("build", "Warehouse", t)); jobs.append(jt)

    # Stand up the factory tree first (craft-minimal), research any workshop-only
    # capabilities the goal needs, then optimise throughput (copies + upgrades +
    # automation + move speed).
    bs, caps, auto, ups, spd, t = build_factory_tree(
        bs, caps, auto, ups, spd, t, steps, jobs)
    bs, caps, auto, ups, spd, t = ensure_producible(
        good, bs, caps, auto, ups, spd, t, steps, jobs)
    bs, caps, auto, ups, spd, t = greedy(
        make_produce_goal(good, amount), bs, caps, auto, ups, spd, t, steps, jobs)
    # the goal itself cannot start before its challenge is ACTIVE
    t = max(t, story_floor({good}))
    t += amount / rate(bs, caps, auto, ups, spd, good)
    return steps, bs, caps, auto, ups, spd, t, jobs


def _research_all_caps(needed, bs, caps, auto, ups, spd, t, steps, jobs):
    """Research every capability in `needed` (closed under prereqs), each in
    prerequisite order, cheapest affordable first."""
    remaining = {c for c in needed if c not in caps}
    while remaining:
        avail = [c for c in remaining if CAP_PREREQ.get(c, set()) <= caps]
        avail = [c for c in avail
                 if np.isfinite(afford_time(_cap_cost(c), bs, caps, auto, ups, spd))]
        if not avail:
            break
        c = min(avail, key=lambda x: afford_time(_cap_cost(x), bs, caps, auto, ups, spd))
        jt = _job_time("research", c, bs, spd)
        t = _step_time("research", c, afford_time(_cap_cost(c), bs, caps, auto, ups, spd),
                       jt, t)
        caps = caps | {c}; remaining.discard(c)
        steps.append(("research", c, t)); jobs.append(jt)
    return caps, t


def plan_research(target):
    """Benchmark reaching a WAREHOUSE research (e.g. 'MekaSuit Integration'):
    build the economy, then research its prerequisite chain in order, producing
    each research's cost bundle. Returns the same shape as plan()."""
    global ACTIVE_CANDIDATES, RELEVANT_CAPS, RELEVANT_ITEMS
    chain = research_chain(target)
    cost_items = {g for d in chain for g in WAREHOUSE_RESEARCH[d]["cost"]}
    ACTIVE_CANDIDATES, RELEVANT_ITEMS, RELEVANT_CAPS = _relevant_seed(cost_items)

    bs, caps, auto, ups, spd = {}, set(BASE_CAPS), set(), frozenset(), frozenset()
    t, steps, jobs = 0.0, [], []
    aff = afford_time(_bcost("Warehouse"), bs, caps, auto, ups, spd)
    jt = _job_time("build", "Warehouse", bs, spd)
    t = _step_time("build", "Warehouse", aff, jt, t)
    bs = _addb(bs, "Warehouse"); steps.append(("build", "Warehouse", t)); jobs.append(jt)

    bs, caps, auto, ups, spd, t = build_factory_tree(
        bs, caps, auto, ups, spd, t, steps, jobs)
    caps, t = _research_all_caps(RELEVANT_CAPS, bs, caps, auto, ups, spd, t, steps, jobs)

    # Optimise the building set for the whole chain's cost, then research in order.
    def finish(bs, caps, auto, ups, spd):
        return sum(afford_time({g: v * WAREHOUSE_COST_MULT for g, v in
                                WAREHOUSE_RESEARCH[d]["cost"].items()},
                               bs, caps, auto, ups, spd) + RESEARCH_WORK for d in chain)
    bs, caps, auto, ups, spd, t = greedy(finish, bs, caps, auto, ups, spd, t, steps, jobs)
    for d in chain:
        cost = {g: v * WAREHOUSE_COST_MULT for g, v in WAREHOUSE_RESEARCH[d]["cost"].items()}
        jt = _job_time("speed", d, bs, spd)
        t = _step_time("wresearch", d, afford_time(cost, bs, caps, auto, ups, spd), jt, t)
        t = max(t, story_floor(set(cost)))
        spd = spd | {d}
        steps.append(("wresearch", d, t)); jobs.append(jt)
    return steps, bs, caps, auto, ups, spd, t, jobs


WAREHOUSE_COST_MULT = 1.0


# ===========================================================================
# 6. THE STORY CLOCK  (source: Story.gd)
#
# Cutscenes are not decoration: their on_complete calls Stockpile.start_challenge,
# and until a challenge is ACTIVE its item is an "unavailable story item", which
#   * hides every building that produces or consumes it from the catalog
#     (Catalog.get_unlocked_buildings), and
#   * cancels/blocks any Workshop order for it (Workshop._on_challenge_updated).
# So merch, the steam engine, the paint and every PC part are hard-gated behind a
# chain of videos.  Story plays ONE cutscene at a time, polls conditions once a
# second and waits DELAY_BETWEEN_CUTSCENES before each -- a serial clock that the
# production plan cannot outrun.
# ===========================================================================
def cutscene_timeline(events):
    """Play out the cutscene DAG against a plan.

    `events` supplies when each trigger becomes true:
      built[cls], cap[capability], seen[item], cumulative[(item, n)],
      challenge_done[item]  -- each a time in seconds (np.inf = never).
    Returns (fires, unlock) where fires is [(var, start, end)] and unlock maps a
    challenge item to the moment its challenge goes ACTIVE."""
    done, unlock, fires = {}, {}, []
    clock = 0.0
    pending = list(CUTSCENES)
    guard = 0
    while pending and guard < 200:
        guard += 1
        ready = []
        for cs in pending:
            after = max([done.get(a, np.inf) for a in cs["after"]] or [0.0])
            cond = _trigger_time(cs["cond"], events)
            t = max(after, cond)
            if np.isfinite(t):
                ready.append((t, cs))
        if not ready:
            break
        ready.sort(key=lambda x: (x[0], CUTSCENES.index(x[1])))
        t, cs = ready[0]
        start = max(clock, t + CUTSCENE_POLL / 2.0) + CUTSCENE_GAP
        end = start + cs["duration"]
        fires.append((cs["var"], start, end))
        done[cs["var"]] = end
        for item in cs["starts"]:
            unlock[item] = end
        clock = end
        pending.remove(cs)
    return fires, unlock


def _trigger_time(cond, events):
    if cond is None:
        return 0.0
    kind = cond[0]
    if kind == "built":
        return events.get("built", {}).get(cond[1], np.inf)
    if kind == "cap":
        return events.get("cap", {}).get(cond[1], np.inf)
    if kind == "seen":
        return events.get("seen", {}).get(cond[1], np.inf)
    if kind == "challenge_done":
        return events.get("challenge_done", {}).get(cond[1], np.inf)
    if kind == "cumulative":
        fn = events.get("cumulative")
        return fn(cond[1], cond[2]) if fn else np.inf
    if kind == "hold":
        fn = events.get("hold")
        return fn(dict(cond[1])) if fn else np.inf
    return np.inf


# ===========================================================================
# 7. EVALUATE + ACTIVITY
#    "Activity" = density of PLAYER ACTIONS over time. Player actions are:
#    building constructions, research, and WORKSHOP CRAFT ORDERS (each good the
#    player hand-crafts in a phase). The design goal is high early density
#    (busy = fun) tapering to a calm late game (manual PC-part crafting only).
# ===========================================================================
def _story_events(steps, bs, caps, ups, total, good, amount):
    """Reduce a plan to the trigger times Story.gd polls for."""
    built, first_seen = {}, {}
    for kind, typ, t in steps:
        if kind == "build":
            built.setdefault(vclass(typ), t)
            for g in variant_items(typ):        # a built producer starts making it
                first_seen.setdefault(g, t)
        elif kind == "research":
            first_seen.update({g: min(first_seen.get(g, np.inf), t)
                               for g in CAP_COST.get(typ, {})})
    cap_time = {}
    for kind, typ, t in steps:
        if kind == "research":
            cap_time[typ] = t
    for c in BASE_CAPS:
        cap_time.setdefault(c, 0.0)
    if good is not None:
        first_seen.setdefault(good, total)

    def cumulative(item, n):
        """When cumulative production of `item` first reaches n, at the plan's
        END-state rate (optimistic, which is the right side to err on for a gate
        that merely unlocks more work)."""
        start = first_seen.get(item, np.inf)
        r = rate(bs, caps, frozenset(), ups, frozenset(), item)
        return np.inf if (not np.isfinite(start) or r <= 0) else start + n / r

    def hold(bundle):
        """When the colony could first have this whole bundle in stock at once --
        it has to be able to MAKE every item, then accumulate the lot."""
        start = max([first_seen.get(g, np.inf) for g in bundle] or [0.0])
        if not np.isfinite(start):
            return np.inf
        return start + afford_time(bundle, bs, caps, frozenset(), ups, frozenset())

    return dict(built=built, cap=cap_time, seen=first_seen,
                challenge_done={}, cumulative=cumulative, hold=hold)


def run_plan(planner):
    """Run a planner to a FIXED POINT over the two whole-plan feedbacks:

      * STORY -- challenge items are locked until their cutscene fires, and the
        cutscene times depend on when the plan builds/researches things, which in
        turn depends on the locks.  Iterate until the unlock times stop moving.
      * WORKER OVERHEAD -- every construction and research is a Job that takes a
        Starknight off production for travel+work seconds.  Spread that over the
        run and hand the LP the crew that is actually left."""
    global STORY_UNLOCK, OVERHEAD_WORKERS
    STORY_UNLOCK, OVERHEAD_WORKERS = {}, 0.0
    result = None
    for _ in range(MAX_FIXED_POINT_PASSES):
        _rate_cache.clear(); _afford_cache.clear()
        steps, bs, caps, auto, ups, spd, total, jobs = planner()
        good = getattr(planner, "goal_good", None)
        amount = getattr(planner, "goal_amount", 0)
        events = _story_events(steps, bs, caps, ups, total, good, amount)
        fires, unlock = cutscene_timeline(events)
        new_overhead = min(WORKERS - 1.0, sum(jobs) / max(total, 1.0))
        # Unlock times only ever move LATER as the plan learns what the story
        # makes it build first, so take the running max: that makes the sequence
        # monotone and it converges upward instead of oscillating.
        merged = dict(STORY_UNLOCK)
        for k, v in unlock.items():
            merged[k] = max(v, merged.get(k, 0.0)) if np.isfinite(v) else merged.get(k, v)
        moved = (any(abs(merged.get(k, np.inf) - STORY_UNLOCK.get(k, np.inf)) > 1.0
                     for k in set(merged) | set(STORY_UNLOCK))
                 or abs(new_overhead - OVERHEAD_WORKERS) > 0.05)
        STORY_UNLOCK = merged if USE_STORY else {}
        OVERHEAD_WORKERS = new_overhead
        result = (steps, bs, caps, auto, ups, spd, total, jobs, fires)
        if not moved:
            break
    return result


def story_violations(steps):
    """Any step the STORY would not actually have allowed yet.  The plan and the
    cutscene clock are solved as a fixed point, so a leftover violation means the
    passes ran out rather than converged -- worth saying out loud."""
    out = []
    for kind, typ, t in steps:
        if kind != "build":
            continue
        floor = story_floor(variant_items(typ))
        if np.isfinite(floor) and t < floor - 1.0:
            out.append((bname(typ), t, floor))
    return out


def evaluate(good, amount):
    def planner():
        return plan(good, amount)
    planner.goal_good, planner.goal_amount = good, amount
    steps, bs, caps, auto, ups, spd, total, jobs, fires = run_plan(planner)
    gate = next((s[2] for s in steps if s[1] == STORY_GATE), np.nan)
    sched = crafting_schedule(steps, good, amount, total)
    return dict(steps=steps, buildings=bs, caps=caps, auto=auto, ups=ups, spd=spd,
                total=total, gate=gate, crafts=sched, good=good, amount=amount,
                jobs=jobs, fires=fires,
                goal_row=f"▶ {amount} {name(good)}", label=f"{amount} x {name(good)}")


def evaluate_research(target):
    def planner():
        return plan_research(target)
    planner.goal_good, planner.goal_amount = None, 0
    steps, bs, caps, auto, ups, spd, total, jobs, fires = run_plan(planner)
    sched = crafting_schedule(steps, None, 0, total)
    return dict(steps=steps, buildings=bs, caps=caps, auto=auto, ups=ups, spd=spd,
                total=total, gate=np.nan, crafts=sched, good=None, amount=0,
                jobs=jobs, fires=fires,
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
            for g, q in BUILD_COST[vclass(typ)].items():
                craft_for(g, q, t, f"build {bname(typ)}")
            have |= BUILDING_OUTPUTS.get(typ, set()) | (
                {VARIANT_YIELD[typ]} if typ in VARIANT_YIELD else set())
        elif kind == "research":
            for g, q in CAP_COST.get(typ, {}).items():
                craft_for(g, q, t, f"research {typ}")
            caps.add(typ)
        elif kind in ("wresearch", "speed"):
            for g, q in WAREHOUSE_RESEARCH.get(typ, {}).get("cost", {}).items():
                craft_for(g, q, t, f"research {typ}")
        elif kind == "automate":
            for g, q in _auto_cost(typ).items():
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
    times = [s[2] for s in steps if np.isfinite(s[2])] + [c[0] for c in crafts]
    if not np.isfinite(total):
        total = max(times) if times else 1.0
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
    if kind == "speed":
        return f"> crew speed: {typ}"
    if kind == "automate":
        return f"* automate {bname(typ)}"
    if kind == "upgrade":
        return f"^ upgrade {bname(typ[0])}: {UPGRADES[typ]['display']}"
    return typ


def report(res):
    global TRAVEL_MODE
    steps, bs, total, crafts = res["steps"], res["buildings"], res["total"], res["crafts"]
    print("=" * 78)
    print("  12 STINKY STARKNIGHTS  --  pacing model (parsed from game source)")
    print("=" * 78)
    print(f"  {len(RECIPES)} recipes | {len(BUILDING_TYPES)} producing buildings | "
          f"{len(CAP_COST)} researchable capabilities | {len(FINISHED)} finished goods")
    if G["skipped"]:
        print(f"  skipped {len(G['skipped'])} incomplete recipe(s): "
              f"{', '.join(G['skipped'])}  (no work/outputs yet)")
    print(f"  Map: {len(TILES)} tiles, {sum(1 for t in TILES if t['walkable'])} walkable, "
          f"{len(BLANK_SITES)} free build sites, {sum(WORKABLE_TILES.values())} workable "
          f"deposits | crew {WORKERS} @ {MEAN_SPEED:.0f} px/s mean")
    print(f"  Travel mode: {TRAVEL_MODE} | story gating: {'on' if USE_STORY else 'off'} | "
          f"investment-job overhead: {OVERHEAD_WORKERS:.2f} of {WORKERS} workers")
    print(f"  Goal: {res['label']}")
    for msg in challenge_limit_warnings(res):
        print(f"  !! {msg}")
    if not np.isfinite(total):
        missing = [g for g in ([res["good"]] if res["good"] else [])
                   if g in CHALLENGE_ITEMS and not np.isfinite(STORY_UNLOCK.get(g, np.inf))]
        why = (f"its challenge never goes ACTIVE in this plan ({', '.join(name(g) for g in missing)}) "
               f"-- the story fixed point needs more passes" if missing else
               "nothing in the plan can produce it")
        print(f"  !! GOAL NEVER REACHED: {why}. Try --passes {MAX_FIXED_POINT_PASSES + 2}.")
    for cs in CUTSCENES:
        if cs.get("unparsed"):
            print(f"  !! cutscene '{cs['var']}' has a condition this model cannot "
                  f"read, so it is treated as ALWAYS TRUE: {cs['unparsed']}")
    for bn, t, floor in story_violations(steps):
        print(f"  !! {bn} is placed at {t/60:.0f}m but the story only unlocks it at "
              f"{floor/60:.0f}m -- the story fixed point did not converge "
              f"(try --passes {MAX_FIXED_POINT_PASSES + 3}).")
    print()

    fires = res.get("fires") or []

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
    n_spd = sum(1 for s in steps if s[0] == "speed")
    print("-" * 78)
    print("  PLAYER ACTIVITY  (density of actions = fun; want early >> late)")
    print("-" * 78)
    print(f"    {n_build} builds, {n_res} research, {n_up} upgrades, {n_spd} crew-speed, "
          f"{n_auto} automations, {len(crafts)} workshop crafts  ({n} actions total)")
    print(f"    density: early half {early:5.2f}/min   ->   late half {late:5.2f}/min")
    jobs = res.get("jobs") or []
    print(f"    those investments are Jobs too: {sum(jobs)/60:.1f} min of Starknight "
          f"time ({OVERHEAD_WORKERS:.2f} workers held back on average)")
    print()

    print("-" * 78)
    print("  STORY CLOCK  (Story.gd; cutscenes are serial and gate every challenge)")
    print("-" * 78)
    for label, s, e in fires:
        starts = next((c["starts"] for c in CUTSCENES if c["var"] == label), [])
        tag = ("   -> unlocks " + ", ".join(name(i) for i in starts[:3]) +
               ("..." if len(starts) > 3 else "")) if starts else ""
        print(f"    {label:<24} {fmt(s)} -> {fmt(e)}{tag}")
    if not fires:
        print("    (story gating disabled)")
    late_gate = [(g, u) for g, u in sorted(STORY_UNLOCK.items(), key=lambda x: x[1])
                 if np.isfinite(u)]
    if late_gate:
        print("    challenge items become craftable at: " +
              ", ".join(f"{name(g)} {u/60:.0f}m" for g, u in late_gate[:6]))
    print()

    # The map is a hard ceiling on the building set -- more copies is not always
    # an option, which is exactly when upgrades become the only lever left.
    print("-" * 78)
    print("  SITE PRESSURE  (copies built vs. tiles the map can hold)")
    print("-" * 78)
    pools = {}
    for v, n_built in sorted(bs.items()):
        if n_built <= 0:
            continue
        d = vdeposit(v)
        pools.setdefault(d, 0)
        pools[d] += n_built
    for d, used in sorted(pools.items(), key=lambda x: -x[1]):
        total_tiles = len(DEPOSIT_SITES.get(d, []))
        flag = "  <- FULL" if used >= total_tiles else ""
        print(f"    {name(d):<28} {used:>3} / {total_tiles:<3} tiles{flag}")
    print()

    # Automation removes the worker cost AND the walk (an automated building runs
    # on a timer, it posts no Job at all), so it is the single biggest throughput
    # lever late on.  Show manual (worker+travel bound) vs fully automated.
    full_caps = set(ALL_CAPS)
    loadout = {}
    for v in BUILDING_TYPES:                 # as many copies as the map allows, max 2
        loadout[v] = min(2, len(DEPOSIT_SITES.get(vdeposit(v), [])))
    loadout["Warehouse"] = 1
    all_auto = frozenset(BUILDING_TYPES)
    full_ups = frozenset(UPGRADES)           # every throughput upgrade researched
    full_spd = frozenset(SPEED_RESEARCH)
    print("-" * 78)
    print("  STEADY-STATE THROUGHPUT per finished good  (<=2x every building, all "
          "caps + upgrades + top crew speed)")
    print(f"  {'':30}{'manual (12 walking)':>22}{'fully automated':>20}")
    print("-" * 78)
    keep = TRAVEL_MODE
    for g in FINISHED:
        # a full colony always has more posted jobs than Starknights, so the manual
        # column is the churn regime; automation removes the Job (and the walk).
        TRAVEL_MODE = "churn"
        man, bm = max_bundle_rate({g: 1.0}, loadout, full_caps, ups=full_ups, spd=full_spd)
        TRAVEL_MODE = keep
        aut, ba = max_bundle_rate({g: 1.0}, loadout, full_caps, all_auto, full_ups, full_spd)
        m = f"{man*60:8.3f}/min" if man > 1e-9 else " (no producer)"
        a = f"{aut*60:8.3f}/min" if aut > 1e-9 else " (no producer)"
        gain = f"x{aut/man:6.1f}" if man > 1e-9 and aut > man else "      "
        print(f"    {name(g):<28}{m:>20}{a:>20} {gain}  [auto: {ba}]")
    TRAVEL_MODE = keep
    print("=" * 78)
    return fires


def challenge_limit_warnings(res):
    """A challenge item stops existing the moment its limit is reached: the
    Challenge goes COMPLETED, which is is_unavailable_story_item() all over again.
    So no plan may lean on more of one than its limit."""
    out = []
    lim = CHALLENGES.get(res["good"], {}).get("limit") if res["good"] else None
    if lim is not None and res["amount"] > lim:
        out.append(f"{name(res['good'])} is a challenge capped at {lim}: the challenge "
                   f"COMPLETES there and the item locks again, so {res['amount']} is "
                   f"unreachable in a real playthrough.")
    # anything the plan has to BUY with a challenge item (research/upgrade costs)
    spend = {}
    for kind, typ, _t in res["steps"]:
        cost = ({} if kind == "build" else
                CAP_COST.get(typ, {}) if kind == "research" else
                WAREHOUSE_RESEARCH.get(typ, {}).get("cost", {})
                if kind in ("wresearch", "speed") else
                UPGRADES[typ]["cost"] if kind == "upgrade" else _auto_cost(typ))
        for g, q in cost.items():
            spend[g] = spend.get(g, 0) + q
    for g, q in sorted(spend.items()):
        lim = CHALLENGES.get(g, {}).get("limit")
        if lim is not None and q > lim:
            out.append(f"the plan spends {q} {name(g)} but its challenge completes "
                       f"(and locks the item) at {lim}.")
    return out


def make_plots(res, fires):
    steps, total, crafts = res["steps"], res["total"], res["crafts"]
    palette = {"build": "#23deff", "research": "#b060e0", "wresearch": "#b060e0",
               "automate": "#40c060", "goal": "#e0a030", "craft": "#e0782a",
               "upgrade": "#d8b020", "speed": "#e05a8a"}

    # One ROW PER type; a dot marks each event. Workshop CRAFT orders are folded
    # into the same timeline (orange) and rows are ordered by first-occurrence
    # TIME, so builds, research and hand-crafts interleave chronologically.
    events = {}
    def add_event(lab, t, kind):
        events.setdefault(lab, []).append((t, kind))
    for k, ty, t in steps:
        if k in ("research", "wresearch"):
            lab = f"research {ty}"
        elif k == "speed":
            lab = f"» crew speed: {ty}"
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
    d = [(s, e) for l, s, e in fires if l == "jelly_debut"]
    if d:
        ax1.axvspan(d[0][0] / 60.0, d[0][1] / 60.0, color="#e0a030", alpha=0.15,
                    label="Jelly debut")
    ax1.set_xlabel("wall-clock minutes")
    ax1.set_title(f"Optimal path to {res['label']}")
    legend_handles = [Line2D([0], [0], marker="o", linestyle="none",
                             markerfacecolor=palette[k], markeredgecolor="none",
                             markersize=7, label=lab)
                      for k, lab in [("build", "build"), ("research", "research"),
                                     ("upgrade", "upgrade"), ("speed", "crew speed"),
                                     ("automate", "automate"),
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
    d = [(s, e) for l, s, e in fires if l == "jelly_debut"]
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
    ap.add_argument("--travel-mode", choices=["auto", "churn", "parked"], default="auto",
                    help="auto: pay travel only once the crew cap binds (default); "
                         "churn: always pay it; parked: never (the old travel-free model)")
    ap.add_argument("--no-story", action="store_true",
                    help="ignore the cutscene/challenge gating on merch and PC parts")
    ap.add_argument("--passes", type=int, default=5,
                    help="story/overhead fixed-point passes (each re-plans; 1 = fastest)")
    args = ap.parse_args()

    global TRAVEL_MODE, USE_STORY, MAX_FIXED_POINT_PASSES
    TRAVEL_MODE = args.travel_mode
    USE_STORY = not args.no_story
    MAX_FIXED_POINT_PASSES = max(1, args.passes)

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
