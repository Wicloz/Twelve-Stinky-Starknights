#!/usr/bin/env python3
"""Clean up the raw Kenney-style hex terrain tiles in creation/terrain/.

Problems in the source set and how each is fixed:

  * Content floats in an oversized canvas, hex face pinned to the bottom.
      -> Output onto a uniform canvas with the hex FACE centred (so the game's
         centred tile sprite seats it correctly), terrain rising above.
  * Bottom point of the hexagon is clipped by the canvas edge.
      -> The face silhouette is redrawn from ideal geometry, so the point is
         restored; colour is extended into the restored tip.
  * Diagonal edges are softly/unevenly anti-aliased while the vertical edges
    are pixel-hard, so they "stand out".
      -> The hexagon silhouette is replaced with a supersampled coverage mask,
         giving consistent, geometry-correct AA on every edge.

The raised terrain (mountains, mesas, trees) above the hex face is preserved.
Flat tiles are reshaped to the full clean hexagon; terrain tiles keep their art
above the face and get the clean mask only on the face (sides + bottom point).
"""

from __future__ import annotations

import glob
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt

SRC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "terrain")
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "terrain_clean")

# --- ideal hex-face geometry (source pixels) --------------------------------
W = 256                      # tile / face width
FACE_TOP = 128               # y of the top vertex in the source frame
FACE_H = 256                 # face height (top vertex -> bottom vertex)
TAPER = 64                   # vertical extent of each diagonal edge
LOWER_VTX = FACE_TOP + FACE_H - TAPER          # y where sides meet bottom taper (320)

# --- output canvas: face centred, tall enough for the tallest terrain -------
OUT_H = 512
CY = OUT_H // 2              # 256; face centre sits here
# face top/bottom in the OUTPUT frame
OTOP = CY - FACE_H // 2      # 128
OBOT = CY + FACE_H // 2      # 384
OUP = OTOP + TAPER          # 192  (upper side vertices)
OLOW = OBOT - TAPER          # 320  (lower side vertices)

TERRAIN_OVERHANG = 8         # >this many px above the face top => "terrain" tile
SS = 8                       # mask supersampling factor


def build_face_mask() -> np.ndarray:
    """Supersampled coverage mask (0..1) of the ideal hex face, output frame."""
    big = Image.new("L", (W * SS, OUT_H * SS), 0)
    verts = [
        (W // 2, OTOP),   # top
        (W,      OUP),    # upper-right
        (W,      OLOW),   # lower-right
        (W // 2, OBOT),   # bottom
        (0,      OLOW),   # lower-left
        (0,      OUP),    # upper-left
    ]
    ImageDraw.Draw(big).polygon([(x * SS, y * SS) for x, y in verts], fill=255)
    small = big.reduce(SS)                       # box-average -> coverage AA
    return np.asarray(small, dtype=np.float32) / 255.0


def lower_vertex_y(alpha: np.ndarray) -> int:
    """Lowest row where the silhouette spans the full width (the side/bottom
    taper join) - a stable landmark for vertical alignment."""
    h, w = alpha.shape
    for y in range(h - 1, -1, -1):
        xs = np.where(alpha[y] > 40)[0]
        if len(xs) and xs.min() <= 1 and xs.max() >= w - 2:
            return y
    return LOWER_VTX


def place_centered(src: np.ndarray) -> np.ndarray:
    """Drop the source tile onto the tall output canvas, aligning its face so
    the lower vertex lands on OLOW (and thus the face centre on CY)."""
    a = src[:, :, 3]
    shift = OLOW - lower_vertex_y(a)
    dst = np.zeros((OUT_H, W, 4), dtype=np.uint8)
    sh, sw = src.shape[:2]
    for ys in range(sh):
        yd = ys + shift
        if 0 <= yd < OUT_H:
            dst[yd] = src[ys]
    return dst


def extend_color(rgb: np.ndarray, opaque: np.ndarray) -> np.ndarray:
    """Fill colour into (soon-to-be-opaque) pixels from the nearest opaque
    source pixel, so new AA edges and the restored tip never show black."""
    if not opaque.any():
        return rgb
    idx = distance_transform_edt(~opaque, return_distances=False, return_indices=True)
    return rgb[idx[0], idx[1]]


def process(path: str, mask: np.ndarray) -> Image.Image:
    src = np.asarray(Image.open(path).convert("RGBA"))
    canvas = place_centered(src)
    a = canvas[:, :, 3].astype(np.float32) / 255.0
    rgb = canvas[:, :, :3]

    top = np.where((canvas[:, :, 3] > 20).any(axis=1))[0]
    overhang = OTOP - int(top.min()) if len(top) else 0
    is_terrain = overhang > TERRAIN_OVERHANG

    if is_terrain:
        # Keep the raised art above the upper side-vertices; use the clean mask
        # on the face (sides + bottom taper). Blend across the join to be safe.
        ys = np.arange(OUT_H, dtype=np.float32)[:, None]
        t = np.clip((ys - (OUP - 4)) / 8.0, 0.0, 1.0)     # 0 above, 1 below
        out_a = a * (1 - t) + mask * t
    else:
        out_a = mask.copy()                                # clean full hexagon

    out_rgb = extend_color(rgb, a > 0.5)
    out = np.dstack([out_rgb, (np.clip(out_a, 0, 1) * 255).round().astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    mask = build_face_mask()
    files = sorted(glob.glob(os.path.join(SRC_DIR, "*.png")))
    for f in files:
        img = process(f, mask)
        img.save(os.path.join(OUT_DIR, os.path.basename(f)))
    print(f"processed {len(files)} tiles -> {OUT_DIR}  ({W}x{OUT_H})")


if __name__ == "__main__":
    main()
