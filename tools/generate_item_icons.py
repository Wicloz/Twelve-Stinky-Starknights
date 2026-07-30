"""Author the stockpile item icons as flat vector SVGs.

One shared outline weight and palette so the whole set reads as a family at the
24px the resource grid draws them at: bold silhouette, one light top face, and
at most a couple of interior details.
"""

import math
import os
import sys

OUT = sys.argv[1]

INK = "#241c16"

# --- palette -----------------------------------------------------------------
WOOD, WOOD_L, WOOD_D = "#a9743f", "#c99560", "#7a5029"
CLAY, CLAY_L = "#b4643c", "#cf8259"
BRICK, BRICK_L, BRICK_D = "#b0503a", "#cd6f52", "#853727"
OIL, OIL_L = "#39324b", "#574c6f"
BRASS, BRASS_L = "#d4a23c", "#ecc568"
STEEL, STEEL_L, STEEL_D = "#9aa5b1", "#c3ccd6", "#6c7683"
NICKEL, NICKEL_L, NICKEL_D = "#9fadb8", "#d3dde4", "#6f7c86"
ELECTRUM, ELECTRUM_L = "#e0c76a", "#f2e39c"
SAND, SAND_L = "#ded1a4", "#f0e6c4"
SALT, SALT_L = "#dbe6ee", "#ffffff"
WATER, WATER_L = "#4aa8d8", "#8ed2f0"
ACID, ACID_L = "#c2d43f", "#e2ef86"
GLASS, GLASS_L = "#a8d3e2", "#e6f5fa"
POLY, POLY_L = "#6fc0a8", "#9ad9c6"
SILICON, SILICON_L = "#5b6b8c", "#8493b3"
PCB, PCB_L = "#2f8f57", "#4fb87a"
GOLD = "#e5c04a"
DARK, DARK_L = "#3b4250", "#5a6375"
JELLY, JELLY_L = "#f06fa0", "#ffa6c8"
CHERRY, CHERRY_L = "#c8384a", "#e2637a"
COFFEE, COFFEE_L = "#6b4530", "#8f6248"
LEAF = "#4f9e46"
WHITE, WHITE_D = "#f4f4f1", "#d3d3cd"
RED = "#d0483c"

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" '
        'width="64" height="64">')
GROUP = (f'<g stroke="{INK}" stroke-width="3" stroke-linejoin="round" '
         'stroke-linecap="round">')


def plain(body):
    """Details drawn on top of an outlined shape, without their own outline."""
    return f'<g stroke="none">{body}</g>'


def thin(d, color=INK, width=1.6):
    """Interior detail lines: takes path data, not markup."""
    return (f'<path d="{d}" fill="none" stroke="{color}" '
            f'stroke-width="{width}" stroke-linecap="round"/>')


def gear(cx, cy, r_out, r_in, teeth):
    pts = []
    step = math.pi / teeth
    for i in range(teeth * 2):
        r = r_out if i % 2 == 0 else r_in
        a = i * step - math.pi / 2
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def blades(cx, cy, r_in, r_out, count, fill):
    out = []
    for i in range(count):
        a = 2 * math.pi * i / count
        b = a + 0.9
        x1, y1 = cx + r_in * math.cos(a), cy + r_in * math.sin(a)
        x2, y2 = cx + r_out * math.cos(a + 0.35), cy + r_out * math.sin(a + 0.35)
        x3, y3 = cx + r_out * math.cos(b), cy + r_out * math.sin(b)
        out.append(f'<path d="M{x1:.1f} {y1:.1f} L{x2:.1f} {y2:.1f} '
                   f'L{x3:.1f} {y3:.1f} Z" fill="{fill}"/>')
    return "".join(out)


# Every solid in the set is built on one cabinet projection: the front face is
# drawn flat on, and depth recedes up and to the right along DEPTH_AXIS. Mixing
# in a second vanishing direction is what makes a flat icon look wrong, so
# nothing here gets to invent its own.
DEPTH_RISE = 0.7


def depth(d):
    return d, d * DEPTH_RISE


def ingot(x, y, w, h, base, light, dark, d=7, taper=4):
    """A cast bar: front face splayed wider at the base, like a real mould."""
    dx, dy = depth(d)
    return (
        f'<path d="M{x} {y} L{x + w} {y} L{x + w + taper} {y + h} '
        f'L{x - taper} {y + h} Z" fill="{base}"/>'
        f'<path d="M{x} {y} L{x + dx} {y - dy} L{x + w + dx} {y - dy} '
        f'L{x + w} {y} Z" fill="{light}"/>'
        f'<path d="M{x + w} {y} L{x + w + dx} {y - dy} '
        f'L{x + w + dx + taper} {y + h - dy} L{x + w + taper} {y + h} Z" fill="{dark}"/>'
    )


def ingots(base, light, dark):
    return (ingot(21, 29, 27, 10, base, light, dark, taper=3)
            + ingot(11, 43, 33, 12, base, light, dark))


def slab(x, y, w, t, d, base, light, dark):
    """A flat sheet: a large lit top surface over a thin visible edge."""
    dx, dy = depth(d)
    return (
        f'<path d="M{x} {y} L{x + w} {y} L{x + w} {y + t} L{x} {y + t} Z" fill="{base}"/>'
        f'<path d="M{x} {y} L{x + dx} {y - dy} L{x + w + dx} {y - dy} '
        f'L{x + w} {y} Z" fill="{light}"/>'
        f'<path d="M{x + w} {y} L{x + w + dx} {y - dy} L{x + w + dx} {y - dy + t} '
        f'L{x + w} {y + t} Z" fill="{dark}"/>'
    )


def box3d(x, y, w, h, d, base, light, dark):
    """Rectangular block in three-quarter view, x/y at its front-top-left."""
    dy = d * DEPTH_RISE
    return (
        f'<path d="M{x} {y + h} L{x} {y} L{x + w} {y} L{x + w} {y + h} Z" fill="{base}"/>'
        f'<path d="M{x} {y} L{x + d} {y - dy} L{x + w + d} {y - dy} L{x + w} {y} Z" fill="{light}"/>'
        f'<path d="M{x + w} {y} L{x + w + d} {y - dy} L{x + w + d} {y + h - dy} '
        f'L{x + w} {y + h} Z" fill="{dark}"/>'
    )


def log_end(cx, cy, r):
    """A log seen end-on: bark ring around a lighter cut face."""
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{WOOD_D}"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r - 3.5}" fill="{WOOD_L}"/>'
        + thin(f'M{cx - r + 7} {cy} A{r - 7} {r - 7} 0 1 1 {cx + r - 7} {cy}',
               WOOD, 1.8)
        + thin(f'M{cx - r + 10.5} {cy} A{r - 10.5} {r - 10.5} 0 1 0 {cx + r - 10.5} {cy}',
               WOOD, 1.8)
    )


ICONS = {}

# --- raw and bulk materials --------------------------------------------------
ICONS["lumber"] = (
    log_end(20, 42, 14) + log_end(46, 42, 13) + log_end(33, 20, 13)
)

ICONS["bricks"] = (
    box3d(6, 42, 32, 11, 7, BRICK, BRICK_L, BRICK_D)
    + box3d(16, 30, 32, 11, 7, BRICK, BRICK_L, BRICK_D)
    + box3d(9, 18, 32, 11, 7, BRICK, BRICK_L, BRICK_D)
)

ICONS["petrochemicals"] = (
    f'<path d="M16 16 L16 50 A16 6 0 0 0 48 50 L48 16 Z" fill="{OIL}"/>'
    f'<ellipse cx="32" cy="16" rx="16" ry="6" fill="{OIL_L}"/>'
    + plain(f'<ellipse cx="32" cy="16" rx="9" ry="3.2" fill="{OIL}"/>'
            f'<path d="M20 22 L20 48 A3 3 0 0 0 23 51 L23 23 Z" fill="{OIL_L}" opacity=".7"/>')
    + thin('M16 28 A16 6 0 0 0 48 28 M16 40 A16 6 0 0 0 48 40', "#8f86a8", 2.4)
)
ICONS["planks"] = (
    f'<rect x="6" y="38" width="52" height="12" rx="2.5" fill="{WOOD_D}"/>'
    f'<rect x="9" y="26" width="46" height="12" rx="2.5" fill="{WOOD}"/>'
    f'<rect x="13" y="14" width="38" height="12" rx="2.5" fill="{WOOD_L}"/>'
    + thin('M18 18 h28 M16 30 h32 M13 42 h38')
)

ICONS["clay"] = (
    f'<path d="M18 50 C18 32 26 20 38 20 C50 20 58 32 58 50 Z" fill="{CLAY}"/>'
    + plain(f'<path d="M26 36 C28 27 33 24 38 24 C41 24 43 25 45 27 '
            f'C38 27 31 31 29 38 Z" fill="{CLAY_L}"/>')
    + thin('M30 44 C34 40 39 39 44 41', "#8a4a2a", 2)
    + f'<path d="M6 50 C6 40 11 34 18 34 C25 34 30 40 30 50 Z" fill="{CLAY}"/>'
    + plain(f'<path d="M11 42 C13 37 16 36 19 37 C15 38 13 41 12 45 Z" fill="{CLAY_L}"/>')
)

ICONS["sand"] = (
    f'<path d="M6 50 C14 32 22 25 32 25 C42 25 50 32 58 50 Z" fill="{SAND}"/>'
    + plain(f'<path d="M32 25 C38 25 43 29 48 36 C40 31 30 31 22 36 '
            f'C26 29 28 25 32 25 Z" fill="{SAND_L}"/>'
            f'<circle cx="20" cy="44" r="1.8" fill="{INK}" opacity=".35"/>'
            f'<circle cx="30" cy="47" r="1.6" fill="{INK}" opacity=".35"/>'
            f'<circle cx="41" cy="43" r="1.8" fill="{INK}" opacity=".35"/>')
)

ICONS["evaporites"] = (
    box3d(27, 24, 15, 15, 6, SALT, SALT_L, "#c2d2dd")
    + box3d(7, 37, 15, 15, 6, SALT, SALT_L, "#c2d2dd")
    + box3d(27, 40, 15, 15, 6, SALT, SALT_L, "#c2d2dd")
)

ICONS["water"] = (
    f'<path d="M32 8 C42 24 52 32 52 40 A20 20 0 0 1 12 40 '
    f'C12 32 22 24 32 8 Z" fill="{WATER}"/>'
    + plain(f'<path d="M24 38 C24 31 27 26 31 20 C25 30 20 33 20 40 '
            f'A12 12 0 0 0 26 50 C24 46 24 42 24 38 Z" fill="{WATER_L}"/>')
)

ICONS["brass_ingots"] = ingots(BRASS, BRASS_L, "#a87d26")
ICONS["cupronickel_ingots"] = ingots(NICKEL, NICKEL_L, NICKEL_D)

# --- processed materials -----------------------------------------------------
ICONS["mechanical_components"] = (
    f'<polygon points="{gear(26, 28, 18, 13, 8)}" fill="{STEEL}"/>'
    f'<circle cx="26" cy="28" r="6" fill="{STEEL_D}"/>'
    f'<polygon points="{gear(46, 46, 12, 8.5, 7)}" fill="{BRASS}"/>'
    f'<circle cx="46" cy="46" r="4" fill="#a87d26"/>'
    + plain(f'<path d="M16 20 A16 16 0 0 1 34 15 L33 19 '
            f'A12 12 0 0 0 19 23 Z" fill="{STEEL_L}"/>')
)

ICONS["electrum_wire"] = (
    # Bottom flange goes down first so the wound body paints over its far half.
    # Drawn after, its whole rim reads as sitting in front of the cylinder.
    f'<ellipse cx="32" cy="48" rx="19" ry="7" fill="#c2a94c"/>'
    # The body closes across its base with the near half of the bottom rim, not
    # a straight edge, so the cylinder never shows a flat line where it lands.
    f'<path d="M19 16 L19 48 A13 5 0 0 0 45 48 L45 16 Z" fill="{ELECTRUM}"/>'
    # Windings wrap a cylinder, so they have to sag across its face by the same
    # amount the rims curve -- straight lines read as a flat card.
    + thin('M20 24 Q32 33 44 24 M20 32 Q32 41 44 32 M20 40 Q32 49 44 40',
           "#a8913c", 2)
    + f'<ellipse cx="32" cy="16" rx="19" ry="7" fill="{ELECTRUM_L}"/>'
    # The loose end has to leave the spool and keep going. Any curve that bends
    # back towards the body closes a loop against it and reads as a jug handle.
    + f'<path d="M44 29 C51 30 54 34 59 40" fill="none" stroke="{INK}" stroke-width="3"/>'
)

ICONS["acrylic"] = (
    slab(9, 45, 34, 7, 14, GLASS, GLASS_L, "#7fb8cc")
    + slab(9, 28, 34, 7, 14, GLASS, GLASS_L, "#7fb8cc")
    + plain(f'<path d="M15 26 L29 16.2 L34 16.2 L20 26 Z" fill="#ffffff" opacity=".55"/>'
            f'<path d="M15 43 L29 33.2 L34 33.2 L20 43 Z" fill="#ffffff" opacity=".55"/>')
)

ICONS["plastic"] = (
    f'<ellipse cx="20" cy="42" rx="11" ry="9" fill="{POLY}"/>'
    f'<ellipse cx="42" cy="43" rx="10" ry="8" fill="{POLY}"/>'
    f'<ellipse cx="31" cy="27" rx="11" ry="9" fill="{POLY_L}"/>'
    + plain(f'<ellipse cx="27" cy="24" rx="4" ry="3" fill="#c8ecdf"/>'
            f'<ellipse cx="16" cy="39" rx="3.5" ry="2.5" fill="{POLY_L}"/>')
)

ICONS["fluid_hardware"] = (
    f'<path d="M22 52 L22 24 A10 10 0 0 1 32 14 L50 14" fill="none" '
    f'stroke="{INK}" stroke-width="15"/>'
    f'<path d="M22 52 L22 24 A10 10 0 0 1 32 14 L50 14" fill="none" '
    f'stroke="{STEEL}" stroke-width="9"/>'
    + plain(f'<path d="M18.5 52 L18.5 24 A13.5 13.5 0 0 1 32 10.5 L32 13 '
            f'A11 11 0 0 0 21 24 L21 52 Z" fill="{STEEL_L}" opacity=".85"/>')
    + f'<rect x="14" y="46" width="16" height="7" rx="2" fill="{STEEL_D}"/>'
    + f'<rect x="44" y="8" width="7" height="14" rx="2" fill="{STEEL_D}"/>'
)

ICONS["sulfuric_acid"] = (
    f'<path d="M26 8 L38 8 L38 24 L52 46 A5 5 0 0 1 48 54 L16 54 '
    f'A5 5 0 0 1 12 46 L26 24 Z" fill="{GLASS_L}"/>'
    + plain(f'<path d="M19 38 L45 38 L52 46 A5 5 0 0 1 48 54 L16 54 '
            f'A5 5 0 0 1 12 46 Z" fill="{ACID}"/>'
            f'<circle cx="26" cy="46" r="2.5" fill="{ACID_L}"/>'
            f'<circle cx="36" cy="49" r="2" fill="{ACID_L}"/>'
            f'<path d="M28 12 L31 12 L31 24 L28 28 Z" fill="#ffffff" opacity=".7"/>')
    + thin('M24 8 h16', INK, 3)
)

# --- electronics -------------------------------------------------------------
ICONS["power_cells"] = (
    f'<rect x="26" y="8" width="12" height="6" rx="2" fill="{STEEL_D}"/>'
    f'<rect x="14" y="14" width="36" height="42" rx="4" fill="{DARK}"/>'
    + plain(f'<rect x="18" y="18" width="8" height="34" rx="2" fill="{DARK_L}"/>'
            f'<path d="M34 22 L24 38 L31 38 L28 50 L40 33 L33 33 Z" fill="{GOLD}"/>')
)

ICONS["semiconductors"] = (
    f'<path d="M20 51 A23 23 0 1 1 44 51 Z" fill="{SILICON}"/>'
    + plain(f'<path d="M14 30 A23 23 0 0 1 44 12 L40 18 '
            f'A17 17 0 0 0 19 32 Z" fill="{SILICON_L}"/>')
    + thin('M12 24 h40 M10 34 h44 M14 44 h36 M22 10 v42 M32 8 v44 M42 10 v42',
           "#2c3549", 1.4)
)

ICONS["integrated_circuits"] = (
    f'<rect x="16" y="16" width="32" height="32" rx="3" fill="{DARK}"/>'
    + plain(f'<rect x="20" y="20" width="24" height="10" rx="2" fill="{DARK_L}"/>'
            f'<circle cx="23" cy="43" r="2.5" fill="{DARK_L}"/>')
    + thin(f'M10 23 h6 M10 32 h6 M10 41 h6 M48 23 h6 M48 32 h6 M48 41 h6 '
           f'M23 10 v6 M32 10 v6 M41 10 v6 M23 48 v6 M32 48 v6 M41 48 v6',
           GOLD, 4)
)

ICONS["electronic_components"] = (
    f'<path d="M8 22 h12 M44 22 h12" fill="none" stroke="{INK}" stroke-width="3"/>'
    f'<rect x="20" y="14" width="24" height="16" rx="4" fill="{SAND_L}"/>'
    + plain(f'<rect x="25" y="14" width="4" height="16" fill="{CHERRY}"/>'
            f'<rect x="32" y="14" width="4" height="16" fill="{COFFEE}"/>'
            f'<rect x="38" y="14" width="3" height="16" fill="{GOLD}"/>')
    + f'<rect x="20" y="38" width="16" height="18" rx="3" fill="{DARK}"/>'
    + f'<path d="M28 38 v-6" fill="none" stroke="{INK}" stroke-width="3"/>'
    + plain(f'<rect x="23" y="41" width="4" height="12" rx="1" fill="{DARK_L}"/>')
    + f'<circle cx="48" cy="46" r="9" fill="{STEEL}"/>'
    + plain(f'<circle cx="48" cy="46" r="4" fill="{STEEL_D}"/>')
)

ICONS["industrial_controllers"] = (
    f'<rect x="8" y="14" width="48" height="36" rx="4" fill="{DARK}"/>'
    + plain(f'<rect x="13" y="19" width="26" height="16" rx="2" fill="{PCB_L}"/>'
            f'<rect x="13" y="40" width="38" height="5" rx="2" fill="{DARK_L}"/>'
            f'<circle cx="46" cy="21" r="3" fill="{RED}"/>'
            f'<circle cx="46" cy="30" r="3" fill="{ACID}"/>')
    + thin('M17 24 h14 M17 30 h9', "#1c5c38", 2)
)

ICONS["actuators"] = (
    f'<rect x="8" y="24" width="30" height="18" rx="4" fill="{STEEL}"/>'
    f'<path d="M38 33 h12" fill="none" stroke="{INK}" stroke-width="9"/>'
    f'<path d="M38 33 h12" fill="none" stroke="{NICKEL_L}" stroke-width="5"/>'
    f'<path d="M50 26 h6 v14 h-6" fill="{BRASS}"/>'
    + plain(f'<rect x="12" y="27" width="22" height="5" rx="2" fill="{STEEL_L}"/>')
    + thin('M18 42 v6 M28 42 v6', INK, 3)
)

# --- challenge goods ---------------------------------------------------------
ICONS["jelly_standees"] = (
    f'<path d="M14 44 C14 26 22 14 32 14 C42 14 50 26 50 44 Z" fill="{JELLY}"/>'
    + plain(f'<path d="M22 32 C22 23 26 18 31 18 C28 22 26 27 26 34 Z" fill="{JELLY_L}"/>'
            f'<circle cx="26" cy="34" r="3" fill="{INK}"/>'
            f'<circle cx="38" cy="34" r="3" fill="{INK}"/>')
    + f'<rect x="10" y="44" width="44" height="8" rx="2" fill="{SAND}"/>'
    + f'<path d="M40 52 L48 58" fill="none" stroke="{INK}" stroke-width="3"/>'
)

# Coffee cherries, not sweet cherries: a tight cluster sitting directly on the
# branch, each fruit crowned by its calyx, under the long pointed coffee leaf.
ICONS["coffee_cherries"] = (
    f'<path d="M28 36 C36 28 45 19 55 12" fill="none" stroke="{INK}" stroke-width="7"/>'
    f'<path d="M28 36 C36 28 45 19 55 12" fill="none" stroke="{COFFEE}" stroke-width="3.5"/>'
    f'<path d="M37 25 C41 11 52 4 61 6 C59 18 49 27 37 25 Z" fill="{LEAF}"/>'
    + thin('M40 24 C46 18 53 11 59 8', "#2f6b2a", 1.8)
    + f'<circle cx="21" cy="44" r="11" fill="{CHERRY}"/>'
    + f'<circle cx="42" cy="47" r="10" fill="#a82c3c"/>'
    + f'<circle cx="31" cy="30" r="10" fill="{CHERRY}"/>'
    + plain(f'<circle cx="17" cy="40" r="3.2" fill="{CHERRY_L}"/>'
            f'<circle cx="27" cy="26" r="2.8" fill="{CHERRY_L}"/>'
            f'<circle cx="20" cy="52" r="2.4" fill="{COFFEE}"/>'
            f'<circle cx="48" cy="52" r="2.2" fill="{COFFEE}"/>'
            f'<circle cx="25" cy="23" r="2.2" fill="{COFFEE}"/>')
)

ICONS["jelly_coffee"] = (
    f'<path d="M16 14 L48 14 L43 52 A4 4 0 0 1 39 56 L25 56 '
    f'A4 4 0 0 1 21 52 Z" fill="{GLASS_L}"/>'
    + plain(f'<path d="M19 34 L45 34 L43 52 A4 4 0 0 1 39 56 L25 56 '
            f'A4 4 0 0 1 21 52 Z" fill="{COFFEE}"/>'
            f'<path d="M20.5 44 L43.5 44 L43 52 A4 4 0 0 1 39 56 L25 56 '
            f'A4 4 0 0 1 21 52 Z" fill="{JELLY}"/>'
            f'<path d="M22 18 L26 18 L24 32 L21 32 Z" fill="#ffffff" opacity=".65"/>')
    + f'<path d="M38 10 L44 30" fill="none" stroke="{INK}" stroke-width="3"/>'
)

ICONS["steam_engine"] = (
    f'<rect x="6" y="46" width="52" height="10" rx="3" fill="{STEEL_D}"/>'
    f'<circle cx="20" cy="30" r="15" fill="{STEEL}"/>'
    + plain(f'<circle cx="20" cy="30" r="5" fill="{STEEL_D}"/>')
    + thin('M20 15 v30 M5 30 h30 M9 19 L31 41 M31 19 L9 41', "#6c7683", 2.4)
    + f'<rect x="38" y="24" width="20" height="14" rx="3" fill="{BRASS}"/>'
    + f'<path d="M35 31 h5" fill="none" stroke="{INK}" stroke-width="5"/>'
    + f'<rect x="42" y="10" width="10" height="14" rx="2" fill="{STEEL_D}"/>'
)

ICONS["white_paint"] = (
    f'<path d="M14 20 L50 20 L47 54 A3 3 0 0 1 44 56 L20 56 '
    f'A3 3 0 0 1 17 54 Z" fill="{WHITE}"/>'
    f'<ellipse cx="32" cy="20" rx="18" ry="6" fill="{WHITE_D}"/>'
    f'<path d="M18 18 C18 6 46 6 46 18" fill="none" stroke="{INK}" stroke-width="3"/>'
    + plain(f'<rect x="22" y="26" width="6" height="24" rx="3" fill="{WHITE_D}"/>')
    + f'<path d="M50 26 C56 32 56 40 50 40 C46 40 46 32 50 26 Z" fill="{WHITE}"/>'
)

# --- PC build ----------------------------------------------------------------
ICONS["pc_ram"] = (
    f'<rect x="6" y="20" width="52" height="20" rx="2" fill="{PCB}"/>'
    + plain(f'<rect x="11" y="24" width="9" height="12" rx="1" fill="{DARK}"/>'
            f'<rect x="23" y="24" width="9" height="12" rx="1" fill="{DARK}"/>'
            f'<rect x="35" y="24" width="9" height="12" rx="1" fill="{DARK}"/>'
            f'<rect x="47" y="24" width="6" height="12" rx="1" fill="{DARK}"/>')
    + f'<path d="M8 44 h48" fill="none" stroke="{GOLD}" stroke-width="7"/>'
    + thin('M18 41 v7 M30 41 v7 M42 41 v7', PCB, 3)
)

ICONS["pc_cpu"] = (
    f'<path d="M14 12 L50 12 L50 44 L44 50 L14 50 Z" fill="{DARK}"/>'
    + plain(f'<rect x="20" y="18" width="24" height="20" rx="2" fill="{NICKEL}"/>'
            f'<rect x="20" y="18" width="24" height="7" rx="2" fill="{NICKEL_L}"/>')
    + thin(f'M10 20 h4 M10 28 h4 M10 36 h4 M50 20 h4 M50 28 h4 '
           f'M20 8 v4 M30 8 v4 M40 8 v4 M20 50 v4 M30 50 v4', GOLD, 3.5)
)

ICONS["pc_gpu"] = (
    f'<rect x="6" y="18" width="46" height="28" rx="3" fill="{PCB}"/>'
    f'<rect x="52" y="12" width="6" height="40" rx="2" fill="{STEEL}"/>'
    f'<circle cx="24" cy="32" r="12" fill="{DARK}"/>'
    + plain(blades(24, 32, 3, 11, 5, DARK_L)
            + f'<circle cx="24" cy="32" r="3.5" fill="{STEEL_L}"/>'
            + f'<rect x="40" y="24" width="9" height="16" rx="2" fill="{DARK}"/>')
    + f'<path d="M10 48 h26" fill="none" stroke="{GOLD}" stroke-width="6"/>'
)

ICONS["pc_motherboard"] = (
    f'<rect x="8" y="8" width="48" height="48" rx="4" fill="{PCB}"/>'
    + plain(f'<rect x="14" y="14" width="16" height="16" rx="2" fill="{NICKEL}"/>'
            f'<rect x="36" y="13" width="6" height="20" rx="2" fill="{DARK}"/>'
            f'<rect x="45" y="13" width="6" height="20" rx="2" fill="{DARK}"/>'
            f'<rect x="14" y="40" width="34" height="6" rx="2" fill="{DARK}"/>'
            f'<circle cx="52" cy="50" r="2.5" fill="{PCB_L}"/>')
    + thin('M14 36 h30', PCB_L, 2)
)

ICONS["pc_power_supply"] = (
    f'<rect x="8" y="14" width="48" height="34" rx="4" fill="{DARK}"/>'
    f'<circle cx="28" cy="31" r="12" fill="{DARK_L}"/>'
    + plain(blades(28, 31, 3, 11, 6, DARK)
            + f'<circle cx="28" cy="31" r="3.5" fill="{STEEL_L}"/>')
    + thin('M46 22 h4 M46 28 h4 M46 34 h4 M46 40 h4', STEEL_L, 2.5)
    + f'<path d="M56 44 C62 44 62 54 54 54" fill="none" stroke="{INK}" stroke-width="4"/>'
)

ICONS["pc_glass"] = (
    f'<rect x="10" y="8" width="44" height="48" rx="3" fill="{GLASS}"/>'
    + plain(f'<path d="M16 56 L38 8 L46 8 L24 56 Z" fill="#ffffff" opacity=".45"/>'
            f'<path d="M44 56 L52 38 L52 56 Z" fill="#ffffff" opacity=".35"/>'
            f'<circle cx="16" cy="14" r="2.5" fill="{STEEL_D}"/>'
            f'<circle cx="48" cy="14" r="2.5" fill="{STEEL_D}"/>'
            f'<circle cx="16" cy="50" r="2.5" fill="{STEEL_D}"/>'
            f'<circle cx="48" cy="50" r="2.5" fill="{STEEL_D}"/>')
)

ICONS["pc_case"] = (
    f'<rect x="16" y="6" width="32" height="52" rx="4" fill="{DARK}"/>'
    + plain(f'<rect x="21" y="11" width="22" height="14" rx="2" fill="{DARK_L}"/>'
            f'<circle cx="32" cy="38" r="8" fill="{DARK_L}"/>'
            + blades(32, 38, 2.5, 7.5, 5, DARK)
            + f'<circle cx="24" cy="52" r="2.5" fill="{ACID}"/>')
    + thin('M25 15 h14 M25 20 h9', DARK, 2)
)

ICONS["pc_fans"] = (
    f'<rect x="6" y="6" width="52" height="52" rx="8" fill="{DARK}"/>'
    f'<circle cx="32" cy="32" r="21" fill="{DARK_L}"/>'
    + plain(blades(32, 32, 6, 20, 6, DARK)
            + f'<circle cx="32" cy="32" r="7" fill="{STEEL}"/>'
            + f'<circle cx="30" cy="30" r="2.5" fill="{STEEL_L}"/>'
            + f'<circle cx="13" cy="13" r="2.5" fill="{STEEL_D}"/>'
            + f'<circle cx="51" cy="13" r="2.5" fill="{STEEL_D}"/>'
            + f'<circle cx="13" cy="51" r="2.5" fill="{STEEL_D}"/>'
            + f'<circle cx="51" cy="51" r="2.5" fill="{STEEL_D}"/>')
)

ICONS["pc_aio_cooler"] = (
    f'<rect x="8" y="6" width="48" height="18" rx="3" fill="{STEEL}"/>'
    + thin('M14 8 v14 M20 8 v14 M26 8 v14 M32 8 v14 M38 8 v14 M44 8 v14 M50 8 v14',
           STEEL_D, 2.4)
    + f'<path d="M22 24 C18 32 20 38 24 42" fill="none" stroke="{INK}" stroke-width="7"/>'
    + f'<path d="M42 24 C46 32 44 38 40 42" fill="none" stroke="{INK}" stroke-width="7"/>'
    + f'<rect x="20" y="40" width="24" height="16" rx="4" fill="{DARK}"/>'
    + plain(f'<circle cx="32" cy="48" r="5" fill="{WATER}"/>'
            f'<circle cx="30" cy="46" r="2" fill="{WATER_L}"/>')
)

ICONS["pc"] = (
    f'<rect x="6" y="10" width="36" height="26" rx="3" fill="{DARK}"/>'
    + plain(f'<rect x="10" y="14" width="28" height="18" rx="1.5" fill="{WATER}"/>'
            f'<path d="M12 32 L26 14 L31 14 L17 32 Z" fill="#ffffff" opacity=".3"/>')
    + f'<path d="M24 36 v6 M16 42 h16" fill="none" stroke="{INK}" stroke-width="3"/>'
    + f'<rect x="44" y="20" width="16" height="36" rx="3" fill="{DARK}"/>'
    + plain(f'<rect x="47" y="24" width="10" height="7" rx="1.5" fill="{DARK_L}"/>'
            f'<circle cx="52" cy="40" r="5" fill="{DARK_L}"/>'
            + blades(52, 40, 1.8, 4.5, 5, DARK)
            + f'<circle cx="48" cy="51" r="2" fill="{ACID}"/>')
)

os.makedirs(OUT, exist_ok=True)
for name, body in sorted(ICONS.items()):
    svg = HEAD + GROUP + body + "</g></svg>"
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as fh:
        fh.write(svg)

print(f"wrote {len(ICONS)} icons to {OUT}")
