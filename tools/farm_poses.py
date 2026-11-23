"""Tool poses from LimeZu's Modern Farm farmer generator (Nov 22), for any character look.
Run from import_packs.py with SRC, OUT and save, or alone: python3 tools/farm_poses.py <packs> <art>.

The farmer generator's body has exactly the same shape as the Modern Interiors body the game's people are built
from, and it has digging, watering and chopping rows that the people's own sheets don't. The people's outfit,
hair, eyes and hats only exist for the Modern Interiors rows, so each tool frame is rebuilt at runtime
(MiChars.compose_farm) from:
  - the farmer body frame, recoloured to the person's skin (arms, legs and the head's skin in the new pose)
  - the person's own layers from their standing frame: the head part moved with the farmer's head, the chest
    part moved with the farmer's chest, and the legs taken from whichever of the person's own standing or walking
    frames has the closest leg shape
  - the farmer's arms drawn back over the clothes (sleeve-coloured where the outfit has sleeves, hands in skin)
This script works out those moves per frame, the arms, and where the tool is gripped, into
art/characters/farm/poses.json, and copies the body rows and the tool layers (axe, shovel, watering can).
"""
import json
import os
import sys
from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

FG = os.path.join(SRC, "Modern_Farm", "Farmer_Generator_Pieces")
MI_BODY = os.path.join(OUT, "characters", "mi", "body", "01.png")

# farmer rows used: [row in the farmer sheet, frames per direction]; idle is the reference
ANIMS = {"dig": (4, 9), "water": (5, 14), "chop": (6, 10)}
TOOLS = {"chop": "Tool_Axe", "dig": "Tool_Shovel", "water": "Tool_Watering_Can"}
DIRS = ["right", "up", "left", "down"]
HEAD_END, LEGS_START = 22, 28        # head rows 0-21, chest 22-27, legs 28-31 (16 x 32 cell)
TOOL_OFF = (-16, -4)                 # where the 48 x 48 tool cell sits against the 16 x 32 body cell


def cell(im, c, r, w=16, h=32):
    return im.crop((c * w, r * h, c * w + w, r * h + h))


def mask(im, y0=0, y1=32):
    px = im.load()
    return {(x, y) for y in range(y0, y1) for x in range(im.width) if px[x, y][3] > 0}


def best_shift(a, b, rx=4, ry=6):
    best, bs = (0, 0), -1e9
    for dy in range(-ry, ry - 1):
        for dx in range(-rx, rx + 1):
            sc = len({(x + dx, y + dy) for x, y in a} & b) - 0.01 * (abs(dx) + abs(dy))
            if sc > bs:
                bs, best = sc, (dx, dy)
    return best


def is_outline(c):
    return c[3] > 0 and max(c[:3]) < 100 and abs(c[0] - c[2]) < 40


def build():
    if not (os.path.isdir(FG) and os.path.isfile(MI_BODY)):
        return 0
    L = lambda p: Image.open(os.path.join(FG, p)).convert("RGBA")
    FB = L("Character Pieces/Bodies/16x16/Body_2.png")
    FH = L("Character Pieces/Hairstyles/16x16/Hairstyle_Long_Blonde.png")
    FE = L("Character Pieces/Eyes/16x16/Eyes_Blue.png")
    FO = L("Character Pieces/Outfits/16x16/Outfit_Braces_Brown.png")
    MB = Image.open(MI_BODY).convert("RGBA")
    # body sheet: idle row then the three tool rows
    sheet = Image.new("RGBA", (896, 32 * 4))
    sheet.alpha_composite(FB.crop((0, 32, 896, 64)), (0, 0))
    for i, a in enumerate(["dig", "water", "chop"]):
        r = ANIMS[a][0]
        sheet.alpha_composite(FB.crop((0, r * 32, 896, r * 32 + 32)), (0, 32 * (i + 1)))
    save(sheet, "characters/farm/body.png")
    tools = {}
    for a, t in TOOLS.items():
        ts = L("Tools/16x16/%s.png" % t)
        row = ts.crop((0, 96, ts.width, 144))
        save(row, "characters/farm/tool_%s.png" % a)
        tools[a] = row
    cols = [cc for cc in (cell(FB, 18, 1).getcolors(512) or []) if cc[1][3] and not is_outline(cc[1])]
    skin_base = max(cols, key=lambda q: q[0])[1]

    out = {"tool_off": list(TOOL_OFF), "skin_base": "#%02x%02x%02x" % skin_base[:3], "rows": {"dig": 1, "water": 2, "chop": 3},
           "anims": {}}
    for a, (r, n) in ANIMS.items():
        per = {}
        for d, dn in enumerate(DIRS):
            frames = []
            i0 = d * 6
            ref = cell(FB, i0, 1)
            h0 = mask(cell(FH, i0, 1)) | mask(cell(FE, i0, 1))
            t0 = mask(cell(FO, i0, 1), HEAD_END, LEGS_START)
            for f in range(n):
                c = d * n + f
                F = cell(FB, c, r)
                h1 = mask(cell(FH, c, r)) | mask(cell(FE, c, r))
                t1 = mask(cell(FO, c, r), 14, 31)
                hd = best_shift(h0, h1)
                td = best_shift(t0, t1, 2, 3)
                # legs: the person's own idle or walk frame whose legs look most like these
                fl = mask(F, LEGS_START, 32)
                best_leg, bl = [1, d * 6], -1e9
                for mr, mn in ((1, 6), (2, 6)):
                    for k in range(mn):
                        ml = mask(cell(MB, d * mn + k, mr), LEGS_START, 32)
                        sc = len(ml & fl) - len(ml ^ fl) - (0.5 if mr == 2 else 0)
                        if sc > bl:
                            bl, best_leg = sc, [mr, d * mn + k]
                # arms: farmer body pixels above the legs that differ from the standing body moved by the head and
                # chest shifts (so the arms in their new place, including where they cross the chest)
                rp = ref.load()
                Fp = F.load()

                def ref_at(x, y):
                    dx, dy = hd if y < HEAD_END else td
                    sx, sy = x - dx, y - dy
                    if 0 <= sx < 16 and 0 <= sy < 32:
                        return rp[sx, sy]
                    return (0, 0, 0, 0)
                arm = []
                for y in range(HEAD_END - 6, LEGS_START):
                    for x in range(16):
                        c1 = Fp[x, y]
                        if c1[3] == 0:
                            continue
                        c0 = ref_at(x, y)
                        if c0[3] == 0:
                            arm.append((x, y))      # outside the standing silhouette: an arm out in the open
                # an arm across the chest: outline pixels inside the silhouette touching an arm already found
                grow = True
                while grow:
                    grow = False
                    have = set(arm)
                    for y in range(HEAD_END, LEGS_START):
                        for x in range(16):
                            if (x, y) in have: continue
                            c1 = Fp[x, y]
                            c0 = ref_at(x, y)
                            if c1[3] and is_outline(c1) and not is_outline(c0) and any((x + ex, y + ey) in have for ex in (-1, 0, 1) for ey in (-1, 0, 1)):
                                arm.append((x, y)); grow = True
                # hands: the end of each arm farthest from the shoulder
                root = (8 + td[0], 23 + td[1])
                pts = set(arm)
                kinds = {}
                seen = set()
                for p0 in arm:
                    if p0 in seen:
                        continue
                    comp, todo = [], [p0]
                    seen.add(p0)
                    while todo:
                        q = todo.pop()
                        comp.append(q)
                        for ddx in (-1, 0, 1):
                            for ddy in (-1, 0, 1):
                                nq = (q[0] + ddx, q[1] + ddy)
                                if nq in pts and nq not in seen:
                                    seen.add(nq)
                                    todo.append(nq)
                    far = max(comp, key=lambda q: (q[0] - root[0]) ** 2 + (q[1] - root[1]) ** 2)
                    for q in comp:
                        dist = ((q[0] - far[0]) ** 2 + (q[1] - far[1]) ** 2) ** 0.5
                        kinds[q] = "h" if dist <= 1.5 and len(comp) >= 3 else "a"
                arms = [[x, y, kinds[(x, y)]] for x, y in arm]
                fr = {"head": list(hd), "chest": list(td), "legs": best_leg, "arms": arms}
                # where the tool is held: the tool pixel nearest a hand, and its far end
                tl = cell(tools[a], c, 0, 48, 48)
                tp = [(x + TOOL_OFF[0], y + TOOL_OFF[1]) for x, y in mask(tl, 0, 48)]
                hands = [(x, y) for x, y, k in arms if k == "h"] or [(x, y) for x, y, k in arms]
                tpx = tl.load()
                # only the tool itself: leave out the pale swing smear, and keep the piece joined to the hand (dirt
                # clods and water drops fly free)
                tp = [q for q in tp if not (min(tpx[q[0] - TOOL_OFF[0], q[1] - TOOL_OFF[1]][:3]) > 170 and tpx[q[0] - TOOL_OFF[0], q[1] - TOOL_OFF[1]][2] > 200)]
                if tp and hands:
                    grip = min(tp, key=lambda q: min((q[0] - h[0]) ** 2 + (q[1] - h[1]) ** 2 for h in hands))
                    have = set(tp); piece = {grip}; todo = [grip]
                    while todo:
                        q = todo.pop()
                        for ex in (-1, 0, 1):
                            for ey in (-1, 0, 1):
                                nq = (q[0] + ex, q[1] + ey)
                                if nq in have and nq not in piece:
                                    piece.add(nq); todo.append(nq)
                    tip = max(piece, key=lambda q: (q[0] - grip[0]) ** 2 + (q[1] - grip[1]) ** 2)
                    fr["grip"] = list(grip)
                    fr["tip"] = list(tip)
                frames.append(fr)
            per[dn] = frames
        out["anims"][a] = {"n": n, "frames": per}
    # pickaxe and hoe: the pack's axe and shovel with a new head at the end of the handle
    for name, src, n in (("pickaxe", "chop", 10), ("hoe", "dig", 9)):
        strip = tools[src].copy()
        sp = strip.load()
        for c in range(strip.width // 48):
            x0 = c * 48
            px = [(x, y) for y in range(48) for x in range(x0, x0 + 48) if sp[x, y][3] > 0]
            if not px:
                continue
            col = lambda q: sp[q[0], q[1]]
            def wood(q):
                r, g, b, a = col(q)
                return r > g + 20 and g > b and r < 230
            def metal(q):
                r, g, b, a = col(q)
                return abs(r - g) < 30 and abs(g - b) < 40 and max(r, g, b) > 90 and not (min(r, g, b) > 170 and b > 200)
            handle = [q for q in px if wood(q)]
            head = [q for q in px if metal(q)]
            if len(handle) < 2 or len(head) < 2:
                continue
            hx = sum(q[0] for q in head) / len(head); hy = sum(q[1] for q in head) / len(head)
            # the handle end under the head, and the far end (the grip)
            near = min(handle, key=lambda q: (q[0] - hx) ** 2 + (q[1] - hy) ** 2)
            far = max(handle, key=lambda q: (q[0] - near[0]) ** 2 + (q[1] - near[1]) ** 2)
            for q in head:
                sp[q[0], q[1]] = (0, 0, 0, 0)
            ax, ay = near[0] - far[0], near[1] - far[1]
            ln = max(1e-6, (ax * ax + ay * ay) ** 0.5)
            ux, uy = ax / ln, ay / ln          # along the handle, toward the head
            vx, vy = -uy, ux                   # across it
            dark, mid, light = (52, 54, 66, 255), (124, 128, 142, 255), (196, 200, 210, 255)
            def put(x, y, c):
                x, y = int(round(x)), int(round(y))
                if x0 <= x < x0 + 48 and 0 <= y < 48:
                    sp[x, y] = c
            tx, ty = near[0] + ux, near[1] + uy
            if name == "pickaxe":
                for k in range(-3, 4):          # a curved bar across the handle, points bent back
                    back = 0.35 * abs(k) * abs(k) / 3.0
                    put(tx + vx * k - ux * back, ty + vy * k - uy * back, light if k in (-1, 0) else mid)
                    put(tx + vx * k - ux * (back + 1), ty + vy * k - uy * (back + 1), dark)
            else:
                side = 1 if vy >= 0 else -1      # the blade hangs toward the ground
                for k in range(0, 4):
                    put(tx + vx * k * side, ty + vy * k * side, mid if k else light)
                    put(tx + vx * k * side - ux, ty + vy * k * side - uy, dark)
        save(strip, "characters/farm/tool_%s.png" % name)
    p = os.path.join(OUT, "characters", "farm", "poses.json")
    with open(p, "w") as fh:
        json.dump(out, fh, separators=(",", ":"))
    return 4


n = build()
print("farm poses:", n)
