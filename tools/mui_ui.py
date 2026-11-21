"""Modern User Interface (LimeZu, warm Style 1): windows, panels, buttons, slots, bars, switches, sliders.

Run by import_packs.py at the end (it passes SRC and OUT), or on its own:
    python3 -I tools/mui_ui.py <unzipped packs folder> art

Every piece keeps the file name the game already loads (art/ui/<name>.png), so UIKit picks it up.
Frame widths for nine-slicing live in UIKit.FRAMES; keep them in step with the pieces cut here.
"""
import colorsys
import os
import sys

from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

SHEET = os.path.join(SRC, "modernuserinterface-win", "16x16", "Modern_UI_Style_1.png")
count = 0


def put(im, rel):
    global count
    p = os.path.join(OUT, "ui", rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    count += 1


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def sat(p):
    return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)[1]


def fill_mask(im):
    """The flat inside of a frame: everything joined to the centre that isn't outline or rim."""
    px = im.load()
    w, h = im.size
    ok = lambda p: p[3] > 0 and sat(p) < 0.42 and lum(p) > 110
    start = (w // 2, h // 2)
    if not ok(px[start]):
        return set()
    seen, todo = {start}, [start]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and ok(px[n]):
                seen.add(n)
                todo.append(n)
    return seen


def recolour(im, pts, want):
    """Recolour chosen pixels so they average out to exactly the wanted colour, keeping light and shade."""
    out = im.copy()
    px = out.load()
    pts = [p for p in pts if px[p][3]]
    if not pts:
        return out
    avg = sum(lum(px[p]) for p in pts) / len(pts)
    w = hexrgb(want)
    for p in pts:
        k = lum(px[p]) / max(avg, 1)
        px[p] = tuple(min(255, int(c * k)) for c in w) + (px[p][3],)
    return out


def shade(im, k, pts=None):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if pts is not None and (x, y) not in pts:
                continue
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
    return out


def grey(im, k=0.85):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                v = int(lum((r, g, b)) * k)
                px[x, y] = (v, v, int(v * 1.04), a)
    return out


def rim(im):
    """The orange rim of a frame (saturated, not the dark outline)."""
    px = im.load()
    return {(x, y) for y in range(im.height) for x in range(im.width)
            if px[x, y][3] and sat(px[x, y]) >= 0.42 and lum(px[x, y]) > 90}


if os.path.isfile(SHEET):
    mu = Image.open(SHEET).convert("RGBA")
    cut = lambda x, y, w, h: mu.crop((x, y, x + w, y + h))

    PARCH_2 = "#efc584"      # UIKit.PARCH_2: list rows are tinted relative to this
    SKY = "#8fbf70"          # portrait background

    # Windows: wood beams with corner posts. Inner panels: a rounded rim with a dark inner line.
    put(cut(8, 8, 32, 31), "window.png")
    panel = cut(58, 129, 28, 29)
    put(panel, "panel_plain.png")
    put(panel, "panel.png")
    put(cut(10, 169, 28, 26), "hud_panel.png")
    port = cut(58, 169, 28, 29)
    put(recolour(port, fill_mask(port), SKY), "portrait.png")
    # The bite screen: red rim, pale inside so the dark red lettering still reads.
    danger = recolour(panel, rim(panel), "#b83a2a")
    put(recolour(danger, fill_mask(danger), "#f6e6cc"), "panel_danger.png")
    put(cut(51, 80, 42, 16), "tooltip.png")

    # List rows and item slots: rounded cards.
    card = cut(60, 251, 24, 25)
    put(recolour(card, fill_mask(card), PARCH_2), "row.png")
    slot = cut(12, 251, 24, 25)
    put(slot, "slot.png")
    put(card, "slot_hover.png")
    sel = recolour(card, rim(card), "#f0c040")
    put(shade(sel, 1.06, fill_mask(sel)), "slot_selected.png")

    # Buttons: raised (normal, hover), pressed sits one pixel lower, disabled greyed.
    btn = cut(13, 368, 22, 16)
    put(btn, "button.png")
    put(shade(btn, 1.08), "button_hover.png")
    pressed = Image.new("RGBA", (22, 16))
    pressed.alpha_composite(cut(61, 369, 22, 15), (0, 1))
    put(pressed, "button_pressed.png")
    put(grey(btn), "button_disabled.png")
    inside = fill_mask(btn)
    green = recolour(btn, inside, "#6aa84f")
    put(green, "button_green.png")
    put(shade(green, 1.1, inside), "button_green_hover.png")
    red = recolour(btn, inside, "#c4503c")
    put(red, "button_red.png")
    put(shade(red, 1.1, inside), "button_red_hover.png")

    # Status badges (Bleeding, Broken limb...): the small rounded tag in three colours.
    tag = cut(80, 353, 16, 15)
    tin = fill_mask(tag)
    put(recolour(tag, tin, "#e08a3c"), "badge.png")
    put(recolour(tag, tin, "#d0503c"), "badge_bad.png")
    put(recolour(tag, tin, "#6aa84f"), "badge_good.png")

    # Bars: dark track with an orange rim; the fills are the pack's glossy strips.
    put(cut(268, 386, 25, 13), "bar_track.png")
    red_fill = cut(319, 389, 18, 6)
    green_fill = cut(271, 405, 18, 6)
    every = {(x, y) for y in range(6) for x in range(18)}
    put(red_fill, "bar_health.png")
    put(recolour(green_fill, every, "#e8c03a"), "bar_energy.png")
    put(recolour(green_fill, every, "#c87a3a"), "bar_hunger.png")
    put(recolour(green_fill, every, "#3a90d8"), "bar_thirst.png")

    # Settings: on/off switches and a slider (track and knob).
    put(cut(341, 417, 23, 12), "switch_on.png")
    put(cut(308, 417, 23, 12), "switch_off.png")
    put(cut(277, 466, 22, 11), "slider_track.png")
    put(cut(273, 498, 13, 12), "slider_knob.png")

    # Icon buttons (orange set, boxed) and bare glyphs recoloured dark for use beside button text.
    ICONS = {"lock": (544, 16), "gear": (624, 16), "home": (640, 16), "list": (656, 16), "trash": (672, 16),
             "check": (544, 32), "close": (560, 32), "plus": (576, 32), "minus": (592, 32),
             "arrow_right": (608, 32), "arrow_left": (624, 32), "arrow_down": (640, 32), "arrow_up": (656, 32),
             "sort": (672, 32), "right": (608, 48), "left": (624, 48), "down": (640, 48), "up": (656, 48),
             "filter": (672, 48), "help": (560, 64), "trophy": (576, 64), "info": (592, 64), "pause": (608, 64),
             "sound": (640, 64), "mute": (656, 64), "sliders": (672, 64), "edit": (608, 80), "cart": (624, 80)}
    for nm, (x, y) in ICONS.items():
        box = cut(x, y, 16, 16)
        put(box, "ib_%s.png" % nm)
        glyph = cut(x, y + 80, 16, 16)
        bb = glyph.getbbox()
        if bb:
            g = glyph.crop(bb)
            dark = recolour(g, {(i, j) for j in range(g.height) for i in range(g.width)}, "#5a3418")
            put(dark, "glyph_%s.png" % nm)
    print("modern ui: %d pieces" % count)

    # Portrait Generator parts (16x16 set): the first row of each sheet (an idle loop of 10 frames,
    # 32x32 each; frame 2 blinks). Same numbering as the character generator, so a person's hair,
    # eyes and accessory map straight across. Saved to art/portraits/<part>/<name>.png.
    PG = os.path.join(SRC, "modernuserinterface-win", "16x16", "Portrait_Generator")
    pg_n = 0
    if os.path.isdir(PG):
        import re
        for sub, part in (("Skins", "skin"), ("Eyes", "eyes"), ("Hairstyles", "hair"), ("Accessories", "acc")):
            for fn in sorted(os.listdir(os.path.join(PG, sub))):
                if not fn.endswith(".png"):
                    continue
                stem = fn[:-4]
                if part == "skin":
                    name = stem.split("_")[-1]                                   # PG_Skin_3 -> 3
                elif part == "eyes":
                    name = stem.split("_")[-1]                                   # PG_Eyes_01 -> 01
                elif part == "hair":
                    m = re.match(r"PG_Hairstyle_(\d+)_(\d+)", stem)             # -> 05_3
                    name = "%s_%s" % (m.group(1), m.group(2))
                else:
                    name = stem.replace("PG_Accessory_", "")                     # -> 11_Beanie_2
                strip = Image.open(os.path.join(PG, sub, fn)).convert("RGBA").crop((0, 0, 320, 32))
                dst = os.path.join(OUT, "portraits", part, name + ".png")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                strip.save(dst)
                pg_n += 1
    print("portrait parts: %d" % pg_n)
else:
    print("modern ui: pack not found")
