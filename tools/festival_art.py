"""Festival set dressing (Nov 21): stalls and carts (Modern Exteriors), bunting and balloons (Modern Interiors
birthday sheet), planting-race pots (Modern Farm) and a wish lantern icon. Run from import_packs.py with SRC,
OUT, save and mute."""
import os
from PIL import Image

ME = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "ME_Theme_Sorter_16x16", "10_Vehicles_Singles_16x16", "ME_Singles_Vehicles_16x16_")
BD = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless", "10_Birthday_party_Shadowless.png")
MFP = os.path.join(SRC, "Modern_Farm", "16x16", "Single_Files_16x16", "Props_and_Buildings_16x16")
MFC = os.path.join(SRC, "Modern_Farm", "16x16", "Single_Files_16x16", "Crops_16x16")


def trim(im):
    b = im.getbbox()
    return im.crop(b) if b else im


def me(n):
    return trim(Image.open(ME + n + ".png").convert("RGBA"))


n = 0
if os.path.isfile(ME + "Fruit_Flowers_Cart_2.png"):
    for name, src in [("fest_flower_cart", "Fruit_Flowers_Cart_2"), ("fest_stall_0", "Street_Food_Cart_1"), ("fest_stall_1", "Street_Food_Cart_3"),
                      ("fest_sign", "Street_Food_Sign_1"), ("fest_table", "Street_Food_Table_1")]:
        save(mute(me(src), 0.1), "objects/%s.png" % name)
        n += 1
if os.path.isfile(BD):
    bd = Image.open(BD).convert("RGBA")
    cell = lambda x, y, w=1, h=1: trim(bd.crop((x * 16, y * 16, (x + w) * 16, (y + h) * 16)))
    save(mute(cell(0, 4, 2, 1), 0.08), "objects/fest_bunting_0.png")
    save(mute(cell(2, 4, 3, 1), 0.08), "objects/fest_bunting_1.png")
    save(mute(cell(2, 4, 3, 1), 0.08), "objects/fest_bunting_2.png")
    save(mute(cell(0, 4, 2, 1), 0.08), "objects/fest_bunting_3.png")
    for v in range(4):
        save(mute(cell(v, 5, 1, 2), 0.08), "objects/fest_balloons_%d.png" % v)
    n += 8
if os.path.isdir(MFP):
    pot = trim(Image.open(os.path.join(MFP, "Pot_Empty_16x16.png")).convert("RGBA"))
    save(pot, "objects/race_pot_0.png")
    sprout = trim(Image.open(os.path.join(MFC, "Crop_Cabbage_Sprout_16x16.png")).convert("RGBA"))
    full = pot.copy()
    c = Image.new("RGBA", (max(16, pot.width), pot.height + sprout.height - 3), (0, 0, 0, 0))
    c.alpha_composite(sprout, ((c.width - sprout.width) // 2, 0))
    c.alpha_composite(pot, ((c.width - pot.width) // 2, sprout.height - 3))
    save(c, "objects/race_pot_1.png")
    n += 2

# a paper wish lantern: warm paper, a dark frame, a glowing middle
L = ["................", "......oooo......", ".....oFFFFo.....", "....oPPPPPPo....", "...oPPLLLLPPo...", "...oPLLYYLLPo...",
     "...oPLYWWYLPo...", "...oPLYWWYLPo...", "...oPLLYYLLPo...", "...oPPLLLLPPo...", "....oPPPPPPo....", ".....oFFFFo.....",
     "......oFFo......", ".......oo.......", "................", "................"]
PAL = {"o": (58, 32, 24, 255), "F": (140, 72, 40, 255), "P": (220, 120, 60, 255), "L": (240, 170, 80, 255), "Y": (252, 214, 120, 255), "W": (255, 246, 210, 255)}
ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y, row in enumerate(L):
    for x, ch in enumerate(row):
        if ch in PAL:
            ic.putpixel((x, y), PAL[ch])
save(ic, "icons/wish_lantern.png")
print("festival art:", n + 1)

# ---------------------------------------------------------------- the later festivals (Nov 22)
# Hollow Night: jack-o'-lanterns, a ghost, a bubbling cauldron and a candy bucket (Modern Interiors Halloween).
# Frostlight and the Warm Hearth Exchange: a decorated tree and gift piles (Modern Interiors Christmas).
# Militia Trials: padded dummies (the gym punching bag, standing and knocked over). Whack-a-zombie holes are drawn here.
TS = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless")


def _pick(sheet, px, py):
    w, h = sheet.size
    a = sheet.load()
    if a[px, py][3] == 0:
        px, py = min(((x, y) for x in range(max(0, px - 10), min(w, px + 11)) for y in range(max(0, py - 10), min(h, py + 11)) if a[x, y][3] > 0),
                     key=lambda q: (q[0] - px) ** 2 + (q[1] - py) ** 2)
    seen = {(px, py)}
    todo = [(px, py)]
    while todo:
        x, y = todo.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q in seen or not (0 <= q[0] < w and 0 <= q[1] < h) or a[q][3] == 0:
                    continue
                seen.add(q)
                todo.append(q)
    xs = [q[0] for q in seen]
    ys = [q[1] for q in seen]
    out = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1), (0, 0, 0, 0))
    for q in seen:
        out.putpixel((q[0] - min(xs), q[1] - min(ys)), a[q])
    return out


m = 0
HW = os.path.join(TS, "11_Halloween_Shadowless.png")
if os.path.isfile(HW):
    hw = Image.open(HW).convert("RGBA")
    for name, p in [("fest_pumpkin_0", (87, 15)), ("fest_pumpkin_1", (135, 15)), ("fest_pumpkin_2", (183, 44)), ("fest_pumpkin_3", (247, 44)),
                    ("fest_ghost", (230, 180)), ("fest_cauldron", (47, 142)), ("fest_candy", (150, 180))]:
        save(mute(_pick(hw, *p), 0.06), "objects/%s.png" % name)
        m += 1
XM = os.path.join(TS, "15_Christmas_Shadowless.png")
if os.path.isfile(XM):
    xm = Image.open(XM).convert("RGBA")
    for name, p in [("fest_tree", (37, 27)), ("fest_gifts_0", (77, 70)), ("fest_gifts_1", (10, 52)), ("fest_gift_sack", (150, 207))]:
        save(mute(_pick(xm, *p), 0.06), "objects/%s.png" % name)
        m += 1
PB = os.path.join(OUT, "objects", "punching_bag.png")
if os.path.isfile(PB):
    bag = Image.open(PB).convert("RGBA")
    save(bag, "objects/fest_dummy_0.png")
    down = bag.rotate(90, expand=True)
    save(down, "objects/fest_dummy_1.png")
    m += 2
# a whack-a-zombie hole: a ring of turned earth round a dark hole
hole = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y in range(16):
    for x in range(16):
        dx, dy = (x - 7.5) / 7.0, (y - 10.0) / 4.5
        r = dx * dx + dy * dy
        if r <= 0.45:
            hole.putpixel((x, y), (28, 20, 18, 255))
        elif r <= 1.0:
            hole.putpixel((x, y), (112, 80, 52, 255) if (x + y) % 3 else (90, 62, 40, 255))
save(hole, "objects/whack_hole.png")
print("later festival art:", m + 1)
