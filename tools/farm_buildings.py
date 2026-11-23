"""Coop, barn and hutch pictures from LimeZu's Modern Farm pack (Nov 22), fitted to the game's footprints.
Run from import_packs.py with SRC, OUT and save, or alone: python3 tools/farm_buildings.py <packs> <art>.

  coop  (6 x 4 tiles, 96 px wide): the Chicken Coop on the left, a small fenced run with straw on the right
  barn  (8 x 5 tiles, 128 px wide): the Small Barn
  hutch (4 x 3 tiles, 64 px wide): the Henhouse
  doghouse (a 1-tile object): the Doghouse
The people's door sits where the picture's door is (Livestock.DOOR_COL) and the animal door in another spot on the
bottom row (Livestock.ANIMAL_COL), drawn over the picture by WorldView. Entries go into art/buildings/index.json
("nosign": no name board painted on).
"""
import json
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

D = os.path.join(SRC, "Modern_Farm", "16x16", "Single_Files_16x16", "Props_and_Buildings_16x16")


def L(name):
    return Image.open(os.path.join(D, name + "_16x16.png")).convert("RGBA")


n = 0
if os.path.isdir(D):
    meta = {}
    # coop: the building, then a run fenced front and back, straw on the ground
    coop = L("Chicken_Coop")
    W, H = 96, coop.height
    im = Image.new("RGBA", (W, H))
    rnd = random.Random(5)
    px = im.load()
    for y in range(H - 30, H - 2):
        for x in range(64, 95):
            c = rnd.choice([(196, 168, 102), (210, 184, 118), (180, 150, 90), (204, 178, 110)])
            px[x, y] = c + (255,)
    for i in range(14):        # pecked-at spots
        x, y = rnd.randint(66, 92), rnd.randint(H - 28, H - 4)
        px[x, y] = (150, 120, 74, 255)
    # posts and rails, chicken wire between them; the front gap at x 65-79 is the gate (drawn by the game)
    POST, RAIL, HI, WIRE = (92, 60, 34, 255), (138, 94, 54, 255), (178, 128, 80, 255), (200, 206, 212, 210)

    def post(x, y0, y1):
        for y in range(y0, y1):
            px[x, y] = POST
            px[x + 1, y] = RAIL

    def rail(x0, x1, y):
        for x in range(x0, x1):
            px[x, y] = HI
            px[x, y + 1] = RAIL

    def wire(x0, x1, y0, y1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                    px[x, y] = WIRE

    wire(66, 93, H - 37, H - 30)
    for x in (64, 79, 93):
        post(x, H - 40, H - 28)
    rail(64, 95, H - 39); rail(64, 95, H - 31)
    wire(94, 96, H - 30, H - 3)
    post(93, H - 30, H - 1)
    wire(82, 93, H - 12, H - 3)
    for x in (64, 80, 93):
        post(x, H - 15, H - 1)
    rail(80, 95, H - 14); rail(80, 95, H - 4)
    im.alpha_composite(coop, (0, 0))
    save(im, "buildings/coop.png")
    meta["coop"] = {"door": 38, "w": W, "h": H, "base": H, "nosign": True}
    n += 1
    barn = L("Barn_Small")
    save(barn, "buildings/barn.png")
    meta["barn"] = {"door": 31, "w": barn.width, "h": barn.height, "base": barn.height, "nosign": True}
    n += 1
    hutch = L("Henhouse")
    save(hutch, "buildings/hutch.png")
    meta["hutch"] = {"door": 27, "w": hutch.width, "h": hutch.height, "base": hutch.height, "nosign": True}
    n += 1
    # the guard dog's doghouse (it was a wooden storage box)
    save(L("Doghouse"), "objects/doghouse.png")
    n += 1
    p = os.path.join(OUT, "buildings", "index.json")
    idx = json.load(open(p)) if os.path.isfile(p) else {}
    idx.update(meta)
    with open(p, "w") as fh:
        json.dump(idx, fh, indent=1)
print("farm buildings:", n)
