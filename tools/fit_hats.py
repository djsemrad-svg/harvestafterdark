"""Fit Daniel's Wearables Final hats to the generator heads (Nov 22).

The pack's hats change size and height when the character turns: side views are 7 to 9 px wide on a
13 px wide head (hair sticks out in front and behind), and sit higher or lower than the front view.
Some front views (the beanie) are narrower than the head too.

For every animation frame:
  - hats that hug the head (FITTED): side views get the front view's top and bottom rows (one row shorter,
    like LimeZu's own hats) and are widened toward the back of the head; front and back are at least 14 px;
  - tall hats (cone, horns, chef's hat, the Lighthouse) keep their shape and are moved so every view sits
    on the same brim line;
  - masks (bandana, gas masks, Grinning Saint) are left alone.
Resizing keeps the first and last row and column, so outlines are never dropped.

Used by tools/import_packs.py. Run alone: python3 tools/fit_hats.py <packs folder> <art folder>
"""
import os
import sys
from PIL import Image

ROW_FRAMES = {1: 6, 2: 6, 3: 6, 4: 6, 5: 6, 6: 3, 7: 12}   # frames per direction in each sheet row
RIGHT, UP, LEFT, DOWN = 0, 1, 2, 3
MASKS = {"HEAD-003", "HEAD-005", "HEAD-012", "HEAD-020"}
FITTED = {"HEAD-001", "HEAD-002", "HEAD-004", "HEAD-006", "HEAD-007", "HEAD-008", "HEAD-009", "HEAD-010",
          "HEAD-011", "HEAD-013", "HEAD-014", "HEAD-015", "HEAD-016", "HEAD-017", "HEAD-018", "HEAD-021"}
MIN_W = 14        # front and back: the head is 14 px wide
HEAD_TOP = 10      # the generator head's top row (idle and walk; attacks lean a little)
SIDE_W = 12       # side: the head is 13 px wide; one pixel of forehead shows under the brim


def _resize(im, w, h):
    """Nearest-neighbour resize that always keeps the edge rows and columns."""
    sw, sh = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sp, op = im.load(), out.load()
    for y in range(h):
        sy = 0 if h == 1 else round(y * (sh - 1) / (h - 1))
        for x in range(w):
            sx = 0 if w == 1 else round(x * (sw - 1) / (w - 1))
            op[x, y] = sp[sx, sy]
    return out


# Cowboy Hat: its crown was a skin-like tan, so it read as a bald head with a dark band across the eyes.
# Recoloured to leather browns, darkest at the brim.
RECOLOUR = {"HEAD-021": {(0xBA, 0x8B, 0x61): (0x8E, 0x5C, 0x3A), (0x87, 0x5C, 0x48): (0x6A, 0x40, 0x28),
                         (0x41, 0x48, 0x58): (0x4A, 0x2E, 0x1E)}}


def fit(sheet, code):
    if code in MASKS or not code.startswith("HEAD"):
        return sheet
    if code in RECOLOUR:
        sheet = sheet.copy()
        px, rc = sheet.load(), RECOLOUR[code]
        for y in range(sheet.height):
            for x in range(sheet.width):
                c = px[x, y]
                if c[3] and c[:3] in rc:
                    px[x, y] = rc[c[:3]] + (c[3],)
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for row, n in ROW_FRAMES.items():
        cy = row * 32
        if cy + 32 > sheet.height:
            continue
        for d in range(4):
            for f in range(n):
                cx = (d * n + f) * 16
                cell = sheet.crop((cx, cy, cx + 16, cy + 32))
                box = cell.getbbox()
                if box is None:
                    continue
                front = sheet.crop(((DOWN * n + f) * 16, cy, (DOWN * n + f) * 16 + 16, cy + 32)).getbbox() or box
                l, t, r, b = box
                w, h = r - l, b - t
                side = d in (RIGHT, LEFT)
                if code in FITTED:
                    # fitted hats: the side view takes the front view's height and grows to cover the head
                    top = min(front[1], HEAD_TOP - 1)     # cover the top of the head, or the hair shows above the crown
                    if side:
                        t2, b2 = top, max(top + 2, front[3] - 1)
                        w2 = max(w, SIDE_W)
                    else:
                        t2, b2 = min(t, HEAD_TOP - 1), b
                        w2 = max(w, MIN_W)
                else:
                    # tall hats (cone, horns, chef's hat, lamp): keep their shape, just sit every view at the
                    # same brim line; the front sat higher than the side, perched on top of the hair
                    side_cell = sheet.crop(((RIGHT * n + f) * 16, cy, (RIGHT * n + f) * 16 + 16, cy + 32)).getbbox() or front
                    brim = min(31, max(front[3], side_cell[3] + 1))
                    shift = (brim - 1 - b) if side else (brim - b)
                    t2, b2 = t + shift, b + shift
                    w2 = w
                w2 = min(w2, 16)
                h2 = b2 - t2
                piece = cell.crop(box)
                if (w2, h2) != (w, h):
                    piece = _resize(piece, w2, h2)
                centre = (l + r) / 2.0
                x2 = int(round(centre - w2 / 2.0))
                if side and code in FITTED and w2 > w:
                    # grow toward the back of the head (the face side keeps its brim or visor where it was)
                    x2 = (r - w2) if d == RIGHT else l
                x2 = max(0, min(16 - w2, x2))
                out.alpha_composite(piece, (cx + x2, cy + t2))
    return out


if __name__ == "__main__":
    src, art = sys.argv[1], sys.argv[2]
    import re
    gear = open(os.path.join(os.path.dirname(os.path.abspath(art)), "scripts", "autoload", "gear_db.gd")).read()
    code_to_id = {c: i for i, c in re.findall(r'"id": "([a-z0-9_]+)", "code": "([A-Z]+-\d+)"', gear)}
    sd = os.path.join(src, "Wearables_Final", "Head", "existing_mi_16x32", "full_generator_sheets")
    for fn in sorted(os.listdir(sd)):
        code = fn[:-4]
        if code in MASKS or code not in code_to_id:
            continue
        sh = fit(Image.open(os.path.join(sd, fn)).convert("RGBA"), code)
        sh.save(os.path.join(art, "characters", "mi", "wear", code_to_id[code] + ".png"))
        print("fitted", code, code_to_id[code])
