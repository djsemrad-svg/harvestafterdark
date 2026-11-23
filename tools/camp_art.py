"""The refugee camp on Brightwater's south bank (Nov 22). Run from import_packs.py with SRC, OUT and save, or
alone: python3 tools/camp_art.py <packs> <art>.

  camp_tarp_0-3       shelters: the game's tent recoloured into a blue tarp, a grey patched sheet, an olive tarp and a
                      faded orange one, with patches sewn on
  camp_bonfire_f0-5   the animated campfire from Modern Exteriors (Animated sheets, Campfire), 6 frames
  camp_cookpot_f0-5   the pot over a fire from Modern Exteriors (Campfire_2), 6 frames
  laundry_line_f0-5   clothes drying on a line (Modern Exteriors Clothes_Hanging_1 and 2), 6 frames; _2_ for the second
  camp_board          the notice board, with paper scraps pinned on
Each animated one also gets a plain <name>.png (frame 0) for places that don't animate.
"""
import colorsys
import os
import random
import sys
from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

ANIM = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "Animated_16x16", "Animated_sheets_16x16")


def recolour(im, hue, sat, light, seed):
    """Canvas (the light tan of the tent) to another colour; poles and ropes stay."""
    im = im.copy()
    px = im.load()
    rnd = random.Random(seed)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if 0.05 < h < 0.17 and l > 0.45 and s > 0.15:       # the canvas
                l2 = min(1.0, l * light)
                r2, g2, b2 = colorsys.hls_to_rgb(hue, l2, sat)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    # patches: small squares of another shade with a dark stitch line
    w, h = im.size
    for _ in range(4):
        cx, cy = rnd.randint(w // 4, 3 * w // 4), rnd.randint(h // 4, 3 * h // 4)
        pw, ph = rnd.randint(4, 7), rnd.randint(3, 5)
        if px[cx, cy][3] == 0:
            continue
        base = px[cx, cy]
        shade = tuple(max(0, min(255, int(c * rnd.choice([0.8, 1.15])))) for c in base[:3])
        for yy in range(cy, min(h, cy + ph)):
            for xx in range(cx, min(w, cx + pw)):
                if px[xx, yy][3]:
                    edge = yy in (cy, cy + ph - 1) or xx in (cx, cx + pw - 1)
                    px[xx, yy] = (tuple(int(c * 0.6) for c in shade) if edge and (xx + yy) % 2 == 0 else shade) + (255,)
    return im


n = 0
tent = os.path.join(OUT, "objects", "tent.png")
if os.path.isfile(tent):
    T = Image.open(tent).convert("RGBA")
    for v, (hue, sat, light) in enumerate([(0.58, 0.45, 0.95), (0.6, 0.06, 0.95), (0.22, 0.3, 0.85), (0.07, 0.55, 0.9)]):
        save(recolour(T, hue, sat, light, v), "objects/camp_tarp_%d.png" % v)
        n += 1


def frames(sheet, fw, fh, count, name):
    global n
    p = os.path.join(ANIM, sheet)
    if not os.path.isfile(p):
        return
    im = Image.open(p).convert("RGBA")
    for i in range(count):
        fr = im.crop((i * fw, 0, i * fw + fw, fh))
        fr = fr.crop(fr.getbbox() or (0, 0, fw, fh)) if i == 0 else fr
        save(im.crop((i * fw, 0, i * fw + fw, fh)), "objects/%s_f%d.png" % (name, i))
        n += 1
    save(im.crop((0, 0, fw, fh)), "objects/%s.png" % name)


frames("Campfire_16x16.png", 16, 32, 6, "camp_bonfire")
frames("Campfire_2_16x16.png", 48, 32, 6, "camp_cookpot")
frames("Clothes_Hanging_1_16x16.png", 64, 48, 6, "laundry_line")
frames("Clothes_Hanging_2_16x16.png", 64, 48, 6, "laundry_line_2")

# proper tents once the camp has shelter (the "Real Shelter" need): the game's tents
for v, src in enumerate(["tent", "field_tent", "tent", "field_tent"]):
    p = os.path.join(OUT, "objects", src + ".png")
    if os.path.isfile(p):
        save(Image.open(p).convert("RGBA"), "objects/camp_tent_%d.png" % v)
        n += 1

# quest item icons for the break-in: a torn biker patch and a sketch of boot prints
from PIL import ImageDraw
ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(ic)
d.polygon([(2, 3), (13, 2), (14, 12), (9, 13), (8, 11), (6, 14), (2, 12)], fill=(58, 46, 40, 255), outline=(24, 18, 16, 255))
d.ellipse((5, 5, 10, 10), fill=(214, 206, 188, 255))
d.point([(6, 7), (9, 7)], fill=(24, 18, 16, 255))
d.line((4, 4, 12, 4), fill=(170, 40, 34, 255))
save(ic, "icons/dry_creek_patch.png")
ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(ic)
d.rectangle((2, 1, 13, 14), fill=(232, 224, 200, 255), outline=(120, 104, 80, 255))
for (x, y) in [(4, 3), (8, 6), (4, 9), (8, 12)]:
    d.ellipse((x, y, x + 2, y + 1), fill=(80, 62, 44, 255))
save(ic, "icons/boot_print_sketch.png")
n += 2

# the clues on the ground: a scrap of patch caught on a nail, and muddy boot prints
ob = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(ob)
d.polygon([(5, 9), (11, 8), (12, 13), (6, 14)], fill=(58, 46, 40, 255), outline=(24, 18, 16, 255))
d.point([(8, 10), (9, 11)], fill=(214, 206, 188, 255))
d.point([(10, 9)], fill=(170, 40, 34, 255))
save(ob, "objects/clue_patch.png")
ob = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(ob)
for (x, y) in [(3, 2), (8, 6), (3, 10), (9, 13)]:
    d.ellipse((x, y, x + 3, y + 2), fill=(74, 56, 40, 210))
    d.point([(x + 1, y + 1)], fill=(52, 38, 28, 230))
save(ob, "objects/clue_prints.png")
n += 2

board = os.path.join(OUT, "objects", "notice_board.png")
if os.path.isfile(board):
    B = Image.open(board).convert("RGBA")
    px = B.load()
    rnd = random.Random(3)
    for _ in range(5):          # scraps of paper pinned at angles
        x, y = rnd.randint(2, B.width - 5), rnd.randint(2, B.height // 2)
        for yy in range(y, y + 3):
            for xx in range(x, x + 3):
                if 0 <= xx < B.width and 0 <= yy < B.height and px[xx, yy][3]:
                    px[xx, yy] = (238, 232, 214, 255) if (xx + yy) % 3 else (200, 192, 170, 255)
        px[x + 1, y] = (190, 40, 40, 255)
    save(B, "objects/camp_board.png")
    n += 1
print("camp art:", n)
