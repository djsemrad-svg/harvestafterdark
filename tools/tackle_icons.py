"""Icons for Wren's new tackle (Nov 22), from Daniel's Item Pack 16x16. Run from import_packs.py with SRC, OUT
and save, or alone: python3 tools/tackle_icons.py <packs> <art>."""
import os
import sys
from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

# id: (pack number, tint or None). The Fluorocarbon Line is the braided spool made clear blue.
ICONS = {"circle_hook": (1104, None), "barbed_hook": (1106, None), "braided_line": (1113, None),
         "fluoro_line": (1113, (150, 210, 235)), "crankbait": (1108, None), "spoon_lure": (1109, None),
         "popper": (1110, None), "moonlight_lure": (1112, (170, 190, 255)), "minnows": (1146, None)}

IP = os.path.join(SRC, "Item_Pack_16x16")
n = 0
for tid, (num, tint) in ICONS.items():
    p = os.path.join(IP, "item%d.png" % num)
    if not os.path.isfile(p):
        continue
    im = Image.open(p).convert("RGBA")
    if tint:
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                l = (r * 0.3 + g * 0.59 + b * 0.11) / 255.0
                if l < 0.2:          # keep the dark outline
                    continue
                px[x, y] = (int(tint[0] * (0.45 + l * 0.6)), int(tint[1] * (0.45 + l * 0.6)), int(tint[2] * (0.45 + l * 0.6)), a)
    save(im, "icons/%s.png" % tid)
    n += 1
print("tackle icons:", n)
