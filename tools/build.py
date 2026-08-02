#!/usr/bin/env python
"""
Build 12 Stinky Starknights without opening the editor.

For every export preset (or just the ones you name):
  1. re-renders the production graph and drops it into assets/, so the in-game
     chain map never ships stale (Godot reimports it on export startup),
  2. runs the Godot export headlessly,
  3. zips the output when the preset exports to a folder (the Web one) -- the
     desktop presets already export straight to .zip.

Usage:
    python build.py [PRESET ...] [--godot PATH] [--skip-graph]
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

GRAPH_SCRIPT = HERE / "production_graph.py"
GRAPH_RENDERED = HERE / "production_graph.png"
GRAPH_IN_GAME = ROOT / "assets" / "production_graph.png"


def find_godot(override: str | None) -> str:
    """Prefer --godot, else the path the Godot Tools extension already knows."""
    if override:
        return override
    settings = ROOT / ".vscode" / "settings.json"
    if settings.exists():
        path = json.loads(settings.read_text(encoding="utf-8")).get("godotTools.editorPath.godot4")
        if path and Path(path).exists():
            return path
    found = shutil.which("godot")
    if not found:
        sys.exit("Godot not found; pass --godot PATH or set godotTools.editorPath.godot4.")
    return found


def read_presets() -> dict[str, Path]:
    """{preset name: export path} straight out of export_presets.cfg."""
    text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    names = re.findall(r'^name="(.+)"$', text, re.MULTILINE)
    paths = re.findall(r'^export_path="(.+)"$', text, re.MULTILINE)
    return dict(zip(names, (ROOT / p for p in paths)))


def rebuild_graph() -> None:
    subprocess.run([sys.executable, str(GRAPH_SCRIPT)], check=True)
    if not GRAPH_RENDERED.exists():
        sys.exit(f"{GRAPH_RENDERED.name} was not rendered; is Graphviz on PATH?")
    shutil.copyfile(GRAPH_RENDERED, GRAPH_IN_GAME)
    print(f"copied {GRAPH_RENDERED.name} -> {GRAPH_IN_GAME.relative_to(ROOT)}")


def zip_dir(source: Path, zip_path: Path) -> None:
    """Flat zip of every file in source, skipping any zip already in there."""
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(source.iterdir()):
            if file.is_file() and file.suffix.lower() != ".zip":
                archive.write(file, file.name)
    print(f"wrote {zip_path} ({zip_path.stat().st_size / 1e6:.0f} MB)")


def export(godot: str, name: str, export_path: Path) -> None:
    export_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"\n=== exporting {name} ===")
    subprocess.run(
        [godot, "--headless", "--path", str(ROOT), "--export-release", name, str(export_path)],
        check=True,
    )
    if export_path.suffix.lower() != ".zip":  # Web: a folder of loose files.
        folder = export_path.parent
        zip_dir(folder, folder.with_suffix(".zip"))
        shutil.rmtree(folder)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("presets", nargs="*", help="preset names; default is all of them")
    ap.add_argument("--godot", help="path to the Godot executable")
    ap.add_argument("--skip-graph", action="store_true",
                    help="export without re-rendering the production graph")
    args = ap.parse_args()

    presets = read_presets()
    wanted = args.presets or list(presets)
    unknown = [name for name in wanted if name not in presets]
    if unknown:
        sys.exit(f"unknown preset(s): {', '.join(unknown)}\nknown: {', '.join(presets)}")

    godot = find_godot(args.godot)
    if not args.skip_graph:
        rebuild_graph()
    for name in wanted:
        export(godot, name, presets[name])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
