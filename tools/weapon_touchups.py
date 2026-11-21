"""Claude's touch-ups to Daniel's Weapons v14 art (agreed Nov 17).

- Scythes: a curved blade at the top of the pole instead of a straight spear tip (held picture and icon).
- Crowbars: a clear hook at the top and a split claw at the bottom (held picture).
- Hunting Bow, Recurve Bow, Laminated Recurve Bow and Ash Hunting Bow: the same dark wood as the other bows.
- Slingshots: a Y-shaped fork with its band, so they no longer read as pistols (held picture).

Each function takes the pack's picture and returns the touched-up one (PIL RGBA).
"""
from PIL import Image

HELD_OUTLINE = (0x31, 0x2D, 0x3A, 255)
ICON_OUTLINE = (0x2D, 0x2A, 0x3B, 255)


def _rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def _outline(im, oc):
    """A 1-pixel outline around everything drawn (4 directions)."""
    out = im.copy()
    w, h = im.size
    px = im.load()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                    po[x, y] = oc
                    break
    return out


def _paint(size, cells, pal):
    """cells: {(x, y): letter}; pal: {letter: '#rrggbb'}."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for (x, y), k in cells.items():
        im.putpixel((x, y), _rgb(pal[k]))
    return im


# ---------------------------------------------------------------- scythes
SCYTHE_PAL = {
    "scythe": {"c": "#707988", "e": "#ccd4de", "d": "#a87b56", "b": "#5e3f2a", "x": "#707988"},
    "balanced_scythe": {"c": "#707988", "e": "#ccd4de", "d": "#a87b56", "b": "#5e3f2a", "x": "#7fa7e1"},
    "gleaner": {"c": "#d5b754", "e": "#eef1f5", "d": "#a87b56", "b": "#5e3f2a", "x": "#d5b754"},
    "last_harvest": {"c": "#815bab", "e": "#eef1f5", "d": "#a87b56", "b": "#5e3f2a", "x": "#d5b754"},
}


def scythe_held(wid):
    cells = {}
    # the blade: a crescent along the top, sweeping back from the pole to a point
    for x in range(12, 22): cells[(x, 2)] = "c"
    for x in range(9, 12): cells[(x, 3)] = "c"
    for x in range(12, 20): cells[(x, 3)] = "e"
    for x in range(20, 22): cells[(x, 3)] = "x"
    for x in range(7, 9): cells[(x, 4)] = "c"
    for x in range(9, 12): cells[(x, 4)] = "e"
    cells[(6, 5)] = "c"
    for x in range(7, 9): cells[(x, 5)] = "e"
    cells[(6, 6)] = "e"
    # the pole, rising from the grip in the bottom left
    pole = {4: (19, 21), 5: (18, 20), 6: (16, 19), 7: (15, 17), 8: (13, 16), 9: (10, 13), 10: (7, 10), 11: (5, 7), 12: (4, 5)}
    for y, (a, b) in pole.items():
        for x in range(a, b): cells[(x, y)] = "d"
    for y in (11, 12, 13):
        for x in range(1, 4): cells[(x, y)] = "b"
    return _outline(_paint((24, 16), cells, SCYTHE_PAL[wid]), HELD_OUTLINE)


def scythe_icon(wid):
    cells = {}
    for x in range(5, 14): cells[(x, 2)] = "c"
    for x in range(3, 5): cells[(x, 3)] = "c"
    for x in range(5, 11): cells[(x, 3)] = "e"
    cells[(2, 4)] = "c"
    for x in range(3, 5): cells[(x, 4)] = "e"
    cells[(2, 5)] = "e"
    # the pole on the diagonal, grip bottom left
    for i, (x, y) in enumerate([(13, 3), (12, 4), (11, 5), (10, 6), (9, 7), (8, 8), (7, 9), (6, 10), (5, 11), (4, 12), (3, 13), (2, 14)]):
        k = "x" if i == 0 else ("d" if i < 8 else "b")
        cells[(x, y)] = k
        if i > 0 and x + 1 < 16 and (x + 1, y) not in cells: cells[(x + 1, y)] = k
    return _outline(_paint((16, 16), cells, SCYTHE_PAL[wid]), ICON_OUTLINE)


# ---------------------------------------------------------------- crowbars
CROWBAR_PAL = {
    "crowbar": {"c": "#ccd4de", "b": "#4f5864", "x": "#4f5864"},
    "reinforced_crowbar": {"c": "#eef1f5", "b": "#707988", "x": "#d5b754"},
}


def crowbar_held(wid):
    cells = {}
    for x in range(3, 18):
        y = round(12 - (x - 3) * 8 / 14)
        cells[(x, y)] = "c"
        cells[(x, y + 1)] = "b"
    # the hook curls over the top and down
    for p in [(18, 3), (19, 2), (20, 2), (21, 3), (22, 4)]: cells[p] = "c"
    for p in [(18, 4), (19, 3), (20, 3), (21, 4), (22, 5), (22, 6)]: cells[p] = "b"
    # a split claw at the bottom end
    for p in [(2, 12), (1, 12)]: cells[p] = "c"
    for p in [(2, 14), (1, 14)]: cells[p] = "b"
    cells.pop((2, 13), None)
    # a grip band (gold on the reinforced one)
    for p in [(7, 10), (7, 11), (8, 10), (8, 11)]: cells[p] = "x"
    return _outline(_paint((24, 16), cells, CROWBAR_PAL[wid]), HELD_OUTLINE)


# ---------------------------------------------------------------- bows
BOW_WOOD = {(0x7C, 0x57, 0x3A): (0x5E, 0x3F, 0x2A)}   # the light wood becomes the darker wood the other bows use
RECOLOUR_BOWS = ["hunting_bow", "recurve_bow", "laminated_recurve_bow", "ash_hunting_bow"]


def bow_held(im):
    im = im.convert("RGBA").copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in BOW_WOOD:
                px[x, y] = BOW_WOOD[(r, g, b)] + (a,)
    return im


# ---------------------------------------------------------------- slingshots
SLING_PAL = {
    "slingshot": {"a": "#7a3934", "w": "#eef1f5", "s": "#ccd4de"},
    "ball_bearing_slingshot": {"a": "#505157", "w": "#eef1f5", "s": "#ccd4de"},
    "firestarter_slingshot": {"a": "#b34828", "w": "#eef1f5", "s": "#f98a39"},
    "bile_sling": {"a": "#5b7e4c", "w": "#eef1f5", "s": "#77c45f"},
}


def sling_held(wid):
    """Flat colours like the pack's other projectile weapons: handle to the left, fork opening to the right."""
    cells = {}
    for y in (8, 9):
        for x in range(3, 10): cells[(x, y)] = "a"
    up = [(9, 7), (10, 7), (10, 6), (11, 6), (11, 5), (12, 5), (12, 4), (13, 4)]
    for x, y in up:
        cells[(x, y)] = "a"
        cells[(x, 17 - y)] = "a"
    # the band, pulled back a little, with a stone in the pouch
    for p in [(13, 5), (12, 6), (12, 7), (12, 10), (12, 11), (13, 12)]: cells[p] = "w"
    cells[(11, 8)] = "w"; cells[(11, 9)] = "w"
    cells[(12, 8)] = "s"; cells[(12, 9)] = "s"
    return _paint((24, 16), cells, SLING_PAL[wid])
