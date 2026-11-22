"""Raised ground pictures (Nov 22), written to art/terrain/. Run from import_packs.py with SRC, OUT and save, or
alone: python3 tools/terrain_art.py <packs> <art>.

earth: LimeZu's earth cliff from Modern Exteriors (1_Terrains_and_Fences, the grass-topped block at columns 8-10,
       rows 42-46). Its flat grass is cut out so the game's own seasonal grass shows on top.
stone: the same pieces with the brown rock turned to grey stone.
turf:  drawn here: a sunlit lip, thin side rims and a one-tile bank of shaded grass, laid over the real ground.
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
print("terrain art:", n + 1)
