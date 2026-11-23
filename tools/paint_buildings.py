"""A fresh coat of paint for buildings you fix up (Daniel, Nov 23), so they match the town once repaired.
Run from import_packs.py with OUT and save (after the building pictures are written), or alone:
python3 tools/paint_buildings.py <art>.

  farmhouse_3.png   Hal's second repair: the rusty roof painted barn red
  farmhouse_4.png   Hal's last repair: the roof painted, the plank walls painted cream, clean all over
  tavern_open.png   the Lantern Post once it's restored: slate roof red, grey metal walls warm wood brown
Art.building_art uses buildings/<kind>_<condition>.png as it is (no wear drawn on) when it exists.

How: each part (roof, walls) is picked out by where it is on the picture and what colour it is, then every pixel
in it is given one of four shades of the new paint by how light it was (split at that part's quartiles), so the
pattern of the corrugation, slates and planks stays and the rust, grime and odd colours go.
"""
import colorsys
import os
import sys
from PIL import Image

if "OUT" not in globals():
    OUT = sys.argv[1]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)


def lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def paint(im, pick, ramp, keep_dark=0.16):
    """Repaint the pixels pick(x, y, c) chooses with the four-shade ramp (dark to light)."""
    px = im.load()
    pts = []
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] < 200 or lum(c) < keep_dark:
                continue
            if pick(x, y, c):
                pts.append((x, y, lum(c)))
    if not pts:
        return
    ls = sorted(p[2] for p in pts)
    q = [ls[len(ls) * k // 4] for k in (1, 2, 3)]
    cols = [hexc(h) for h in ramp]
    for x, y, l in pts:
        i = 0 if l < q[0] else 1 if l < q[1] else 2 if l < q[2] else 3
        px[x, y] = cols[i] + (px[x, y][3],)


def scrub(im, pick, amount=0.5):
    """Clean without repainting: pull odd-coloured specks toward the part's average colour, a touch lighter."""
    px = im.load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y][3] >= 200 and lum(px[x, y]) >= 0.16 and pick(x, y, px[x, y])]
    if not pts:
        return
    avg = [sum(px[x, y][i] for x, y in pts) / len(pts) for i in range(3)]
    for x, y in pts:
        c = px[x, y]
        h, s, v = hsv(c)
        # keep the light and dark of each pixel, take the hue and saturation toward the average
        ah, as_, av = colorsys.rgb_to_hsv(*(a / 255 for a in avg))
        r, g, b = colorsys.hsv_to_rgb(ah, as_ * (1 - amount) + s * amount * 0.6, min(1.0, v * 1.06))
        px[x, y] = (int(r * 255), int(g * 255), int(b * 255), c[3])


n = 0
src = os.path.join(OUT, "buildings", "farmhouse.png")
if os.path.isfile(src):
    base = Image.open(src).convert("RGBA")
    EAVE = 97   # the roof ends and the plank walls begin here

    def roof(x, y, c):
        if 12 <= x <= 26 and y <= 36:
            return False      # the chimney and aerial
        return y < EAVE

    # the farmhouse's own bits that keep their colours: windows, awning, door, mailbox, the side vent, a lamp
    KEEP = [(20, 99, 44, 117), (66, 98, 96, 118), (107, 99, 138, 131), (141, 103, 154, 117), (170, 93, 192, 108),
            (49, 99, 61, 109)]

    def walls(x, y, c):
        if y < EAVE or y >= 132:
            return False      # the roof above, the steps below
        if x >= 160 and y >= 116:
            return False      # the stone footing round the side
        for r in KEEP:
            if r[0] <= x <= r[2] and r[1] <= y <= r[3]:
                return False
        h, s, v = hsv(c)
        return s <= 0.4

    RED = ["#5a2622", "#863428", "#a5463a", "#c25a4a"]
    CREAM = ["#8a7a62", "#c8b894", "#ddd0ae", "#efe6cc"]
    im3 = base.copy()
    paint(im3, roof, RED)
    save(im3, "buildings/farmhouse_3.png")
    im4 = base.copy()
    paint(im4, roof, RED)
    paint(im4, walls, CREAM)
    save(im4, "buildings/farmhouse_4.png")
    n += 2

src = os.path.join(OUT, "buildings", "tavern.png")
if os.path.isfile(src):
    base = Image.open(src).convert("RGBA")

    def eave(x):
        return 88 + abs(x - 120) * 0.53

    def t_roof(x, y, c):
        return 35 <= x <= 208 and y < eave(x) and y < 138

    def t_walls(x, y, c):
        if t_roof(x, y, c) or y >= 222:
            return False
        h, s, v = hsv(c)
        if s > 0.22 and 0.02 <= h <= 0.14:
            return False      # wooden awning, window frames, door, the brown side wall
        return s < 0.24 and 0.45 <= h <= 0.8 or s < 0.1

    im = base.copy()
    paint(im, t_roof, ["#4e2422", "#6e3028", "#8c3e32", "#a85040"])
    paint(im, t_walls, ["#4e3c32", "#76604e", "#957a62", "#b2967a"])
    save(im, "buildings/tavern_open.png")
    n += 1
print("painted buildings:", n)
