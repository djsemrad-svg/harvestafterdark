"""Raised ground pictures (Nov 22), written to art/terrain/. Run from import_packs.py with SRC, OUT and save, or
alone: python3 tools/terrain_art.py <packs> <art>.

earth: LimeZu's earth cliff from Modern Exteriors (1_Terrains_and_Fences, the grass-topped block at columns 8-10,
       rows 42-46). Its flat grass is cut out so the game's own seasonal grass shows on top.
stone: the same pieces with the brown rock turned to grey stone.
turf:  drawn here: a sunlit lip, thin side rims and a one-tile bank of shaded grass, laid over the real ground.
boulder: Serene Village's boulder plateau, a rim of boulders and a one-tile face of big ones.
Pieces: <style>_n[_w|_e] (top row), _m_w/_m_e (sides), _s[_w|_e] (bottom row), _f1/_f2[_w|_e] (the face),
steps_<style>_<row>_<l|r> (two tiles wide), shadow (the foot of a cliff)."""
import colorsys
import os
import sys
from collections import Counter
from PIL import Image, ImageDraw

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

SHEET = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "ME_Theme_Sorter_16x16", "1_Terrains_and_Fences_16x16.png")
n = 0
if os.path.isfile(SHEET):
    ME = Image.open(SHEET).convert("RGBA")

    def cell(c, r):
        return ME.crop((c * 16, r * 16, (c + 1) * 16, (r + 1) * 16))

    FLAT = Counter(p[:3] for p in cell(9, 43).getdata() if p[3]).most_common(1)[0][0]

    def piece(c, r):
        p = cell(c, r).copy()
        px = p.load()
        for y in range(16):
            for x in range(16):
                if px[x, y][3] and px[x, y][:3] == FLAT:
                    px[x, y] = (0, 0, 0, 0)
        return p

    def stone(im):
        im = im.copy()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if not a:
                    continue
                h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
                if s > 0.12 and (h < 0.17 or h > 0.9):
                    r2, g2, b2 = colorsys.hls_to_rgb(0.6, l * 0.92, 0.07)
                    px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
        return im

    COLS = {"w": 8, "": 9, "e": 10}
    ROWS = {"n": 42, "m": 43, "s": 44, "f1": 45, "f2": 46}
    for style, fn in (("earth", lambda im: im), ("stone", stone)):
        for row, rr in ROWS.items():
            for col, cc in COLS.items():
                if row == "m" and col == "":
                    continue
                save(fn(piece(cc, rr)), "terrain/%s_%s%s.png" % (style, row, ("_" + col) if col else ""))
                n += 1

# ---------------------------------------------------------------- turf: drawn over the ground
LIP, LIP2, RIM, BANK, TUFT, FOOT = (166, 212, 104, 255), (126, 174, 78, 240), (52, 86, 44, 230), (18, 42, 16, 130), (46, 84, 40, 220), (30, 52, 26, 240)


def turf(row, col):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if row == "n":
        d.line((0, 0, 15, 0), fill=LIP)
        d.line((0, 1, 15, 1), fill=LIP2)
    if row == "f1":
        d.rectangle((0, 0, 15, 15), fill=BANK)
        d.line((0, 0, 15, 0), fill=LIP)
        d.line((0, 1, 15, 1), fill=LIP2)
        for x in range(1, 16, 4):
            d.line((x, 3, x + 1, 7), fill=TUFT)
            d.line((x + 2, 8, x + 2, 11), fill=TUFT)
        d.line((0, 15, 15, 15), fill=FOOT)
    if col == "w":
        d.line((0, 0, 0, 15), fill=RIM)
    if col == "e":
        d.line((15, 0, 15, 15), fill=RIM)
    return im


for row in ("n", "m", "s", "f1"):
    for col in ("w", "", "e"):
        if row == "m" and col == "":
            continue
        save(turf(row, col), "terrain/turf_%s%s.png" % (row, ("_" + col) if col else ""))
        n += 1


# ---------------------------------------------------------------- steps, two tiles wide
def steps(rows, wood):
    top, front, dark = ((176, 124, 78, 255), (132, 86, 54, 255), (58, 40, 32, 255)) if wood else ((172, 172, 178, 255), (122, 124, 134, 255), (58, 58, 72, 255))
    h = rows * 16
    im = Image.new("RGBA", (32, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y0 = 9                        # the top step starts a little way into the rise's last row
    d.rectangle((1, y0, 30, h - 1), fill=dark)
    for sy in range(y0 + 1, h - 3, 5):
        d.rectangle((2, sy, 29, sy + 2), fill=top)
        d.rectangle((2, sy + 3, 29, sy + 3), fill=front)
    d.line((1, y0, 1, h - 1), fill=dark)
    d.line((30, y0, 30, h - 1), fill=dark)
    return im


for style, rows, wood in (("earth", 3, True), ("stone", 3, False), ("turf", 2, True)):
    st = steps(rows, wood)
    for k in range(rows):
        save(st.crop((0, k * 16, 16, k * 16 + 16)), "terrain/steps_%s_%d_l.png" % (style, k))
        save(st.crop((16, k * 16, 32, k * 16 + 16)), "terrain/steps_%s_%d_r.png" % (style, k))
        n += 2

# the shadow a cliff casts on the ground at its foot
sh = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y in range(9):
    a = int(80 * (1 - y / 9.0))
    for x in range(16):
        sh.putpixel((x, y), (10, 20, 10, a))
save(sh, "terrain/shadow.png")
n += 1


# ---------------------------------------------------------------- boulder: Serene Village's boulder plateau (Nov 22)
# A rim of round boulders round the top and a one-tile face of big boulders (cols 0-5, rows 7-10 of the sheet),
# its flat grass cut out so the game's grass shows. Steps are the sheet's own dirt landing and stairs.
SV = os.path.join(SRC, "Serene_Village_revamped_v1.9", "SERENE_VILLAGE_REVAMPED", "Serene_Village_16x16.png")
if os.path.isfile(SV):
    SVI = Image.open(SV).convert("RGBA")
    GRASS = {(118, 197, 100), (123, 203, 105)}

    def sv(c, r):
        p = SVI.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
        px = p.load()
        for y in range(16):
            for x in range(16):
                q = px[x, y]
                if q[3] and q[:3] in GRASS:
                    px[x, y] = (0, 0, 0, 0)
                elif q[3]:      # a little less pink, to sit beside the other rock
                    h, l, s2 = colorsys.rgb_to_hls(q[0] / 255, q[1] / 255, q[2] / 255)
                    if not (q[1] > q[0] + 8):
                        r2, g2, b2 = colorsys.hls_to_rgb(h, l, s2 * 0.7)
                        px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), q[3])
        return p

    BCOL = {"w": 0, "": 2, "e": 5}
    for row, rr in {"n": 7, "m": 8, "s": 9}.items():
        for col, cc in BCOL.items():
            if row == "m" and col == "":
                continue
            save(sv(1 if (row == "s" and col == "") else cc, rr), "terrain/boulder_%s%s.png" % (row, ("_" + col) if col else ""))
            n += 1
    for col, cc in {"w": 0, "": 1, "e": 5}.items():
        save(sv(cc, 10), "terrain/boulder_f1%s.png" % (("_" + col) if col else ""))
        n += 1
    save(sv(4, 10), "terrain/boulder_f1_b.png")       # a second big boulder, every other tile
    n += 1
    for k in range(2):
        save(sv(2, 9 + k), "terrain/steps_boulder_%d_l.png" % k)
        save(sv(3, 9 + k), "terrain/steps_boulder_%d_r.png" % k)
        n += 2

# ---------------------------------------------------------------- second pass (Nov 22)
# east shadow: the ground just east of a rise, darkest against the face
def shadow_e(alpha):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in range(11):
        a = int(alpha * (1 - x / 11.0) ** 1.4)
        for y in range(16):
            im.putpixel((x, y), (10, 16, 26, a))
    return im


save(shadow_e(70), "terrain/shadow_e.png")
save(shadow_e(34), "terrain/shadow_e_turf.png")
n += 2

# steep dirt trail: a worn slope up the face instead of steps (same footprint: 2 tiles wide, face rows + 1)
DIRT, DIRT_LT, DIRT_DK, EDGE, PEB = (128, 92, 62), (152, 114, 78), (98, 68, 46), (64, 44, 34), (170, 160, 150)


def trail(rows, stony):
    """A worn path up the slope: the game's own dirt (grey gravel on stone cliffs), darker toward the foot, ragged
    grass-worn edges, footholds and pebbles. No hard border, so it reads as ground, not a plank."""
    import random
    rnd = random.Random(7 + rows + (3 if stony else 0))
    src = os.path.join(OUT, "tiles", "dirt_summer_0.png" if os.path.isfile(os.path.join(OUT, "tiles", "dirt_summer_0.png")) else "dirt_0.png")
    tex = Image.open(src).convert("RGBA") if os.path.isfile(src) else Image.new("RGBA", (16, 16), DIRT + (255,))
    h = rows * 16
    im = Image.new("RGBA", (32, h), (0, 0, 0, 0))
    px = im.load()
    tp = tex.load()
    y0 = 6
    left = [3 + rnd.randint(0, 2) for _ in range(h)]
    right = [28 - rnd.randint(0, 2) for _ in range(h)]
    for y in range(y0, h):
        t = (y - y0) / max(1, h - y0 - 1)                 # 0 at the top of the slope, 1 at the foot
        shade = 1.08 - 0.32 * t
        for x in range(32):
            if x < left[y] or x > right[y]:
                continue
            r, g, b, _ = tp[x % 16, y % 16]
            if stony:
                v = (r + g + b) // 3
                r, g, b = int(v * 0.96), int(v * 0.98), int(v * 1.06)
            edge = min(x - left[y], right[y] - x)
            a = 150 if edge == 0 else 255
            k = shade * (0.82 if edge <= 1 else 1.0)
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
        # footholds: a dark scuff with a light lip above, every 6 px
        if (y - y0) % 6 == 5:
            for x in range(left[y] + 3, right[y] - 2):
                if rnd.random() < 0.8:
                    q = px[x, y]
                    px[x, y] = (int(q[0] * 0.7), int(q[1] * 0.7), int(q[2] * 0.7), q[3])
                    q = px[x, y - 1]
                    px[x, y - 1] = (min(255, int(q[0] * 1.15)), min(255, int(q[1] * 1.15)), min(255, int(q[2] * 1.15)), q[3])
    for _ in range(rows * 5):
        x, y = rnd.randint(7, 24), rnd.randint(y0 + 3, h - 3)
        px[x, y] = PEB + (255,)
        px[x + 1, y + 1] = (80, 70, 64, 255)
    return im


for style, rows, stony in (("earth", 3, False), ("stone", 3, True), ("turf", 2, False)):
    tr = trail(rows, stony)
    for k in range(rows):
        save(tr.crop((0, k * 16, 16, k * 16 + 16)), "terrain/trail_%s_%d_l.png" % (style, k))
        save(tr.crop((16, k * 16, 32, k * 16 + 16)), "terrain/trail_%s_%d_r.png" % (style, k))
        n += 2

# waterfalls: LimeZu's falls from the same Modern Exteriors sheet (columns 25-27, rows 49-54), the water rolling
# down through 4 frames (_f0.._f3); the rock walls stay still. Stone cliffs get the rock in grey.
FOAM = (236, 246, 250)
if os.path.isfile(SHEET):
    FALL = ME.crop((25 * 16, 49 * 16, 28 * 16, 55 * 16))      # 48 x 96

    def is_water(p):
        return p[3] and p[2] > p[0] + 30

    def frame(k):
        src = FALL.load()
        out = FALL.copy()
        o = out.load()
        for y in range(16, 80):                            # rows 50-53 cycle
            sy = 16 + (y - 16 - k * 4) % 64
            for x in range(48):
                if is_water(src[x, y]) and is_water(src[x, sy]):
                    o[x, y] = src[x, sy]
        return out

    for style, fn in (("earth", lambda im: im), ("stone", stone)):
        for k in range(4):
            fr = fn(frame(k))
            for dx in range(3):
                save(fr.crop((dx * 16, 0, dx * 16 + 16, 16)), "terrain/fall_%s_top_%d_f%d.png" % (style, dx, k))
                for row in range(2):
                    save(fr.crop((dx * 16, 16 + row * 16, dx * 16 + 16, 32 + row * 16)), "terrain/fall_%s_%d_%d_f%d.png" % (style, row, dx, k))
                n += 3
    # foam on the pool at the foot
    for k in range(4):
        for dx in range(3):
            im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            for i in range(5):
                x = (i * 7 + k * 3 + dx * 5) % 16
                y = 1 + (i * 5 + k * 2) % 9
                d.line((x, y, min(15, x + 3), y), fill=FOAM + (220 - y * 15,))
            d.line((0, 0, 15, 0), fill=FOAM + (230,))
            save(im, "terrain/fall_foam_%d_f%d.png" % (dx, k))
            n += 1


# winter: the green edges of the cliffs and banks under snow
def snowy(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > r + 8 and g >= b:
                l = (r + g + b) / 3
                v = 0.62 + 0.38 * min(1.0, l / 150)
                px[x, y] = (int(222 * v), int(230 * v), int(242 * v), a)
    return im


for f in sorted(os.listdir(os.path.join(OUT, "terrain"))):
    if f.startswith(("earth_", "stone_", "turf_", "boulder_")) and f.endswith(".png") and "_winter" not in f:
        im = Image.open(os.path.join(OUT, "terrain", f)).convert("RGBA")
        w = snowy(im)
        if list(w.getdata()) != list(im.getdata()):
            save(w, "terrain/" + f.replace(".png", "_winter.png"))
            n += 1
print("terrain art:", n)
