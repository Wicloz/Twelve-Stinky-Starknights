#!/usr/bin/env python3
"""Hex map maintenance tool for world.tscn.

The map is designed in the Godot editor - that scene is the source of truth for
which tiles exist and how they're decorated (terrain, deposits, buildings). This
script only keeps tile *positions* honest: each HexTile's `position` is derived
from its axial `q`/`r`, so if a tile gets dragged by accident, or the tile size
changes, `realign` snaps every tile back onto the grid without touching any of
its other properties or its child nodes.

Default action is `realign` (safe, non-destructive). The one-time structural
operations are behind flags:

    python hex_map_builder.py                 # realign positions in world.tscn
    python hex_map_builder.py --dry-run       # report what realign would change
    python hex_map_builder.py --build         # create a fresh radius-N hex of tiles
    python hex_map_builder.py --clear         # remove every tile
    python hex_map_builder.py -o out.tscn     # write a copy instead of in place

If the tile/texture size changes, update TILE_WIDTH / TILE_HEIGHT / PADDING
below and re-run.
"""

from __future__ import annotations

import argparse
import os
import random
import re
import string
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ============================================================================
# SETTINGS  (formerly @export vars on the _HexMapBuilder node)
# ============================================================================

SCENE_PATH = os.path.join(HERE, "world.tscn")

TILE_SCENE_PATH = "res://objects/HexTile.tscn"
TILE_SCENE_UID = "uid://bo1ttpfaa10pe"

PARENT_NODE = "HexMap"      # node whose children are the tiles
TILE_WIDTH = 256
TILE_HEIGHT = 256
PADDING = 16
RADIUS = 8                  # size of the hex --build lays down

_ID_ALPHABET = string.ascii_lowercase + string.digits
_SECTION_RE = re.compile(r"(?m)^\[")


# ============================================================================
# .tscn parsing
# ============================================================================

class Section:
    """One top-level `.tscn` block, kept verbatim (including its trailing blank
    line) so untouched blocks round-trip byte-for-byte."""

    def __init__(self, raw: str):
        self.raw = raw
        header = raw.splitlines()[0] if raw else ""
        m = re.match(r"\[(\w+)", header)
        self.kind = m.group(1) if m else ""
        self.attrs = dict(re.findall(r'(\w+)="([^"]*)"', header))
        m = re.search(r"\bunique_id=(\d+)", header)
        self.unique_id = int(m.group(1)) if m else None

    @property
    def name(self) -> str:
        return self.attrs.get("name", "")

    @property
    def parent(self):
        return self.attrs.get("parent")


def split_sections(text: str) -> list[Section]:
    starts = [m.start() for m in _SECTION_RE.finditer(text)]
    if not starts:
        return []
    bounds = starts + [len(text)]
    sections = []
    if starts[0] != 0:                       # opaque leading block (unusual)
        pre = Section("")
        pre.raw = text[: starts[0]]
        sections.append(pre)
    for i, start in enumerate(starts):
        sections.append(Section(text[start: bounds[i + 1]]))
    return sections


def is_tile(s: Section) -> bool:
    return s.kind == "node" and s.parent == PARENT_NODE and s.name.startswith("Tile=")


def is_subtree(s: Section) -> bool:
    return (s.kind == "node" and s.parent is not None
            and (s.parent == PARENT_NODE or s.parent.startswith(PARENT_NODE + "/")))


# ============================================================================
# geometry
# ============================================================================

def axial_to_world(q: int, r: int):
    x = (q + r * 0.5) * (TILE_WIDTH + PADDING)
    y = r * (TILE_HEIGHT + PADDING) * 0.75
    return x, y


def fmt_num(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else repr(float(v))


def position_line(q: int, r: int, nl: str):
    x, y = axial_to_world(q, r)
    if x == 0 and y == 0:                    # Godot omits the (0,0) default
        return None
    return f"position = Vector2({fmt_num(x)}, {fmt_num(y)}){nl}"


def hex_coords(radius: int):
    """q outer, r inner - matches the node order the editor produced."""
    for q in range(-radius, radius + 1):
        for r in range(-radius, radius + 1):
            if max(abs(q), abs(r), abs(-q - r)) > radius:
                continue
            yield q, r


# ============================================================================
# actions
# ============================================================================

def realign(sections: list[Section], nl: str) -> int:
    """Rewrite each tile's `position` from its q/r; leave everything else be."""
    changed = 0
    for s in sections:
        if not is_tile(s):
            continue
        first = s.raw.find(nl)
        header, body = s.raw[:first], s.raw[first + len(nl):]
        qm = re.search(r"(?m)^q = (-?\d+)\s*$", body)
        rm = re.search(r"(?m)^r = (-?\d+)\s*$", body)
        q = int(qm.group(1)) if qm else 0
        r = int(rm.group(1)) if rm else 0

        body = re.sub(r"(?m)^position = Vector2\([^)]*\)\r?\n", "", body)
        pos = position_line(q, r, nl)
        if pos:                              # position goes first, before q/r
            body = pos + body

        new_raw = header + nl + body
        if new_raw != s.raw:
            s.raw = new_raw
            changed += 1
    return changed


def _tile_ext_resource_id(sections: list[Section], nl: str):
    """Find the HexTile.tscn ext_resource id, creating the declaration if the
    scene doesn't have one yet. Returns (id, new_section_or_None, insert_index)."""
    ids, last, next_n, found = set(), None, 1, None
    for idx, s in enumerate(sections):
        if s.kind != "ext_resource":
            continue
        last = idx
        rid = s.attrs.get("id")
        if rid:
            ids.add(rid)
            pre = rid.split("_", 1)[0]
            if pre.isdigit():
                next_n = max(next_n, int(pre) + 1)
        if s.attrs.get("path") == TILE_SCENE_PATH:
            found = rid
    if found:
        return found, None, last
    while True:
        rid = f"{next_n}_" + "".join(random.choices(_ID_ALPHABET, k=5))
        next_n += 1
        if rid not in ids:
            break
    line = (f'[ext_resource type="PackedScene" uid="{TILE_SCENE_UID}" '
            f'path="{TILE_SCENE_PATH}" id="{rid}"]{nl}')
    return rid, Section(line), last


def build(sections: list[Section], nl: str) -> tuple[list[str], int]:
    """Lay down a fresh radius-N hex of plain tiles (position/q/r only),
    replacing any existing HexMap contents. Reuses unique_ids by tile name."""
    hexmap = next((s for s in sections if s.kind == "node"
                   and s.name == PARENT_NODE and s.parent == "."), None)
    if hexmap is None:
        raise SystemExit(f'error: parent node "{PARENT_NODE}" not found in scene')

    tile_id, new_extres, extres_at = _tile_ext_resource_id(sections, nl)
    existing_uid = {s.name: s.unique_id for s in sections
                    if is_tile(s) and s.unique_id is not None}
    used = set(int(x) for x in re.findall(r"\bunique_id=(\d+)", "".join(s.raw for s in sections)))

    def mint():
        while True:
            uid = random.randint(1, 2147483647)
            if uid not in used:
                used.add(uid)
                return uid

    blocks = []
    for q, r in hex_coords(RADIUS):
        name = f"Tile={q},{r}"
        uid = existing_uid.get(name) or mint()
        lines = [f'[node name="{name}" parent="{PARENT_NODE}" '
                 f'unique_id={uid} instance=ExtResource("{tile_id}")]']
        pos = position_line(q, r, nl)
        if pos:
            lines.append(pos.rstrip(nl))
        if q != 0:
            lines.append(f"q = {q}")
        if r != 0:
            lines.append(f"r = {r}")
        blocks.append(nl.join(lines) + nl + nl)

    out = []
    for idx, s in enumerate(sections):
        if new_extres and idx == extres_at:
            out.append(new_extres.raw)
        if is_subtree(s):
            continue
        out.append(s.raw)
        if s is hexmap:
            out.extend(blocks)
    if new_extres and extres_at is None:
        out[1:1] = [new_extres.raw]
    return out, len(blocks)


# ============================================================================
# driver
# ============================================================================

def process(text: str, action: str):
    nl = "\r\n" if "\r\n" in text else "\n"
    sections = split_sections(text)

    if action == "build":
        out, n = build(sections, nl)
        return "".join(out), {"action": "build", "tiles": n}
    if action == "clear":
        removed = sum(1 for s in sections if is_subtree(s))
        out = "".join(s.raw for s in sections if not is_subtree(s))
        return out, {"action": "clear", "removed": removed}
    # realign (default)
    n = realign(sections, nl)
    return "".join(s.raw for s in sections), {"action": "realign", "moved": n}


def main(argv=None):
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = p.add_mutually_exclusive_group()
    g.add_argument("--build", action="store_const", dest="action", const="build",
                   help="one-time: create a fresh radius-%d hex of tiles" % RADIUS)
    g.add_argument("--clear", action="store_const", dest="action", const="clear",
                   help="one-time: remove every tile under %s" % PARENT_NODE)
    p.set_defaults(action="realign")
    p.add_argument("scene", nargs="?", default=SCENE_PATH,
                   help="path to the .tscn (default: world.tscn next to this script)")
    p.add_argument("-o", "--output",
                   help="write here instead of editing the scene in place")
    p.add_argument("--dry-run", action="store_true",
                   help="report what would change without writing")
    args = p.parse_args(argv)

    with open(args.scene, "rb") as f:
        text = f.read().decode("utf-8")

    result, stats = process(text, args.action)
    dest = args.output or args.scene

    if stats["action"] == "realign":
        summary = f"realign: repositioned {stats['moved']} tile(s)"
    elif stats["action"] == "build":
        summary = f"build: wrote {stats['tiles']} tile(s)"
    else:
        summary = f"clear: removed {stats['removed']} node(s)"
    summary += f" {'->' if not args.dry_run else '(target)'} {dest}"

    if not args.dry_run:
        with open(dest, "wb") as f:
            f.write(result.encode("utf-8"))
    print(("[dry-run] " if args.dry_run else "") + summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
