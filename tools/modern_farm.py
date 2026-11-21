"""Modern Farm pack (LimeZu, Nov 21): crops, crop icons and seed bags, fruit trees, farm animals and a few
farm props. Run from import_packs.py with SRC, OUT, save, mute, snow_laden, hexrgb and hue_set.

Crops the pack has use their own growth stages. The rest borrow the closest pack crop and have the
vegetable or fruit part recoloured to the crop's colour, so a whole field matches. Game stages:
0 seeds, 1 sprout, 2 young plant, 3 grown but not ripe, 4 ready.
"""
import colorsys
import json
import os
import random
from PIL import Image

MF = os.path.join(SRC, "Modern_Farm")
S16 = os.path.join(MF, "16x16")
CROPS = os.path.join(S16, "Single_Files_16x16", "Crops_16x16")
TREES = os.path.join(S16, "Single_Files_16x16", "Fruit_Trees_16x16")
PROPS = os.path.join(S16, "Single_Files_16x16", "Props_and_Buildings_16x16")
ICONS = os.path.join(MF, "Icons", "Icons_16x16", "Icons_16x16_Singles")
ANIM = os.path.join(S16, "Animals_16x16")
CF = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "crop_fish_colours.json")))


def rgba(path):
    return Image.open(path).convert("RGBA")


def crop_img(name):
    p = os.path.join(CROPS, name + "_16x16.png")
    return rgba(p) if os.path.isfile(p) else None


def is_leaf(p):
    """Green to teal leaves and stems (the pack's greens lean blue, so test the hue, not just g > r)."""
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return 70 / 360 <= h <= 200 / 360 and s > 0.18 and v > 0.22


def palette(im):
    return {p[:3] for p in im.getdata() if p[3]} if im is not None else set()


def produce_mask(im, base):
    px = im.load()
    out = set()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] and sum(p[:3]) > 90 and p[:3] not in base and not is_leaf(p):
                out.add((x, y))
    return out


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def recolour_at(im, pts, want):
    """Move the shades at the given pixels onto one colour, keeping the light and dark."""
    if not pts:
        return im
    out = im.copy()
    px = out.load()
    base = sum(lum(px[x, y]) for x, y in pts) / len(pts)
    w = hexrgb(want)
    for x, y in pts:
        p = px[x, y]
        k = lum(p) / max(base, 1)
        px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
    return out


def tint_all(im, want):
    """Leafy greens: the whole plant moved to the crop's green (outline kept)."""
    pts = {(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3] and sum(im.getpixel((x, y))[:3]) > 90}
    return recolour_at(im, pts, want)


# ---------------------------------------------------------------- crops
# pack crop -> [ripe picture, grown-but-unripe picture, picture whose colours count as "not produce"]
TEMPLATE = {
    "Berry": ["Ripe", "Fruitless", "Fruitless"], "Cabbage": ["Ripe", "Stage_1", "Sprout"],
    "Carrot": ["Ripe_3", "Stage_1", "Sprout"], "Cauliflower": ["Ripe", "Fruitless", "Fruitless"],
    "Chili_Pepper": ["Ripe", "Fruitless", "Fruitless"], "Corn": ["Ripe", "Fruitless", "Fruitless"],
    "Cotton": ["Ripe", "Fruitless", "Fruitless"], "Grain": ["Ripe", "Stage_2", "Stage_2"],
    "Grapes": ["Ripe_1", "Fruitless_1", "Fruitless_1"], "Onion": ["Ripe", "Stage_1", "Sprout"],
    "Pumpkin": ["Ripe", "green", "Sprout"], "Radish": ["Ripe_2", "Stage_2", "Sprout"],
    "Strawberry": ["Ripe", "Fruitless", "Fruitless"], "Tomato": ["Ripe", "Fruitless", "Fruitless"],
    "Turnip": ["Ripe", "Stage_1", "Sprout"], "Watermelon": ["Ripe", "Stage_1", "Sprout"],
    "Zucchini": ["Ripe", "Fruitless_1", "Fruitless_1"],
}
OWN = {"cabbage": "Cabbage", "carrot": "Carrot", "cauliflower": "Cauliflower", "coffee_bean": "Berry", "corn": "Corn",
       "cotton": "Cotton", "onion": "Onion", "hot_pepper": "Chili_Pepper", "pumpkin": "Pumpkin", "radish": "Radish",
       "tomato": "Tomato", "frost_turnip": "Turnip", "melon": "Watermelon", "wheat": "Grain", "zucchini": "Zucchini",
       "strawbloom": "Strawberry"}
BORROW = {"amber_yam": "Carrot", "parsnip": "Carrot", "beet": "Radish", "emberroot": "Radish", "garlic": "Onion",
          "peanut": "Turnip", "potato": "Turnip", "ashgrain": "Grain", "flax": "Grain", "sunflower": "Corn",
          "bell_pepper": "Chili_Pepper", "bluebell_berry": "Berry", "bogberry": "Berry", "moonbloom": "Cotton",
          "chamomile": "Cotton", "yarrow": "Cotton", "eggplant": "Tomato", "squash": "Pumpkin",
          "cinder_bean": "Grapes", "hops": "Grapes", "snapbean": "Grapes", "snowpea": "Grapes", "soybean": "Grapes",
          "cucumber": "Zucchini"}
LEAFY = {"basil", "bok_choy", "frost_leek", "kale", "lettuce", "spinach"}
UNRIPE = "#7aa850"


def stages_for(t):
    ripe_n, mid_n, base_n = TEMPLATE[t]
    seed = crop_img("Seed_" + t)
    sprout = crop_img("Crop_%s_Sprout" % t)
    young = crop_img("Crop_%s_Stage_1" % t)
    ripe = crop_img("Crop_%s_%s" % (t, ripe_n))
    base = palette(crop_img("Crop_%s_%s" % (t, base_n)))
    if mid_n == "green":
        mid = recolour_at(ripe, produce_mask(ripe, base), UNRIPE)
    else:
        mid = crop_img("Crop_%s_%s" % (t, mid_n))
    return [seed, sprout, young, mid, ripe], base


def pad(im):
    """Bottom-aligned on a 16-wide canvas at least a tile tall."""
    c = Image.new("RGBA", (16, max(16, im.height)), (0, 0, 0, 0))
    c.alpha_composite(im, ((16 - im.width) // 2, c.height - im.height))
    return c


n_crops = 0
if os.path.isdir(CROPS):
    for cid, info in CF["crops"].items():
        col = info["color"] or "#888888"
        if cid in OWN:
            frames, _ = stages_for(OWN[cid])
        elif cid in BORROW or cid in LEAFY:
            t = BORROW.get(cid, "Cabbage")
            frames, base = stages_for(t)
            if cid in LEAFY:
                frames = frames[:2] + [tint_all(f, col) for f in frames[2:]]
            elif cid != "cucumber":
                frames = frames[:2] + [recolour_at(f, produce_mask(f, base), col) for f in frames[2:]]
        else:
            continue
        for st, im in enumerate(frames):
            save(pad(mute(im, 0.1)), "crops/%s_%d.png" % (cid, st))
        n_crops += 1

# ---------------------------------------------------------------- crop icons and seed bags
ICON_NAME = {"Berry": "Coffee", "Grapes": "Grape", "Turnip": "turnip"}
CROP_ICON = {"carrot": "Crops_ Carrot", "cauliflower": "Crops_Cauliflower",
             "corn": "Crops_ Corn", "cotton": "Crops_Cotton", "onion": "Crops_ Onion", "hot_pepper": "Crops_Chili_Pepper",
             "pumpkin": "Crops_Pumpkin", "radish": "Crops_Radish", "tomato": "Crops_Tomato", "frost_turnip": "Crops_Turnip",
             "melon": "Crops_Watermelon", "wheat": "Crops_Grain", "zucchini": "Crops_Zucchini",
             "strawbloom": "Crops_Strawberry", "lettuce": "Crops_Lettuce"}
n_icons = 0


def pack_icon(name):
    if name.startswith("Pickup_"):
        p = os.path.join(S16, "Single_Files_16x16", "Pickup_Items_16x16", name + "_16x16.png")
    else:
        p = os.path.join(ICONS, "Icons_16x16_%s.png" % name)
    return rgba(p) if os.path.isfile(p) else None


def to_icon(im):
    c = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    b = im.getbbox()
    im = im.crop(b)
    c.alpha_composite(im, ((16 - im.width) // 2, (16 - im.height) // 2))
    return c


if os.path.isdir(ICONS):
    empty = rgba(os.path.join(ICONS, "Icons_16x16_Seed_Bags_Empty.png"))
    epx = empty.load()
    for cid, info in CF["crops"].items():
        col = info["color"] or "#888888"
        if cid in CROP_ICON and pack_icon(CROP_ICON[cid]) is not None:
            save(mute(to_icon(pack_icon(CROP_ICON[cid])), 0.08), "icons/%s.png" % cid)
            n_icons += 1
        t = "Lettuce" if cid == "lettuce" else OWN.get(cid) or BORROW.get(cid) or ("Lettuce" if cid in LEAFY else None)
        if t is None:
            continue
        bag = pack_icon("Seed_Bags_" + ICON_NAME.get(t, t))
        if bag is None:
            bag = pack_icon("Seed_Bags_Lettuce")
        if cid not in OWN and cid != "lettuce" or t not in ICON_NAME and pack_icon("Seed_Bags_" + t) is None:
            bpx = bag.load()
            pic = {(x, y) for y in range(16) for x in range(16) if bpx[x, y][3] and bpx[x, y] != epx[x, y] and sum(bpx[x, y][:3]) > 90}
            if cid in LEAFY or t == "Cabbage":
                bag = recolour_at(bag, pic, col)
            else:
                bag = recolour_at(bag, {q for q in pic if not is_leaf(bpx[q[0], q[1]])}, col)
        save(mute(bag, 0.08), "icons/%s_seed.png" % cid)
        n_icons += 1

# ---------------------------------------------------------------- fruit trees
# The pack's small trees (about as wide as the game's wild trees): a young tree while it grows, then the
# grown tree with 0 to 3 rounds of fruit (art.gd picks objects/fruit_tree_<fruit>_<young|0..3>_<season>.png).
FRUIT = {"apple": "#c8302a", "peach": "#f0985a", "pear": "#e8d848", "cherry": "#a01830", "plum": "#6a2a72", "walnut": "#a8884a"}
AUTUMN = ["#8a3a1a", "#b8581e", "#d8822a", "#e8a83a", "#f0c860"]
n_trees = 0


def autumn(im):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and is_leaf(p):
                i = min(4, int(lum(p) / 256 * 5 * 1.4))
                px[x, y] = hexrgb(AUTUMN[i]) + (p[3],)
    return out


def canopy_spots(im, n, seed):
    """Fruit spots inside the leaves, away from the edge, spread out."""
    px = im.load()
    ok = []
    for y in range(2, im.height - 14):
        for x in range(2, im.width - 3):
            if all(px[x + dx, y + dy][3] and is_leaf(px[x + dx, y + dy]) for dx in (-1, 0, 1, 2) for dy in (-1, 0, 1, 2) if abs(dx) + abs(dy) < 3):
                ok.append((x, y))
    rnd = random.Random(seed)
    rnd.shuffle(ok)
    out = []
    for p in ok:
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) > 4 for q in out):
            out.append(p)
        if len(out) >= n:
            break
    return out


def add_fruit(im, spots, colour):
    out = im.copy()
    px = out.load()
    c = hexrgb(colour)
    hi = tuple(min(255, v + 70) for v in c)
    dk = tuple(int(v * 0.6) for v in c)
    ol = (40, 30, 40, 255)
    for x, y in spots:
        # a round fruit: 3 wide, dark outline underneath, light spot on top
        for dx, dy in [(0, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (2, 0), (0, 1), (1, 1)]:
            px[x + dx, y + dy] = c + (255,)
        px[x, y - 1] = hi + (255,)
        px[x + 1, y + 1] = dk + (255,)
        for dx, dy in [(-1, 1), (2, 1), (0, 2), (1, 2)]:
            px[x + dx, y + dy] = ol
    return out


def blossoms(im, seed):
    out = im.copy()
    px = out.load()
    for i, (x, y) in enumerate(canopy_spots(im, 14, seed)):
        px[x, y] = (246, 222, 230, 255) if i % 3 else (232, 160, 190, 255)
        px[x + 1, y] = (250, 240, 244, 255)
    return out


if os.path.isdir(TREES):
    grown = rgba(os.path.join(TREES, "Fruit_Tree_Small_Apple_16x16.png"))
    young = {k: rgba(os.path.join(TREES, "Fruit_Tree_Small_%s_16x16.png" % v)) for k, v in [("a", "Peach"), ("b", "Orange")]}
    for fi, (fr, colour) in enumerate(FRUIT.items()):
        y_im = young["b" if fr in ("cherry", "plum") else "a"]
        spots = canopy_spots(grown, 10, fi * 7 + 1)
        for season in ["spring", "summer", "autumn", "winter"]:
            def seasoned(im, fruit_on):
                if season == "winter":
                    return snow_laden(im)
                if season == "autumn":
                    return autumn(im)
                if season == "spring" and not fruit_on:
                    return blossoms(im, fi)
                return im
            save(mute(seasoned(y_im, False), 0.1), "objects/fruit_tree_%s_young_%s.png" % (fr, season))
            for n in range(4):
                im = add_fruit(grown, spots[:[0, 4, 7, 10][n]], colour) if n else grown
                save(mute(seasoned(im, n > 0), 0.1), "objects/fruit_tree_%s_%d_%s.png" % (fr, n, season))
        n_trees += 1

# ---------------------------------------------------------------- farm animals
# Walk strips for art/animals/<type>_<0|1>.png and young ones in <type>_baby_<0|1>.png. Pack sheets have
# 24 columns: 6 frames facing right, up, left, down. The walk row is the one that moves most.
ANIMALS = {
    "chicken": ["Chickens_and_Roosters/Chicken_White", "Chickens_and_Roosters/Chicken_Brown", "Chickens_and_Roosters/Chick", "Chickens_and_Roosters/Chick"],
    "rabbit": ["Rabbits/Rabbit_Gray", "Rabbits/Rabbit_Brown", "Rabbits/Rabbit_Baby_Gray", "Rabbits/Rabbit_Baby_Brown"],
    "duck": ["Ducks/Duck_White", "Ducks/Duck_Brown", "Ducks/Duckling_Yellow", "Ducks/Duckling_Brown"],
    "cow": ["Cows/Cow", "Cows/Cow_Caramel", "Cows/Cow_Baby", "Cows/Cow_Baby_Caramel"],
    "goat": ["Goats/Goat_White", "Goats/Goat_Brown", "Goats/Goat_Baby_White", "Goats/Goat_Baby_Brown"],
    "sheep": ["Sheeps/Sheep_White", "Sheeps/Sheep_Gray", "Sheeps/Sheep_Baby_White", "Sheeps/Sheep_Baby_Brown"],
    "pig": ["Pigs/Pig_Pink", "Pigs/Pig_Pink_and_Brown", "Pigs/Piglet_Pink_Light", "Pigs/Piglet_Gray"],
    "guard_dog": ["Dogs/Dog_German_Shepherd_Brown", "Dogs/Dog_German_Shepherd_Dark_Brown"],
    "barn_cat": ["Cats/Cat_Hugo", "Cats/Cat_Kitkat"],
}
# sheets with label bands between rows: [frame width, frame height, walk row top]
LAYOUT = {"Dogs": (48, 32, 128), "Cats": (32, 32, 128)}


def walk_strip(rel):
    p = os.path.join(ANIM, rel + ("_16x16.png" if not rel.startswith("Cats") else ".png"))
    if not os.path.isfile(p):
        return None
    sh = rgba(p)
    folder = rel.split("/")[0]
    if folder in LAYOUT:
        fw, fh, top = LAYOUT[folder]
    else:
        fh = sh.height // 4
        fw = 32 if folder == "Ducks" and "Duckling" not in rel else sh.width // 24
        best = -1
        for r in (1, 2, 3):
            fr = [sh.crop((c * fw, r * fh, c * fw + fw, r * fh + fh)) for c in range(12, 18)]
            d = sum(sum(abs(a[3] - b[3]) for a, b in zip(fr[i].getdata(), fr[i + 1].getdata())) for i in range(5))
            if d > best:
                best, top = d, r * fh
    out = Image.new("RGBA", (fw * 6, fh * 3), (0, 0, 0, 0))
    for row, c0 in enumerate([12, 18, 6]):       # side (facing left), down, up
        for i in range(6):
            out.alpha_composite(sh.crop(((c0 + i) * fw, top, (c0 + i + 1) * fw, top + fh)), (i * fw, row * fh))
    return out, {"fw": fw, "fh": fh, "n": 6, "rows": {"side": 0, "down": 1, "up": 2}, "face": "left"}


ANI_INDEX = os.path.join(OUT, "animals", "index.json")
n_anim = 0
if os.path.isdir(ANIM):
    idx = json.load(open(ANI_INDEX)) if os.path.isfile(ANI_INDEX) else {}
    for typ, rels in ANIMALS.items():
        for i, rel in enumerate(rels):
            got = walk_strip(rel)
            if got is None:
                continue
            nm = "%s_%d" % (typ, i) if i < 2 else "%s_baby_%d" % (typ, i - 2)
            save(mute(got[0], 0.1), "animals/%s.png" % nm)
            idx[nm] = got[1]
            n_anim += 1
    json.dump(idx, open(ANI_INDEX, "w"), indent=1)

# ---------------------------------------------------------------- farm props
n_props = 0
if os.path.isdir(PROPS):
    def prop(name):
        im = rgba(os.path.join(PROPS, name + "_16x16.png"))
        return im.crop(im.getbbox())
    sc = mute(prop("Scarecrow"), 0.1)
    save(sc, "objects/scarecrow.png")
    save(hue_set(sc, "#8a9098", lambda p: (max(p[:3]) - min(p[:3])) > 20 and sum(p[:3]) > 120), "objects/tin_scarecrow.png")
    save(mute(prop("Drinking_Trough_Small_Full"), 0.1), "objects/water_trough.png")
    save(mute(prop("Hay_Manger_Small_Full_1"), 0.1), "objects/feed_trough.png")
    save(mute(prop("Hay_Manger_Small_Full_1"), 0.1), "objects/hay_hopper.png")
    save(mute(prop("Sprinkler"), 0.1), "objects/pressure_sprinkler.png")
    n_props = 6

print("modern farm: %d crops, %d icons, %d fruit trees, %d animal strips, %d props" % (n_crops, n_icons, n_trees, n_anim, n_props))
