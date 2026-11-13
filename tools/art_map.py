"""Which part of which sheet becomes which game sprite.
Each entry: output path (under art/), sheet, box (x0, y0, x1, y1), output width, output height (0 = keep aspect),
optional colours, optional flags: "mirror" flips horizontally.
"""
B = "buildings/"; O = "objects/"; T = "trees/"; A = "animals/"; E = "enemies/"; C = "characters/"

## Empty for now: Daniel is redoing the art. Add entries here when new sheets arrive:
## (output path under art/, sheet letter from atlas_tool.SHEETS, (x0, y0, x1, y1) box, width, height)
MAP = []

## Building footprints in tiles (width, height). Art is fitted inside width x (height + 2) tiles.
FOOT = {"farmhouse": (6, 5), "store": (8, 6), "ranch": (8, 6), "tavern": (8, 6), "archive": (9, 6),
        "clinic": (7, 5), "workshop": (7, 5), "guild": (8, 6), "greenhouse": (7, 6), "guild": (8, 6)}
