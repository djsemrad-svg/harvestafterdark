"""Shop furniture for Brightwater's clinic, store, workshop, guild, ranch and forge (Nov 21).
Modern Interiors pieces plus a few Modern Farm props. Run from import_packs.py with SRC, OUT, save and mute."""
import os
from PIL import Image

T = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless")
MFP = os.path.join(SRC, "Modern_Farm", "16x16", "Single_Files_16x16", "Props_and_Buildings_16x16")
_sheets = {}


def sheet(name):
    if name not in _sheets:
        _sheets[name] = Image.open(os.path.join(T, name + "_Shadowless.png")).convert("RGBA")
    return _sheets[name]


def trim(im):
    b = im.getbbox()
    return im.crop(b) if b else im


def cell(name, x, y, w=1, h=1):
    return trim(sheet(name).crop((x * 16, y * 16, (x + w) * 16, (y + h) * 16)))


def pick(name, px, py):
    """The object under pixel (px, py): every drawn pixel joined to it, trimmed."""
    im = sheet(name)
    w, h = im.size
    a = im.load()
    if a[px, py][3] == 0:
        px, py = min(((x, y) for x in range(max(0, px - 12), min(w, px + 13)) for y in range(max(0, py - 12), min(h, py + 13)) if a[x, y][3] > 0),
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


def P(name, cx, cy, ox=8, oy=8):
    return pick(name, cx * 16 + ox, cy * 16 + oy)


def farm(name):
    return trim(Image.open(os.path.join(MFP, name + "_16x16.png")).convert("RGBA"))


H, G, GY, SR = "19_Hospital", "16_Grocery_store", "8_Gym", "25_Shooting_Range"


def stocked_shelf(seed):
    """A grocery shelf with goods on each level (the pack draws the shelf and the goods separately)."""
    sh = P(G, 2, 9)
    out = sh.copy()
    goods = [cell(G, 1, 12), cell(G, 2, 12), cell(G, 3, 12), cell(G, 4, 12), cell(G, 5, 13), cell(G, 6, 13), cell(G, 7, 13), cell(G, 9, 13), cell(G, 10, 13)]
    px = sh.load()
    light = [y for y in range(sh.height) if sum(1 for x in range(sh.width) if px[x, y][3] and sum(px[x, y][:3]) > 560) > sh.width // 2]
    ends = [y for y in light if y + 1 not in light]
    k = seed
    for y in ends:
        x = 4
        while True:
            g = goods[k % len(goods)]
            k += 2
            if x + g.width > sh.width - 2:
                break
            out.alpha_composite(g, (x, max(0, y - g.height + 1)))
            x += g.width
    return out


PIECES = {
    # clinic
    "clinic_bed": lambda: cell(H, 7, 69, 2, 2),
    "med_cart": lambda: P(H, 8, 66, 12, 0),
    "doctor_desk": lambda: P(H, 10, 66, 14, 8),
    "med_cabinet": lambda: P(H, 0, 69, 12, 0),
    "drawers": lambda: P(H, 4, 71, 8, 8),
    "clinic_plant": lambda: P(H, 1, 13, 8, 0),
    "wait_chair": lambda: P(H, 11, 19, 8, 8),
    # general store
    "checkout": lambda: P(G, 7, 25, 8, 4),
    "drink_fridge": lambda: trim(cell(G, 0, 23, 1, 3).crop((0, 0, 16, 41))),
    "stocked_shelf": lambda: stocked_shelf(0),
    "produce_crate": lambda: cell(G, 4, 60, 2, 2),
    "basket_stack": lambda: P(G, 14, 13, 8, 0),
    # guild
    "punching_bag": lambda: P(GY, 6, 2, 8, 8),
    "dumbbell_rack": lambda: P(GY, 1, 14, 8, 10),
    "weight_bench": lambda: P(GY, 11, 2, 12, 8),
    "range_target": lambda: cell(SR, 7, 0, 1, 3),
    "range_bench": lambda: cell(SR, 0, 1, 2, 1),
    # workshop, ranch, forge (Modern Farm props)
    "work_table": lambda: farm("Woodwork_Crafting_Table_Full"),
    "diy_table": lambda: farm("DIY_Crafting_Table_Full"),
    "board_stack": lambda: farm("Wood_Board_Load"),
    "milk_cans": lambda: farm("Milk_Can_2"),
    "egg_crate": lambda: farm("Egg_Box"),
    "feed_sacks": lambda: farm("Sack_Jute_Load_1"),
    "hay_pile": lambda: farm("Hay_Fresh_Pile"),
    "log_stack": lambda: farm("Trunk_Load_Big_Vertical"),
}

n = 0
for name, make in PIECES.items():
    try:
        im = make()
    except Exception as e:      # a missing sheet: leave that piece to the code-drawn fallback
        print("shop furniture: skipped", name, e)
        continue
    save(mute(im, 0.06), "objects/%s.png" % name)
    n += 1
print("shop furniture:", n)
