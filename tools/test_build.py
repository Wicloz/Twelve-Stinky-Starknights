#!/usr/bin/env python
"""Self-check for build.py: preset parsing and zipping. Run: python test_build.py"""

import tempfile
import zipfile
from pathlib import Path

import build


def test_presets():
    presets = build.read_presets()
    assert "12SS Web" in presets, presets
    assert presets["12SS Web"].name == "index.html", presets["12SS Web"]
    assert all(p.suffix == ".zip" for n, p in presets.items() if n != "12SS Web"), presets


def test_zip_dir():
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "out"
        src.mkdir()
        (src / "index.html").write_text("hi")
        (src / "index.pck").write_bytes(b"x" * 1000)
        (src / "stale.zip").write_bytes(b"old")  # must be skipped
        out = Path(tmp) / "out.zip"
        build.zip_dir(src, out)
        with zipfile.ZipFile(out) as z:
            assert z.namelist() == ["index.html", "index.pck"], z.namelist()
            assert z.read("index.html") == b"hi"


if __name__ == "__main__":
    test_presets()
    test_zip_dir()
    print("ok")
