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
        save(warm(t) if setname == "Bleak-Yellow" else t, "tiles/grass_%s_%d.png" % (season, v))
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
# Each part sheet keeps only its first 3 rows (still frames, idle, walk), 16x32 frames, 24 per row:
# right 0-5, up 6-11, left 12-17, down 18-23. index.json lists each part with its main colour so the game
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
    index = {}
    for part, folder, prefix in [("body", "Bodies", "Body_"), ("eyes", "Eyes", "Eyes_"), ("outfit", "Outfits", "Outfit_"),
                                 ("hair", "Hairstyles", "Hairstyle_"), ("acc", "Accessories", "Accessory_")]:
        index[part] = {}
        d = os.path.join(CG, folder, "16x16")
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png"):
                continue
            im = Image.open(os.path.join(d, f)).convert("RGBA").crop((0, 0, 896, 96))
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
                im = Image.open(f).convert("RGBA").crop((0, 0, 896, 96))
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
        "house_a": S % ("Camping", "Mobile_House_Big_5"), "house_b": S % ("Camping", "Mobile_House_Big_7"), "ruin": A % "Post_Apocalyptic_House_2",
        "d_house_blue": A % "Post_Apocalyptic_House_1", "d_house_red": A % "Post_Apocalyptic_House_1",
        "d_house_green": A % "Post_Apocalyptic_House_2", "d_house_yellow": A % "Post_Apocalyptic_House_2", "d_ruin": A % "Post_Apocalyptic_House_2",
        "store": S % ("Shopping_Center_and_Markets", "Mall_1"), "tavern": A % "Victorian_House_5", "tavern_open": A % "Victorian_House_5",
        "forge": "23_MIlitary_Base_16x16_Dormitory_1.png",
        "ranch": A % "Country_House", "clinic": "22_Post_Office_16x16_Building_2.png", "workshop": S % ("Generic_Building", "Hardware_Store"),
        "guild": "23_MIlitary_Base_16x16_Dormitory_2.png", "townhall": S % ("Generic_Building", "Condo_6"),
        "archive": "23_MIlitary_Base_16x16_Dormitory_4.png", "archive_open": "23_MIlitary_Base_16x16_Dormitory_4.png",
        "baitshack": S % ("Camping", "Mobile_House_Small_1"),
        "d_diner": S % ("Shopping_Center_and_Markets", "Market_Big_1"), "d_pawn": S % ("Shopping_Center_and_Markets", "Market_Small_1"),
        "d_guns": S % ("Shopping_Center_and_Markets", "Market_Small_5"), "d_pharmacy": S % ("Shopping_Center_and_Markets", "Market_Small_9"),
        "d_police": S % ("Police_Station", "Police_Station_Small_1"), "d_church": S % ("Graveyard", "Grace_Chapel"),
        "d_shed": S % ("City_Props", "Junk_Shack_1"), "d_school": S % ("School", "School_1"),
        "d_thrift": S % ("Shopping_Center_and_Markets", "Market_Medium_2"), "d_gas": S % ("Shopping_Center_and_Markets", "Market_Medium_3"),
        "d_burger": S % ("Shopping_Center_and_Markets", "Market_Big_2"), "d_pizza": S % ("Shopping_Center_and_Markets", "Market_Big_3"),
        "d_chicken": S % ("Shopping_Center_and_Markets", "Market_Medium_4"), "d_taco": S % ("Shopping_Center_and_Markets", "Market_Medium_5"),
        "d_hotdog": S % ("Shopping_Center_and_Markets", "Market_Small_3"), "d_hardware": S % ("Generic_Building", "Hardware_Store"),
        "d_garage": "23_MIlitary_Base_16x16_Dormitory_3.png", "d_firehouse": S % ("Fire_Station", "Building"),
        "d_warehouse": "23_MIlitary_Base_16x16_Hangar.png", "d_bar": "23_MIlitary_Base_16x16_Dormitory_4.png",
        "d_scrap_office": S % ("City_Props", "Container_House_1"), "d_lumber_office": S % ("Camping", "Mobile_House_Medium_1"),
        "d_mill": "23_MIlitary_Base_16x16_Hangar.png", "d_farmhouse": A % "One_Story_House",
        "d_bait": S % ("Camping", "Mobile_House_Small_2"), "d_boathouse": S % ("Camping", "Mobile_House_Big_1"),
        "d_ranger": S % ("Camping", "Mobile_House_Big_5"), "d_cabin": S % ("Camping", "Mobile_House_Medium_5"),
        "d_lab": S % ("Hotel_and_Hospital", "Hospital_1"), "d_lab6": "23_MIlitary_Base_16x16_Bunker.png",
        "d_booth": S % ("Police_Station", "Parking_Booth_2"), "d_clubhouse": A % "Country_House_No_Banisters",
    }
    # where each picture's door (or the foot of its steps) is, in pixels from the left; default the middle
    DOOR = {"archive": 32, "archive_open": 32, "d_bar": 32, "forge": 32, "guild": 33, "baitshack": 40, "d_bait": 40,
            "d_boathouse": 40, "d_booth": 24, "d_cabin": 42, "d_clubhouse": 48, "ranch": 48, "d_farmhouse": 145, "d_firehouse": 46,
            "d_guns": 24, "d_hotdog": 24, "d_pawn": 24, "d_pharmacy": 24, "d_hardware": 40, "workshop": 40,
            "d_house_blue": 124, "d_house_red": 124, "farmhouse": 124, "d_house_green": 123, "d_house_yellow": 123, "d_ruin": 123, "ruin": 123,
            "d_lab": 65, "d_lab6": 67, "d_lumber_office": 40, "d_mill": 77, "d_warehouse": 77, "d_ranger": 42, "house_a": 42, "house_b": 42,
            "d_scrap_office": 35, "d_shed": 68, "store": 138, "tavern": 45, "tavern_open": 45, "townhall": 55}
    # pictures whose steps end above the picture's bottom edge: the ground line at the door, in pixels from the top.
    # Whatever is drawn below it (a porch) hangs in front and is solid.
    BASE = {"ranch": 208, "d_clubhouse": 208}
    meta = {}
    for kind, f in BUILDINGS.items():
        p = os.path.join(ME, f)
        if not os.path.exists(p):
            print("missing building art:", kind, f)
            continue
        im = load(p)
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
            "bas": ("14_Basement_Singles", "Basement_Singles")}
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
    "fishermans_stew": ("prop:jar:48", ("hue", "#c8a060")), "ember_chili": ("mi:kit:385", None),
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
}


def kit_src(spec):
    kind, _, rest = spec.partition(":")
    if kind == "ky":
        return load(os.path.join(KY, rest + ".png")), 0.12
    if kind == "food":
        return load(os.path.join(FOOD, rest + ".png")), 0.0
    if kind == "prop":
        f, n = rest.split(":")
        D2 = {"food": "4-FOOD", "jar": "5-BOTTLES CANS JARS KETTLES VASES", "misc": "6-MISCELLANEOUS"}
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
