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
from PIL import Image

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
    meta = {}
    for kind, f in BUILDINGS.items():
        p = os.path.join(ME, f)
        if not os.path.exists(p):
            print("missing building art:", kind, f)
            continue
        im = load(p)
        save(im, "buildings/%s.png" % kind)
        meta[kind] = {"w": im.width, "h": im.height, "door": im.width // 2}
    with open(os.path.join(OUT, "buildings", "index.json"), "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    written.append("buildings/index.json")
    print("buildings:", len(meta))
