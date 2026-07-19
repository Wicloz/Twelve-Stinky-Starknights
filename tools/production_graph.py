#!/usr/bin/env python
"""
Production-chain grapher for 12 Stinky Starknights.

Parses the Godot source of truth -- items (Stockpile.gd), recipes (Crafting.gd),
building->recipe bindings (*.tscn), and deposit->building placement rules
(Catalog.gd) -- and renders the whole production tree as a Graphviz graph.

Deposits (raw items that no recipe produces -- the things dug/pumped/harvested
out of the ground) are the ROOT nodes on the left; everything flows rightward to
the finished goods. Each recipe is a box connecting its inputs to its outputs and
labelled with the building that runs it.

Renders TWO graphs (each as .dot plus .svg/.png when Graphviz is on PATH):
  * production_graph.*           -- item/recipe production chains.
  * production_graph_buildings.* -- the same flow with each recipe folded onto
    the BUILDING that runs it, plus construction-cost edges (dashed) showing what
    every buildable costs to raise.

Nothing here is hard-coded from the recipe tables -- re-run it after editing any
Crafting.gd / Catalog.gd / *.tscn and the graphs update themselves.

Usage:
    python production_graph.py [--root GAME_DIR] [--out BASENAME]
                              [--format svg,png] [--no-render]
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


# ===========================================================================
# Data model
# ===========================================================================
@dataclass
class Recipe:
    key: str                                   # RecipeType enum name
    index: int                                 # position in the enum
    display_name: str = ""
    inputs: dict[str, int] = field(default_factory=dict)   # ItemType -> qty
    outputs: dict[str, int] = field(default_factory=dict)  # ItemType -> qty
    work: str = ""                             # raw work expression
    capabilities: list[str] = field(default_factory=list)
    building: str | None = None                # display name of factory, if any


@dataclass
class Building:
    cls: str                                   # class_name
    base: str                                  # extends ...
    display_name: str
    recipe_index: int | None = None            # for FactoryBuilding
    harvest_override: list[str] = field(default_factory=list)  # ItemType names


# ===========================================================================
# Small parsing helpers
# ===========================================================================
def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_enum(text: str, name: str) -> list[str]:
    """Return the identifiers of `enum <name> { ... }` in declaration order."""
    m = re.search(r"enum\s+" + re.escape(name) + r"\s*\{(.*?)\}", text, re.S)
    if not m:
        raise ValueError(f"enum {name} not found")
    body = re.sub(r"#.*", "", m.group(1))              # strip comments
    body = re.sub(r"=\s*[^,]+", "", body)              # strip explicit values
    return [tok.strip() for tok in body.split(",") if tok.strip()]


# ===========================================================================
# Stockpile.gd  ->  item display names
# ===========================================================================
def parse_items(stockpile_text: str) -> dict[str, str]:
    """ItemType enum name -> human display name."""
    names: dict[str, str] = {}
    block = re.search(r"_ITEM_NAMES.*?\{(.*?)\n\}", stockpile_text, re.S)
    src = block.group(1) if block else stockpile_text
    for enum_name, disp in re.findall(r"ItemType\.(\w+)\s*:\s*\"([^\"]*)\"", src):
        names[enum_name] = disp
    # make sure every enum member exists even if it has no pretty name
    for enum_name in parse_enum(stockpile_text, "ItemType"):
        names.setdefault(enum_name, enum_name.replace("_", " ").title())
    return names


# ===========================================================================
# Crafting.gd  ->  recipes (indexed by RecipeType order)
# ===========================================================================
def parse_recipes(crafting_text: str) -> dict[int, Recipe]:
    order = parse_enum(crafting_text, "RecipeType")
    index_of = {name: i for i, name in enumerate(order)}

    recipes: dict[int, Recipe] = {}
    current: Recipe | None = None
    for raw in crafting_text.splitlines():
        line = raw.split("#", 1)[0]

        m = re.search(r"_recipe_map\[RecipeType\.(\w+)\]\s*=\s*recipe", line)
        if m:
            key = m.group(1)
            current = Recipe(key=key, index=index_of.get(key, -1))
            recipes[current.index] = current
            continue

        if current is None:
            continue

        m = re.search(r"\.display_name\s*=\s*\"([^\"]*)\"", line)
        if m:
            current.display_name = m.group(1)
        m = re.search(r"\.inputs\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", line)
        if m:
            current.inputs[m.group(1)] = int(m.group(2))
        m = re.search(r"\.outputs\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", line)
        if m:
            current.outputs[m.group(1)] = int(m.group(2))
        m = re.search(r"\.work\s*=\s*(.+)", line)
        if m:
            current.work = m.group(1).strip()
        m = re.search(r"needs_capabilities\.append\(Capabilities\.(\w+)\)", line)
        if m:
            current.capabilities.append(m.group(1))
    return recipes


# ===========================================================================
# objects/buildings/*.gd + *.tscn  ->  buildings and their recipe/harvest
# ===========================================================================
def parse_buildings(buildings_dir: Path) -> dict[str, Building]:
    buildings: dict[str, Building] = {}

    for gd in sorted(buildings_dir.glob("*.gd")):
        text = read(gd)
        m = re.search(r"class_name\s+(\w+)", text)
        if not m:
            continue
        cls = m.group(1)
        base = (re.search(r"extends\s+(\w+)", text) or [None, ""])[1]
        disp = (re.search(r'get_display_name\(\)\s*->\s*String:\s*\n\s*return\s+"([^"]*)"',
                          text) or [None, cls])[1]
        harvest = re.findall(r"_will_harvest\[Stockpile\.ItemType\.(\w+)\]", text)
        buildings[cls] = Building(cls=cls, base=base, display_name=disp,
                                  harvest_override=harvest)

    # recipe index lives in the scene file (default 0 when the line is omitted)
    for tscn in sorted(buildings_dir.glob("*.tscn")):
        text = read(tscn)
        m = re.search(r'path="res://objects/buildings/(\w+)\.gd"', text)
        if not m or m.group(1) not in buildings:
            continue
        b = buildings[m.group(1)]
        if b.base == "FactoryBuilding":
            rm = re.search(r"^\s*recipe\s*=\s*(\d+)", text, re.M)
            b.recipe_index = int(rm.group(1)) if rm else 0

    return buildings


# ===========================================================================
# Catalog.gd  ->  per-building construction cost + placement deposits
# ===========================================================================
def parse_catalog(catalog_text: str) -> dict[str, dict]:
    """building class -> {"cost": {ItemType: qty}, "deposits": [ItemType, ...]}.

    Order follows the catalog so the buildable list stays in declaration order."""
    result: dict[str, dict] = {}
    for block in catalog_text.split("item = CatalogItem.new()"):
        scene = re.search(r'preload\("res://objects/buildings/(\w+)\.tscn"\)', block)
        if not scene:
            continue
        cost = {m.group(1): int(m.group(2)) for m in re.finditer(
            r"\.cost\[Stockpile\.ItemType\.(\w+)\]\s*=\s*(\d+)", block)}
        dep = re.search(r"allowed_deposits\s*=\s*\[([^\]]*)\]", block, re.S)
        deposits = ([d for d in re.findall(r"ItemType\.(\w+)", dep.group(1))
                     if d != "NONE"] if dep else [])
        result[scene.group(1)] = {"cost": cost, "deposits": deposits}
    return result


# ===========================================================================
# Assemble the graph model
# ===========================================================================
def build_graph(items, recipes, buildings, allowed_deposits, build_costs):
    # recipe -> building display name (invert the factory bindings)
    for b in buildings.values():
        if b.recipe_index is not None and b.recipe_index in recipes:
            recipes[b.recipe_index].building = b.display_name

    # deposit item -> extraction building display name
    deposit_source: dict[str, str] = {}
    for cls, deposits in allowed_deposits.items():
        for d in deposits:
            deposit_source.setdefault(d, buildings[cls].display_name
                                      if cls in buildings else cls)
    # extraction buildings that harvest a fixed item (e.g. coffee farm, logging)
    for b in buildings.values():
        if b.base == "ExtractionBuilding":
            for item in b.harvest_override:
                deposit_source.setdefault(item, b.display_name)

    produced = {g for r in recipes.values() for g in r.outputs}
    consumed = {g for r in recipes.values() for g in r.inputs}
    all_items = produced | consumed
    roots = sorted(all_items - produced)          # deposits / raw materials
    # terminal goods: produced but neither fed into a recipe nor spent on a build
    finals = sorted(produced - consumed - build_costs)

    return recipes, deposit_source, all_items, roots, finals


# ===========================================================================
# Graphviz DOT emission
# ===========================================================================
def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


# shared node/edge palette
C_DEPOSIT = ('shape=cylinder, style=filled, fillcolor="#c8e6c9", '
             'color="#2e7d32", penwidth=1.5')
C_FINAL = ('shape=box, style="filled,rounded", fillcolor="#ffe0b2", '
           'color="#e65100", penwidth=1.5')
C_ITEM = 'shape=ellipse, style=filled, fillcolor="#e3f2fd", color="#1565c0"'
C_RECIPE = 'shape=box, style="filled", fillcolor="#f5f5f5", color="#616161"'
C_BUILDING = ('shape=box3d, style=filled, fillcolor="#ede7f6", '
              'color="#5e35b1", penwidth=1.5')
E_PRODUCE = 'color="#e65100"'
E_COST = 'style=dashed, color="#5e35b1", fontcolor="#5e35b1"'


def emit_item_nodes(add, items, all_items, roots, finals, deposit_source,
                    annotate_source=True):
    """Emit the coloured item nodes shared by both graphs."""
    add("  // item nodes")
    for item in sorted(all_items):
        label = esc(items.get(item, item))
        if item in roots:
            src = deposit_source.get(item) if annotate_source else None
            sub = f"\\n({esc(src)})" if src else ""
            add(f'  "i_{item}" [label="{label}{sub}", {C_DEPOSIT}];')
        elif item in finals:
            add(f'  "i_{item}" [label="{label}", {C_FINAL}];')
        else:
            add(f'  "i_{item}" [label="{label}", {C_ITEM}];')
    add("")


def _header(add, name):
    add(f"digraph {name} {{")
    add('  rankdir=LR;')
    add('  bgcolor="white";')
    add('  node [fontname="Helvetica", fontsize=10];')
    add('  edge [fontname="Helvetica", fontsize=8, color="#888888", '
        'arrowsize=0.7];')
    add("")


def to_dot(items, recipes, deposit_source, all_items, roots, finals) -> str:
    """Graph 1: item/recipe production chains."""
    L: list[str] = []
    add = L.append
    _header(add, "production")
    emit_item_nodes(add, items, all_items, roots, finals, deposit_source)

    # --- recipe nodes + edges ---
    add("  // recipe nodes")
    for r in sorted(recipes.values(), key=lambda x: x.index):
        who = r.building or "Workshop"
        label = f"{esc(r.display_name or r.key)}\\n[{esc(who)}]"
        add(f'  "r_{r.key}" [label="{label}", {C_RECIPE}];')
        for item, qty in r.inputs.items():
            add(f'  "i_{item}" -> "r_{r.key}" [label="{qty}"];')
        for item, qty in r.outputs.items():
            add(f'  "r_{r.key}" -> "i_{item}" [label="{qty}", {E_PRODUCE}];')
    add("")

    # keep the deposits lined up on the left edge
    add("  { rank=source; " + " ".join(f'"i_{d}";' for d in roots) + " }")

    add("""
  subgraph cluster_legend {
    label="Legend"; fontname="Helvetica"; fontsize=11; color="#bbbbbb";
    "lg_dep"  [label="Deposit (root)", shape=cylinder, style=filled,
               fillcolor="#c8e6c9", color="#2e7d32"];
    "lg_int"  [label="Intermediate item", shape=ellipse, style=filled,
               fillcolor="#e3f2fd", color="#1565c0"];
    "lg_fin"  [label="Finished good", shape=box, style="filled,rounded",
               fillcolor="#ffe0b2", color="#e65100"];
    "lg_rec"  [label="Recipe [building]", shape=box, style=filled,
               fillcolor="#f5f5f5", color="#616161"];
    "lg_dep" -> "lg_int" -> "lg_rec" -> "lg_fin" [style=invis];
  }""")

    add("}")
    return "\n".join(L)


def to_dot_buildings(items, recipes, catalog, buildings, deposit_source,
                     all_items, roots, finals) -> str:
    """Graph 2: buildings as nodes, with construction cost (dashed) plus the
    production flow (solid) folded onto the building that performs it."""
    L: list[str] = []
    add = L.append
    _header(add, "buildings")

    # every item that appears in a recipe OR as a construction cost / deposit
    g2_items = set(all_items)
    for info in catalog.values():
        g2_items |= set(info["cost"]) | set(info["deposits"])
    # the extractor->deposit edges below already name the source, so skip the
    # "(Pitmine)" label annotation here to avoid the redundancy
    emit_item_nodes(add, items, g2_items, roots, finals, deposit_source,
                    annotate_source=False)

    add("  // building nodes (construction cost = dashed purple, "
        "production = solid)")
    handled_recipes: set[int] = set()
    for cls, info in catalog.items():
        b = buildings.get(cls)
        name = esc(b.display_name if b else cls)
        bid = f"b_{cls}"
        add(f'  "{bid}" [label="{name}", {C_BUILDING}];')

        # construction cost: each required item feeds the building (dashed)
        for item, qty in info["cost"].items():
            add(f'  "i_{item}" -> "{bid}" [label="{qty}", {E_COST}];')

        if b is None:
            continue
        # production: fold the factory recipe onto the building node
        if b.base == "FactoryBuilding" and b.recipe_index in recipes:
            r = recipes[b.recipe_index]
            handled_recipes.add(r.index)
            for item, qty in r.inputs.items():
                add(f'  "i_{item}" -> "{bid}" [label="{qty}"];')
            for item, qty in r.outputs.items():
                add(f'  "{bid}" -> "i_{item}" [label="{qty}", {E_PRODUCE}];')
        # extraction: the building yields its deposit(s)
        for dep in info["deposits"] + (b.harvest_override
                                       if b.base == "ExtractionBuilding" else []):
            add(f'  "{bid}" -> "i_{dep}" [color="#2e7d32", style=bold];')
    add("")

    # any recipe with no catalog building (e.g. Workshop-only) stays as a box
    leftover = [r for r in recipes.values() if r.index not in handled_recipes]
    if leftover:
        add("  // workshop-only recipes (no dedicated building)")
        for r in sorted(leftover, key=lambda x: x.index):
            label = f"{esc(r.display_name or r.key)}\\n[Workshop]"
            add(f'  "r_{r.key}" [label="{label}", {C_RECIPE}];')
            for item, qty in r.inputs.items():
                add(f'  "i_{item}" -> "r_{r.key}" [label="{qty}"];')
            for item, qty in r.outputs.items():
                add(f'  "r_{r.key}" -> "i_{item}" [label="{qty}", {E_PRODUCE}];')
        add("")

    add("""
  subgraph cluster_legend {
    label="Legend"; fontname="Helvetica"; fontsize=11; color="#bbbbbb";
    "lg_dep"  [label="Deposit", shape=cylinder, style=filled,
               fillcolor="#c8e6c9", color="#2e7d32"];
    "lg_int"  [label="Intermediate item", shape=ellipse, style=filled,
               fillcolor="#e3f2fd", color="#1565c0"];
    "lg_fin"  [label="Finished good", shape=box, style="filled,rounded",
               fillcolor="#ffe0b2", color="#e65100"];
    "lg_bld"  [label="Building", shape=box3d, style=filled,
               fillcolor="#ede7f6", color="#5e35b1"];
    "lg_dep" -> "lg_int" -> "lg_fin" -> "lg_bld" [style=invis];
    "lg_ci" [label="item", shape=ellipse, style=filled,
             fillcolor="#e3f2fd", color="#1565c0"];
    "lg_cb" [label="Building", shape=box3d, style=filled,
             fillcolor="#ede7f6", color="#5e35b1"];
    "lg_ci" -> "lg_cb" [label="construction cost", style=dashed,
                        color="#5e35b1", fontcolor="#5e35b1"];
    "lg_pb" [label="Building", shape=box3d, style=filled,
             fillcolor="#ede7f6", color="#5e35b1"];
    "lg_pi" [label="item", shape=ellipse, style=filled,
             fillcolor="#e3f2fd", color="#1565c0"];
    "lg_pb" -> "lg_pi" [label="produces", color="#e65100",
                        fontcolor="#e65100"];
    "lg_eb" [label="Extractor", shape=box3d, style=filled,
             fillcolor="#ede7f6", color="#5e35b1"];
    "lg_ed" [label="Deposit", shape=cylinder, style=filled,
             fillcolor="#c8e6c9", color="#2e7d32"];
    "lg_eb" -> "lg_ed" [label="extracts deposit", color="#2e7d32",
                        style=bold, fontcolor="#2e7d32"];
    "lg_ki" [label="item", shape=ellipse, style=filled,
             fillcolor="#e3f2fd", color="#1565c0"];
    "lg_kb" [label="Building", shape=box3d, style=filled,
             fillcolor="#ede7f6", color="#5e35b1"];
    "lg_ki" -> "lg_kb" [label="consumes (recipe input)"];
  }""")

    add("}")
    return "\n".join(L)


# ===========================================================================
# Main
# ===========================================================================
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    here = Path(__file__).resolve().parent
    ap.add_argument("--root", default=here.parent, type=Path,
                    help="game project root (default: the folder above this script)")
    ap.add_argument("--out", default=str(here / "production_graph"),
                    help="output basename (default: production_graph, beside this script)")
    ap.add_argument("--format", default="svg,png",
                    help="comma-separated render formats (default: svg,png)")
    ap.add_argument("--no-render", action="store_true",
                    help="only write the .dot file, don't invoke Graphviz")
    args = ap.parse_args()

    root: Path = args.root
    stockpile = root / "scripts" / "globals" / "Stockpile.gd"
    crafting = root / "scripts" / "globals" / "Crafting.gd"
    catalog = root / "scripts" / "globals" / "Catalog.gd"
    buildings_dir = root / "objects" / "buildings"

    for p in (stockpile, crafting, catalog, buildings_dir):
        if not p.exists():
            print(f"error: {p} not found -- is --root pointing at the game?",
                  file=sys.stderr)
            return 1

    items = parse_items(read(stockpile))
    recipes = parse_recipes(read(crafting))
    buildings = parse_buildings(buildings_dir)
    catalog_data = parse_catalog(read(catalog))
    allowed_deposits = {cls: info["deposits"]
                        for cls, info in catalog_data.items() if info["deposits"]}
    build_costs = {item for info in catalog_data.values() for item in info["cost"]}

    recipes, deposit_source, all_items, roots, finals = build_graph(
        items, recipes, buildings, allowed_deposits, build_costs)

    # --- console summary ---
    print(f"parsed {len(items)} items, {len(recipes)} recipes, "
          f"{len(buildings)} buildings, {len(catalog_data)} buildable")
    print(f"  deposits (roots): {', '.join(items.get(r, r) for r in roots)}")
    print(f"  finished goods:   {', '.join(items.get(f, f) for f in finals)}")

    fmts = [f.strip() for f in args.format.split(",") if f.strip()]
    out_base = Path(args.out)

    dot1 = to_dot(items, recipes, deposit_source, all_items, roots, finals)
    render(dot1, out_base, fmts, not args.no_render)

    dot2 = to_dot_buildings(items, recipes, catalog_data, buildings,
                            deposit_source, all_items, roots, finals)
    render(dot2, out_base.with_name(out_base.name + "_buildings"),
           fmts, not args.no_render)

    return 0


def render(dot: str, out_base: Path, fmts: list[str], do_render: bool) -> None:
    """Write <out_base>.dot and, if Graphviz is available, render each format."""
    dot_path = out_base.with_suffix(".dot")
    dot_path.write_text(dot, encoding="utf-8")
    print(f"wrote {dot_path}")

    if not do_render:
        return
    dot_exe = shutil.which("dot")
    if not dot_exe:
        print(f"note: Graphviz `dot` not on PATH; wrote {dot_path.name} only. "
              f"Render with:  dot -Tsvg {dot_path.name} -o {out_base.name}.svg")
        return
    for fmt in fmts:
        out = f"{out_base}.{fmt}"
        try:
            subprocess.run([dot_exe, f"-T{fmt}", str(dot_path), "-o", out],
                           check=True)
            print(f"wrote {out}")
        except subprocess.CalledProcessError as e:
            print(f"error rendering {fmt}: {e}", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
