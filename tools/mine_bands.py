"""Mine depth bands 21-100 (Nov 21): tiles for the ancient cave (3), green living cave (4), crumbling dungeon (5)
and pristine dungeon (6). The caves recolour the mine's own rock; the dungeons use Farm Game Dungeon Cellar
brick and slabs. Writes art/tiles/mfloorN_0-3, mwallN_0-3 and mwallN_face_0-1. Run from import_packs.py with
SRC, OUT and save."""
import os
import random
from PIL import Image

TILES = os.path.join(OUT, "tiles")
CELLAR = os.path.join(SRC, "Farm_Game_Dungeon_Cellar_Tileset", "Farm Game Dungeon Cellar Tileset", "Tilesets", "FG_Cellar.png")


def lum(p):
    return (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / 255.0


def ramp(im, dark, light):
    """Every pixel onto a two-colour ramp by its brightness (keeps the shading, changes the stone)."""
    out = im.convert("RGBA").copy()
    px = out.load()
    vals = [lum(px[x, y]) for y in range(out.height) for x in range(out.width) if px[x, y][3]]
    lo, hi = min(vals), max(vals)
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if not p[3]:
                continue
            k = (lum(p) - lo) / max(0.001, hi - lo)
            px[x, y] = tuple(int(dark[i] + (light[i] - dark[i]) * k) for i in range(3)) + (p[3],)
    return out


def dim(im, k):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            px[x, y] = (int(p[0] * k), int(p[1] * k), int(p[2] * k), p[3])
    return out


def wear(im, seed, cracks=6, moss=4):
    """Crumbling: dark cracks and a little moss."""
    out = im.copy()
    px = out.load()
    r = random.Random(seed)
    for i in range(cracks):
        x, y = r.randrange(1, 15), r.randrange(1, 15)
        for j in range(r.randrange(2, 5)):
            if 0 <= x < 16 and 0 <= y < 16:
                p = px[x, y]
                px[x, y] = (int(p[0] * 0.45), int(p[1] * 0.45), int(p[2] * 0.45), 255)
            x += r.choice([-1, 0, 1]); y += 1
    for i in range(moss):
        x, y = r.randrange(0, 16), r.randrange(0, 16)
        px[x, y] = (74, 104, 58, 255)
    return out


H = lambda s: tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))
n = 0
if os.path.isfile(os.path.join(TILES, "mfloor_0.png")):
    caves = {3: ("mfloor", "mwall", ("#4a3622", "#c8a46a"), ("#2a1e14", "#8a6a44")),        # ancient: sandstone
             4: ("mfloor2", "mwall2", ("#1e3424", "#6aa06a"), ("#10201a", "#3e6a4e"))}      # living: moss and teal
    for band, (fl, wl, fc, wc) in caves.items():
        for v in range(4):
            save(ramp(Image.open(os.path.join(TILES, "%s_%d.png" % (fl, v))), H(fc[0]), H(fc[1])), "tiles/mfloor%d_%d.png" % (band, v))
            save(ramp(Image.open(os.path.join(TILES, "%s_%d.png" % (wl, v))), H(wc[0]), H(wc[1])), "tiles/mwall%d_%d.png" % (band, v))
        for v in range(2):
            save(ramp(Image.open(os.path.join(TILES, "%s_face_%d.png" % (wl, v))), H(wc[0]), H(wc[1])), "tiles/mwall%d_face_%d.png" % (band, v))
        n += 10
if os.path.isfile(CELLAR):
    sh = Image.open(CELLAR).convert("RGBA")
    cell = lambda x, y: sh.crop((x * 16, y * 16, x * 16 + 16, y * 16 + 16))
    # 5 crumbling: brown brick and slabs, cracked; 6 pristine: grey brick and slabs as they are
    for band, bricks, slabs, broken in [(5, [(1, 3), (2, 3), (3, 3)], [(10, 13), (11, 13), (12, 13), (13, 13)], True),
                                        (6, [(1, 10), (2, 10), (1, 10)], [(10, 14), (11, 14), (12, 14), (13, 14)], False)]:
        for v in range(4):
            f = cell(*slabs[v])
            w = dim(cell(*bricks[v % len(bricks)]), 0.42)
            if broken:
                f = wear(f, v * 7 + 1)
                w = wear(w, v * 7 + 3, 3, 2)
            save(f, "tiles/mfloor%d_%d.png" % (band, v))
            save(w, "tiles/mwall%d_%d.png" % (band, v))
        for v in range(2):
            face = cell(*bricks[v])
            save(wear(face, v * 5 + 9, 4, 3) if broken else face, "tiles/mwall%d_face_%d.png" % (band, v))
        n += 10
print("mine band tiles:", n)

# loot boxes and chests (opened = _1)
if os.path.isfile(CELLAR):
    def gold(im):
        out = im.copy()
        px = out.load()
        for y in range(out.height):
            for x in range(out.width):
                p = px[x, y]
                if p[3] and p[0] > p[2] + 10:          # the wood turns to gilt
                    l = lum(p)
                    px[x, y] = (int(120 + 135 * l), int(90 + 120 * l), int(20 + 50 * l), p[3])
        return out
    save(cell(28, 8), "objects/mine_loot_box_0.png"); save(cell(29, 8), "objects/mine_loot_box_1.png")
    save(dim(cell(30, 8), 0.8), "objects/mine_big_chest_0.png"); save(dim(cell(31, 8), 0.8), "objects/mine_big_chest_1.png")
    save(gold(cell(30, 8)), "objects/mine_legendary_chest_0.png"); save(gold(cell(31, 8)), "objects/mine_legendary_chest_1.png")
    print("mine chests: 6")
