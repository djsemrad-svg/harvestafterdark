"""Turns the AI-generated pixel sheets in art_source/ into game-ready sprites.

The sheets are painted, not true pixel art, so each sprite is:
  1. cut out (background removed: black, white, fake checkerboard or real alpha),
  2. shrunk to the game's 16 px grid with a box filter,
  3. reduced to a small palette, with hard alpha.

Usage:
  python3 tools/atlas_tool.py segment            # numbered contact sheets in /tmp/seg
  python3 tools/atlas_tool.py build              # writes art/ from tools/art_map.py
"""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_source")
SHEETS = {
    "a": ("sheet_a_retro_tileset.png", "black"),
    "b": ("sheet_b_farm_atlas.png", "checker"),
    "c": ("sheet_c_characters.png", "alpha"),
    "d": ("sheet_d_town_buildings.png", "checker"),
    "e": ("sheet_e_combat_guild.png", "white"),
}
_BG = {}

def sheet_bg(sheet):
    if sheet not in _BG:
        a, mode = load(sheet)
        bg = background(a, mode)
        # clean the halo: pale, grey pixels hugging the background are blended edge pixels
        rgb = a[..., :3].astype(int)
        sat = rgb.max(-1) - rgb.min(-1)
        br = rgb.mean(-1)
        pale = (sat < 40) & (br > 170) if mode != "black" else (rgb.max(-1) < 55)
        for _ in range(3):
            bg = bg | (pale & ndimage.binary_dilation(bg, iterations=1))
        _BG[sheet] = bg
    return _BG[sheet]

def load(sheet):
    f, mode = SHEETS[sheet]
    return np.array(Image.open(os.path.join(SRC, f)).convert("RGBA")), mode

def background(a, mode):
    rgb = a[..., :3].astype(int)
    if mode == "alpha":
        bg = a[..., 3] < 128
        # some sheets also paint a white margin
        return bg | ((rgb.min(-1) > 246) & _border_connected((rgb.min(-1) > 246)))
    if mode == "white":
        sat = rgb.max(-1) - rgb.min(-1)
        white = (sat < 22) & (rgb.mean(-1) > 226)
        return _border_connected(white) | _big_components(white, 300)
    if mode == "black":
        dark = rgb.max(-1) < 30
        return _border_connected(dark) | _big_components(dark, 400)
    # fake checkerboard: alternating light and mid grey squares of ~13 px.
    sat = rgb.max(-1) - rgb.min(-1)
    br = rgb.mean(-1)
    light = (sat < 18) & (br > 238)
    mid = (sat < 18) & (br > 192) & (br < 228)
    ld = ndimage.uniform_filter(light.astype(float), 17)
    md = ndimage.uniform_filter(mid.astype(float), 17)
    bg = (light | mid | ((sat < 18) & (br > 190))) & (ld > 0.15) & (md > 0.15)
    bg = ndimage.binary_closing(bg, iterations=1)
    return bg

def _border_connected(m):
    lab, n = ndimage.label(m)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(edge))

def _big_components(m, area):
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(n + 1))
    return np.isin(lab, [i for i in range(1, n + 1) if sizes[i] >= area])

def segment(sheet, min_area=120):
    a, mode = load(sheet)
    fg = ~background(a, mode)
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=3))
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None: continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        if (y1 - y0) * (x1 - x0) < min_area or fg[y0:y1, x0:x1].sum() < min_area * 0.5: continue
        boxes.append([x0, y0, x1, y1])
    boxes.sort(key=lambda b: (b[1] // 40, b[0]))
    return boxes

def contact(sheet):
    a, mode = load(sheet)
    boxes = segment(sheet)
    im = Image.fromarray(a).convert("RGB")
    d = ImageDraw.Draw(im)
    for i, b in enumerate(boxes):
        d.rectangle(b, outline=(255, 0, 255))
        d.rectangle([b[0], b[1], b[0] + 22, b[1] + 11], fill=(0, 0, 0))
        d.text((b[0] + 1, b[1]), str(i), fill=(255, 255, 0))
    os.makedirs("/tmp/seg", exist_ok=True)
    im.save("/tmp/seg/%s.png" % sheet)
    json.dump(boxes, open("/tmp/seg/%s.json" % sheet, "w"))
    return boxes

def cut(sheet, box, pad=2):
    a, mode = load(sheet)
    x0, y0, x1, y1 = box
    sub = a[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad].copy()
    bg = sheet_bg(sheet)[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad]
    sub[bg, 3] = 0
    # keep only the biggest connected piece plus anything touching it (drops neighbours' slivers)
    fg = sub[..., 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=2))
    if n > 1:
        sizes = ndimage.sum(fg, lab, range(n + 1))
        keep = lab == int(np.argmax(sizes[1:]) + 1)
        sub[~keep, 3] = 0
    ys, xs = np.where(sub[..., 3] > 0)
    return sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

def shrink(rgba, w, h, colors=32, alpha_cut=120):
    f = rgba.astype(float)
    al = f[..., 3:4] / 255.0
    f[..., :3] *= al
    small = np.array(Image.fromarray(f.clip(0, 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(float)
    alpha = small[..., 3:4] / 255.0
    rgb = np.where(alpha > 0, small[..., :3] / np.maximum(alpha, 1e-3), 0).clip(0, 255).astype(np.uint8)
    keep = small[..., 3] > alpha_cut
    q = np.array(Image.fromarray(rgb).quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB"))
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = q
    out[..., 3] = keep * 255
    # small pale specks are background showing through gaps
    rgbf = out[..., :3].astype(int)
    pale = keep & ((rgbf.max(-1) - rgbf.min(-1)) < 30) & (rgbf.mean(-1) > 200)
    lab, n = ndimage.label(pale)
    if n:
        sizes = ndimage.sum(pale, lab, range(n + 1))
        small_pale = np.isin(lab, [i for i in range(1, n + 1) if sizes[i] <= 3])
        out[small_pale, 3] = 0
        keep = keep & ~small_pale
    # pale pixels on the outer edge are leftover background
    for _ in range(2):
        rgbf = out[..., :3].astype(int)
        edge = keep & ndimage.binary_dilation(~keep, iterations=1)
        pale_edge = edge & ((rgbf.max(-1) - rgbf.min(-1)) < 34) & (rgbf.mean(-1) > 190)
        out[pale_edge, 3] = 0
        keep = keep & ~pale_edge
    # remove lonely pixels at the edge (background specks)
    lone = keep & (ndimage.convolve(keep.astype(int), np.ones((3, 3)), mode="constant") <= 2)
    out[lone, 3] = 0
    return out

def build(out_dir=os.path.join(ROOT, "art")):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import art_map
    n = 0
    for path, sheet, box, w, h, *rest in art_map.MAP:
        rgba = cut(sheet, box)
        sh, sw = rgba.shape[:2]
        if path.startswith("buildings/"):
            kind = os.path.basename(path)[:-4].rsplit("_", 1)[0] if os.path.basename(path)[:-4].rsplit("_", 1)[-1].isdigit() else os.path.basename(path)[:-4]
            fw, fh = art_map.FOOT[kind]
            scale = min(fw * 16 / sw, (fh + 2) * 16 / sh)
            w, h = max(1, round(sw * scale)), max(1, round(sh * scale))
        elif not h:
            h = max(1, round(sh * w / sw))
        elif not w:
            w = max(1, round(sw * h / sh))
        img = shrink(rgba, w, h)
        dest = os.path.join(out_dir, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        Image.fromarray(img).save(dest)
        n += 1
    print("wrote", n, "sprites to", out_dir)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "segment"
    if cmd == "segment":
        for s in (sys.argv[2:] or SHEETS.keys()):
            print(s, len(contact(s)))
    elif cmd == "build":
        build()
