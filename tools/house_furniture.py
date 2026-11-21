"""Farmhouse furniture from Modern Interiors (Nov 21). Run from import_packs.py with SRC, OUT and save()."""
import os
from PIL import Image

T = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless")
_sheets = {}


def sheet(name):
    if name not in _sheets:
        _sheets[name] = Image.open(os.path.join(T, name + "_Shadowless.png")).convert("RGBA")
    return _sheets[name]


def cell(name, x, y, w=1, h=1):
    return sheet(name).crop((x * 16, y * 16, (x + w) * 16, (y + h) * 16))


def trim(im):
    b = im.getbbox()
    return im.crop(b) if b else im


def pick(name, px, py, gap=0):
    """The object under pixel (px, py) on a sheet: every drawn pixel joined to it (allowing a gap), trimmed."""
    im = sheet(name)
    w, h = im.size
    a = im.load()
    seen = {(px, py)}
    todo = [(px, py)]
    if a[px, py][3] == 0:
        # start from the nearest drawn pixel
        best = min(((x, y) for x in range(max(0, px - 16), min(w, px + 17)) for y in range(max(0, py - 16), min(h, py + 17)) if a[x, y][3] > 0),
                   key=lambda q: (q[0] - px) ** 2 + (q[1] - py) ** 2)
        seen = {best}; todo = [best]
    while todo:
        x, y = todo.pop()
        for dx in range(-1 - gap, 2 + gap):
            for dy in range(-1 - gap, 2 + gap):
                q = (x + dx, y + dy)
                if q in seen or not (0 <= q[0] < w and 0 <= q[1] < h) or a[q][3] == 0:
                    continue
                seen.add(q); todo.append(q)
    xs = [q[0] for q in seen]; ys = [q[1] for q in seen]
    out = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1), (0, 0, 0, 0))
    for q in seen:
        out.putpixel((q[0] - min(xs), q[1] - min(ys)), a[q])
    return out


def vtrim(im):
    """Trim top and bottom only, so 16-wide pieces keep their width and line up."""
    b = im.getbbox()
    return im.crop((0, b[1], im.width, b[3])) if b else im


def counter(top, front, sink=None):
    """A counter piece: the front stands on the floor, the top sits on it, a sink (if any) set into the top."""
    t, f = vtrim(top), vtrim(front)
    sk = vtrim(sink) if sink is not None else None
    th = max(t.height, sk.height if sk else 0)
    out = Image.new("RGBA", (16, th + f.height), (0, 0, 0, 0))
    out.alpha_composite(t, (0, th - t.height))
    if sk is not None:
        out.alpha_composite(sk, (0, th - sk.height))
    out.alpha_composite(f, (0, th))
    return out


def stack(*layers, size=(16, 32)):
    """Layers as (image, dx, dy), drawn in order on a fixed canvas (kept untrimmed so pieces line up)."""
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for im, dx, dy in layers:
        out.alpha_composite(im, (dx, dy))
    return out


K, L, B, BD = "12_Kitchen", "2_LivingRoom", "14_Basement", "4_Bedroom"
PIECES = {}
# a kitchen counter run against the back wall: grey top, pale cabinet fronts; 16x32, the top over the wall row
PIECES["kitchen_counter_0"] = counter(cell(K, 4, 6), cell(K, 3, 8))
PIECES["kitchen_counter_1"] = counter(cell(K, 5, 6), cell(K, 4, 8))
PIECES["kitchen_counter_2"] = counter(cell(K, 5, 6), cell(K, 5, 8))
PIECES["kitchen_counter_3"] = counter(cell(K, 6, 6), cell(K, 6, 8))
# the sink set into the counter (two halves), and a stove that matches the run
PIECES["sink_0"] = counter(cell(K, 5, 6), cell(K, 4, 8), cell(K, 8, 8))
PIECES["sink_1"] = counter(cell(K, 5, 6), cell(K, 4, 8), cell(K, 9, 8))
PIECES["stove"] = trim(cell(K, 9, 11, 1, 2))
PIECES["chair_l"] = trim(cell(K, 7, 13, 1, 2))
# living room
PIECES["hearth"] = trim(cell(L, 4, 23, 2, 3))
PIECES["house_plant_0"] = pick(L, 11 * 16 + 16, 2 * 16 + 4)
PIECES["house_plant_1"] = pick(L, 14 * 16 + 4, 23 * 16 + 8)
PIECES["bookcase"] = trim(cell(L, 10, 24, 2, 3))
PIECES["wardrobe"] = pick(L, 7 * 16 + 16, 5 * 16 + 8)
PIECES["armchair"] = pick(B, 5 * 16 + 8, 34 * 16 + 4)
PIECES["wall_art_0"] = pick(L, 8, 29 * 16 + 8)
PIECES["wall_art_1"] = pick(L, 8, 31 * 16 + 8)
PIECES["wall_map"] = pick(L, 11 * 16, 23 * 16 + 8)
# bedroom
PIECES["big_bed"] = pick(BD, 9 * 16, 22 * 16)
PIECES["nightstand"] = trim(sheet(BD).crop((96, 160, 112, 192)))
PIECES["rug_round"] = pick(BD, 3 * 16, 23 * 16)
PIECES["cellar_ladder"] = pick(B, 1 * 16 + 8, 10 * 16 + 8)

for name, im in PIECES.items():
    save(im, "objects/%s.png" % name)
print("farmhouse furniture:", len(PIECES))
