"""The Curio Cabinet (Nov 22): relic icons and the shop's museum furniture.
Run from import_packs.py with SRC, OUT, save and mute, or alone: python3 tools/curio_art.py <packs> <art>.

Relic icons come from Daniel's Item Pack 16x16 (numbers in RELIC_ICONS, which must match the ids in
scripts/world/relics.gd). Furniture comes from Modern Interiors' museum theme: glass cabinets that are
empty or full (they fill as you donate), vases on plinths, a rope barrier, framed butterflies and a small
landscape for the walls, and a wide cabinet that becomes the metal and gem wall."""
import os
import sys
from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

    def mute(im, amt=0.15):
        return im

RELIC_ICONS = {
    "leather_journal": 652, "field_guide": 653, "road_atlas": 654, "recipe_tin": 655, "sealed_letter": 642,
    "wax_seal": 643, "hand_drawn_map": 660, "land_deed": 647, "star_chart": 663, "blueprint_roll": 664,
    "small_landscape": 662, "magnifying_glass": 657, "brass_telescope": 773, "brass_compass": 766,
    "fountain_pen": 637, "inkwell": 651, "briar_pipe": 703, "music_box": 715, "hurricane_lamp": 716,
    "memory_stick": 962, "sim_card": 964, "handheld_game": 977, "vhs_tape": 845, "compact_disc": 848,
    "filament_bulb": 949, "brass_gauge": 941, "crystal_ball": 880, "brass_trumpet": 853, "little_lyre": 856,
    "mandolin": 836, "pewter_knight": 787, "pewter_king": 784, "bone_dice": 791, "ivory_domino": 792,
    "deck_of_cards": 793, "tarot_card": 794, "signed_baseball": 765, "pageant_crown": 874, "china_teacup": 810,
    "enamel_mug": 811, "perfume_bottle": 774, "dreamcatcher": 832, "hand_bell": 937, "heart_locket": 688,
    "signet_ring": 892, "sapphire_ring": 893, "silk_top_hat": 316, "lace_parasol": 699, "altar_candle": 697,
    "festival_mask": 303, "fox_mask": 304, "porcelain_mask": 305, "bronze_medal": 167, "silver_medal": 168,
    "gold_medal": 169, "crystal_award": 170, "silver_dollar": 1158, "gold_doubloon": 1159, "old_banknote": 1160,
    "skeleton_key": 691, "ornate_key": 694, "clay_urn": 680, "marble_bust": 782, "gilded_idol": 762,
    "jade_idol": 763, "anatomy_skull": 1167, "painted_skull": 1168, "glass_eye": 1169, "diving_helmet": 1116,
    "life_ring": 1114,
}

IP = os.path.join(SRC, "Item_Pack_16x16")
n = 0
if os.path.isdir(IP):
    for rid, num in RELIC_ICONS.items():
        p = os.path.join(IP, "item%d.png" % num)
        if os.path.isfile(p):
            save(mute(Image.open(p).convert("RGBA"), 0.05), "icons/%s.png" % rid)
            n += 1
print("relic icons:", n)

# ---------------------------------------------------------------- museum furniture
T = os.path.join(SRC, "moderninteriors-win", "1_Interiors", "16x16", "Theme_Sorter_Shadowless", "22_Museum_Shadowless.png")
if os.path.isfile(T):
    SH = Image.open(T).convert("RGBA")
    A = SH.load()

    def pick(px, py):
        """The object under pixel (px, py): every drawn pixel joined to it, trimmed."""
        w, h = SH.size
        if A[px, py][3] == 0:      # on a gap inside the piece: start from the nearest drawn pixel
            px, py = min(((x, y) for x in range(max(0, px - 12), min(w, px + 13)) for y in range(max(0, py - 12), min(h, py + 13))
                          if A[x, y][3] > 0), key=lambda q: (q[0] - px) ** 2 + (q[1] - py) ** 2)
        seen = {(px, py)}
        todo = [(px, py)]
        while todo:
            x, y = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in seen or not (0 <= q[0] < w and 0 <= q[1] < h) or A[q][3] == 0:
                        continue
                    seen.add(q)
                    todo.append(q)
        xs = [q[0] for q in seen]
        ys = [q[1] for q in seen]
        out = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1), (0, 0, 0, 0))
        for q in seen:
            out.putpixel((q[0] - min(xs), q[1] - min(ys)), A[q])
        return out

    PIECES = {
        # small cabinets (2 tiles wide): empty, and three different full ones
        "curio_cabinet_empty": (97, 1112), "curio_cabinet_full_0": (177, 1051), "curio_cabinet_full_1": (177, 1148),
        "curio_cabinet_full_2": (207, 1206),
        # wide cabinets (5 tiles wide): empty and full
        "curio_wide_empty": (37, 1112), "curio_wide_full": (197, 1098),
        "curio_vase_0": (47, 205), "curio_vase_1": (82, 205), "curio_vase_2": (117, 250),
        "curio_rope": (20, 287), "curio_bugs": (47, 560), "curio_landscape": (112, 355),
    }
    for name, (px, py) in PIECES.items():
        save(mute(pick(px, py), 0.05), "objects/%s.png" % name)
    # the metal and gem wall: the empty wide cabinet; the game draws each donated bar and gem on its shelves
    save(mute(pick(37, 1112), 0.05), "objects/curio_wall.png")
    print("curio furniture:", len(PIECES) + 1)
