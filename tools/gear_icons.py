"""Clothing icons for tools/import_packs.py.

Tops and trousers are drawn from a few shapes (T-shirt, long sleeves, hoodie, jacket, vest, coat, trousers,
shorts, skirt) in the PostApocalypse pack's style: dark plum outline, light from the top left, a shade
down the right. Each item picks a shape, colours and small details (zips, pockets, plates, stripes).
"""
from PIL import Image

OUTLINE = (43, 32, 51, 255)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def scale(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


class Canvas:
    def __init__(self):
        self.im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        self.px = self.im.load()
        self.mask = [[False] * 16 for _ in range(16)]

    def fill(self, x0, y0, x1, y1, col):
        for y in range(max(0, y0), min(16, y1 + 1)):
            for x in range(max(0, x0), min(16, x1 + 1)):
                self.px[x, y] = col
                self.mask[y][x] = True

    def dot(self, x, y, col):
        if 0 <= x < 16 and 0 <= y < 16:
            self.px[x, y] = col

    def clear(self, x0, y0, x1, y1):
        for y in range(max(0, y0), min(16, y1 + 1)):
            for x in range(max(0, x0), min(16, x1 + 1)):
                self.px[x, y] = (0, 0, 0, 0)
                self.mask[y][x] = False

    def shade(self, base):
        """Light from the top left: right-hand columns of each run darker, left edge lighter."""
        for y in range(16):
            xs = [x for x in range(16) if self.mask[y][x]]
            if not xs:
                continue
            runs, cur = [], [xs[0]]
            for x in xs[1:]:
                if x == cur[-1] + 1:
                    cur.append(x)
                else:
                    runs.append(cur)
                    cur = [x]
            runs.append(cur)
            for r in runs:
                if len(r) >= 3 and self.px[r[0], y][:3] == base[:3]:
                    self.px[r[0], y] = scale(base, 1.15)
                for x in r[-max(1, len(r) // 3):]:
                    if self.px[x, y][:3] == base[:3]:
                        self.px[x, y] = scale(base, 0.78)

    def outline(self):
        m = self.mask
        out = []
        for y in range(16):
            for x in range(16):
                if not m[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < 16 and 0 <= ny < 16) or not m[ny][nx]:
                        out.append((x, y))
                        break
        for x, y in out:
            self.px[x, y] = OUTLINE


def top(kind, col, detail=None, accent="#e8e0d0"):
    """kind: tee, long, hoodie, jacket, vest, carrier, coat, suit."""
    base = hexc(col)
    acc = hexc(accent)
    c = Canvas()
    long_body = kind in ("coat",)
    bottom = 15 if long_body else 14
    # body
    if kind in ("vest", "carrier"):
        c.fill(3, 2, 12, bottom, base)
    else:
        c.fill(4, 2, 11, bottom, base)
        # sleeves
        sl_end = 6 if kind == "tee" else 12
        c.fill(1, 3, 3, sl_end, base)
        c.fill(12, 3, 14, sl_end, base)
        c.fill(2, 2, 3, 2, base)
        c.fill(12, 2, 13, 2, base)
    # neck
    c.clear(6, 2, 9, 2)
    c.fill(6, 3, 9, 3, base)
    if kind == "hoodie":
        c.fill(5, 0, 10, 2, base)
        c.clear(7, 1, 8, 2)
    if kind in ("vest", "carrier"):
        c.clear(6, 2, 9, 4)
    c.shade(base)
    # details on top of the shading
    dark = scale(base, 0.6)
    if kind == "hoodie":
        c.fill(6, 9, 9, 11, scale(base, 0.85))
        c.dot(7, 4, acc); c.dot(8, 4, acc); c.dot(7, 5, acc); c.dot(8, 6, acc)
    if kind in ("jacket", "coat"):
        for y in range(3, bottom + 1):
            c.dot(7, y, dark)
        c.dot(6, 3, scale(base, 1.2)); c.dot(9, 3, scale(base, 1.2))
        c.dot(5, 4, scale(base, 1.2)); c.dot(10, 4, scale(base, 1.2))
    if kind == "vest":
        c.fill(4, 8, 5, 10, dark); c.fill(10, 8, 11, 10, dark)
        for y in range(5, bottom + 1):
            c.dot(7, y, dark)
    if kind == "carrier":
        c.fill(4, 5, 11, 11, dark)
        c.fill(5, 6, 10, 10, scale(base, 0.9))
        c.fill(4, 12, 5, 13, dark); c.fill(7, 12, 8, 13, dark); c.fill(10, 12, 11, 13, dark)
    if kind == "suit":
        c.fill(6, 3, 9, 8, acc)
        c.dot(7, 4, hexc("#202020")); c.dot(8, 4, hexc("#202020"))
        c.dot(6, 3, dark); c.dot(9, 3, dark)
    if detail == "stripes":            # reflective bands
        for y in (8, 12):
            for x in range(1, 15):
                if c.mask[y][x]:
                    c.dot(x, y, acc)
    if detail == "flowers":
        for x, y in [(5, 5), (9, 7), (6, 10), (10, 11), (2, 4), (13, 5)]:
            c.dot(x, y, acc)
    if detail == "print":
        c.fill(6, 6, 9, 8, acc)
    if detail == "plaid":
        for y in range(2, 15):
            for x in range(1, 15):
                if c.mask[y][x] and (x % 3 == 0 or y % 3 == 0):
                    c.dot(x, y, scale(c.px[x, y], 0.8))
    if detail == "camo":
        for x, y in [(4, 5), (5, 6), (9, 4), (10, 9), (6, 11), (11, 12), (3, 10), (8, 13)]:
            if c.mask[y][x]:
                c.dot(x, y, acc)
    if detail == "tufts":
        for x, y in [(2, 5), (4, 3), (6, 7), (9, 5), (11, 9), (13, 6), (5, 12), (10, 13), (3, 9), (12, 3)]:
            if c.mask[y][x]:
                c.dot(x, y, acc)
                c.dot(x, y + 1, scale(acc, 0.7)) if y + 1 < 16 and c.mask[y + 1][x] else None
    if detail == "spikes":
        for x in (2, 5, 8, 11, 14):
            c.fill(x, 0, x, 1, hexc("#9aa0a8"))
            c.mask[0][x] = c.mask[1][x] = True
    if detail == "patch":
        c.fill(5, 6, 10, 9, acc)
        c.dot(7, 7, hexc("#202020")); c.dot(8, 8, hexc("#202020"))
    if detail == "seams":
        for y in range(3, bottom + 1):
            c.dot(4, y, acc); c.dot(11, y, acc)
    if detail == "zip":
        for y in range(4, bottom):
            c.dot(7, y, acc)
    c.outline()
    return c.im


def bottoms(kind, col, detail=None, accent="#e8e0d0"):
    """kind: trousers, shorts, skirt."""
    base = hexc(col)
    acc = hexc(accent)
    c = Canvas()
    leg_end = 8 if kind == "shorts" else 14
    if kind == "skirt":
        c.fill(3, 2, 12, 3, base)
        c.fill(2, 4, 13, 10, base)
    else:
        c.fill(3, 1, 12, 4, base)
        c.fill(3, 5, 7, leg_end, base)
        c.fill(8, 5, 12, leg_end, base)
        c.clear(7, 7, 8, leg_end)
        c.fill(7, 5, 7, 6, base)
    c.shade(base)
    dark = scale(base, 0.62)
    # waistband
    for x in range(3, 13):
        if c.mask[2 if kind == "skirt" else 1][x]:
            c.dot(x, 2 if kind == "skirt" else 1, dark)
    if detail == "cargo":
        c.fill(3, 8, 4, 10, dark); c.fill(11, 8, 12, 10, dark)
    if detail == "knees":
        c.fill(4, 9, 6, 10, acc); c.fill(9, 9, 11, 10, acc)
    if detail == "stripe":
        for y in range(2, leg_end + 1):
            c.dot(3, y, acc); c.dot(12, y, acc)
    if detail == "chaps":
        c.fill(3, 5, 6, leg_end - 1, acc); c.fill(9, 5, 12, leg_end - 1, acc)
    if detail == "plates":
        c.fill(3, 7, 6, 11, acc); c.fill(9, 7, 12, 11, acc)
        c.dot(4, 8, dark); c.dot(10, 8, dark)
    if detail == "straps":
        c.fill(4, 0, 4, 1, acc); c.fill(11, 0, 11, 1, acc)
        c.mask[0][4] = c.mask[0][11] = True
    if detail == "plaid":
        for y in range(1, 15):
            for x in range(2, 14):
                if c.mask[y][x] and (x % 3 == 1 or y % 3 == 1):
                    c.dot(x, y, scale(c.px[x, y], 0.75) if c.px[x, y][3] else c.px[x, y])
    if detail == "stripes":
        for y in range(1, 15):
            for x in range(2, 14):
                if c.mask[y][x] and x % 2 == 0:
                    c.dot(x, y, scale(c.px[x, y], 1.2))
    if detail == "wash":
        for x, y in [(4, 5), (5, 8), (10, 6), (11, 11), (4, 12), (9, 13), (6, 3), (10, 3)]:
            if c.mask[y][x]:
                c.dot(x, y, acc)
    if detail == "number":
        c.fill(9, 6, 11, 9, acc)
    c.outline()
    return c.im


TOPS = {
    "t_shirt": ("tee", "#b8b8b0"), "hoodie": ("hoodie", "#6a7a8a"), "flannel_shirt": ("long", "#a83a2a", "plaid"),
    "denim_jacket": ("jacket", "#4a6a9a"), "hunting_vest": ("vest", "#d86a2a"), "hazmat_jacket": ("jacket", "#e8d040", "seams", "#e8783a"),
    "leather_jacket": ("jacket", "#4a3028"), "police_vest": ("carrier", "#2a3448"), "firefighter_coat": ("coat", "#3a3a30", "stripes", "#e8d040"),
    "military_plate_carrier": ("carrier", "#5a6a3a"), "padded_hoodie": ("hoodie", "#4a5a6a"), "camo_hunting_vest": ("vest", "#5a6a3a", "camo", "#3a3a24"),
    "lined_leather_jacket": ("jacket", "#5a3a28", "zip", "#c8b8a0"), "reinforced_police_vest": ("carrier", "#1e2636"),
    "upgraded_plate_carrier": ("carrier", "#4a5a30"), "ghillie_wrap": ("coat", "#4a5a2a", "tufts", "#7a8a3a"),
    "bikers_kutte": ("vest", "#2a2424", "patch", "#c8b8a0"), "juggernaut_riot_suit": ("carrier", "#23262c", "spikes"),
    "the_briar_king": ("carrier", "#3a3028", "spikes"), "quarantine": ("coat", "#e8e8e0", "seams", "#e8783a"),
    "hawaiian_shirt": ("tee", "#3a9ac8", "flowers", "#f8e070"), "tuxedo_jacket": ("suit", "#1e1e24"),
    "burger_mascot_suit": ("tee", "#e8902a", "print", "#a8402a"), "band_tee": ("tee", "#222226", "print", "#e8e0d0"),
    "lab_coat": ("coat", "#ececec"),
}
BOTTOMS = {
    "running_shorts": ("shorts", "#3a5aa8", "stripe"), "sweatpants": ("trousers", "#7a7a80"), "snow_pants": ("trousers", "#3a6aa8", "knees", "#2a3a5a"),
    "jeans": ("trousers", "#3a5a8a"), "cargo_pants": ("trousers", "#7a7048", "cargo"), "canvas_work_pants": ("trousers", "#a8885a", "knees", "#6a5434"),
    "police_tactical_pants": ("trousers", "#2a3040", "cargo"), "motorcycle_pants": ("trousers", "#2a2424", "knees", "#4a4448"),
    "chainsaw_chaps": ("trousers", "#4a4a4a", "chaps", "#d86a2a"), "military_leg_guards": ("trousers", "#5a6a3a", "plates", "#3a4428"),
    "reinforced_jeans": ("trousers", "#34507a", "knees", "#6a6a6a"), "deep_pocket_cargo_pants": ("trousers", "#6a6440", "cargo"),
    "lightweight_tactical_pants": ("trousers", "#4a4a3a", "cargo"), "padded_motorcycle_pants": ("trousers", "#222226", "plates", "#3a3a3a"),
    "reinforced_chainsaw_chaps": ("trousers", "#3a3a3a", "chaps", "#c84a1a"), "compression_leggings": ("trousers", "#26262c", "stripe", "#3aa8c8"),
    "fishermans_waders": ("trousers", "#4a6a3a", "straps", "#3a3a30"), "kneecapper_guards": ("trousers", "#3a3a40", "plates", "#8a8a90"),
    "appointed_rounds": ("trousers", "#4a6a9a", "stripe", "#1a1a1a"), "wrecker": ("trousers", "#6a4a3a", "number", "#d8c8a0"),
    "kilt": ("skirt", "#3a6a3a", "plaid"), "pajama_pants": ("trousers", "#8a9ad8", "stripes"), "tuxedo_pants": ("trousers", "#1e1e24", "stripe", "#3a3a40"),
    "plaid_golf_pants": ("trousers", "#c8b040", "plaid"), "acid_wash_jeans": ("trousers", "#7a9ac8", "wash", "#e8f0f8"),
}


def make_top(iid):
    spec = TOPS[iid]
    return top(spec[0], spec[1], spec[2] if len(spec) > 2 else None, spec[3] if len(spec) > 3 else "#e8e0d0")


def make_bottom(iid):
    spec = BOTTOMS[iid]
    return bottoms(spec[0], spec[1], spec[2] if len(spec) > 2 else None, spec[3] if len(spec) > 3 else "#e8e0d0")
