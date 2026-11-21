"""Copy art from Daniel's asset packs into res://art/ under the names the game looks for.

Usage: python3 -I tools/import_packs.py <folder with the unzipped packs> <repo>/art

Packs used:
  PostApocalypse_AssetPack_v1.1.2 (TheLazyStone): ground tiles, trees, bushes, weeds, street props, wrecks
  Free_pixel_food_16x16 (alexkovacsart): crop, food and drink icons
  Kyrises_16x16_RPG_Icon_Pack_V1.3: gem, bar, log, plank, bone, candle icons
  GunsPack (greenpixels): ammo icons
The game picks these files up by name (see Art.override and Art.obj_override). Delete a file to go back
to the generated art for that thing.
"""
import os, sys
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
PA = os.path.join(SRC, "PostApocalypse_AssetPack_v1.1.2")
PO = os.path.join(PA, "Objects")
NAT = os.path.join(PO, "Nature")
FL = os.path.join(NAT, "Flowers_Mashrooms_Other-nature-stuff")
INV = os.path.join(PA, "UI", "Inventory", "Objects")
FOOD = os.path.join(SRC, "Free_pixel_food_16x16", "Free_pixel_food_16x16", "Icons")
KY = os.path.join(SRC, "Kyrises_16x16_RPG_Icon_Pack_V1.3", "Kyrise's 16x16 RPG Icon Pack - V1.3", "icons", "16x16")
GUN = os.path.join(SRC, "GunsPack", "GunsPack")

SEASON_SET = {"spring": "Green", "summer": "Dark-Green", "autumn": "Bleak-Yellow"}
written = []


def load(path):
    im = Image.open(path).convert("RGBA")
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def save(im, rel):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    written.append(rel)


def icon(im, rel):
    """Centre a small sprite on a 16x16 icon canvas, sitting a little low like the game's icons."""
    if im.width > 16 or im.height > 16:
        raise SystemExit("too big for an icon: " + rel)
    c = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    c.alpha_composite(im, ((16 - im.width) // 2, 16 - im.height - (16 - im.height) // 3))
    save(c, "icons/" + rel + ".png")


def tint(im, dark, light):
    """Recolour a grey template: map each pixel's brightness onto a dark..light ramp, keep outlines."""
    d = tuple(int(dark[i:i + 2], 16) for i in (1, 3, 5))
    l = tuple(int(light[i:i + 2], 16) for i in (1, 3, 5))
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            if lum < 0.2:
                continue
            t = min(1.0, (lum - 0.2) / 0.75)
            px[x, y] = tuple(int(d[i] + (l[i] - d[i]) * t) for i in range(3)) + (a,)
    return out


ramp_tint = tint   # kept under its own name: later loops reuse the name "tint"


def tone(im, want):
    """Recolour so the picture's average colour becomes the wanted one; light and dark detail stays."""
    out = im.copy()
    px = out.load()
    w = tuple(int(want[i:i + 2], 16) for i in (1, 3, 5))
    lum = lambda p: 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]
    pts = [(x, y) for y in range(out.height) for x in range(out.width) if px[x, y][3]]
    avg = sum(lum(px[x, y]) for x, y in pts) / max(1, len(pts))
    for x, y in pts:
        k = lum(px[x, y]) / max(avg, 1)
        px[x, y] = tuple(min(255, int(c * k)) for c in w) + (px[x, y][3],)
    return out


def vivid(im, sat=1.3, val=1.0):
    """More colour: scale saturation (and brightness) of every pixel."""
    import colorsys
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                h, s_, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                r2, g2, b2 = colorsys.hsv_to_rgb(h, min(1.0, s_ * sat), min(1.0, v * val))
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return out


def snowify(im):
    """Winter version of a plant: settle snow on the top edge of every clump of leaves."""
    out = im.copy()
    px = out.load()
    src = im.load()
    for x in range(im.width):
        for y in range(1, im.height):
            r, g, b, a = src[x, y]
            if a == 0 or r + g + b < 150:
                continue
            ar, ag, ab, aa = src[x, y - 1]
            if aa == 0 or ar + ag + ab < 150:      # top edge: the pixel above is outline or air
                px[x, y] = (236, 240, 246, a)
                if y + 1 < im.height and src[x, y + 1][3] and sum(src[x, y + 1][:3]) >= 150:
                    px[x, y + 1] = (206, 214, 226, a)
    return out


def snow_laden(im):
    """Winter deciduous tree: the leaf clumps become heaps of snow, the trunk stays bark."""
    out = snowify(im)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0 or r + g + b < 150 or r > g * 1.15:   # outline or bark
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            t = min(1.0, max(0.0, (lum - 0.35) / 0.45))
            px[x, y] = (int(150 + 90 * t), int(160 + 84 * t), int(178 + 72 * t), a)
    return out


def warm(im):
    """The pack's "bleak" autumn colours lean grey-purple: nudge them towards dry straw."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r + g + b >= 120:
                px[x, y] = (min(255, int(r * 1.08 + 6)), min(255, int(g * 1.04 + 4)), int(b * 0.82), a)
    return out


def bleak(path):
    return warm(load(path)) if "Bleak-Yellow" in path else load(path)


def tile(sheet, cx, cy):
    return Image.open(sheet).convert("RGBA").crop((cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16))


# ---------------------------------------------------------------- ground tiles
for season, setname in SEASON_SET.items():
    sheet = os.path.join(PA, "Tiles", "Background_%s_TileSet.png" % setname)
    # the only tiles in the sheet with no edging on them
    for v, (cx, cy) in enumerate([(14, 0), (16, 0), (14, 2), (16, 2)]):
        t = tile(sheet, cx, cy)
        t = warm(t) if setname == "Bleak-Yellow" else t
        # richer, deeper green than the pack's (closer to Pixel Crawler's lush grass, but not as loud)
        t = vivid(t, 1.2, 0.97) if season == "autumn" else tone(t, {"spring": "#5e8e40", "summer": "#4c7c36"}[season])
        save(t, "tiles/grass_%s_%d.png" % (season, v))
# grass with wildflowers (spring, summer) or mushrooms (autumn): variants 4-7, drawn on about 1 tile in 7
SV = os.path.join(SRC, "Serene_Village_revamped_v1.9", "SERENE_VILLAGE_REVAMPED", "Serene_Village_16x16.png")
if os.path.isfile(SV):
    svs = Image.open(SV).convert("RGBA")
    def sv_bit(x, y, w, h):
        return svs.crop((x, y, x + w, y + h))
    PINK, WHITE, BLUE, DAISY = sv_bit(281, 375, 6, 6), sv_bit(297, 376, 6, 6), sv_bit(289, 387, 6, 6), sv_bit(37, 211, 6, 5)
    PINK2, WHITE2, BLUE2 = sv_bit(291, 409, 6, 6), sv_bit(274, 402, 6, 6), sv_bit(278, 388, 6, 6)
    RED_SH, BROWN_SH, WHITE_SH = sv_bit(284, 429, 7, 7), sv_bit(276, 462, 6, 6), sv_bit(291, 492, 7, 8)
    BITS = {"spring": [[PINK, WHITE2], [BLUE, DAISY], [WHITE, PINK2], [DAISY, BLUE2, PINK]],
            "summer": [[DAISY, BLUE], [WHITE, DAISY], [BLUE2, PINK], [DAISY, WHITE2, BLUE]],
            "autumn": [[RED_SH], [BROWN_SH, BROWN_SH], [WHITE_SH], [RED_SH, BROWN_SH]]}
    SPOTS = [[(2, 3), (9, 9)], [(8, 2), (3, 10)], [(4, 8), (10, 3)], [(1, 2), (9, 6), (4, 10)]]
    for season in ["spring", "summer", "autumn"]:
        for v in range(4):
            t = Image.open(os.path.join(OUT, "tiles", "grass_%s_%d.png" % (season, v))).convert("RGBA")
            for bit, (bx, by) in zip(BITS[season][v], SPOTS[v]):
                t.alpha_composite(bit, (bx, by))
            save(t, "tiles/grass_%s_%d.png" % (season, v + 4))
green = os.path.join(PA, "Tiles", "Background_Green_TileSet.png")
# road and dirt have one plain tile each: flips of it make the other variants
FLIPS = [lambda t: t, lambda t: t.transpose(Image.FLIP_LEFT_RIGHT), lambda t: t.transpose(Image.FLIP_TOP_BOTTOM), lambda t: t.transpose(Image.ROTATE_180)]
for v, f in enumerate(FLIPS):
    save(f(tile(green, 5, 9)), "tiles/road_%d.png" % v)
    save(f(tile(green, 15, 1)), "tiles/dirt_%d.png" % v)

# ---------------------------------------------------------------- trees and plants
TREE_SEASON = {"spring": "Green", "summer": "Dark-Green", "autumn": "Orange"}
TREE2_SEASON = {"spring": "Green", "summer": "Dark-Green", "autumn": "Yellow"}
for season in TREE_SEASON:
    s1, s2 = TREE_SEASON[season], TREE2_SEASON[season]
    save(load(os.path.join(NAT, s1, "Tree_5_Big_%s.png" % s1)), "trees/tree_%s.png" % season)
    save(load(os.path.join(NAT, s2, "Tree_9_Small-oak_%s.png" % s2)), "trees/tree2_%s.png" % season)
save(snow_laden(load(os.path.join(NAT, "Bleak-Yellow", "Tree_5_Big_Bleak-Yellow.png"))), "trees/tree_winter.png")
save(snow_laden(load(os.path.join(NAT, "Bleak-Yellow", "Tree_9_Small-oak_Bleak-Yellow.png"))), "trees/tree2_winter.png")
save(snowify(load(os.path.join(NAT, "Dark-Green", "Tree_6_Big-pine_Dark-Green.png"))), "trees/pine_winter.png")
save(load(os.path.join(NAT, "Green", "Tree_6_Pine_Big_Green.png")), "trees/pine_spring.png")
for season in ["summer", "autumn"]:
    save(load(os.path.join(NAT, "Dark-Green", "Tree_6_Big-pine_Dark-Green.png")), "trees/pine_%s.png" % season)
save(load(os.path.join(NAT, "Tree_4_Dry_Green.png") if os.path.exists(os.path.join(NAT, "Tree_4_Dry_Green.png")) else os.path.join(FL, "Tree_4_Dry_Green.png")), "objects/dead_tree.png")
save(load(os.path.join(FL, "Stump_1.png")), "objects/stump.png")
save(load(os.path.join(FL, "Stump_2_Mushrooms.png")), "objects/mushroom_log.png")
save(load(os.path.join(FL, "Stick.png")), "objects/twig.png")
save(load(os.path.join(FL, "Rocks", "Rock_7.png")), "objects/rock.png")
save(load(os.path.join(FL, "Rocks", "Rock_6.png")), "objects/rock2.png")
for season, setname in SEASON_SET.items():
    for v, g in enumerate(["Grass_3", "Grass_4", "Grass_5", "Grass_2"]):
        save(bleak(os.path.join(NAT, setname, "%s_%s.png" % (g, setname))), "objects/weeds_%s_%d.png" % (season, v))
# bushes: green in spring and summer, four autumn colours, bare yellow in winter
for v in range(4):
    save(load(os.path.join(NAT, "Green", "Bush_1_Green.png")), "objects/bush_spring_%d.png" % v)
    save(load(os.path.join(NAT, "Dark-Green", "Bush_1_Dark-Green.png")), "objects/bush_summer_%d.png" % v)
    a = ["Orange", "Red", "Yellow", "Bleak-Yellow"][v]
    save(bleak(os.path.join(NAT, a, "Bush_1_%s.png" % a)), "objects/bush_autumn_%d.png" % v)
save(snow_laden(load(os.path.join(NAT, "Bleak-Yellow", "Bush_1_Bleak-Yellow.png"))), "objects/bush.png")
# a little more colour in living plants, and one bush in four flowering in spring and summer (Serene Village clumps)
for rel in [r for r in written if (r.startswith("trees/") or r.startswith("objects/bush_") or r.startswith("objects/weeds_"))
            and ("spring" in r or "summer" in r)]:
    save(vivid(Image.open(os.path.join(OUT, rel)).convert("RGBA"), 1.25, 0.98), rel)
# weeds and bushes from Pixel Crawler's vegetation: leafy clumps and ferns in season colours (the old ones were
# grey-blue and read as dark marks on the richer grass)
PCV = os.path.join(SRC, "Pixel_Crawler_-_Free_Pack_Exterior_0.1", "Pixel Crawler - Free Pack", "Environment", "Props", "Static", "Vegetation.png")
if os.path.isfile(PCV):
    veg = Image.open(PCV).convert("RGBA")
    def vcell(x, y, w=16, h=16):
        im = veg.crop((x, y, x + w, y + h))
        return im.crop(im.getbbox())
    for season, dy in [("spring", 144), ("summer", 192), ("autumn", 240)]:
        for v, (x, yy) in enumerate([(96, 32), (112, 32), (64, 0), (64, 16)]):
            im = vcell(x, dy + yy)
            save(vivid(im, 1.0, 0.9) if season == "summer" else im, "objects/weeds_%s_%d.png" % (season, v))
    for season, cols in [("spring", [0, 0, 0]), ("summer", [0, 0, 0]), ("autumn", [3, 2, 3])]:
        for v, c in enumerate(cols):
            im = vcell(c * 48, 0, 32, 32)
            save(vivid(im, 1.0, 0.88) if season == "summer" else im, "objects/bush_%s_%d.png" % (season, v))
    save(vcell(48, 0, 32, 32), "objects/bush_autumn_3.png")
if os.path.isfile(SV):
    # one bush in four flowers: a Pixel Crawler bush dotted with Serene Village blossoms (pink in spring, yellow in summer)
    for season, bit in [("spring", (281, 375, 6, 6)), ("summer", (37, 211, 6, 5))]:
        b = Image.open(os.path.join(OUT, "objects", "bush_%s_0.png" % season)).convert("RGBA")
        fl = svs.crop((bit[0], bit[1], bit[0] + bit[2], bit[1] + bit[3]))
        for (fx, fy) in [(5, 4), (15, 2), (21, 9), (9, 12), (17, 16), (4, 15)]:
            if fx + fl.width <= b.width and fy + fl.height <= b.height:
                b.alpha_composite(fl, (fx, fy))
        save(b, "objects/bush_%s_3.png" % season)
# trees and pines from Pixel Crawler: full, leafy and seasonal (green, orange and gold, snowy)
PCT = os.path.join(SRC, "Pixel_Crawler_-_Free_Pack_Exterior_0.1", "Pixel Crawler - Free Pack", "Environment", "Props", "Static", "Trees")
if os.path.isdir(PCT):
    def pc_cell(rel, x, y, w, h):
        im = Image.open(os.path.join(PCT, rel)).convert("RGBA").crop((x, y, x + w, y + h))
        return im.crop(im.getbbox())
    def pc_big(rel, row, idx):
        """The idx-th largest-to-smallest-by-x full tree in a growth-stage row of Size_02 (32 x 64 rows)."""
        import numpy as np
        from scipy import ndimage
        a = np.array(Image.open(os.path.join(PCT, rel)).convert("RGBA").crop((0, row * 64, 256, row * 64 + 64)))
        lab, n = ndimage.label(a[..., 3] > 0, structure=np.ones((3, 3)))
        sl = sorted([s_ for s_ in ndimage.find_objects(lab) if (s_[0].stop - s_[0].start) > 40], key=lambda s_: s_[1].start)[idx]
        im = Image.fromarray(a[sl])
        return im
    pc_shade = lambda im, k: vivid(im, 1.0, k)
    # the old PostApocalypse trees stay as a fourth, scruffier kind
    for season in ["spring", "summer", "autumn", "winter"]:
        old_p = os.path.join(OUT, "trees", "tree_%s.png" % season)
        if os.path.exists(old_p):
            save(Image.open(old_p).convert("RGBA"), "trees/tree4_%s.png" % season)
    oak = lambda c, r: pc_cell("Model_01/Size_03.png", c * 48, r * 96, 48, 96)
    save(vivid(oak(0, 0), 0.85, 0.97), "trees/tree_spring.png")
    save(pc_shade(oak(0, 0), 0.9), "trees/tree_summer.png")
    save(oak(0, 1), "trees/tree_autumn.png")
    save(oak(3, 0), "trees/tree_winter.png")
    save(vivid(pc_big("Model_01/Size_02.png", 0, 0), 0.85, 0.97), "trees/tree2_spring.png")
    save(pc_shade(pc_big("Model_01/Size_02.png", 0, 0), 0.9), "trees/tree2_summer.png")
    save(pc_big("Model_01/Size_02.png", 1, 1), "trees/tree2_autumn.png")
    save(pc_big("Model_01/Size_02.png", 0, 3), "trees/tree2_winter.png")
    pine = lambda c, r: pc_cell("Model_02/Size_03.png", c * 48, r * 80, 48, 80)
    save(pine(1, 1), "trees/pine_spring.png")
    save(pine(0, 1), "trees/pine_summer.png")
    save(pine(1, 0), "trees/pine_autumn.png")
    save(snowify(pine(0, 0)), "trees/pine_winter.png")
    # slim, tall trees (green, red in autumn) and short round pines
    slim = lambda x, y: pc_cell("Model_03/Size_02.png", x, y, 30, 75)
    save(slim(0, 5), "trees/tree3_spring.png")
    save(pc_shade(slim(0, 5), 0.88), "trees/tree3_summer.png")
    save(slim(64, 85), "trees/tree3_autumn.png")
    save(Image.open(os.path.join(OUT, "trees", "tree2_winter.png")).convert("RGBA"), "trees/tree3_winter.png")
    for season, c in [("spring", 1), ("summer", 0), ("autumn", 0)]:
        save(pine(0, 0) if season != "spring" else pine(1, 0), "trees/pine2_%s.png" % season)
    save(snowify(pine(1, 0)), "trees/pine2_winter.png")
    short = lambda x, y: pc_cell("Model_02/Size_02.png", x, y, 45, 47)
    for season in ["spring", "summer", "autumn"]:
        save(short(3, 1) if season != "autumn" else short(67, 1), "trees/pine3_%s.png" % season)
    save(snowify(short(3, 1)), "trees/pine3_winter.png")

# ---------------------------------------------------------------- street props and wrecks
V = os.path.join(PO, "Vehicles")
cars = [os.path.join(V, "Rust", "Car_4_Rust", "Car_4_Rust_Blue.png"), os.path.join(V, "Rust", "Car_4_Rust", "Car_4_Rust_Green.png"),
        os.path.join(V, "Rust", "Car_4_Rust", "Car_4_Rust_Red.png"), os.path.join(V, "Rust", "Car_4_Rust", "Car_4_Rust_Yellow.png")]
for v, p in enumerate(cars):
    save(load(p), "objects/car_wreck_%d.png" % v)
buses = ["Yellow", "Yellow", "Blue", "Light-Green"]
for v, c in enumerate(buses):
    save(load(os.path.join(V, "Rust", "Car_8_Rust_Bus", "Car_8_Rust_%s_Bus.png" % c)), "objects/bus_wreck_%d.png" % v)
for v, c in enumerate(["Red", "Gray", "Blue", "Green"]):
    save(load(os.path.join(V, "Normal", "Car_9_Motorcycle", "Car_9_%s_Motorcycle_Side.png" % c)), "objects/motorcycle_wreck_%d.png" % v)
for v, c in enumerate(["Container_3_Gray_Horizontal", "Container_7_Red_Horizontal", "Container_11_Green_Horizontal", "Container_8_Red_Horizontal_Overgrown_Green"]):
    save(load(os.path.join(PO, "Container", c + ".png")), "objects/shipping_container_%d.png" % v)
save(load(os.path.join(PO, "Garbage-Bin_1.png")), "objects/dumpster.png")
save(load(os.path.join(PO, "Garbage-Bin_2.png")), "objects/dumpster_open.png")
for v, b in enumerate(["Barrel_rust_red_1", "Barrel_blue_1", "Barrel_red_1", "Barrel_rust_blue_1"]):
    save(load(os.path.join(PO, b + ".png")), "objects/barrel_%d.png" % v)
save(load(os.path.join(PO, "Street-Light_1_Side.png")), "objects/lamp_post.png")
save(load(os.path.join(PO, "2-Tires_Grass_Green.png")), "objects/tire_stack_spring.png")
save(load(os.path.join(PO, "2-Tires_Grass_Dark-Green.png")), "objects/tire_stack_summer.png")
save(bleak(os.path.join(PO, "2-Tires_Grass_Bleak-Yellow.png")), "objects/tire_stack_autumn.png")
save(load(os.path.join(PO, "Tire_1.png")), "objects/tire_stack.png")
save(load(os.path.join(PO, "Metal-Plates.png")), "objects/scrap_pile.png")
save(load(os.path.join(PO, "Gray-brick_Debris.png")), "objects/rubble.png")
save(load(os.path.join(INV, "Icon_Bullet-crate_Green.png")), "objects/supply_crate.png")
for v, h in enumerate(["red", "yellow", "red", "yellow"]):
    save(load(os.path.join(PO, "Hydrant_1_%s.png" % h)), "objects/hydrant_%d.png" % v)
save(load(os.path.join(PO, "Traffic-cone.png")), "objects/traffic_cone.png")
for v, t in enumerate(["Trash-can_1", "Trash-can_2", "Trash-can_1", "Trash-can_2"]):
    save(load(os.path.join(PO, t + ".png")), "objects/trash_can_%d.png" % v)
for v, t in enumerate(["Trash-bag_1", "Trash-bag_2", "Cardboard_1", "Cardboard_2"]):
    save(load(os.path.join(PO, t + ".png")), "objects/trash_bags_%d.png" % v)
for v, c in enumerate(["Red", "Blue", "Red", "Blue"]):
    save(load(os.path.join(PO, "Vending-machine_%s.png" % c)), "objects/vending_machine_%d.png" % v)
save(load(os.path.join(PO, "Shopping-cart.png")), "objects/shopping_cart.png")
save(load(os.path.join(PO, "Stop-sign_Down_1.png")), "objects/stop_sign.png")

# ---------------------------------------------------------------- icons
FOOD_ICONS = {
    "apple": "fruit_apple", "cherry": "fruit_cherry", "peach": "fruit_peach", "melon": "fruit_watermelon",
    "carrot": "vegetable_carrot", "corn": "vegetable_corn", "tomato": "vegetable_tomato", "potato": "vegetable_potato",
    "pumpkin": "vegetable_pumpkin", "onion": "vegetable_onion", "garlic": "vegetable_garlic", "eggplant": "vegetable_eggplant",
    "bell_pepper": "vegetable_bellpepper_red", "hot_pepper": "vegetable_jalapeno", "cucumber": "vegetable_cucumber",
    "coffee_bean": "coffee_raw", "wild_grape": "fruit_grape_red",
    "bread_loaf": "pastry_bread", "cheese": "cheese_gouda", "goat_cheese": "cheese_camembert",
    "egg": "eggs_brown", "large_egg": "eggs_white", "fried_egg": "eggs_fried", "milk": "coffee_milkjug",
    "preserves": "jam_strawberry", "roasted_coffee": "coffee_darkroast", "camp_coffee": "coffee_espresso",
    "chamomile_tea": "coffee_tea", "mint_tea": "coffee_greentea", "canned_soup": "canned_soup",
}
for gid, f in FOOD_ICONS.items():
    icon(load(os.path.join(FOOD, f + ".png")), gid)
PA_ICONS = {"bandage": "Icon_Bandage", "med_kit": "Icon_First-Aid-Kit_Red", "surgery_kit": "Icon_First-Aid-Kit_White",
            "canned_beans": "Icon_Canned-food"}
for gid, f in PA_ICONS.items():
    icon(load(os.path.join(INV, f + ".png")), gid)
KY_ICONS = {"amethyst": "gem_01j", "jade": "gem_01a", "garnet": "gem_01g", "diamond": "crystal_01e", "emerald": "crystal_01a",
            "ruby": "crystal_01d", "sapphire": "crystal_01c", "topaz": "crystal_01b", "opal": "crystal_01f",
            "ember_opal": "crystal_01g", "glimmerite": "crystal_01j", "quartz": "shard_01e",
            "wood": "wood_01a", "plank": "plank_01a", "bone": "bone01a", "candle": "candle_01b", "cotton": "cotton_01a",
            "gold_bar": "ingot_01d", "silver_bar": "ingot_01c", "bronze_bar": "ingot_01a", "aurium_bar": "ingot_01e"}
for gid, f in KY_ICONS.items():
    icon(load(os.path.join(KY, f + ".png")), gid)
silver = load(os.path.join(KY, "ingot_01c.png"))
BAR_TINTS = {"copper_bar": ("#6a3018", "#f0a070"), "iron_bar": ("#3a3c42", "#b4b8c0"), "steel_bar": ("#2e3c4c", "#c8dcec"),
             "brass_bar": ("#6a5018", "#f4dc80"), "lead_bar": ("#2a2e38", "#8a90a0"), "tin_bar": ("#5a6060", "#eef2f2"),
             "zinc_bar": ("#3a4a52", "#c4d8e0"), "scrap_ingot": ("#3e2418", "#b07a50")}
for gid, (d, l) in BAR_TINTS.items():
    icon(tint(silver, d, l), gid)
AMMO = {"ammo_9mm": "PistolAmmoSmall", "ammo_22lr": "PistolAmmoSmall", "ammo_45acp": "PistolAmmoBig", "ammo_357": "PistolAmmoBig",
        "ammo_556": "RifleAmmoSmall", "ammo_308": "RifleAmmoBig", "ammo_3030": "RifleAmmoBig", "ammo_50bmg": "RifleAmmoBig",
        "buckshot": "ShotgunShellSmall", "shotgun_slug": "ShotgunShellBig"}
for gid, f in AMMO.items():
    icon(load(os.path.join(GUN, "Bullets", f + ".png")), gid)

print(len(written), "files written to", OUT)


# ---------------------------------------------------------------- people (Modern Interiors character generator)
# Each part sheet keeps the generator rows the game animates, 16x32 frames, in this order: 0 still frames,
# 1 idle (breathing), 2 walk, 3 hit (swing), 4 punch, 5 stab, 6 hurt, 7 pick up (GEN_ROWS). Most rows have 6
# frames per direction: right 0-5, up 6-11, left 12-17, down 18-23 (hurt 3 per direction, pick up 12). index.json lists each part with its main colour so the game
# can match a look ("dark skin, grey curly hair, blue jacket") to the nearest parts.
import json
from collections import Counter
CG = os.path.join(SRC, "moderninteriors-win", "2_Characters", "Character_Generator")
if os.path.isdir(CG):
    def main_colour(im, col=3):
        fr = im.crop((col * 16, 0, col * 16 + 16, 32))
        c = Counter(p[:3] for p in fr.getdata() if p[3] > 0 and sum(p[:3]) > 175 and p[:3] not in [(70, 70, 94), (58, 58, 80)])
        if not c:
            c = Counter(p[:3] for p in fr.getdata() if p[3] > 0)
        return "#%02x%02x%02x" % c.most_common(1)[0][0] if c else "#000000"
    GEN_ROWS = [0, 1, 2, 13, 14, 15, 19, 9]
    def gen_rows(im):
        out = Image.new("RGBA", (896, 32 * len(GEN_ROWS)), (0, 0, 0, 0))
        for i, r in enumerate(GEN_ROWS):
            out.alpha_composite(im.crop((0, r * 32, 896, r * 32 + 32)), (0, i * 32))
        return out
    index = {}
    for part, folder, prefix in [("body", "Bodies", "Body_"), ("eyes", "Eyes", "Eyes_"), ("outfit", "Outfits", "Outfit_"),
                                 ("hair", "Hairstyles", "Hairstyle_"), ("acc", "Accessories", "Accessory_")]:
        index[part] = {}
        d = os.path.join(CG, folder, "16x16")
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png"):
                continue
            im = gen_rows(Image.open(os.path.join(d, f)).convert("RGBA"))
            key = f[len(prefix):-4]
            save(im, "characters/mi/%s/%s.png" % (part, key))
            index[part][key] = main_colour(im)
    # add-ons from Modern Exteriors: work and uniform outfits and hats
    AD = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "Character_Generator_Addons_16x16")
    ADDONS = {"outfit": {"40_01": "Outfit_Soldier", "41_01": "Outfit_Firefighter", "42_01": "Outfit_Military_General",
                         "43_01": "Outfit_Postman", "44_01": "Outfit_Scout_16x16_1", "44_02": "Outfit_Scout_16x16_2", "44_03": "Outfit_Scout_16x16_3"},
              "acc": {"20_Worker_Helmet_01": "Accessory_20_Worker_Helmet", "21_Worker_Jacket_01": "Accessory_21_Worker_Jacket",
                      "22_Scout_Snapback_01": "Accessory_22_Scout_Snapback", "26_Postman_Hat_01": "Accessory_26_Postman_Hat_and_Bag",
                      "27_Soldier_Helmet_01": "Accessory_27_Soldier_Helmet", "28_General_Hat_01": "Accessory_28_Military_General_Hat"}}
    if os.path.isdir(AD):
        for part, m in ADDONS.items():
            for key, fname in m.items():
                f = os.path.join(AD, fname + ("" if fname.endswith(("_1", "_2", "_3")) else "_16x16") + ".png")
                im = gen_rows(Image.open(f).convert("RGBA"))
                save(im, "characters/mi/%s/%s.png" % (part, key))
                index[part][key] = main_colour(im)
    p = os.path.join(OUT, "characters", "mi", "index.json")
    with open(p, "w") as fh:
        json.dump(index, fh, indent=1, sort_keys=True)
    written.append("characters/mi/index.json")
    print("people parts:", {k: len(v) for k, v in index.items()})


# ---------------------------------------------------------------- interiors (Modern Interiors)
# Floors and walls from the Room Builder; furniture cut from the shadowless theme sheets (boxes found by
# segmenting the sheets: sheet, (x0, y0, x1, y1)).
MI = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16")
if os.path.isdir(MI):
    RB = os.path.join(MI, "Room_Builder_subfiles")
    floors = os.path.join(RB, "Room_Builder_Floors_16x16.png")
    walls = os.path.join(RB, "Room_Builder_Walls_16x16.png")
    FLOORS = {"floor": (0, 12), "floor_oak": (12, 26), "floor_tile": (12, 4), "floor_carpet": (9, 18), "floor_concrete": (12, 8), "floor_lab": (12, 30)}
    for t, (cx, cy) in FLOORS.items():
        for v, (dx, dy) in enumerate([(1, 0), (1, 1), (1, 0), (1, 1)]):
            save(tile(floors, cx + dx, cy + dy), "tiles/%s_%d.png" % (t, v))
    # the lower half of each 2-tile wall, which carries the baseboard
    WALLS = {"wall": (0, 6), "wall_paper": (24, 24), "wall_rose": (24, 0), "wall_panel": (12, 0), "wall_brick": (12, 22), "wall_concrete": (0, 30), "wall_lab": (24, 14)}
    for t, (cx, cy) in WALLS.items():
        save(tile(walls, cx + 1, cy + 1), "tiles/%s.png" % t)
    FURNITURE = {
    "loot_fridge": ("12_Kitchen_16x16", (144, 375, 160, 411)),
    "fridge": ("12_Kitchen_16x16", (144, 375, 160, 411)),
    "loot_cabinet": ("12_Kitchen_16x16", (1, 177, 15, 191)),
    "counter": ("12_Kitchen_16x16", (152, 242, 168, 256)),
    "stove": ("12_Kitchen_16x16", (128, 210, 144, 235)),
    "sink": ("12_Kitchen_16x16", (133, 113, 157, 127)),
    "table": ("1_Generic_16x16", (81, 81, 95, 95)),
    "chair": ("12_Kitchen_16x16", (66, 177, 79, 198)),
    "loot_dresser": ("1_Generic_16x16", (113, 1016, 128, 1034)),
    "loot_desk": ("5_Classroom_and_library_16x16", (64, 81, 77, 103)),
    "loot_shelf": ("5_Classroom_and_library_16x16", (192, 210, 208, 231)),
    "shelf": ("5_Classroom_and_library_16x16", (192, 210, 208, 231)),
    "bookshelf": ("5_Classroom_and_library_16x16", (49, 210, 63, 250)),
    "loot_locker": ("18_Jail_16x16", (209, 32, 223, 59)),
    "loot_medicine": ("18_Jail_16x16", (225, 73, 240, 87)),
    "loot_gun_case": ("25_Shooting_Range", (66, 19, 78, 32)),
    "old_bed": ("4_Bedroom_16x16", (231, 386, 251, 426)),
    "bed": ("4_Bedroom_16x16", (167, 385, 187, 425)),
    "lamp": ("2_LivingRoom_16x16", (193, 200, 206, 233)),
    "mirror": ("1_Generic_16x16", (226, 1056, 238, 1081)),
    "flower_pot": ("2_LivingRoom_16x16", (193, 322, 207, 345))
    }
    for t, (sheet_name, box) in FURNITURE.items():
        sh = os.path.join(MI, "Theme_Sorter_Shadowless", sheet_name.replace("_16x16", "") + "_Shadowless.png")
        im = Image.open(sh).convert("RGBA").crop(box)
        bb = im.getbbox()
        save(im.crop(bb) if bb else im, "objects/%s.png" % t)
    print("interiors:", len(FLOORS), "floors,", len(WALLS), "walls,", len(FURNITURE), "furniture")


# ---------------------------------------------------------------- buildings (Modern Exteriors)
# One whole building picture per building kind. The outdoor maps are built at twice their design size
# (MapScale), and each building's footprint follows its picture, lined up on its door.
# "door" is the door's centre in pixels from the picture's left edge (default: the middle).
ME = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "Modern_Exteriors_Complete_Singles_16x16")
if os.path.isdir(ME):
    A = "24_Additional_Houses_%s_16x16.png"
    S = "ME_Singles_%s_16x16_%s.png"
    BUILDINGS = {
        "farmhouse": A % "Post_Apocalyptic_House_1", "greenhouse": S % ("Garden", "Large_Greenhouse_Example"),
        "house_a": S % ("Villas", "Villa_1"), "house_b": S % ("Villas", "Villa_4"), "ruin": A % "Post_Apocalyptic_House_2",
        "d_house_blue": A % "Post_Apocalyptic_House_1", "d_house_red": A % "Post_Apocalyptic_House_1",
        "d_house_green": A % "Post_Apocalyptic_House_2", "d_house_yellow": A % "Post_Apocalyptic_House_2", "d_ruin": A % "Post_Apocalyptic_House_2",
        "store": S % ("Shopping_Center_and_Markets", "Market_Medium_1"), "tavern": A % "Japanese_House", "tavern_open": A % "Japanese_House",
        "forge": S % ("Generic_Building", "Condo_3_44"),
        "ranch": A % "One_Story_House", "clinic": S % ("Shopping_Center_and_Markets", "Market_Small_8"), "workshop": S % ("Generic_Building", "Hardware_Store_Example"),
        "guild": S % ("Police_Station", "Police_Station_Small_1"), "townhall": S % ("Villas", "Villa_2"),
        "archive": S % ("Generic_Building", "Condo_3_45"), "archive_open": S % ("Generic_Building", "Condo_3_45"),
        "baitshack": S % ("Camping", "Mobile_House_Small_1"),
        "d_diner": S % ("Shopping_Center_and_Markets", "Market_Big_1"), "d_pawn": S % ("Shopping_Center_and_Markets", "Market_Small_1"),
        "d_guns": S % ("Shopping_Center_and_Markets", "Market_Small_5"), "d_pharmacy": S % ("Shopping_Center_and_Markets", "Market_Small_9"),
        "d_police": S % ("Police_Station", "Police_Station_Small_1"), "d_church": S % ("Graveyard", "Grace_Chapel"),
        "d_shed": S % ("City_Props", "Junk_Shack_1"), "d_school": S % ("School", "School_1"),
        "d_thrift": S % ("Shopping_Center_and_Markets", "Market_Medium_2"), "d_gas": S % ("Shopping_Center_and_Markets", "Market_Medium_3"),
        "d_burger": S % ("Shopping_Center_and_Markets", "Market_Big_2"), "d_pizza": S % ("Shopping_Center_and_Markets", "Market_Big_3"),
        "d_chicken": S % ("Shopping_Center_and_Markets", "Market_Medium_4"), "d_taco": S % ("Shopping_Center_and_Markets", "Market_Medium_5"),
        "d_hotdog": S % ("Shopping_Center_and_Markets", "Market_Small_3"), "d_hardware": S % ("Generic_Building", "Hardware_Store"),
        "d_garage": S % ("Shopping_Center_and_Markets", "Market_Medium_10"), "d_firehouse": S % ("Fire_Station", "Building"),
        "d_warehouse": "23_MIlitary_Base_16x16_Hangar.png", "d_bar": S % ("Generic_Building", "Condo_3_45"),
        "d_scrap_office": S % ("City_Props", "Container_House_1"), "d_lumber_office": S % ("Camping", "Mobile_House_Medium_1"),
        "d_mill": "23_MIlitary_Base_16x16_Hangar.png", "d_farmhouse": A % "One_Story_House",
        "d_bait": S % ("Camping", "Mobile_House_Small_2"), "d_boathouse": S % ("Camping", "Mobile_House_Big_1"),
        "d_ranger": S % ("Camping", "Mobile_House_Big_5"), "d_cabin": S % ("Camping", "Mobile_House_Medium_5"),
        "d_lab": S % ("Hotel_and_Hospital", "Hospital_1"), "d_lab6": "23_MIlitary_Base_16x16_Bunker.png",
        "d_booth": S % ("Police_Station", "Parking_Booth_2"), "d_clubhouse": S % ("Camping", "Mobile_House_Big_3"),
        # Brightwater's lived-in homes (not enterable, Nov 17)
        "home_v3": S % ("Villas", "Villa_3"), "home_v5": S % ("Villas", "Villa_5"),
        "home_m2": S % ("Camping", "Mobile_House_Medium_2"), "home_m4": S % ("Camping", "Mobile_House_Medium_4"),
        "home_s3": S % ("Camping", "Mobile_House_Small_3"), "home_s4": S % ("Camping", "Mobile_House_Small_4"),
        "home_b2": S % ("Camping", "Mobile_House_Big_2"),
    }
    # where each picture's door (or the foot of its steps) is, in pixels from the left; default the middle
    # (Nov 17: town buildings swapped for small-town ones with a front door at ground level)
    DOOR = {"archive": 40, "archive_open": 40, "d_bar": 40, "forge": 40, "guild": 56, "d_garage": 56, "baitshack": 40, "d_bait": 40,
            "d_boathouse": 40, "d_booth": 24, "d_cabin": 42, "d_clubhouse": 42, "ranch": 145, "d_farmhouse": 145, "d_firehouse": 46,
            "d_guns": 24, "d_hotdog": 24, "d_pawn": 24, "d_pharmacy": 24, "d_hardware": 40, "workshop": 32,
            "d_house_blue": 124, "d_house_red": 124, "farmhouse": 124, "d_house_green": 123, "d_house_yellow": 123, "d_ruin": 123, "ruin": 123,
            "d_lab": 65, "d_lab6": 67, "d_lumber_office": 40, "d_mill": 77, "d_warehouse": 77, "d_ranger": 42, "house_a": 36, "house_b": 36,
            "d_scrap_office": 35, "d_shed": 40, "store": 56, "tavern": 88, "tavern_open": 88, "townhall": 36,
            "home_v3": 36, "home_v5": 36, "home_m2": 39, "home_m4": 39, "home_s3": 39, "home_s4": 39, "home_b2": 40, "clinic": 24}
    # pictures whose steps end above the picture's bottom edge: the ground line at the door, in pixels from the top.
    # Whatever is drawn below it (a porch) hangs in front and is solid.
    BASE = {}     # (Reyes Ranch and the Dry Creek clubhouse used porch pictures; both now have front doors)
    def clinic_front(im):
        """A small corner shop turned clinic: the STORE sign becomes a red cross, the awning red and white."""
        im = im.copy()
        px = im.load()
        for y in range(70, 82):
            for x in range(11, 37):
                if px[x, y][3] and sum(px[x, y][:3]) > 300:
                    px[x, y] = (232, 236, 240, 255)
        for y in range(71, 81):
            for x in range(12, 36):
                if px[x, y][3] and sum(px[x, y][:3]) < 400:
                    px[x, y] = (232, 236, 240, 255)
        cx, cy = 23, 75
        for d in range(-3, 4):
            for t in (0, 1):
                px[cx + t, cy + d] = (200, 48, 40, 255)
                px[cx + d, cy + t] = (200, 48, 40, 255)
        for y in range(60, 100):
            for x in range(36, 80):
                r, g, b, a = px[x, y]
                if a and r > 200 and 110 < g < 190 and b < 90:        # orange stripes to red
                    px[x, y] = (196, 52, 44, a)
        return im

    BUILD_FIX = {"clinic": clinic_front}
    meta = {}
    for kind, f in BUILDINGS.items():
        p = os.path.join(ME, f)
        if not os.path.exists(p):
            print("missing building art:", kind, f)
            continue
        im = load(p)
        if kind in BUILD_FIX:
            im = BUILD_FIX[kind](im)
        save(im, "buildings/%s.png" % kind)
        meta[kind] = {"w": im.width, "h": im.height, "door": DOOR.get(kind, im.width // 2)}
        # the soft shadow some pictures carry on their right isn't wall: the footprint stops at the solid part
        al = im.split()[3].point(lambda a: 255 if a > 200 else 0)
        sb = al.getbbox()
        if sb and sb[2] < im.width:
            meta[kind]["sw"] = sb[2]
        if kind in BASE:
            b = BASE[kind]
            px = im.load()
            xs = [x for x in range(im.width) for y in range(b + 4, im.height) if px[x, y][3] > 200]
            meta[kind]["base"] = b
            if xs:
                meta[kind]["over"] = [min(xs), max(xs)]
    with open(os.path.join(OUT, "buildings", "index.json"), "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    written.append("buildings/index.json")
    print("buildings:", len(meta))


# ---------------------------------------------------------------- crops and seeds (Sunnyside World)
# Growth stages for every crop. Crops the pack has use their own art; the rest borrow the closest crop
# shape and have the vegetable/fruit part recoloured to the crop's colour, so a whole field matches.
SUN = os.path.join(SRC, "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_Assets", "Elements", "Crops")
CF = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "crop_fish_colours.json")))


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def is_leaf(p):
    r, g, b = p[:3]
    return g > r + 8 and g >= b


def recolour(im, want, part="produce", keep_light=False):
    """Move one part's shades onto a colour (leaf = green pixels, produce = everything else), keeping shading."""
    out = im.copy()
    px = out.load()
    pix = [px[x, y] for y in range(out.height) for x in range(out.width) if px[x, y][3] > 0 and sum(px[x, y][:3]) > 90
           and (is_leaf(px[x, y]) == (part == "leaf"))]
    if not pix:
        return out
    base = sum(0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] for p in pix) / len(pix)
    w = hexrgb(want)
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0 or sum(p[:3]) <= 90 or is_leaf(p) != (part == "leaf"):
                continue
            k = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / max(base, 1)
            px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
    return out


def mute(im, amt=0.15):
    """Sunnyside is brighter than the post-apocalypse world: take a little of its saturation off."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                l = 0.3 * r + 0.59 * g + 0.11 * b
                px[x, y] = (int(r + (l - r) * amt), int(g + (l - g) * amt), int(b + (l - b) * amt), a)
    return out


def pad16(im):
    c = Image.new("RGBA", (16, max(16, im.height)), (0, 0, 0, 0))
    c.alpha_composite(im, ((16 - im.width) // 2, c.height - im.height))
    return c


if os.path.isdir(SUN):
    OWN = {"beet": "beetroot", "cabbage": "cabbage", "carrot": "carrot", "cauliflower": "cauliflower", "kale": "kale",
           "parsnip": "parsnip", "potato": "potato", "pumpkin": "pumpkin", "radish": "radish", "sunflower": "sunflower", "wheat": "wheat"}
    SHAPE = {"root": "radish", "leafy": "cabbage", "big": "pumpkin", "tall": "wheat", "bush": "kale", "vine": "wheat",
             "berry": "kale", "flower": "sunflower", "mushroom": "cauliflower", "nut": "potato", "leaf": "kale"}
    sun = lambda n, i: load(os.path.join(SUN, "%s_%02d.png" % (n, i)))
    for cid, info in CF["crops"].items():
        own = OWN.get(cid)
        tmpl = own or SHAPE.get(info["shape"], "radish")
        col = info["color"] or "#888888"
        frames = [sun(tmpl, i) for i in (1, 2, 3, 4)]
        if not own:
            if info["shape"] in ("bush", "berry"):
                # leafy plant with fruit: dots of the crop's colour on the grown plant
                ripe = frames[3].copy()
                d = ImageDraw.Draw(ripe)
                for fx, fy in [(3, 5), (8, 3), (10, 8), (5, 9)]:
                    if fx < ripe.width - 2 and fy < ripe.height - 2:
                        d.rectangle([fx, fy, fx + 1, fy + 1], fill=hexrgb(col) + (255,))
                        ripe.putpixel((fx, fy), tuple(min(255, c + 60) for c in hexrgb(col)) + (255,))
                frames[3] = ripe
            elif info["shape"] == "leafy":
                frames = [recolour(f, col, "produce") for f in frames]
            elif info["shape"] == "vine":
                frames = [recolour(f, "#6aa040", "produce") if i < 3 else recolour(f, col, "produce") for i, f in enumerate(frames)]
            else:
                frames = [recolour(f, col, "produce") for f in frames]
        # game stages: 0 just planted .. 4 ready; stage 3 is the grown plant, still unripe
        unripe = recolour(frames[3], "#7aa850", "produce") if info["shape"] not in ("leafy", "bush", "berry") else frames[2]
        stages = [frames[0], frames[1], frames[2], unripe, frames[3]]
        for st, im in enumerate(stages):
            save(pad16(mute(im)), "crops/%s_%d.png" % (cid, st))
        # crop and seed icons
        if not os.path.exists(os.path.join(OUT, "icons", cid + ".png")) and (own or info["shape"] in ("root", "leafy", "big", "tall")):
            ic = sun(tmpl, 5)
            icon(mute(ic if own else recolour(ic, col, "produce")), cid)
        icon(mute(recolour(load(os.path.join(SUN, "seeds_generic.png")), col, "produce")), cid + "_seed")
    print("crops:", len(CF["crops"]))

# ---------------------------------------------------------------- fish and tackle (Hollow Dolphin fishing icons)
HD = os.path.join(SRC, "Hollow_Dolphin_Fishing_Icon_Pack", "Separated Sprites", "16x16")
if os.path.isdir(HD):
    hd = lambda n: Image.open(os.path.join(HD, "fishing_icons_16x16_%d.png" % n)).convert("RGBA")

    def tint_fish(im, want):
        """Recolour a fish's body to its colour; outline, eye and highlights stay."""
        out = im.copy()
        px = out.load()
        body = [px[x, y] for y in range(16) for x in range(16) if px[x, y][3] and 120 < sum(px[x, y][:3]) < 640]
        if not body:
            return out
        base = sum(0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] for p in body) / len(body)
        w = hexrgb(want)
        for y in range(16):
            for x in range(16):
                p = px[x, y]
                if p[3] and 120 < sum(p[:3]) < 640:
                    k = min(1.3, max(0.55, (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / max(base, 1)))
                    px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
        return mute(out, 0.22)
    # body shapes, picked by the kind of fish
    SHAPES = {"small": 4, "round": 13, "sleek": 25, "long": 16, "big": 38, "flat": 37, "odd": 27, "spiny": 28, "deep": 14}
    KIND = {"minnow": "small", "shad": "small", "silver_dace": "small", "gold_shiner": "small", "ice_smelt": "small", "stone_loach": "small",
            "pond_sunfish": "flat", "crappie": "flat", "lake_perch": "spiny", "sunset_bream": "flat", "bramble_bass": "round",
            "brook_trout": "sleek", "brown_trout": "sleek", "rainbow_trout": "sleek", "chinook_salmon": "sleek", "highland_char": "sleek",
            "lake_whitefish": "sleek", "walleye": "long", "muskie": "long", "river_gar": "long", "ghost_pike": "long",
            "mirror_carp": "round", "glow_carp": "round", "golden_koi": "round", "river_chub": "round", "rotgill": "odd",
            "mud_catfish": "big", "spotted_bullhead": "big", "burbot": "big", "old_whiskers": "big", "bowfin": "big",
            "pale_sturgeon": "deep", "ridge_lurker": "deep", "lantern_queen": "deep", "cave_blindfish": "odd"}
    SPECIAL = {"bog_eel": 15, "lamprey": 15, "crayfish": 57, "river_clam": 69, "snapping_turtle": 72, "bullfrog": 27}
    for fid, info in CF["fish"].items():
        col = info["color"] or "#7a8a9a"
        if fid in SPECIAL:
            im = hd(SPECIAL[fid])
            im = tint_fish(im, col) if fid not in ("river_clam",) else im
        else:
            im = tint_fish(hd(SHAPES[KIND.get(fid, "round")]), col)
        save(im, "icons/%s.png" % fid)
    TACKLE = {"bait": 59, "premium_bait": 60, "magnet_bait": 67, "cork_bobber": 53, "trap_bobber": 54, "glow_lure": 55,
              "spinner": 56, "lead_weight": 82, "treasure_hook": 80, "crab_pot": 89, "fishing_rod": 17,
              "fishing_rod_bamboo": 5, "fishing_rod_fiberglass": 6, "fishing_rod_ironreel": 7, "fishing_rod_aurium": 8,
              "empty_bottle": 104, "plastic_bag": 105, "old_can": 106}
    for gid, n in TACKLE.items():
        save(hd(n), "icons/%s.png" % gid)
    print("fish:", len(CF["fish"]), "tackle:", len(TACKLE))


# ---------------------------------------------------------------- interface (Kenney UI Pack Pixel Adventure, PostApocalypse UI, Modern Interiors emotes)
# Menus: Kenney's wood-and-parchment frames (16x16 nine-slice tiles). On-screen bars and the hotbar: the
# PostApocalypse pack's slate cells and bars. Speech-bubble emotes over heads: Modern Interiors.
KEN = os.path.join(SRC, "kenney_ui-pack-pixel-adventure", "Tiles", "Small tiles", "Thick outline")
PAUI = os.path.join(SRC, "PostApocalypse_AssetPack_v1.1.2", "UI")
MIUI = os.path.join(SRC, "moderninteriors-win", "4_User_Interface_Elements", "UI_16x16.png")


def shade(im, k):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
    return out


def hue_to(im, want, only=lambda p: True):
    """Recolour pixels (keeping their lightness) toward a colour."""
    out = im.copy()
    px = out.load()
    w = hexrgb(want)
    lw = 0.3 * w[0] + 0.59 * w[1] + 0.11 * w[2]
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and only(p):
                k = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / max(lw, 1)
                px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
    return out


def hue_set(im, want, only=lambda p: True):
    """Like hue_to, but the chosen pixels average out to exactly the wanted colour."""
    out = im.copy()
    px = out.load()
    sel = [(x, y) for y in range(out.height) for x in range(out.width) if px[x, y][3] and only(px[x, y])]
    if not sel:
        return out
    lum = lambda p: 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]
    avg = sum(lum(px[x, y]) for x, y in sel) / len(sel)
    w = hexrgb(want)
    for x, y in sel:
        p = px[x, y]
        k = lum(p) / max(avg, 1)
        px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
    return out


def pix_icon(rows, pal):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                im.putpixel((x, y), pal[ch])
    return im


if os.path.isdir(KEN):
    kt = lambda n: load(os.path.join(KEN, "tile_%04d.png" % n))
    save(kt(33), "ui/panel.png")          # parchment in a nailed wood frame
    save(kt(10), "ui/panel_plain.png")
    save(kt(58), "ui/panel_metal.png")    # riveted grey metal
    save(kt(49), "ui/tooltip.png")
    wood = kt(11)
    save(wood, "ui/button.png")
    save(shade(wood, 1.15), "ui/button_hover.png")
    save(shade(wood, 0.82), "ui/button_pressed.png")
    save(shade(wood, 0.7).convert("LA").convert("RGBA"), "ui/button_disabled.png")
    save(hue_to(wood, "#5e9a44"), "ui/button_green.png")
    save(hue_to(shade(wood, 1.15), "#5e9a44"), "ui/button_green_hover.png")
    save(kt(3), "ui/button_red.png")
    save(shade(kt(3), 1.12), "ui/button_red_hover.png")
    light = lambda p: 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] > 200
    save(hue_set(kt(49), "#efc584", light), "ui/row.png")                       # list rows: darker parchment
    save(hue_set(kt(10), "#8fbf70", light), "ui/portrait.png")                  # portrait frame, sky inside
    save(hue_set(kt(10), "#8a2a1e", lambda p: not light(p) and sum(p[:3]) > 200), "ui/panel_danger.png")
    save(hue_set(kt(3), "#c8642a", lambda p: sum(p[:3]) > 200), "ui/badge.png")
    save(kt(3), "ui/badge_bad.png")
    save(kt(98), "ui/badge_good.png")
    for n, nm in [(83, "l"), (84, "m"), (85, "r")]:
        save(kt(n), "ui/ribbon_%s.png" % nm)
    print("ui: kenney")
if os.path.isdir(PAUI):
    save(load(os.path.join(PAUI, "Inventory", "Inventory-Cell.png")), "ui/slot.png")
    save(load(os.path.join(PAUI, "Inventory", "Inventory-Chosen.png")), "ui/slot_selected.png")
    save(shade(load(os.path.join(PAUI, "Inventory", "Inventory-Cell.png")), 1.18), "ui/slot_hover.png")
    save(load(os.path.join(PAUI, "Inventory", "Inventory_1.png")), "ui/hud_panel.png")
    hp = load(os.path.join(PAUI, "HP", "HP-Bar.png"))
    tr = hp.crop((12, 0, hp.width, hp.height))
    end = tr.crop((tr.width - 5, 0, tr.width, tr.height)).transpose(Image.FLIP_LEFT_RIGHT)
    tr.paste(end, (0, 0))
    for y in range(4, 8):                       # dark inside, so the empty part reads as empty
        for x in range(2, tr.width - 2):
            if tr.getpixel((x, y))[3] == 0:
                tr.putpixel((x, y), (43, 32, 51, 235))
    save(tr, "ui/bar_track.png")
    fill = load(os.path.join(PAUI, "HP", "HP.png"))
    save(fill, "ui/bar_health.png")
    save(load(os.path.join(PAUI, "Hunger", "Hunger.png")).resize((fill.width, fill.height), Image.NEAREST), "ui/bar_hunger.png")
    save(hue_to(fill, "#e8c03a"), "ui/bar_energy.png")
    save(hue_to(fill, "#3a90d8"), "ui/bar_thirst.png")
    save(load(os.path.join(PAUI, "HP", "Heart_Full.png")), "ui/icon_health.png")
    save(load(os.path.join(PAUI, "Hunger", "Hunger_Full.png")), "ui/icon_hunger.png")
    # energy and thirst have no icon in the pack: drawn here in its palette (dark plum outline, soft highlight)
    pal = {"o": (43, 32, 51, 255), "y": (232, 192, 58, 255), "Y": (255, 232, 140, 255), "d": (176, 128, 30, 255),
           "b": (58, 144, 216, 255), "B": (160, 210, 245, 255), "n": (34, 90, 150, 255)}
    save(pix_icon(["....oooo.....", "...oYyyo.....", "..oYyyo......", "..oyyo.......", ".oyyyoooo....", ".oyyyyyyyo...",
                   "..ooooyydo...", ".....oydo....", "....oydo.....", "...oydo......", "...odo.......", "...oo........"], pal), "ui/icon_energy.png")
    save(pix_icon([".....oo......", "....obbo.....", "...obbbbo....", "...obbbbo....", "..obBbbbbo...", "..obBbbbbo...",
                   ".obBbbbbbbo..", ".obbbbbbbbo..", ".obbbbbbbno..", "..obbbbbno...", "...onnnno....", "....oooo....."], pal), "ui/icon_thirst.png")
    print("ui: postapoc")
if os.path.isfile(MIUI):
    sheet = Image.open(MIUI).convert("RGBA")
    EMOTE = {"heart": (6, 6), "question": (8, 6), "alert": (9, 6), "alarm": (10, 6), "sleep": (11, 6), "music": (12, 6),
             "sweat": (15, 38), "angry": (11, 130), "dots": (7, 194)}
    for name, (col, y) in EMOTE.items():
        t = sheet.crop((col * 16, y, col * 16 + 16, y + 30))
        b = t.getbbox()
        if b:
            save(t.crop((0, b[1], 16, b[3])), "ui/emote_%s.png" % name)
    print("ui: emotes", len(EMOTE))


# ---------------------------------------------------------------- weapons (Full_pack guns, The Ultimate Pixel Sword Pack)
# Icons are 16x16 on the diagonal (handle or grip bottom-left, tip or muzzle top-right), like the tools.
# Guns, bows and crossbows also get a "held" picture pointing right, drawn in the player's hands when aiming.
GUNS = os.path.join(SRC, "Gun_Full_pack")
SWORDS = os.path.join(SRC, "UltimateSwordPack", "TheUltimateSwordPack_0.png")
if os.path.isdir(GUNS) and os.path.isfile(SWORDS):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pixel_icons as PI
    import numpy as np
    _gsheets = {}

    def gun_sheet(n):
        if n not in _gsheets:
            cs = PI.comps(os.path.join(GUNS, "%d.png" % n))
            cs.sort(key=lambda c: (c[0][0] // 40, c[0][1]))
            _gsheets[n] = cs
        return _gsheets[n]

    def gun(i, cw=0):
        """Gun i of the plain sheet; cw picks one of the pack's 34 colour versions (same gun, other finish)."""
        (px, py), base = gun_sheet(0)[i]
        if cw:
            for (qx, qy), im in gun_sheet(cw):
                if abs(qx - px) <= 3 and abs(qy - py) <= 3 and abs(im.width - base.width) <= 2 and abs(im.height - base.height) <= 2:
                    return im
        return base

    swords = PI.comps(SWORDS)
    swords.sort(key=lambda c: (c[0][1] // 40, c[0][0]))
    sword = lambda i: swords[i][1]

    def tint_part(im, want, part="metal"):
        """Recolour the steel (grey) or the wood (brown) of a weapon, keeping its shading."""
        a = np.array(im).astype(float)
        rgb = a[:, :, :3]
        mx, mn = rgb.max(-1), rgb.min(-1)
        sat = (mx - mn) / np.maximum(mx, 1)
        lum = 0.3 * rgb[:, :, 0] + 0.59 * rgb[:, :, 1] + 0.11 * rgb[:, :, 2]
        op = a[:, :, 3] > 0
        if part == "metal":
            sel = op & (sat < 0.2) & (lum > 70)
        elif part == "wood":
            sel = op & (sat >= 0.25) & (rgb[:, :, 0] > rgb[:, :, 2] + 20) & (lum > 50)
        else:
            sel = op & (lum > 45)
        if not sel.any():
            return im
        w = np.array(hexrgb(want), float)
        k = lum[sel] / max(lum[sel].mean(), 1)
        a[sel, :3] = np.clip(w[None, :] * k[:, None], 0, 255)
        return Image.fromarray(a.astype(np.uint8))

    def held_gun(im, maxw=22):
        oc = PI.outline_colour(im)
        if im.width <= maxw:
            return im
        a = np.array(im).astype(int)
        m = a[:, :, 3] > 0
        isout = m & (np.abs(a[:, :, :3] - np.array(oc)).sum(-1) <= 30)
        a[isout, 3] = 0
        core = Image.fromarray(a.astype(np.uint8))
        core = core.crop(core.getbbox())
        k = (maxw - 2) / core.width
        sm = PI.shrink(core, maxw - 2, max(2, round(core.height * k)), cover=0.25, reoutline=False)
        r = Image.new("RGBA", (sm.width + 2, sm.height + 2), (0, 0, 0, 0))
        r.alpha_composite(sm, (1, 1))
        return PI.add_outline(r, oc)

    def fit_h(im, h):
        if im.height <= h:
            return im
        return PI.shrink(im, max(1, round(im.width * h / im.height)), h, cover=0.25, reoutline=False)

    # weapon id: (gun index, colour version) ; colour versions only for upgraded and legendary guns
    GUN = {"pistol_22": (153, 0), "pistol_9mm": (145, 0), "pistol_45": (160, 0), "match_grade_9mm_pistol": (157, 0),
           "revolver_357": (150, 0), "tuned_357_revolver": (158, 0), "twin_hammer_revolver": (180, 1), "dead_mans_hand": (155, 18),
           "flare_gun": (151, 0), "cinderheart": (151, 22),
           "compact_smg": (10, 0), "extended_compact_smg": (11, 0), "smg_45": (8, 0), "shock_trooper_smg": (13, 10),
           "sawed_off_shotgun": (55, 0), "double_barrel_shotgun": (56, 0), "polished_double_barrel": (56, 18), "last_rites": (56, 21),
           "pump_shotgun": (52, 0), "ported_pump_shotgun": (51, 0), "dragons_breath_pump": (52, 16),
           "rifle_22": (36, 0), "match_grade_22_rifle": (36, 6), "lever_action_rifle": (33, 0), "smooth_lever_action": (33, 1),
           "bolt_action_rifle": (34, 0), "scoped_bolt_action_rifle": (90, 0), "deadeye_bolt_action": (90, 29),
           "carbine": (61, 0), "battle_rifle": (63, 0), "assault_rifle": (58, 0), "custom_assault_rifle": (59, 0), "acid_etched_assault_rifle": (58, 5),
           "light_machine_gun": (85, 0), "tuned_light_machine_gun": (86, 0), "turncoat": (85, 11),
           "sniper_50": (89, 0), "long_goodbye": (89, 6)}
    n = 0
    for wid, (gi, cw) in GUN.items():
        sp = gun(gi, cw)
        save(PI.icon16(sp, 45), "icons/%s.png" % wid)
        save(held_gun(sp), "held/%s.png" % wid)
        n += 1
    # weapon id: (sword pack index, tint) ; tint = (colour, "metal" | "wood" | "all")
    SW = {"kitchen_knife": (0, None), "combat_knife": (47, None), "honed_combat_knife": (47, ("#d8e4ec", "metal")), "bayonet": (1, None),
          "meat_cleaver": (41, None), "machete": (45, None), "tempered_machete": (45, ("#b8c8d8", "metal")), "serrated_machete": (56, None),
          "kukri": (18, None), "honed_kukri": (18, ("#d8e4ec", "metal")), "hush": (18, ("#2a2a30", "metal")),
          "katana": (25, None), "tempered_katana": (25, ("#c8d8e8", "metal")), "shadowstep_katana": (24, ("#34343e", "metal")), "kintsugi": (24, ("#2a2830", "metal")),
          "sickle": (19, None), "scythe": (159, None), "balanced_scythe": (159, ("#c8d8e8", "metal")), "gleaner": (158, ("#d8c070", "metal")), "last_harvest": (159, ("#e8f0f4", "metal")),
          "hatchet": (104, None), "balanced_hatchet": (104, ("#c8d8e8", "metal")), "throwing_axe": (106, None), "the_twins": (106, ("#b83a2a", "metal")),
          "fire_axe": (105, ("#c8382a", "metal")), "heavy_fire_axe": (105, ("#a82a20", "metal")), "headsmans_axe": (109, None),
          "splitting_maul": (127, None), "sledgehammer": (128, None), "reinforced_sledgehammer": (128, ("#9aa8b8", "metal")),
          "shieldbreaker": (128, ("#3a4a6a", "metal")), "thunderclap": (128, ("#4a8ad8", "metal")), "claw_hammer": (130, None), "ice_axe": (147, None),
          "baseball_bat": (63, None), "weighted_baseball_bat": (63, ("#8a5a30", "wood")), "club": (64, None), "nail_bat": (65, None),
          "barbed_wire_bat": (66, None), "rebar_club": (99, ("#6a5a4a", "wood")),
          "makeshift_spear": (152, None), "javelin": (150, None), "fishing_spear": (165, None), "pitchfork": (161, None),
          "throwing_knives": (47, None), "balanced_throwing_knives": (47, ("#d8e4ec", "metal")), "venom_throwing_knives": (47, ("#6ab040", "metal"))}
    for wid, (si, tint) in SW.items():
        sp = sword(si)
        if tint:
            sp = tint_part(sp, *tint)
        save(PI.icon16(sp, -45), "icons/%s.png" % wid)
        n += 1
    # bows and crossbows: icon on the diagonal, held picture facing right
    BOW = {"recurve_bow": (198, None), "laminated_recurve_bow": (202, None), "hunting_bow": (197, None), "ash_hunting_bow": (207, None),
           "compound_bow": (205, None), "tuned_compound_bow": (199, None), "hunters_compound_bow": (205, ("#4a5a3a", "wood")), "whisper": (206, ("#e8e0d0", "wood"))}
    for wid, (si, tint) in BOW.items():
        sp = sword(si)
        if tint:
            sp = tint_part(sp, *tint)
        save(PI.icon16(sp.transpose(Image.FLIP_LEFT_RIGHT), -45), "icons/%s.png" % wid)
        save(fit_h(sp.transpose(Image.FLIP_LEFT_RIGHT), 18), "held/%s.png" % wid)
        n += 1
    XBOW = {"crossbow": (180, None), "hand_crossbow": (177, None), "scrap_crossbow": (178, None), "waxed_rail_crossbow": (180, ("#c89850", "wood")),
            "repeating_crossbow": (182, None), "iron_psalm": (179, ("#3a3a40", "wood"))}
    for wid, (si, tint) in XBOW.items():
        sp = sword(si)
        if tint:
            sp = tint_part(sp, *tint)
        save(PI.icon16(sp, -45), "icons/%s.png" % wid)
        side = sp.rotate(-90, expand=True)
        save(held_gun(side, 18), "held/%s.png" % wid)
        n += 1
    # arrows and bolts
    AMMO = {"arrow": (213, None), "broadhead_arrow": (216, None), "fire_arrow": (213, ("#e8782a", "metal")), "bolts": (215, None), "explosive_bolt": (215, ("#c83a2a", "metal"))}
    for wid, (si, tint) in AMMO.items():
        sp = sword(si)
        if tint:
            sp = tint_part(sp, *tint)
        save(PI.icon16(sp, -45), "icons/%s.png" % wid)
        n += 1
    print("weapons:", n)


# ---------------------------------------------------------------- 150+ PROPS ITEMS (side view) 16x16
# Cosy side-view props: chests, jars, bottles, cans, boots, bags, pots. Used as item icons (and the chests as
# world objects), muted a little to sit with the post-apocalypse art. id: (folder, number, recolour or None)
PROPS = os.path.join(SRC, "Props150_side", "PNG")
if os.path.isdir(PROPS):
    D = {"acc": "1-ACCESSORIES", "chest": "3-CHESTS and LOCKS", "food": "4-FOOD", "jar": "5-BOTTLES CANS JARS KETTLES VASES", "misc": "6-MISCELLANEOUS"}
    prop = lambda f, n: load(os.path.join(PROPS, D[f], "%d.png" % n))
    PROP_ICONS = {
        # bags and boots
        "satchel": ("acc", 7, None), "hiking_pack": ("acc", 8, None), "military_rucksack": ("acc", 9, "#5a6a3a"), "ammo_pouch": ("acc", 4, "#6a5a3a"),
        "hiking_boots": ("misc", 1, None), "broken_in_hiking_boots": ("misc", 1, None), "work_boots": ("misc", 2, None), "treaded_work_boots": ("misc", 2, None),
        "combat_boots": ("misc", 3, "#3a3a34"), "reinforced_combat_boots": ("misc", 3, "#2a2a2a"), "snow_boots": ("misc", 4, None), "torn_boot": ("misc", 2, "#6a5a4a"),
        "broken_umbrella": ("acc", 19, "#5a5a5a"),
        # storage
        "chest": ("chest", 8, None), "large_chest": ("chest", 7, None), "lockbox": ("chest", 12, None),
        # food and drink
        "canned_meat": ("misc", 5, None), "canned_peaches": ("misc", 6, None), "canned_tuna": ("misc", 7, None), "soda": ("misc", 8, None),
        "crackers": ("food", 16, "#c89858"), "chocolate_bar": ("food", 9, None), "pear": ("food", 15, "#c8b048"), "plum": ("food", 1, "#6a2a6a"),
        "cherry_tart": ("food", 4, None), "apple_biscuits": ("food", 5, None), "pancakes": ("food", 13, "#d8a050"), "flatbread": ("misc", 15, None),
        "blackberry": ("food", 11, None), "wild_raspberry": ("food", 12, None), "cranberry": ("food", 12, "#a82a3a"), "bluebell_berry": ("food", 10, None),
        "honey": ("jar", 9, None), "wildflower_honey": ("jar", 8, None), "peanut_butter": ("jar", 12, None),
        "pickles": ("jar", 16, None), "sauerkraut": ("jar", 17, "#c8c070"), "kimchi": ("jar", 18, None),
        "dandelion_tea": ("jar", 21, None), "pine_tea": ("jar", 29, None), "willow_tea": ("jar", 19, None),
        "cooking_oil": ("jar", 35, None), "truffle_oil": ("jar", 30, None), "elderflower_cordial": ("jar", 37, None), "melon_chill": ("jar", 36, None),
        "hard_cider": ("jar", 38, None), "bean_pot": ("jar", 39, None), "veggie_stew": ("jar", 48, None), "rabbit_stew": ("jar", 49, None), "trout_chowder": ("jar", 50, None),
        # medicine and farm supplies
        "antibiotics": ("jar", 22, None), "iodine_tablets": ("jar", 23, None), "vitamins": ("jar", 24, None), "painkillers": ("jar", 25, None),
        "antiseptic": ("jar", 3, None), "soap": ("jar", 1, None), "pest_spray": ("jar", 5, None), "growth_tonic": ("jar", 6, None),
        # tools, forage, flowers
        "frying_pan": ("misc", 36, None), "milk_pail": ("misc", 41, None), "wild_mint": ("misc", 34, None), "elderflower": ("misc", 43, None),
        "moonbloom": ("misc", 45, None), "chickweed": ("misc", 46, None),
    }
    n = 0
    for iid, (f, num, tint) in PROP_ICONS.items():
        im = prop(f, num)
        if tint:
            im = hue_set(im, tint, lambda p: sum(p[:3]) > 120 and (max(p[:3]) - min(p[:3])) > 25)
        if iid == "frying_pan" and "PI" in globals():
            save(PI.icon16(mute(im, 0.22), 45), "icons/frying_pan.png")   # held like the other weapons
        else:
            icon(mute(im, 0.22), iid)
        n += 1
    # the chests double as the placed chests on the farm
    for oid, num in [("chest", 8), ("large_chest", 7), ("lockbox", 3)]:
        im = prop("chest", num)
        if oid == "lockbox":
            im = hue_set(im, "#6a707a", lambda p: sum(p[:3]) > 120 and (max(p[:3]) - min(p[:3])) > 25)
        save(mute(im, 0.22), "objects/%s.png" % oid)
    print("props:", n)


# ---------------------------------------------------------------- world objects from Modern Exteriors and Modern Interiors
# Single pictures for props, machines and vehicles; walls and fences are built as 16 joining pieces
# (objects/<type>_c<mask>.png, mask bits 1 = west, 2 = east, 4 = north, 8 = south) from a straight piece
# across and a straight piece down.
MEROOT = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_16x16", "ME_Theme_Sorter_16x16")
MIROOT = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless")
if os.path.isdir(MEROOT) and os.path.isdir(MIROOT):
    import glob as _glob
    _me_cache = {}

    def me(name):
        """A Modern Exteriors single by the end of its file name, trimmed to what's drawn."""
        if name not in _me_cache:
            hits = sorted(_glob.glob(os.path.join(MEROOT, "*Singles*", "*_16x16_" + name + ".png")))
            if not hits:
                raise SystemExit("no exterior single: " + name)
            _me_cache[name] = hits[0]
        im = load(_me_cache[name])
        return im.crop(im.getbbox())

    def sheet_tile(path, x, y, w=1, h=1, trim=True):
        im = Image.open(path).convert("RGBA").crop((x * 16, y * 16, (x + w) * 16, (y + h) * 16))
        return im.crop(im.getbbox()) if trim and im.getbbox() else im

    TERR = os.path.join(MEROOT, "1_Terrains_and_Fences_16x16.png")
    mi = lambda sheet, x, y, w=1, h=1: sheet_tile(os.path.join(MIROOT, sheet + "_Shadowless.png"), x, y, w, h)

    def put_over(base, top, dx=0, dy=0):
        out = base.copy()
        out.alpha_composite(top, ((base.width - top.width) // 2 + dx, base.height - top.height + dy))
        return out

    OBJ = {
        # power and defenses
        "generator": me("Electric_Box_1"), "battery_bank": me("Electric_Box_2"), "solar_panel": me("Solar_Panel"),
        "floodlight": me("Light_Tower_1"), "landmine": me("Mine_1"), "nail_mine": me("Mine_2"),
        # camp, farm and home
        "campfire": me("Campfire_3"), "campfire_ring": me("Campfire_1"), "cookstove": mi("12_Kitchen", 8, 11, 1, 2),
        "bee_house": me("Brown_Little_Bird_House"), "doghouse": me("Brown_Wood_Storage"), "sleeping_bag": me("Sleeping_Bag_3"),
        "log_pile": me("Cut_Wood_Bench_2"), "bench": me("Bench_7"), "ladder_up": me("Villa_Ladder_1"),
        # signs and boards
        "sign": me("Sign_6"), "wood_sign": me("Sign_4"), "notice_board": me("Sign_8"),
        # scavenging props
        "crate": me("Pier_Crates_1"), "loot_crate": me("Pier_Crates_2"), "tent": me("Tent_3"),
        "field_tent": me("Tent_2"), "medical_tent": put_over(me("Tent_3"), me("Military_Tent_Brown_Cross_1").crop((0, 0, me("Military_Tent_Brown_Cross_1").width, 14)), 0, -4),
        "police_car": me("Police_Car_1"), "fire_truck": me("Fire_Truck_Left"), "heli_wreck": mute(me("Helicopter_1"), 0.35),
        "boat": me("Boat_2_Left_1"), "fuel_pump": me("Gas_Station_Petrol_Pump_Props_5"),
        "sandbags": me("Sandbag_Pile_Horizontal"), "barricade": me("Traffic_Barrier_1"), "jersey_barrier": me("Barrier_1"),
        "fryer": mi("12_Kitchen", 7, 32, 2, 2), "server_rack": mi("18_Jail", 8, 21, 1, 2), "lab_bench": mi("19_Hospital", 10, 65, 2, 2),
        "cell_bars": mi("18_Jail", 1, 5, 1, 2),
        # machines and stations
        "smoker": me("Barbecue_1"), "ferment_barrel": me("Brown_Barrel_1"), "rain_collector": me("Barrel_1"), "compost_bin": me("Green_Closed_Trash_Can"),
        "water_purifier": me("Drinking_Fountain_1"), "chem_station": me("Military_Tent_Shelf_2"), "electronics_bench": me("Military_Tent_Shelf_3"),
        "weapon_rack": me("Military_Tent_Locker_1"), "table_set": me("Benched_Table_1"), "oil_lantern": me("Lantern_1"),
        # district props
        "biohazard_bin": me("Barrel_9"), "decon_shower": me("Portable_Toilet_2"), "stolen_goods": me("Pier_Crates_5"),
        "big_stump": me("Stump_2"), "boulder": me("Rock_8"),
    }
    OBJ.update({
        "ladder_down": me("Bunker_Base_Trapdoor_Open_Props"),
        "loot_toolbox": me("Tool_Box_1"), "loot_toolbox_open": me("Tool_Box_2"),
        "window": mi("1_Generic", 15, 44, 1, 1),
        "gravel_path": sheet_tile(TERR, 29, 9, trim=False), "stone_path": sheet_tile(TERR, 25, 9, trim=False),
        "wood_floor": load(os.path.join(OUT, "tiles", "floor_oak_0.png")) if os.path.exists(os.path.join(OUT, "tiles", "floor_oak_0.png")) else sheet_tile(TERR, 29, 9, trim=False),
    })
    for v, nm in enumerate(["Crack_1", "Crack_2", "Crack_3", "Crack_5"]):
        save(me(nm), "objects/road_crack_%d.png" % v)
    for oid, im in OBJ.items():
        save(im, "objects/%s.png" % oid)
    # gravestones: four kinds, picked per stone
    for v, nm in enumerate(["Grey_Cross_1", "Marble_Grey_Tombstone_1", "Small_Black_Tombstone_1", "Long_Tombstone_1"]):
        save(me(nm), "objects/gravestone_%d.png" % v)

    def joined(H, V, post=None):
        """16 joining pieces from a straight piece across (H) and a straight piece down (V, 16 tall)."""
        ch = max(16, H.height, post.height if post else 0)
        pieces = {}
        for nb in range(16):
            c = Image.new("RGBA", (16, ch), (0, 0, 0, 0))
            w, e, n, s = nb & 1, nb & 2, nb & 4, nb & 8
            vx = (16 - V.width) // 2
            if n and s:
                c.alpha_composite(V, (vx, ch - 16))
            elif n:
                c.alpha_composite(V.crop((0, 0, V.width, 10)), (vx, ch - 16))
            elif s:
                c.alpha_composite(V.crop((0, 6, V.width, 16)), (vx, ch - 10))
            hy = ch - H.height
            if w:
                c.alpha_composite(H.crop((0, 0, 8, H.height)), (0, hy))
            if e:
                c.alpha_composite(H.crop((8, 0, 16, H.height)), (8, hy))
            if post is not None:
                c.alpha_composite(post, ((16 - post.width) // 2, ch - post.height))
            elif not (w or e or n or s):
                c.alpha_composite(H, (0, hy))
            elif (n or s) and not (w or e):
                pass
            pieces[nb] = c
        return pieces

    def full16(im):
        """Stretch a short vertical run to a full tile by repeating its middle (keeps it seamless top to bottom)."""
        if im.height >= 16:
            return im.crop((0, im.height - 16, im.width, im.height))
        out = Image.new("RGBA", (im.width, 16), (0, 0, 0, 0))
        mid = im.crop((0, im.height // 2, im.width, im.height // 2 + 1))
        for yy in range(16):
            out.alpha_composite(mid, (0, yy))
        return out

    T = lambda x, y: sheet_tile(TERR, x, y)
    TN = lambda x, y: sheet_tile(TERR, x, y, trim=False)
    fence_v = full16(T(22, 71))
    JOIN = {
        "fence": (TN(23, 70).crop(TN(23, 70).getbbox()), fence_v, T(22, 71).crop((0, 0, T(22, 71).width, min(T(22, 71).height, TN(23, 70).getbbox()[3] - TN(23, 70).getbbox()[1])))),
        "electric_fence": (TN(23, 60).crop(TN(23, 60).getbbox()), full16(T(22, 61)), None),
        "stone_wall": (TN(9, 16).crop(TN(9, 16).getbbox()), full16(T(8, 17)), None),
        "sandbag_wall": (me("Sandbag_Horizontal_Single"), full16(me("Sandbag_Vertical_Single")), None),
        "barbed_fence": (me("Barbed_Wire_1_Horizontal"), full16(me("Barbed_Wire_1_Vertical")), None),
        "rail_fence": (me("Dormitory_Fence_1_Horizontal_1"), full16(me("Dormitory_Fence_1_Left_1")), None),
    }
    for oid, (H, V, P) in JOIN.items():
        if H.width != 16:
            # pieces narrower or wider than a tile: take a 16 wide slice from the middle, or centre it
            if H.width > 16:
                H = H.crop(((H.width - 16) // 2, 0, (H.width - 16) // 2 + 16, H.height))
            else:
                c = Image.new("RGBA", (16, H.height), (0, 0, 0, 0)); c.alpha_composite(H, ((16 - H.width) // 2, 0)); H = c
        for nb, im in joined(H, V, P).items():
            save(im, "objects/%s_c%d.png" % (oid, nb))
    print("objects:", len(OBJ) + 4, "joined:", len(JOIN))
    # garden tools: shovels and rake as weapons, the watering can as the basic tool; axe, pick and hoe from the sword pack
    for iid, nm, tint in [("shovel", "Ground_Brown_Shovel_Right", None), ("grave_digger", "Ground_Red_Shovel_Right", "#3a3438"),
                          ("garden_rake", "Ground_Red_Rake_Right", None), ("watering_can", "Grey_Watering_Can_Full_Right", None)]:
        im = me(nm)
        if tint:
            im = hue_set(im, tint, lambda p: sum(p[:3]) > 120 and (max(p[:3]) - min(p[:3])) > 40)
        if (im.width > 16 or im.height > 16) and "PI" in globals():
            k = min(16 / im.width, 16 / im.height)
            im = PI.shrink(im, max(1, round(im.width * k)), max(1, round(im.height * k)), cover=0.3, reoutline=False)
        icon(im, iid)
    if "PI" in globals():
        for iid, si in [("axe", 107), ("pickaxe", 146), ("hoe", 135)]:
            save(PI.icon16(sword(si), -45), "icons/%s.png" % iid)

    # ground tiles
    for v, (x, y) in enumerate([(25, 5), (26, 5), (28, 5), (29, 5)]):
        save(sheet_tile(TERR, x, y, trim=False), "tiles/water_%d.png" % v)
    for v, (x, y) in enumerate([(25, 9), (26, 9), (25, 9), (26, 9)]):
        save(sheet_tile(TERR, x, y, trim=False), "tiles/pave_%d.png" % v)
    for v, (x, y) in enumerate([(17, 56), (18, 56), (19, 56), (20, 56)]):
        save(sheet_tile(TERR, x, y, trim=False), "tiles/sand_%d.png" % v)
    print("tiles: water, pave, sand")


# ---------------------------------------------------------------- icons for placeable things, from their new world pictures
# tools/place_map.json (item id -> object it places) is exported from the game's Data.
PLACE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "place_map.json")
if os.path.isfile(PLACE) and "PI" in globals():
    n = 0
    for iid, oid in json.load(open(PLACE)).items():
        if os.path.exists(os.path.join(OUT, "icons", iid + ".png")):
            continue
        src = None
        for nm in ["objects/%s.png" % oid, "objects/%s_c3.png" % oid, "objects/%s_0.png" % oid]:
            if os.path.exists(os.path.join(OUT, nm)):
                src = Image.open(os.path.join(OUT, nm)).convert("RGBA")
                break
        if src is None:
            continue
        src = src.crop(src.getbbox())
        if src.width > 16 or src.height > 16:
            k = min(16 / src.width, 16 / src.height)
            src = PI.shrink(src, max(1, round(src.width * k)), max(1, round(src.height * k)), cover=0.3, reoutline=False)
        icon(src, iid)
        n += 1
    print("placeable icons:", n)


# ---------------------------------------------------------------- gear: hats from the character generator, clothes drawn, shoes from the props pack
GEN32 = os.path.join(SRC, "moderninteriors-win", "2_Characters", "Character_Generator")
ADD32 = os.path.join(SRC, "modernexteriors-win", "Modern_Exteriors_32x32", "Character_Generator_Addons_32x32")
if os.path.isdir(GEN32) and "PI" in globals():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gear_icons as GI

    def gen_front(rel, top_rows=None):
        """The facing-front still frame of a 32x32 generator layer, trimmed (top_rows: keep only the top part)."""
        hits = sorted(_glob.glob(os.path.join(GEN32, "Accessories", "32x32", rel))) or sorted(_glob.glob(os.path.join(ADD32, "**", rel), recursive=True))
        im = Image.open(hits[0]).convert("RGBA").crop((96, 0, 128, 64))
        if top_rows:
            im = im.crop((0, 0, 32, top_rows))
        return im.crop(im.getbbox())

    def fit16(im):
        if im.width > 16 or im.height > 16:
            k = min(16 / im.width, 16 / im.height)
            im = PI.shrink(im, max(1, round(im.width * k)), max(1, round(im.height * k)), cover=0.3, reoutline=False)
        return im

    tint_all = lambda im, col: hue_set(im, col, lambda p: sum(p[:3]) > 110)
    HATS = {
        "baseball_cap": ("Accessory_04_Snapback_32x32_01.png", None), "beanie": ("Accessory_11_Beanie_32x32_01.png", None),
        "bandana_mask": ("Accessory_07_Bataclava_32x32_03.png", "#a83a2a"), "bike_helmet": ("Accessory_20_Worker_Helmet_32x32.png", "#3a8ad8"),
        "vented_bike_helmet": ("Accessory_20_Worker_Helmet_32x32.png", "#3ac8b8"), "gas_mask": ("Accessory_07_Bataclava_32x32_03.png", None),
        "filtered_gas_mask": ("Accessory_07_Bataclava_32x32_03.png", "#5a6a4a"), "hard_hat": ("Accessory_20_Worker_Helmet_32x32.png", None),
        "padded_hard_hat": ("Accessory_20_Worker_Helmet_32x32.png", "#e8782a"), "football_helmet": ("Accessory_27_Soldier_Helmet_32x32.png", "#8a2a2a"),
        "motorcycle_helmet": ("Accessory_07_Bataclava_32x32_01.png", None), "tinted_motorcycle_helmet": ("Accessory_07_Bataclava_32x32_02.png", None),
        "riot_helmet": ("Accessory_27_Soldier_Helmet_32x32.png", "#2a3040"), "reinforced_riot_helmet": ("Accessory_27_Soldier_Helmet_32x32.png", "#1a1e28"),
        "military_helmet": ("Accessory_27_Soldier_Helmet_32x32.png", None), "scouts_boonie_hat": ("Accessory_22_Scout_Snapback_32x32.png", None),
        "night_owl_helmet": ("Accessory_27_Soldier_Helmet_32x32.png", "#2a3428"), "the_lighthouse": ("Accessory_20_Worker_Helmet_32x32.png", "#b8903a"),
        "cowboy_hat": ("Accessory_08_Detective_Hat_32x32_01.png", None), "traffic_cone": ("Accessory_19_Party_Cone_32x32_01.png", "#e8782a"),
        "tinfoil_hat": ("Accessory_19_Party_Cone_32x32_01.png", "#c8ccd4"), "chefs_hat": ("Accessory_18_Chef_32x32_01.png", None),
    }
    n = 0
    for iid, (f, tint) in HATS.items():
        im = gen_front(f, 40)
        if tint:
            im = tint_all(im, tint)
        icon(fit16(im), iid)
        n += 1
    fh = gen_front("Outfit_Firefighter_32x32.png", 40)
    icon(fit16(fh), "firefighters_helmet")
    for iid in GI.TOPS:
        save(GI.make_top(iid), "icons/%s.png" % iid)
    for iid in GI.BOTTOMS:
        save(GI.make_bottom(iid), "icons/%s.png" % iid)
    n += 1 + len(GI.TOPS) + len(GI.BOTTOMS)
    # shoes and boots: the props pack's four, recoloured
    if os.path.isdir(PROPS):
        SHOES = {"flip_flops": (4, "#3aa8c8"), "slippers": (4, "#8a6a9a"), "sneakers": (4, None), "running_shoes": (4, "#3a8ad8"),
                 "rain_boots": (1, "#e8c83a"), "cowboy_boots": (2, "#8a5a30"), "felt_soled_sneakers": (4, "#6a5a4a"),
                 "cushioned_running_shoes": (4, "#3ac888"), "ghost_steps": (3, "#3a3a44"), "marathon_racers": (4, "#d84a3a"),
                 "stompers": (3, "#2a2420"), "starting_gun": (4, "#e8b83a"), "firewalkers": (3, "#241c1c"), "bunny_slippers": (4, "#f0d8e0"),
                 "clown_shoes": (4, "#d83a3a"), "dress_shoes": (4, "#1e1e22"), "light_up_sneakers": (4, "#e870c8"), "gold_sneakers": (4, "#e8c040")}
        for iid, (num, tint) in SHOES.items():
            im = prop("misc", num)
            if tint:
                im = hue_set(im, tint, lambda p: sum(p[:3]) > 110 and (max(p[:3]) - min(p[:3])) > 12)
            icon(mute(im, 0.22), iid)
            n += 1
    print("gear icons:", n)


# ---------------------------------------------------------------- kitbashed icons: food, materials, ores and finds
# Pieces taken from the packs above and recoloured to fit: Modern Interiors kitchen, grocery, hospital and
# Halloween props, Kyrise's gems and odds, Sunnyside's ore nuggets and mushrooms, the food and props packs.
# Each entry: id -> (source, recolour). Sources: "ky:<name>", "food:<name>", "prop:<folder>:<n>", "mi:<theme>:<n>",
# "ore:<kind>", "shroom:<kind>", "pa:<name>", "sun:<name>", "hd:<n>". Recolours: ("ramp", dark, light) maps
# brightness onto a ramp (keeps outlines); ("hue", colour) recolours the coloured parts; ("all", colour)
# recolours everything but the outline.
SUNG = os.path.join(SRC, "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_Gamemaker", "sprites")
SUNE = os.path.join(SRC, "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_Assets", "Elements")
MIS = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Singles")
MI_THEME = {"kit": ("12_Kitchen_Singles", "Kitchen_Singles"), "gro": ("16_Grocery_Store_Singles", "Grocery_Store_Singles"),
            "hos": ("19_Hospital_SIngles", "Hospital_Singles"), "hal": ("11_Halloween_Singles", "Halloween_Singles"),
            "bas": ("14_Basement_Singles", "Basement_Singles"),
            "clo": ("21_Clothing_Store_Singles", "Clothing_Store_Singles")}
KIT = {
    # ores, stone and minerals
    "gold_ore": ("ore:gold", None), "silver_ore": ("ore:silver", None), "aurium_ore": ("ore:bluestone", None),
    "copper_ore": ("ore:gold", ("ramp", "#5a2410", "#f0a070")), "iron_ore": ("ore:stone", ("ramp", "#3a2620", "#c8987c")),
    "lead_ore": ("ore:silver", ("ramp", "#22242e", "#8a90a4")), "tin_ore": ("ore:silver", ("ramp", "#4a5050", "#e8eeee")),
    "zinc_ore": ("ore:silver", ("ramp", "#2a3a44", "#b8d4dc")),
    "coal": ("ore:coal", None), "stone": ("ore:stone", None), "gravel": ("pa:Icon_Rock", None),
    "clay": ("ore:stone", ("ramp", "#5a2a18", "#d88a5a")), "sulfur": ("ore:stone", ("ramp", "#5a5010", "#f0e060")),
    "salt": ("ore:stone", ("ramp", "#8a8c96", "#ffffff")),
    "amber": ("ky:shard_01g", ("ramp", "#6a3008", "#f8c050")), "calcite": ("ky:gem_01e", ("ramp", "#8a6a5a", "#fff0e0")),
    "fluorite": ("ky:shard_01j", ("ramp", "#2a4a6a", "#b8f0e8")), "jasper": ("ky:shard_01d", ("ramp", "#5a1a10", "#e07050")),
    "malachite": ("ky:shard_01a", ("ramp", "#0a3a20", "#60d090")), "mica": ("ky:shard_01h", None),
    "obsidian": ("ky:shard_01i", ("ramp", "#0e0c14", "#6a6080")), "pyrite": ("ky:gem_01b", ("ramp", "#5a4a10", "#e8d888")),
    "marble": ("ky:stoneblock_01a", ("ramp", "#8a8c94", "#ffffff")), "limestone": ("ky:stoneblock_01a", ("ramp", "#7a6a50", "#efe4c8")),
    "brick": ("ky:stoneblock_01a", ("ramp", "#5a2018", "#d8704a")), "cement": ("ky:stoneblock_01a", ("ramp", "#5a5c60", "#c8ccd0")),
    "petrified_wood": ("ky:wood_01a", ("ramp", "#3a3434", "#b8b0a4")), "hardwood": ("ky:wood_01a", ("ramp", "#2a160c", "#a06438")),
    "bamboo": ("ky:wood_01a", ("ramp", "#3a4a10", "#d8e080")), "wooden_pole": ("ky:staff_01a", ("ramp", "#3a2414", "#c89060")),
    "fiber": ("ky:cotton_01a", ("ramp", "#2a4a18", "#b8d888")), "glass_shards": ("ky:shard_01c", ("ramp", "#3a6a7a", "#e8faff")),
    "resin": ("ky:coin_01a", ("ramp", "#5a2a04", "#e8a030")), "sap": ("ky:coin_01a", ("ramp", "#7a4a08", "#f8d060")),
    # geodes
    "geode": ("ky:pearl_01a", None), "frost_geode": ("ky:pearl_01a", ("ramp", "#2a3a5a", "#d0ecff")),
    "ember_geode": ("ky:pearl_01a", ("ramp", "#4a1a0a", "#f08050")), "deep_geode": ("ky:pearl_01a", ("ramp", "#1e1430", "#8a70b0")),
    "crystal_geode": ("ky:pearl_01a", ("ramp", "#3a3050", "#e0d0ff")), "fossil_nodule": ("ky:pearl_01a", ("ramp", "#4a3a24", "#d8c8a0")),
    # finds and keepsakes
    "old_coin": ("ky:coin_01d", None), "rusted_key": ("ky:key_02a", ("ramp", "#3a1a0a", "#c06a30")),
    "wedding_ring": ("ky:ring_01d", None), "war_medal": ("ky:necklace_03d", None), "dog_tags": ("ky:necklace_01b", None),
    "arrowhead": ("ky:gem_01i", ("ramp", "#2a2a2e", "#a8a8b0")), "charred_bone": ("ky:bone01a", ("ramp", "#140e0c", "#5a4a40")),
    "diary_page": ("ky:scroll_01h", None), "letter": ("ky:scroll_01b", None), "sheriff_page": ("ky:scroll_01a", None),
    "smith_notes": ("ky:scroll_01c", None), "halvorsen_notes": ("ky:scroll_01d", None), "conspiracy_note": ("ky:scroll_01f", None),
    "journal_half": ("ky:scroll_01e", None), "journal_half_a": ("ky:scroll_01g", None), "journal_half_b": ("ky:scroll_01g", ("hue", "#3a6a8a")),
    "soggy_paper": ("ky:scroll_01h", ("ramp", "#3a3a34", "#a8a890")),
    "lab_keycard": ("mi:hos:51", None),
    # medicine, samples and zombie parts
    "adrenaline_shot": ("mi:hos:529", None), "antiviral": ("mi:hos:530", None), "ammo_serum": ("mi:hos:531", None),
    "serum_sample": ("ky:potion_02c", None), "infected_sample": ("ky:potion_01c", None), "blood_bag": ("ky:potion_03a", None),
    "burn_salve": ("prop:jar:10", ("hue", "#7ac08a")), "sterile_bandage": ("pa:Icon_Bandage", ("all", "#e8eef4")),
    "screamer_sac": ("mi:hal:210", None), "rotten_flesh": ("mi:hal:209", ("ramp", "#2a2a18", "#a0a070")),
    "stalker_eye": ("ky:pearl_01e", None),
    # drinks, fuels and jars
    "water_bottle": ("prop:jar:31", None), "dirty_water": ("prop:jar:34", ("hue", "#7a6a40")),
    "lamp_oil": ("prop:jar:33", ("hue", "#d89830")), "biofuel": ("prop:jar:32", ("hue", "#9ac030")),
    "mayonnaise": ("prop:jar:13", ("hue", "#e8e0c0")), "aged_roe": ("prop:jar:11", ("hue", "#e86a2a")),
    "powdered_milk": ("prop:jar:14", ("hue", "#e8ecf0")), "ale": ("ky:cup_02a", ("hue", "#d8902a")),
    "energy_drink": ("food:soda_sprite", None), "flare": ("ky:candle_01b", ("hue", "#d83a2a")),
    "incendiary_shell": ("gun:ShotgunShellBig", ("hue", "#e8602a")), "ball_bearings": ("ky:coin_02c", None),
    # cooked dishes: plates, trays and bowls
    "apple_crumble": ("mi:gro:386", None), "pumpkin_pie": ("mi:gro:386", ("hue", "#e07a2a")), "berry_cobbler": ("mi:gro:386", ("hue", "#8a2a5a")),
    "tomato_soup": ("prop:jar:49", ("hue", "#d83a2a")), "beet_borscht": ("prop:jar:49", ("hue", "#a01a4a")),
    "onion_soup": ("prop:jar:49", ("hue", "#c08a3a")), "ashgrain_porridge": ("prop:jar:49", ("hue", "#d8c8a0")),
    "fishermans_stew": ("prop:jar:48", ("hue", "#c8a060")), "crayfish_boil": ("prop:jar:48", ("hue", "#d8502a")), "ember_chili": ("mi:kit:385", None),
    "baked_potato": ("mi:kit:400", None), "breakfast_skillet": ("mi:kit:387", None), "skillet_hash": ("mi:kit:386", None),
    "morel_skillet": ("mi:kit:388", ("hue", "#8a5a3a")), "snowpea_stirfry": ("mi:kit:389", None), "stuffed_peppers": ("mi:kit:390", None),
    "fish_tacos": ("mi:kit:384", None), "survivor_plate": ("mi:kit:401", None), "deviled_eggs": ("food:eggs_softboiled", None),
    "garden_omelette": ("food:eggs_scrambled", None), "pb_toast": ("food:pastry_brioche", None), "mushroom_toast": ("mi:kit:214", None),
    "cabbage_rolls": ("mi:gro:211", ("hue", "#7aa04a")), "chestnut_stuffing": ("mi:gro:213", None), "honey_cornbread": ("mi:gro:217", None),
    "potato_gratin": ("mi:gro:215", None), "ratatouille": ("mi:gro:219", None), "trail_bar": ("mi:gro:210", None),
    "field_rations": ("mi:gro:117", None), "forager_salad": ("mi:gro:122", None), "radish_slaw": ("mi:gro:120", None),
    "harvest_feast": ("mi:gro:136", None), "instant_noodles": ("mi:gro:242", None), "mre": ("mi:gro:117", ("hue", "#6a7a3a")),
    "venison_steak": ("mi:gro:304", None), "boar_roast": ("mi:gro:303", None), "salmon_bake": ("mi:gro:279", ("hue", "#e88a5a")),
    "roast_poultry": ("mi:gro:283", ("hue", "#c8803a")), "glazed_carrots": ("mi:kit:213", None),
    "roast_corn": ("food:vegetable_corn", ("ramp", "#4a2a08", "#f0c860")), "squash_bake": ("mi:gro:388", ("hue", "#e0902a")),
    "fried_fish": ("hd:25", ("ramp", "#4a2408", "#e8b060")), "smoked_fish": ("hd:25", ("ramp", "#1e1008", "#9a6a3a")),
    # meat, eggs, milk and animal goods
    "venison": ("mi:kit:215", None), "boar_meat": ("mi:gro:278", None), "rabbit_meat": ("mi:gro:282", None), "poultry": ("mi:gro:283", None),
    "animal_fat": ("mi:gro:282", ("ramp", "#6a5a40", "#fff4dc")), "jerky": ("mi:gro:280", ("ramp", "#2a1008", "#a05a30")),
    "smoked_meat": ("mi:gro:278", ("ramp", "#2a140a", "#b07048")),
    "duck_egg": ("sun:egg", ("ramp", "#4a5a50", "#e8f4e8")), "quail_egg": ("sun:egg", ("ramp", "#5a4a3a", "#f4ead8")),
    "golden_egg": ("sun:egg", ("ramp", "#6a4a08", "#ffe070")), "goat_milk": ("sun:milk", None), "large_milk": ("food:coffee_milkjug", ("hue", "#e8d8a0")),
    "butter": ("mi:gro:384", ("hue", "#f0e080")), "beeswax": ("mi:gro:385", ("hue", "#d8a030")),
    "truffle": ("ky:shard_01h", ("ramp", "#140c08", "#6a5040")),
    # forage and crops
    "glowcap": ("shroom:blue_01", None), "field_mushroom": ("shroom:red_01", ("all", "#e8dcc8")), "chanterelle": ("shroom:red_01", ("all", "#e8a030")),
    "morel": ("shroom:red_01", ("all", "#8a6040")), "puffball": ("shroom:blue_03", ("all", "#f0ece0")),
    "dried_mushrooms": ("shroom:red_01", ("all", "#6a4a30")),
    "holly_berry": ("ky:flower_01a", None), "dandelion": ("ky:flower_02a", None),
    "rose_hip": ("prop:food:6", ("hue", "#d0402a")), "sunberry": ("prop:food:6", ("hue", "#f0b030")),
    "wild_ginseng": ("food:vegetable_ginger", None), "winter_root": ("food:vegetable_ginger", ("ramp", "#4a4a5a", "#e8e4f0")),
    "wild_leek": ("prop:food:14", ("hue", "#d8e0b0")), "frost_lichen": ("ky:leaf_01a", ("ramp", "#3a4a5a", "#d0e8f0")),
    "willow_bark": ("ky:wood_01a", ("ramp", "#2a2a1a", "#8a8a60")), "dried_fruit": ("prop:food:11", ("hue", "#8a4a2a")),
    "bogberry": ("food:fruit_blueberry", ("hue", "#5a3a6a")), "strawbloom": ("food:fruit_strawberry", None),
    "zucchini": ("food:vegetable_cucumber", ("ramp", "#0e2a0e", "#6aa04a")),
    # packaged food and junk
    "hardtack": ("ky:cookie_01a", ("ramp", "#5a4a30", "#f0e0b8")), "moldy_bread": ("food:pastry_bread", ("ramp", "#2a3a20", "#a8b880")),
    "rotten_food": ("food:fruit_apple", ("ramp", "#2a2010", "#8a7a40")), "wet_cardboard": ("mi:hos:53", ("ramp", "#2a2014", "#8a7050")),
    # cloth, hides and straps (Modern Interiors clothing store: folded fabric, pelts, belts)
    "cloth": ("mi:clo:157", None), "linen": ("mi:clo:158", None), "cotton_cloth": ("mi:clo:159", ("ramp", "#6a6a64", "#fbf8ee")),
    "wool_cloth": ("mi:clo:157", ("ramp", "#4a2a20", "#d0907a")), "rag": ("mi:clo:159", ("ramp", "#3a3428", "#a89a7a")),
    "leather": ("mi:clo:158", ("ramp", "#2a1408", "#a8683a")),
    "deer_hide": ("mi:clo:343", None), "tanned_pelt": ("mi:clo:344", None), "boar_hide": ("mi:clo:345", None),
    "rabbit_fur": ("mi:clo:346", None), "wool": ("mi:clo:346", ("ramp", "#8a8a84", "#fafaf4")),
    "brute_hide": ("mi:clo:348", ("ramp", "#1e2a1e", "#7a8a6a")),
    "leather_strap": ("mi:clo:50", ("ramp", "#3a1e0e", "#b07040")), "leather_grip": ("mi:clo:49", ("ramp", "#1e1008", "#6a4028")),
    # kits in small chests, jars of powder, glass and stones
    "blade_kit": ("prop:chest:1", None), "ranged_kit": ("prop:chest:2", None), "sewing_kit": ("prop:chest:3", None),
    "gear_kit": ("prop:chest:4", None), "blunt_kit": ("prop:chest:5", ("hue", "#8a5a30")), "gun_kit": ("prop:chest:6", ("hue", "#5a6a3a")),
    "shell_press": ("prop:chest:5", ("hue", "#5a5a64")),
    "gunpowder": ("prop:jar:7", ("hue", "#3a3a3e")), "saltpeter": ("prop:jar:15", ("hue", "#e8e8e0")),
    "glass_bottle": ("prop:jar:2", ("all", "#a8d8c8")), "glass": ("ky:stoneblock_01a", ("ramp", "#4a7a8a", "#e8faff")),
    "magnesium": ("ky:ingot_01c", ("ramp", "#5a5a64", "#f4f4fa")), "whetstone": ("ky:stoneblock_01a", ("ramp", "#22283a", "#8a96b0")),
    "bolt_schematic": ("ky:scroll_01c", ("ramp", "#0e2a5a", "#90c0f0")), "spitter_gland": ("mi:hal:209", ("ramp", "#2a3a08", "#d8f050")),
}


def kit_src(spec):
    kind, _, rest = spec.partition(":")
    if kind == "ky":
        return load(os.path.join(KY, rest + ".png")), 0.12
    if kind == "food":
        return load(os.path.join(FOOD, rest + ".png")), 0.0
    if kind == "prop":
        f, n = rest.split(":")
        D2 = {"chest": "3-CHESTS and LOCKS", "food": "4-FOOD", "jar": "5-BOTTLES CANS JARS KETTLES VASES", "misc": "6-MISCELLANEOUS"}
        return load(os.path.join(PROPS, D2[f], n + ".png")), 0.22
    if kind == "mi":
        t, n = rest.split(":")
        d, stem = MI_THEME[t]
        return load(os.path.join(MIS, d, "%s_%s.png" % (stem, n))), 0.18
    if kind == "ore":
        d = os.path.join(SUNG, "spr_deco_ore_" + rest)
        return load(os.path.join(d, [f for f in os.listdir(d) if f.endswith(".png")][0])), 0.1
    if kind == "shroom":
        im = Image.open(os.path.join(SUNE, "Plants", "spr_deco_mushroom_%s_strip4.png" % rest)).convert("RGBA")
        im = im.crop((0, 0, im.width // 4, im.height))
        return im.crop(im.getbbox()), 0.1
    if kind == "sun":
        return load(os.path.join(SUNE, "Crops", rest + ".png")), 0.1
    if kind == "pa":
        return load(os.path.join(INV, rest + ".png")), 0.0
    if kind == "gun":
        return load(os.path.join(SRC, "GunsPack", "GunsPack", "Bullets", rest + ".png")), 0.0
    if kind == "hd":
        return load(os.path.join(HD, "fishing_icons_16x16_%s.png" % rest)), 0.0
    raise SystemExit("unknown source " + spec)


def kit_recolour(im, op):
    if op is None:
        return im
    if op[0] == "ramp":
        return ramp_tint(im, op[1], op[2])
    coloured = lambda p: sum(p[:3]) > 110 and (max(p[:3]) - min(p[:3])) > 22
    if op[0] == "hue":
        return hue_set(im, op[1], coloured)
    if op[0] == "all":
        return hue_set(im, op[1], lambda p: sum(p[:3]) > 110)
    raise SystemExit("unknown recolour %r" % (op,))


if os.path.isdir(MIS) and os.path.isdir(KY) and "PI" in globals():
    n = 0
    for iid, (spec, op) in KIT.items():
        im, m = kit_src(spec)
        im = kit_recolour(im, op)
        if im.width > 16 or im.height > 16:
            k = 16 / max(im.width, im.height)
            im = PI.shrink(im, max(1, round(im.width * k)), max(1, round(im.height * k)))
        icon(mute(im, m) if m else im, iid)
        n += 1
    print("kitbashed icons:", n)


# ---------------------------------------------------------------- car and bus wrecks at people scale (Modern Exteriors vehicles)
# The PostApocalypse wrecks are drawn for its tiny characters; these match the 16x32 people. Paint fades to
# a wreck colour with rust speckles, glass goes dark, and some get soot from a fire.
VEH = os.path.join(MEROOT, "10_Vehicles_Singles_16x16", "ME_Singles_Vehicles_16x16_")
if os.path.isfile(VEH + "Car_Right_1.png"):
    import colorsys, random

    def wreck(im, paint, seed, burn=0.0, speck=0.10):
        r = random.Random(seed)
        out = im.copy()
        px = out.load()
        pr, pg, pb = hexrgb(paint)
        pl = max(1, 0.3 * pr + 0.59 * pg + 0.11 * pb)
        for y in range(out.height):
            for x in range(out.width):
                R, G, B, A = px[x, y]
                if not A:
                    continue
                h, s_, v = colorsys.rgb_to_hsv(R / 255, G / 255, B / 255)
                if B > R + 25 and v > 0.55 and s_ < 0.6:          # glass: dark and cracked
                    k = 0.7 + 0.3 * r.random()
                    px[x, y] = (int(46 * k), int(54 * k), int(62 * k), A)
                elif s_ > 0.25 and v > 0.25:                     # paint: faded to the wreck colour
                    l = min(1.25, (0.3 * R + 0.59 * G + 0.11 * B) / pl)
                    c = [min(255, int(ch * l * 0.92)) for ch in (pr, pg, pb)]
                    if r.random() < speck:
                        c = [int(c[0] * 0.75 + 30), int(c[1] * 0.55 + 12), int(c[2] * 0.4)]
                    px[x, y] = tuple(c) + (A,)
                else:                                              # trim, tyres, chrome: dull grey
                    g = int((0.3 * R + 0.59 * G + 0.11 * B) * 0.9)
                    px[x, y] = (g, int(g * 0.97), int(g * 0.93), A)
                if burn and r.random() < burn * (0.4 + 0.6 * y / out.height):
                    R, G, B, A = px[x, y]
                    px[x, y] = (int(R * 0.35), int(G * 0.32), int(B * 0.3), A)
        return out
    veh = lambda n: load(VEH + n + ".png")
    for v, (n, c, b) in enumerate([("Car_Right_1", "#7a3a30", 0), ("Car_Left_2", "#4a5a6a", 0.25),
                                    ("Car_Right_3", "#6a6a4a", 0), ("Car_Left_4", "#5a4a40", 0.5)]):
        save(wreck(veh(n), c, v + 1, b), "objects/car_wreck_%d.png" % v)
    for v, (n, c, b) in enumerate([("Bus_Right_1", "#b8902a", 0.15), ("Bus_Left_1", "#b8902a", 0.3),
                                    ("Bus_Right_1", "#4a6a8a", 0.1), ("Bus_Left_1", "#6a7a4a", 0.2)]):
        save(wreck(veh(n), c, v + 11, b, 0.03), "objects/bus_wreck_%d.png" % v)
    print("wrecks: 8")


# ---------------------------------------------------------------- roads and dirt with detail and edges
# Roads: Modern Exteriors cracked asphalt, with a concrete curb drawn where a road meets pavement or grass
# (tiles/road_edge_<side>.png). Dirt: Pixel Crawler's lumpy dirt, toned down, with a ragged fringe of grass
# drawn over it where it meets grass (tiles/dirt_edge_<season>_<side>.png). Sides: n, s, e, w.
CITY = os.path.join(MEROOT, "2_City_Terrains_16x16.png")
PCF = os.path.join(SRC, "Pixel_Crawler_-_Free_Pack_Exterior_0.1", "Pixel Crawler - Free Pack", "Environment", "Tilesets", "Floors_Tiles.png")
if os.path.isfile(CITY) and os.path.isfile(PCF):
    import random
    city = Image.open(CITY).convert("RGBA")
    for v, (cx, cy) in enumerate([(0, 4), (1, 5), (2, 6), (3, 7)]):
        save(city.crop((cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)), "tiles/road_%d.png" % v)
    pcf = Image.open(PCF).convert("RGBA")
    for v, (x, y) in enumerate([(176, 160), (192, 160), (208, 176), (192, 176)]):
        save(tone(pcf.crop((x, y, x + 16, y + 16)), "#80603f"), "tiles/dirt_%d.png" % v)
    def rot(im, side):
        return {"n": im, "s": im.transpose(Image.ROTATE_180), "w": im.transpose(Image.ROTATE_90), "e": im.transpose(Image.ROTATE_270)}[side]
    # curb: drawn for the north side, turned for the others
    curb = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in range(16):
        curb.putpixel((x, 0), (206, 198, 190, 255))
        curb.putpixel((x, 1), (170, 160, 156, 255))
        curb.putpixel((x, 2), (60, 54, 62, 150))
    for side in "nsew":
        save(rot(curb, side), "tiles/road_edge_%s.png" % side)
    for season in ["spring", "summer", "autumn"]:
        g = Image.open(os.path.join(OUT, "tiles", "grass_%s_0.png" % season)).convert("RGBA")
        r = random.Random(season)
        fr = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        depth = [2 + r.randint(0, 2) for _ in range(16)]
        for x in range(1, 15):
            if r.random() < 0.3:
                depth[x] = max(depth[x], depth[x - 1] + 1)
        for x in range(16):
            for y in range(depth[x]):
                fr.putpixel((x, y), g.getpixel((x, y)))
            fr.putpixel((x, depth[x]), (40, 30, 20, 110))      # a soft shadow under the grass lip
        for side in "nsew":
            save(rot(fr, side), "tiles/dirt_edge_%s_%s.png" % (season, side))
    # tilled soil: a mound (Sunnyside World's shape) on dark dirt; watered is darker
    SOIL = os.path.join(SUNE, "Crops", "soil_00.png")
    for name, base, mound, bx in [("dry", "#5e4128", "#8a6040", 176), ("wet", "#3c2a1a", "#5a3e28", 192)]:
        t = tone(pcf.crop((bx, 160, bx + 16, 176)), base)
        t.alpha_composite(tone(Image.open(SOIL).convert("RGBA"), mound), (0, 2))
        save(t, "tiles/soil_%s.png" % name)
    # sand: the Terrains sheet's is orange; a paler, duller sand reads better next to the grass
    for f in sorted(os.listdir(os.path.join(OUT, "tiles"))):
        if f.startswith("sand") and f.endswith(".png"):
            save(tone(Image.open(os.path.join(OUT, "tiles", f)).convert("RGBA"), "#c4ae84"), "tiles/" + f)
    print("roads and dirt: 4 + 4 tiles, edges")


# ---------------------------------------------------------------- farm animals
# Strips of walk frames in art/animals/<type>_<0|1>.png; art/animals/index.json gives each strip's frame
# size, frame count, which row faces down / up / sideways, and which way the side view faces.
# Cows: Farm RPG (four directions). Chickens: Farm RPG. Pigs, sheep, ducks: Sunnyside World. Quail: the
# Sunnyside bird, recoloured. Goats: the Farm RPG bull, recoloured and smaller. All muted a little.
FRPG = os.path.join(SRC, "Farm_RPG_FREE_16x16_-_Tiny_Asset_Pack", "Farm RPG FREE 16x16 - Tiny Asset Pack", "Farm Animals")
if os.path.isdir(FRPG) and os.path.isdir(SUNE):
    AN = {}
    def an_save(nm, im, fw, fh, n, rows, face):
        save(mute(im, 0.12), "animals/%s.png" % nm)
        AN[nm] = {"fw": fw, "fh": fh, "n": n, "rows": rows, "face": face}
    frpg = lambda f: Image.open(os.path.join(FRPG, f)).convert("RGBA")
    sun = lambda f: Image.open(os.path.join(SUNE, "Animals", f)).convert("RGBA")
    def recol(im, pick, want):
        out = im.copy()
        px = out.load()
        for y in range(out.height):
            for x in range(out.width):
                p = px[x, y]
                if p[3] and pick(p):
                    lum = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / 255
                    w = hexrgb(want)
                    k = 0.55 + 0.9 * lum
                    px[x, y] = tuple(min(255, int(c * k)) for c in w) + (p[3],)
        return out
    brownish = lambda p: p[0] > p[2] + 30 and p[0] < 220 and sum(p[:3]) > 140
    whiteish = lambda p: min(p[:3]) > 170
    side_only = {"side": 0}
    an_save("chicken_0", frpg("Chicken Blonde  Green.png").crop((0, 0, 64, 16)), 16, 16, 4, side_only, "left")
    an_save("chicken_1", frpg("Chicken Red.png").crop((0, 0, 64, 16)), 16, 16, 4, side_only, "left")
    cow = frpg("Female Cow Brown.png")
    an_save("cow_0", cow, 32, 32, 4, {"side": 0, "down": 1, "up": 2}, "left")
    an_save("cow_1", recol(cow, brownish, "#2a2a2e"), 32, 32, 4, {"side": 0, "down": 1, "up": 2}, "left")
    bull = frpg("Male Cow Brown.png")
    small = lambda im: im.resize((im.width * 3 // 4, im.height * 3 // 4), Image.NEAREST)
    an_save("goat_0", small(recol(recol(bull, brownish, "#8a8278"), whiteish, "#e8e0d0")), 24, 24, 4, {"side": 0, "down": 1, "up": 2}, "left")
    an_save("goat_1", small(recol(recol(bull, brownish, "#5a3e28"), whiteish, "#a88a64")), 24, 24, 4, {"side": 0, "down": 1, "up": 2}, "left")
    pig = sun("spr_deco_pig_01_strip4.png")
    an_save("pig_0", pig, 32, 32, 4, side_only, "left")
    an_save("pig_1", hue_set(pig, "#8a6a5a", lambda p: p[0] > p[2] + 20), 32, 32, 4, side_only, "left")
    sheep = sun("spr_deco_sheep_01_strip4.png")
    an_save("sheep_0", sheep, 32, 32, 4, side_only, "left")
    an_save("sheep_1", recol(sheep, whiteish, "#5a5458"), 32, 32, 4, side_only, "left")
    duck = sun("spr_deco_duck_01_strip4.png")
    dpx = duck.load()
    for y in range(duck.height):          # the strip shows it swimming: drop the water line
        for x in range(duck.width):
            p = dpx[x, y]
            if p[3] and p[2] > p[0] + 40 and p[1] > p[0] + 20:
                dpx[x, y] = (0, 0, 0, 0)
    an_save("duck_0", recol(duck, lambda p: p[0] > 180 and p[1] > 150 and p[2] < 140, "#f0ece0"), 16, 16, 4, side_only, "left")
    an_save("duck_1", recol(duck, lambda p: p[0] > 180 and p[1] > 150, "#9a7a50"), 16, 16, 4, side_only, "left")
    bird = sun("spr_deco_bird_01_strip4.png")
    an_save("quail_0", recol(bird, lambda p: sum(p[:3]) > 300, "#a88a62"), 16, 16, 4, side_only, "left")
    an_save("quail_1", recol(bird, lambda p: sum(p[:3]) > 300, "#6a5a44"), 16, 16, 4, side_only, "left")
    os.makedirs(os.path.join(OUT, "animals"), exist_ok=True)
    json.dump(AN, open(os.path.join(OUT, "animals", "index.json"), "w"), indent=1)
    print("animals:", len(AN))


# ---------------------------------------------------------------- the mine: cave walls, floors and rocks
# Walls: Pixel Crawler's rock (brown in the upper mine, grey further down): a rough rock top, and a cobbled
# rock face where a wall has floor below it (tiles/<wall>_face_<v>.png). Floors: the lumpy dirt, darker.
# Rocks: Sunnyside World's small mine rocks: plain ones per palette, and one per ore or gem with its
# flecks or crystals recoloured (objects/ore_rock_<id>.png).
PCW = os.path.join(SRC, "Pixel_Crawler_-_Free_Pack_Exterior_0.1", "Pixel Crawler - Free Pack", "Environment", "Tilesets", "Wall_Tiles.png")
SUNTS = os.path.join(SRC, "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_ASSET_PACK_V2.1", "Sunnyside_World_Assets", "Tileset", "spr_tileset_sunnysideworld_16px.png")
if os.path.isfile(PCW) and os.path.isfile(SUNTS) and os.path.isfile(PCF):
    pcw = Image.open(PCW).convert("RGBA")
    cell = lambda x, y: pcw.crop((x, y, x + 16, y + 16))
    for wall, x0, tint_to in [("mwall", 16, "#6a4c34"), ("mwall2", 112, None)]:
        for v, (dx, dy) in enumerate([(16, 16), (32, 16), (16, 32), (32, 32)]):
            t = cell(x0 + dx, dy)
            save(tone(t, tint_to) if tint_to else t, "tiles/%s_%d.png" % (wall, v))
        for v, dx in enumerate([16, 32]):
            t = cell(x0 + dx, 96)
            save(tone(t, "#4e3624") if tint_to else t, "tiles/%s_face_%d.png" % (wall, v))
    for fl, col in [("mfloor", "#4c3a2a"), ("mfloor2", "#3c3c44")]:
        for v, (x, y) in enumerate([(176, 160), (192, 160), (208, 176), (192, 176)]):
            save(tone(pcf.crop((x, y, x + 16, y + 16)), col), "tiles/%s_%d.png" % (fl, v))
    sts = Image.open(SUNTS).convert("RGBA")
    def sun_rock(row):
        im = sts.crop((848, 336 + row * 32, 880, 368 + row * 32))
        return im.crop(im.getbbox())
    plain, silver, coal, blue, gold = sun_rock(4), sun_rock(0), sun_rock(1), sun_rock(2), sun_rock(3)
    save(mute(plain, 0.1), "objects/rock_lower_0.png")
    save(mute(tone(plain, "#7a6a5a"), 0.1), "objects/rock_upper_0.png")
    save(mute(shade(plain, 0.9), 0.1), "objects/rock_lower_1.png")
    save(mute(shade(tone(plain, "#7a6a5a"), 0.9), 0.1), "objects/rock_upper_1.png")
    def flecks(im, want, pick=None):
        """Recolour only the flecks or crystals: the pixels that differ from the plain rock."""
        out = im.copy()
        pp, op = plain.load(), out.load()
        sel = [(x, y) for y in range(out.height) for x in range(out.width)
               if op[x, y][3] and (x >= plain.width or y >= plain.height or sum(abs(op[x, y][i] - pp[x, y][i]) for i in range(3)) > 60)]
        if not sel:
            return out
        lum = lambda p: 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]
        avg = sum(lum(op[x, y]) for x, y in sel) / len(sel)
        w = hexrgb(want)
        for x, y in sel:
            k = lum(op[x, y]) / max(avg, 1)
            op[x, y] = tuple(min(255, int(c * k)) for c in w) + (op[x, y][3],)
        return out
    bright = None
    ORE = {"coal": (coal, None), "silver_ore": (silver, None), "gold_ore": (gold, None), "aurium_ore": (blue, None),
           "copper_ore": (gold, "#d8743a"), "iron_ore": (gold, "#c8907a"), "tin_ore": (silver, "#d8dcd8"),
           "zinc_ore": (silver, "#a8c4d0"), "lead_ore": (silver, "#7a8090"), "saltpeter": (silver, "#f4f0e8"),
           "quartz": (blue, "#e8f0f4"), "amethyst": (blue, "#a070e0"), "topaz": (blue, "#f0c040"), "emerald": (blue, "#40d080"),
           "ruby": (blue, "#e04050"), "sapphire": (blue, "#4070f0"), "diamond": (blue, "#f4fbff"), "jade": (blue, "#60c090"),
           "garnet": (blue, "#a02838"), "opal": (blue, "#f0c8e8"), "ember_opal": (blue, "#f0703a"), "glimmerite": (blue, "#c0f0f0")}
    for oid, (base, col) in ORE.items():
        save(mute(flecks(base, col, bright) if col else base, 0.08), "objects/ore_rock_%s.png" % oid)
    save(mute(flecks(plain.copy(), "#c8b8a0", lambda p: False), 0.1), "objects/geode_rock.png")
    g = Image.open(os.path.join(OUT, "objects", "geode_rock.png")).convert("RGBA")
    for x, y in [(5, 6), (8, 5), (10, 7)]:          # a few purple crystal glints
        if x < g.width and y < g.height and g.getpixel((x, y))[3]:
            g.putpixel((x, y), (154, 106, 208, 255))
    save(g, "objects/geode_rock.png")
    print("mine: walls, floors, %d rocks" % (len(ORE) + 5))


# ---------------------------------------------------------------- farm equipment
# Pixel Crawler's farm props: the scarecrow (and a tin one), troughs (cut down to one tile: both ends of the
# long trough), the worm bin and nest box (its small planter box), the shipping crate. Sprinklers are drawn
# here as small pixel pictures. The crab pot uses its Hollow Dolphin icon.
PCFARM = os.path.join(SRC, "Pixel_Crawler_-_Free_Pack_Exterior_0.1", "Pixel Crawler - Free Pack", "Environment", "Props", "Static", "Farm.png")
if os.path.isfile(PCFARM) and "PI" in globals():
    fm = Image.open(PCFARM).convert("RGBA")
    piece = lambda x, y, w, h: fm.crop((236 + x, y, 236 + x + w, y + h))
    def trim(im):
        return im.crop(im.getbbox())
    sc = trim(piece(8, 32, 24, 48))
    sc = PI.shrink(sc, round(sc.width * 0.72), round(sc.height * 0.72), reoutline=False)
    save(sc, "objects/scarecrow.png")
    save(hue_set(sc, "#8a9098", lambda p: (max(p[:3]) - min(p[:3])) > 20 and sum(p[:3]) > 120), "objects/tin_scarecrow.png")
    def ends(im):
        """A long trough cut down to one tile: its left and right ends side by side."""
        out = Image.new("RGBA", (16, im.height), (0, 0, 0, 0))
        out.alpha_composite(im.crop((0, 0, 8, im.height)), (0, 0))
        out.alpha_composite(im.crop((im.width - 8, 0, im.width, im.height)), (8, 0))
        return out
    empty = ends(piece(84, 0, 48, 16))
    water = empty.copy()
    wp = water.load()
    for y in range(3, 13):
        for x in range(2, 14):
            if wp[x, y][3] and sum(wp[x, y][:3]) < 120:      # the dark inside fills with water
                wp[x, y] = (58, 104, 150, 255) if (x + y) % 5 else (120, 170, 210, 255)
    save(water, "objects/water_trough.png")
    feed = ends(piece(84, 16, 48, 16))
    save(feed, "objects/feed_trough.png")
    save(feed, "objects/hay_hopper.png")
    box = trim(piece(116, 32, 16, 16))
    worms = hue_set(box, "#3e2a1c", lambda p: p[1] > 50 and abs(p[0] - p[1]) < 60 and sum(p[:3]) > 150)
    for x, y in [(5, 6), (6, 6), (10, 8), (11, 8)]:
        if worms.getpixel((x, y))[3]: worms.putpixel((x, y), (200, 120, 120, 255))
    save(worms, "objects/worm_bin.png")
    save(hue_set(box, "#c8a85a", lambda p: p[1] > 60 and abs(p[0] - p[1]) < 60 and sum(p[:3]) > 150), "objects/nest_box.png")
    save(trim(piece(68, 8, 16, 24)), "objects/shipping_box.png")
    if os.path.exists(os.path.join(OUT, "icons", "crab_pot.png")):
        save(Image.open(os.path.join(OUT, "icons", "crab_pot.png")).convert("RGBA"), "objects/crab_pot.png")
    SPR = {
        "bucket_sprinkler": ["................", "................", "................", "......oooo......", ".....oBbbBo.....",
                             "......oooo......", "....oooooooo....", "...oLLLLLLLLo...", "...oMMMMMMMMo...", "....oMMMMMMo....",
                             "....oMDMMDMo....", "....oMMMMMMo....", ".....oMMMMo.....", ".....oDDDDo.....", "......oooo......", "................"],
        "pressure_sprinkler": ["................", "................", "......oooo......", ".....oCccCo.....", "..oo.oCCCCo.oo..",
                               ".oCcooCHHCooCco.", "..ooCCCHHCCCoo..", ".....oCCCCo.....", "......oCCo......", ".......oo.......",
                               "......oMMo......", "......oMMo......", "....ooMMMMoo....", "...oDDDDDDDDo...", "....oooooooo....", "................"],
        "drip_array": ["................", "................", "................", "..oooooooooooo..", ".oLLLLLLLLLLLLo.",
                       ".oMMBMMBMMBMMMo.", ".oMMMMMMMMMMMMo.", ".oDDDDDDDDDDDDo.", "..oooooooooooo..", "...oCo.oCo.oCo..",
                       "...oCo.oCo.oCo..", "....w...w...w...", "...........w....", "....w...........", "................", "................"],
    }
    SPAL = {"o": (30, 28, 32, 255), "L": (196, 200, 206, 255), "M": (138, 144, 152, 255), "D": (88, 92, 100, 255),
            "B": (120, 170, 210, 255), "b": (70, 110, 160, 255), "C": (200, 122, 64, 255), "c": (236, 170, 110, 255),
            "H": (150, 84, 40, 255), "w": (120, 170, 210, 200)}
    for oid, rows in SPR.items():
        im = pix_icon(rows, SPAL)
        save(im.crop(im.getbbox()), "objects/%s.png" % oid)
    print("farm equipment: 14")


# ---------------------------------------------------------------- the 16x16 item pack (Daniel, Nov 16; 1,244 unnamed icons item<N>.png)
# One consistent style. Used for icons the other packs had nothing for, and in place of the weakest kitbashed
# ones (ores, stone, soups, mushrooms) so those match. id -> (item number, recolour or None).
ITEMPACK = os.path.join(SRC, "Item_Pack_16x16")
ITEM_PACK = {
 # weapons
 "crowbar": (940, None), "reinforced_crowbar": (940, ("ramp", "#1e2230", "#9aa8c0")), "pipe_wrench": (803, None),
 "lead_pipe": (930, None), "live_wire_pipe": (930, ("ramp", "#10243a", "#80c8f0")), "tire_iron": (724, None),
 "slingshot": (734, None), "ball_bearing_slingshot": (734, ("ramp", "#2a2a30", "#c8ccd4")), "firestarter_slingshot": (734, ("hue", "#d0502a")),
 "bile_sling": (734, ("hue", "#7aa030")), "wooden_boomerang": (828, None), "steel_boomerang": (828, ("ramp", "#2a2e38", "#c8d0dc")),
 "razor_boomerang": (828, ("ramp", "#3a1010", "#e07060")), "comet": (828, ("ramp", "#4a3008", "#ffe080")),
 "riot_shield": (199, None), "molotov_cocktail": (708, None), "pipe_bomb": (909, None), "police_baton": (821, ("ramp", "#101014", "#5a5a66")),
 # crafting parts
 "bell_bronze": (613, None), "feather": (1176, None), "gear_assembly": (934, None), "spring": (935, None), "magnet": (711, None),
 "copper_coil": (948, None), "metal_pipe": (930, None), "nails": (932, None), "precision_parts": (933, None), "rope": (689, None),
 "thread": (979, None), "circuit_board": (960, None), "fuse": (950, None), "car_battery": (911, None), "saw_blade": (769, None),
 "rebar": (922, ("ramp", "#3a2014", "#b07a5a")), "duct_tape": (936, None), "y_branch": (1010, None), "broken_katana_blade": (923, None),
 "copper_wire": (689, ("ramp", "#4a1e08", "#f0a060")), "rubber_tubing": (689, ("ramp", "#101010", "#5a5a5a")), "barbed_wire": (736, None),
 # finds
 "ammonite": (1116, None), "cassette_tape": (849, None), "vinyl_record": (847, None), "pocket_watch": (941, None), "radio_dial": (846, None),
 "toy_robot": (912, None), "snow_globe": (880, None), "game_cartridge": (977, None), "childs_drawing": (646, None), "evac_flyer": (642, None),
 "faded_postcard": (641, None), "mammoth_tooth": (1205, None), "zombie_tooth": (1185, None),
 # gadgets, resources, forage
 "binoculars": (732, None), "flashlight": (728, None), "builders_hammer": (710, None), "shears": (759, None), "gold_pan": (806, None),
 "lockpick_set": (778, None), "pine_cone": (621, None), "hay": (916, None), "e_scrap": (963, None), "ash": (780, None),
 "acorn": (1000, None), "hazelnut": (493, None), "chestnut": (1014, ("ramp", "#2a1408", "#a8603a")), "walnut": (493, ("ramp", "#2a1a0a", "#b08a5a")),
 "fiddlehead": (488, None), "pine_needles": (1036, ("hue", "#3a6a3a")),
 "snapbean": (363, None), "snowpea": (363, ("hue", "#9ad07a")), "soybean": (363, ("hue", "#a8a050")), "cinder_bean": (363, ("hue", "#a83a2a")),
 # sacks and supplies
 "flour": (683, None), "cornmeal": (683, ("hue", "#e0c060")), "beet_sugar": (683, ("hue", "#e8d8d0")), "rice_bag": (683, ("hue", "#e8e4d0")),
 "fertilizer": (683, ("hue", "#7a5a3a")), "quality_fertilizer": (683, ("hue", "#5a7a3a")), "tree_fertilizer": (683, ("hue", "#3a6a4a")),
 "bone_meal": (683, ("hue", "#f0ece0")), "mixed_feed": (683, ("hue", "#c8a060")), "compost": (1193, None), "moisture_mulch": (1019, None),
 "frost_cloth": (669, None), "granola_bar": (354, ("hue", "#b08a50")),
 "bent_fork": (797, None), "dead_battery": (947, ("ramp", "#1a1a1a", "#7a7a72")), "shredded_tire": (752, None),
 "herbal_poultice": (997, None), "suture_kit": (633, None),
 "gasoline": (939, None), "diesel": (939, ("hue", "#4a6a3a")), "propane_tank": (938, ("hue", "#c8ccd0")),
 "grinning_saint": (302, None), "viking_horns": (207, None), "lucky_paw": (1212, None), "sinew": (1217, ("hue", "#d8a090")),
 "runner_tendon": (1217, ("hue", "#a83a3a")), "sleeping_bag": (1161, None), "trail_camera": (755, None),
 "torch_post": (719, None), "ham_radio": (846, ("ramp", "#202420", "#8a9a7a")), "anvil": (747, None),
 "apple_sapling": (1003, None), "cherry_sapling": (1003, None), "peach_sapling": (1003, None), "pear_sapling": (1003, None),
 "plum_sapling": (1003, None), "walnut_sapling": (1003, None),
 # replacing weaker kitbashed icons so they match
 "copper_ore": (1133, None), "gold_ore": (1121, None), "coal": (1126, None), "stone": (1137, None), "gravel": (1127, None),
 "clay": (1128, None), "geode": (1142, None), "glass_shards": (545, None),
 "iron_ore": (1133, ("ramp", "#2a1a14", "#c89a80")), "tin_ore": (1133, ("ramp", "#3a4040", "#e8ecec")), "zinc_ore": (1133, ("ramp", "#283840", "#b8d4dc")),
 "lead_ore": (1133, ("ramp", "#1a1c24", "#8a90a0")), "silver_ore": (1133, ("ramp", "#3a3c48", "#f4f6fa")),
 "tomato_soup": (476, None), "onion_soup": (497, None), "fishermans_stew": (498, None), "ashgrain_porridge": (475, None),
 "beet_borscht": (476, ("hue", "#a01a4a")),
 "morel": (412, None), "chanterelle": (469, None), "glowcap": (389, None), "field_mushroom": (327, None), "dandelion": (1042, None),
 "holly_berry": (617, None), "wild_leek": (474, None),
}

if os.path.isdir(ITEMPACK):
    n = 0
    for iid, (num, op) in ITEM_PACK.items():
        p = os.path.join(ITEMPACK, "item%d.png" % num)
        if not os.path.exists(p):
            print("missing pack item", num, "for", iid)
            continue
        im = Image.open(p).convert("RGBA")
        if op is not None:
            im = ramp_tint(im, op[1], op[2]) if op[0] == "ramp" else hue_set(im, op[1], lambda q: (max(q[:3]) - min(q[:3])) > 22 and sum(q[:3]) > 110)
        save(mute(im, 0.06), "icons/%s.png" % iid)
        n += 1
    print("item pack icons:", n)


# ---------------------------------------------------------------- wildlife (art/critters/<kind>_<frame>.png)
# Small animals that come and go in the background: a flying bird (seen from above), squirrel, rabbit, rat and
# butterfly, drawn here, plus the Sunnyside World pigeon on the ground and a crow recoloured from it.
CRIT = {
    "flyer": [[".o.....o.", "obo...obo", ".obo.obo.", "..obbbo..", "...obo..."],
              [".........", "...obo...", ".oobbboo.", "obbo.obbo", ".o.....o."]],
    "squirrel": [["oo........", "odo.......", "odo...oo..", ".odooobbo.", "..obbbbbeo", "..obbbbbo.", "..oo..oo.."],
                 ["oo........", "odo.......", ".odo..oo..", "..oooobbo.", "..obbbbbeo", ".obbbbbo..", ".oo....oo."]],
    "rabbit": [[".......oo.", "......obo.", "......obo.", "..oooobbbo", ".owbbbbbeo", ".obbbbbbo.", "..oo..oo.."],
               [".......oo.", "......obo.", "..oooobbo.", ".owbbbbbbo", ".obbbbbbeo", "oo.....oo.", ".........."]],
    "rat": [[".......o..", ".....oobo.", "ttoobbbbeo", "..obbbbbo.", "...o..o..."],
            [".......o..", ".....oobo.", ".ttobbbbeo", "..obbbbbo.", "..o....o.."]],
    "butterfly": [["ww.ww", "wwoww", ".wow.", "..o.."], [".wow.", ".wow.", "..o..", "....."]],
}
CPAL = {"flyer": {"o": (34, 30, 34, 255), "b": (88, 76, 70, 255)},
        "squirrel": {"o": (52, 30, 18, 255), "b": (160, 92, 46, 255), "d": (196, 126, 64, 255), "e": (20, 14, 10, 255)},
        "rabbit": {"o": (52, 40, 30, 255), "b": (150, 122, 92, 255), "w": (240, 236, 228, 255), "e": (20, 14, 10, 255)},
        "rat": {"o": (30, 26, 28, 255), "b": (96, 86, 84, 255), "t": (170, 128, 128, 255), "e": (10, 8, 8, 255)},
        "butterfly": {"o": (40, 34, 34, 255), "w": (255, 255, 255, 255)}}
for kind, frames in CRIT.items():
    for i, rows in enumerate(frames):
        save(pix_icon(rows, CPAL[kind]), "critters/%s_%d.png" % (kind, i))
if os.path.isdir(SUNE):
    strip = Image.open(os.path.join(SUNE, "Animals", "spr_deco_bird_01_strip4.png")).convert("RGBA")
    for i in range(4):
        fr = strip.crop((i * 16, 0, i * 16 + 16, 16))
        fpx = fr.load()
        for y in range(16):
            for x in range(16):
                q = fpx[x, y]
                if q[3] and q[1] > q[0] + 15 and q[1] > q[2] + 5:       # drop the grassy shadow under it
                    fpx[x, y] = (0, 0, 0, 0)
        fr = fr.crop(fr.getbbox())
        if "PI" in globals():
            fr = PI.shrink(fr, 10, max(1, round(fr.height * 10 / fr.width)))
        save(mute(fr, 0.1), "critters/pigeon_%d.png" % i)
        crow = fr.copy()
        cp = crow.load()
        for y in range(crow.height):
            for x in range(crow.width):
                p = cp[x, y]
                if p[3] and sum(p[:3]) > 200:      # body and beak to black
                    k = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / 255
                    cp[x, y] = (int(20 + 50 * k), int(20 + 50 * k), int(28 + 56 * k), p[3])
        save(crow, "critters/crow_%d.png" % i)
print("critters: done")


# tools from the item pack: one picture per upgrade tier (Basic, Copper, Iron, Silver, Gold, Aurium)
# icons/<tool>.png is Basic, icons/<tool>_t<tier>.png the upgrades. The watering can keeps its Modern Exteriors
# picture with the tier tint.
TOOL_TIERS = {"pickaxe": [28, 23, 22, 24, 25, 26], "axe": [47, 42, 41, 43, 44, 45], "shovel": [76, 78, 77, 79, 80, 81],
              "hoe": [99, 95, 94, 96, 97, 98], "scythe": [106, 107, 111, 108, 109, 110]}
if os.path.isdir(ITEMPACK):
    for tool, nums in TOOL_TIERS.items():
        for tier, num in enumerate(nums):
            im = mute(Image.open(os.path.join(ITEMPACK, "item%d.png" % num)).convert("RGBA"), 0.06)
            save(im, "icons/%s.png" % tool if tier == 0 else "icons/%s_t%d.png" % (tool, tier))
    print("tool tiers: %d tools" % len(TOOL_TIERS))


# ---------------------------------------------------------------- Brightwater dressing (Nov 17)
# Yards, gardens, mailboxes and the square's fountain and statue, from Modern Exteriors; and the salvage wall
# around town, kitbashed from corrugated sheet, planks and pallets.
if os.path.isdir(MEROOT):
    def _g(n): return me(n)
    DRESS = {
        "mailbox_0": _g("Brown_Little_Bird_House"), "mailbox_1": _g("Blue_Little_Bird_House"),
        "mailbox_2": _g("Brown_Little_Bird_House"), "mailbox_3": _g("Blue_Little_Bird_House"),
        "flower_bed_0": _g("Villa_Yard_Flowers_10"), "flower_bed_1": _g("Villa_Yard_Flowers_11"),
        "flower_bed_2": _g("Villa_Yard_Flowers_12"), "flower_bed_3": _g("Villa_Yard_Flowers_13"),
        "flower_patch_0": _g("Villa_Yard_Flowers_5"), "flower_patch_1": _g("Villa_Yard_Flowers_6"),
        "flower_patch_2": _g("Villa_Yard_Flowers_8"), "flower_patch_3": _g("Villa_Yard_Flowers_7"),
        "hedge_0": _g("Bush_14"), "hedge_1": _g("Bush_15"), "hedge_2": _g("Bush_14"), "hedge_3": _g("Bush_15"),
        "shrub_0": _g("Bush_18"), "shrub_1": _g("Bush_20"), "shrub_2": _g("Bush_19"), "shrub_3": _g("Bush_21"),
        "topiary_0": _g("Bush_6"), "topiary_1": _g("Bush_10"), "topiary_2": _g("Bush_7"), "topiary_3": _g("Bush_13"),
        "fountain": _g("Fountain_1"), "statue": _g("Fountain_2_1"),
        "garden_shed_0": _g("Brown_Wood_Storage"), "garden_shed_1": _g("Blue_Brown_Wood_Storage"),
        "garden_shed_2": _g("White_Wood_Storage"), "garden_shed_3": _g("Red_White_Wood_Storage"),
    }
    for nm, im in DRESS.items():
        save(im, "objects/%s.png" % nm)

    # salvage wall: four patch kinds, so a run of wall is a patchwork of whatever people found
    import random as _rnd

    def _hx(h):
        return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

    def salvage_panel(kind, seed, w=16, h=24):
        r = _rnd.Random(seed)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = im.load()
        tops = [r.choice([2, 2, 3, 3, 4]) for _ in range(w)]
        if kind == 2:                    # planks: each 4 wide, ragged tops
            tops = []
            for b in range(0, w, 4):
                t = r.choice([2, 3, 4, 5])
                tops += [t] * 4
        pal = {0: ("#5a626c", "#7d8691", "#a3abb4"), 1: ("#6e3a24", "#985a3a", "#bf7d55"),
               2: ("#5c4028", "#86603c", "#a8804f"), 3: ("#3e5e62", "#5f878c", "#86aeb2")}[kind]
        dk, md, lt = (_hx(c) for c in pal)
        for x in range(w):
            for y in range(tops[x], h):
                if kind == 2:
                    c = md if (x % 4) in (1, 2) else (lt if x % 4 == 0 else dk)
                else:
                    c = (lt if x % 3 == 0 else (dk if x % 3 == 2 else md))      # corrugation ribs
                px[x, y] = c
        # rust runs and grime on metal; nails and a cross board on planks
        if kind in (0, 1, 3):
            rust = _hx("#8a4e2c")
            for _ in range(3):
                x0 = r.randrange(w); y0 = r.randrange(4, h - 6)
                for y in range(y0, min(h - 1, y0 + r.randrange(3, 8))):
                    if px[x0, y][3]: px[x0, y] = rust
            # a bolted seam
            sy = r.randrange(8, 14)
            for x in range(w):
                if px[x, sy][3]: px[x, sy] = dk
            for x in range(1, w, 5):
                if px[x, sy - 1][3]: px[x, sy - 1] = _hx("#c9ccd0")
        else:
            for x in range(1, w, 4):
                for y in (6, h - 6):
                    px[x, y] = _hx("#2b2622")
            if r.random() < 0.6:                 # a cross brace
                for i in range(w):
                    y = 8 + (i * (h - 14)) // w
                    for dy in (0, 1):
                        if y + dy < h: px[i, y + dy] = lt if dy == 0 else dk
        # outline the top edge and darken the foot
        out = _hx("#2a2624")
        for x in range(w):
            t = tops[x]
            px[x, t] = out
        # a timber post at the joint, a little taller than the sheets
        for y in range(0, h):
            px[0, y] = out
            px[1, y] = _hx("#7a5634") if y else out
            px[2, y] = _hx("#4e3622") if y else out
        for x in range(w):
            for y in (h - 1, h - 2):
                p = px[x, y]
                if p[3]: px[x, y] = (p[0] * 6 // 10, p[1] * 6 // 10, p[2] * 6 // 10, 255)
        return im

    def salvage_down(seed):
        """The wall running away from you: its top edge seen from above, posts every half tile."""
        r = _rnd.Random(seed)
        im = Image.new("RGBA", (6, 16), (0, 0, 0, 0))
        px = im.load()
        for y in range(16):
            for x in range(6):
                if x in (0, 5): c = _hx("#2a2624")
                elif x == 1: c = _hx("#a3abb4")
                else: c = _hx("#7d8691") if (y // 4 + seed) % 3 else _hx("#985a3a")
                px[x, y] = c
        for y in (3, 11):
            for x in range(6):
                px[x, y] = _hx("#5c4028") if x not in (0, 5) else _hx("#2a2624")
        return im

    for v in range(4):
        kinds = [0, 2, 1, 3]
        H = salvage_panel(kinds[v], 40 + v)
        V = salvage_down(v)
        for nb, im in joined(H, V).items():
            save(im, "objects/salvage_wall_c%d_%d.png" % (nb, v))
            if v == 0:
                save(im, "objects/salvage_wall_c%d.png" % nb)
    print("town dressing: %d props, salvage wall" % len(DRESS))


# ---------------------------------------------------------------- water details (Nov 17)
# River rocks (Modern Exteriors camping rocks, shrunk), lily pads, a sunken log and reeds (drawn here).
if os.path.isdir(MEROOT):
    for v, nm in enumerate(["Rock_1", "Rock_2", "Rock_3", "Rock_5"]):
        im = me(nm)
        if im.width > 12 and "PI" in globals():
            im = PI.shrink(im, 12, max(1, round(im.height * 12 / im.width)))
        elif im.width > 12:
            im = im.resize((12, max(1, round(im.height * 12 / im.width))), Image.NEAREST)
        im = im.copy()
        rp = im.load()
        for yy in range(im.height):
            for xx in range(im.width):
                q = rp[xx, yy]
                if q[3] and q[1] > q[0] + 8 and q[1] >= q[2]:      # the grass it sat in
                    rp[xx, yy] = (0, 0, 0, 0)
        im = im.crop(im.getbbox())
        save(shade(im, 0.92) if "shade" in globals() else im, "tiles/water_rock_%d.png" % v)

    def _px(rows, pal):
        h = len(rows); w = max(len(r) for r in rows)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        p = im.load()
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in pal: p[x, y] = _hx(pal[ch])
        return im

    LILY = ["..oooo.o..",
            ".oggggo.o.",
            "ogglggoggo",
            "oglllggggo",
            "ogglgggddo",
            ".oggggddo.",
            "..oooooo.."]
    LILY2 = ["..oooo..",
             ".oggggo.",
             "oglggo.o",
             "ogggggdo",
             ".oggddo.",
             "..oooo.."]
    FLOWER = [".w.", "wpw", ".w."]
    lp = {"o": "#2e4a26", "g": "#5e9a3c", "l": "#86bf56", "d": "#467a30"}
    for v in range(4):
        base = _px(LILY if v % 2 == 0 else LILY2, lp)
        if v >= 2:
            c = Image.new("RGBA", (base.width + 1, base.height + 1), (0, 0, 0, 0))
            c.alpha_composite(base, (0, 1))
            fl = _px(FLOWER, {"w": "#f4eef2" if v == 2 else "#f2a6c4", "p": "#f2d04a"})
            c.alpha_composite(fl, (3, 0))
            base = c
        save(base, "tiles/water_lily_%d.png" % v)
    # a log, half under: bark above the waterline, a drowned blue-green below
    LOG = ["..oooooooooooooooooooooooo..",
           ".obbbBbbbbbbBbbbbbbBbbbbbbbo",
           "ocrrbbbbBbbbbbbbBbbbbbbbbbbo",
           "orcrbbbbbbbbBbbbbbbbbBbbbbbo",
           "ocrrbbBbbbbbbbbbbbbbbbbbbbbo",
           ".owwwwwwwwwwwwwwwwwwwwwwwwwo",
           "..uuuuuuuuuuuuuuuuuuuuuuuuu."]
    save(_px(LOG, {"o": "#2a1e16", "b": "#6e4a2c", "B": "#4e3420", "r": "#b88a5a", "c": "#8a6440",
                   "w": "#cfe6ee", "u": "#2f6a78"}), "tiles/water_log.png")
    REEDS = [".b...b..",
             ".b..bb.b",
             ".bb.bb.b",
             ".gg..g.g",
             "g.g.g.gg",
             "g.gg..g.",
             ".gg.g.g.",
             "..ggggg.",
             "..dgdgd."]
    save(_px(REEDS, {"b": "#6a4a2a", "g": "#6aa04a", "d": "#3e6a2e"}), "tiles/water_reeds.png")
    print("water details: rocks, lilies, log, reeds")


# ---------------------------------------------------------------- Aurium in rainbow (Nov 17)
# Everything made of Aurium (ore, bar, the mine rock's flecks, top-tier tools, the Aurium Rod) gets a rainbow
# sweep across its metal, keeping the picture's own shading. Runs last, on the finished files.
import colorsys as _cs


def rainbow(im, mask, sat=0.85, span=0.83, lift=0.22):
    out = im.copy()
    px = out.load()
    pts = [(x, y) for y in range(out.height) for x in range(out.width) if px[x, y][3] and mask(px[x, y], x, y)]
    if not pts:
        return out
    # run the colours along the shape's longest direction, so a bar laid either way gets the whole spectrum
    best = None
    for dx, dy in [(1, 0), (0, -1), (1, -1), (1, 1)]:
        vals = [dx * x + dy * y for x, y in pts]
        sp = max(vals) - min(vals)
        if best is None or sp > best[0]:
            best = (sp, dx, dy, min(vals))
    sp, ddx, ddy, lo = best
    for x, y in pts:
        r, g, b, a = px[x, y]
        v = max(r, g, b) / 255.0
        hue = (ddx * x + ddy * y - lo) / max(1, sp) * span
        nr, ng, nb = _cs.hsv_to_rgb(hue % 1.0, sat, min(1.0, lift + v * (1.0 - lift) * 1.05))
        px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def _hsv(p):
    return _cs.rgb_to_hsv(p[0] / 255.0, p[1] / 255.0, p[2] / 255.0)


def _ld(rel):
    p = os.path.join(OUT, rel)
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


not_outline = lambda p, x, y: _hsv(p)[2] > 0.2
n = 0
for rel in ["icons/aurium_bar.png", "icons/aurium_ore.png"]:
    im = _ld(rel)
    if im is not None:
        save(rainbow(im, not_outline), rel); n += 1
# the mine rock: only its blue flecks
im = _ld("objects/ore_rock_aurium_ore.png")
if im is not None:
    save(rainbow(im, lambda p, x, y: _hsv(p)[1] > 0.3 and 0.45 < _hsv(p)[0] < 0.75), "objects/ore_rock_aurium_ore.png"); n += 1
# top-tier tools: the head is where the Aurium picture differs from the Basic one
for tool in ["axe", "hoe", "pickaxe", "shovel", "scythe"]:
    t5 = _ld("icons/%s_t5.png" % tool); t0 = _ld("icons/%s.png" % tool)
    if t5 is None:
        continue
    def head(p, x, y):
        h, sa, va = _hsv(p)
        return va > 0.2 and sa > 0.2 and 0.38 < h < 0.62       # the teal metal, not the wooden handle
    rb = rainbow(t5, head)
    save(rb, "icons/%s_t5.png" % tool)
    save(rb, "icons/%s_aurium.png" % tool); n += 1
# the watering can: its grey metal (the same pixels the game tints for upgrades)
wc = _ld("icons/watering_can.png")
if wc is not None:
    rb = rainbow(wc, not_outline)
    save(rb, "icons/watering_can_t5.png"); save(rb, "icons/watering_can_aurium.png"); n += 1
# the Aurium Rod: the rod itself, not the line or reel
rod = _ld("icons/fishing_rod_aurium.png")
if rod is not None:
    save(rainbow(rod, lambda p, x, y: _hsv(p)[1] > 0.3 and _hsv(p)[2] > 0.25), "icons/fishing_rod_aurium.png"); n += 1
print("aurium rainbow: %d pictures" % n)


# ---------------------------------------------------------------- mouse pointers (Nov 17)
# LimeZu Modern User Interface (warm style): arrow, pointing hand, grabbing hand, and the corner-bracket
# crosshair for aiming.
MUI = os.path.join(SRC, "modernuserinterface-win", "16x16", "Modern_UI_Style_1.png")
if os.path.isfile(MUI):
    mu = Image.open(MUI).convert("RGBA")
    def mu_cell(x, y, w=16, h=16):
        c = mu.crop((x, y, x + w, y + h))
        return c.crop(c.getbbox())
    save(mu_cell(160, 336), "ui/cursor_arrow.png")
    save(mu_cell(176, 336), "ui/cursor_hand.png")
    save(mu_cell(192, 336), "ui/cursor_grab.png")
    save(mu_cell(160, 288, 32, 32), "ui/crosshair.png")
    print("mouse pointers: 4")


# ---------------------------------------------------------------- Modern UI windows and controls (Nov 21)
# Windows, panels, buttons, slots, bars, switches and the slider from LimeZu's Modern User Interface
# (warm Style 1). Replaces the Kenney and PostApocalypse interface pieces cut above.
import runpy
runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "mui_ui.py"), init_globals={"SRC": SRC, "OUT": OUT})

# Wooden Crate (Nov 21): the cheap 12-slot storage box uses the pier crate, shrunk to one tile.
_cr = os.path.join(OUT, "objects", "crate.png")
if os.path.isfile(_cr):
    _c = Image.open(_cr).convert("RGBA")
    _c = _c.crop(_c.getbbox())
    if _c.width > 16:
        _c = _c.resize((16, max(1, round(_c.height * 16 / _c.width))), Image.NEAREST)
    save(_c, "objects/wood_crate.png")
    _i = Image.new("RGBA", (16, 16))
    _i.alpha_composite(_c.crop((0, 0, 16, min(16, _c.height))), (0, 16 - min(16, _c.height)))
    save(_i, "icons/wood_crate.png")

# ---------------------------------------------------------------- Selected Assets v5 (Daniel's curated pack, Nov 21)
# Inventory icons; crafting machines and turrets (32x32, 17 px painted, bottom anchored); closed wood and
# metal gates and the reinforced wall as joining pieces (already in the game's mask order); watchtower and
# wind turbine; museum cases, ledger, donation desk and stolen goods; police tape; mine details. The pack's
# trellis, raised bed and electric fence world pictures are left out on purpose (the game has its own).
SA = os.path.join(SRC, "Selected_Assets_v5")
if os.path.isdir(SA):
    n = 0
    inv = os.path.join(SA, "Inventory_Overrides")
    for fn in sorted(os.listdir(inv)):
        if fn.endswith(".png"):
            save(Image.open(os.path.join(inv, fn)).convert("RGBA"), "icons/" + fn); n += 1
    WP = os.path.join(SA, "World_Proposals")
    for fn in sorted(os.listdir(os.path.join(WP, "Stations"))):
        if fn.endswith(".png") and fn not in ("cold_frame.png",):          # cold frame sits on a crop tile: keep the game's
            save(Image.open(os.path.join(WP, "Stations", fn)).convert("RGBA"), "objects/" + fn); n += 1
    for fn in ("arc_pylon", "crossbow_turret", "flame_turret", "nail_turret", "sentry_turret", "shotgun_turret", "watchtower", "wind_turbine"):
        save(Image.open(os.path.join(WP, "Defenses", fn + ".png")).convert("RGBA"), "objects/%s.png" % fn); n += 1
    GR = os.path.join(SA, "Godot_Ready", "art", "objects")
    for fn in sorted(os.listdir(GR)):
        if fn.endswith(".png"):
            save(Image.open(os.path.join(GR, fn)).convert("RGBA"), "objects/" + fn); n += 1
    TP = os.path.join(WP, "Town_Props")
    for src, dst in (("display_case_empty", "display_case"), ("display_case_artifact", "display_case_1"),
                     ("display_case_fossil", "display_case_2"), ("display_case_gem", "display_case_3"),
                     ("display_case_ore", "display_case_4"), ("museum_desk", "museum_desk"), ("town_ledger", "town_ledger"),
                     ("stolen_goods_covered", "stolen_goods"), ("stolen_goods_revealed", "stolen_goods_full"),
                     ("police_tape", "police_tape")):
        save(Image.open(os.path.join(TP, src + ".png")).convert("RGBA"), "objects/%s.png" % dst); n += 1
    MD = os.path.join(WP, "Mine_Details")
    for fn in sorted(os.listdir(MD)):
        if fn.endswith(".png"):
            save(Image.open(os.path.join(MD, fn)).convert("RGBA"), "mine/" + fn); n += 1
    save(Image.open(os.path.join(MD, "broken_ore_cart.png")).convert("RGBA"), "objects/mine_cart.png"); n += 1
    print("selected assets v5: %d pictures" % n)

# ---------------------------------------------------------------- Coastal Fishing v5 (Daniel's pack, Nov 21)
# Redrawn side-view icons for every fish already in the game, plus the 10 new freshwater fish. The sea fish
# and beach finds wait for the Coastal Region.
CF = os.path.join(SRC, "Coastal_Fishing_v5")
if os.path.isdir(CF):
    FRESH = ["bluegill", "pumpkinseed", "mosquitofish", "golden_tench", "fathead_minnow", "river_redhorse",
             "freshwater_drum", "grass_pickerel", "longnose_sucker", "stonecat_madtom"]
    new = set(f[:-4] for f in os.listdir(os.path.join(CF, "new_fish", "icons_16")))
    n = 0
    for fn in sorted(os.listdir(os.path.join(CF, "combined_fish", "icons_16"))):
        fid = fn[:-4]
        if fid not in new or fid in FRESH:
            save(Image.open(os.path.join(CF, "combined_fish", "icons_16", fn)).convert("RGBA"), "icons/" + fn); n += 1
    print("coastal fishing: %d fish icons" % n)

# ---------------------------------------------------------------- Weapons v14 (Daniel's pack, Nov 21)
# A 16x16 icon and a 24x16 held picture (pointing right, grip on the left) for all 131 weapons, with
# Claude's touch-ups (tools/weapon_touchups.py). Replaces the icons and held pictures made above.
WV = os.path.join(SRC, "Weapons_v14")
if os.path.isdir(WV):
    import json, re
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import weapon_touchups as WT
    gear = open(os.path.join(os.path.dirname(OUT), "scripts", "autoload", "gear_db.gd")).read()
    code_to_id = {c: i for i, c in re.findall(r'"id": "([a-z0-9_]+)", "code": "([A-Z]+-\d+)"', gear)}
    import pixel_icons as PI
    import numpy as np
    # handguns and SMGs are drawn as big as rifles in the pack; shrink them so they sit in one hand
    SMALL_GUNS = {"Pistol": 12, "Revolver": 13, "SMG": 16}

    def small_gun(im, width):
        b = im.getbbox()
        core = im.crop(b)
        oc = PI.outline_colour(core)
        a = np.array(core).astype(int)
        isout = (a[:, :, 3] > 0) & (np.abs(a[:, :, :3] - np.array(oc)).sum(-1) <= 30)
        a[isout, 3] = 0
        core = Image.fromarray(a.astype(np.uint8))
        core = core.crop(core.getbbox())
        k = (width - 2) / core.width
        sm = PI.add_outline(_pad1(PI.shrink(core, width - 2, max(3, round(core.height * k)), cover=0.25, reoutline=False)), oc)
        out = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
        out.alpha_composite(sm, (b[0], max(0, 12 - sm.height)))
        return out

    def _pad1(im):
        r = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
        r.alpha_composite(im, (1, 1))
        return r

    n = 0
    for w in json.load(open(os.path.join(WV, "weapon_manifest.json"))):
        wid = code_to_id.get(w["id"])
        if wid is None:
            continue
        icon = Image.open(os.path.join(WV, w["icon"])).convert("RGBA")
        held = Image.open(os.path.join(WV, w["held_right"])).convert("RGBA")
        if wid in WT.SCYTHE_PAL:
            icon, held = WT.scythe_icon(wid), WT.scythe_held(wid)
        elif wid in WT.CROWBAR_PAL:
            held = WT.crowbar_held(wid)
        elif wid in WT.RECOLOUR_BOWS:
            held = WT.bow_held(held)
        elif wid in WT.SLING_PAL:
            held = WT.sling_held(wid)
        if w["type"] in SMALL_GUNS:
            held = small_gun(held, SMALL_GUNS[w["type"]])
        save(icon, "icons/%s.png" % wid)
        save(held, "held/%s.png" % wid)
        n += 1
    print("weapons v14:", n)
