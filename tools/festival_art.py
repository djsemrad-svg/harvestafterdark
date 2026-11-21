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
