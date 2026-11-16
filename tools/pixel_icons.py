"""Pixel-art helpers for tools/import_packs.py: cut sprites out of sheets, shrink without losing thin parts,
rotate to the diagonal and outline. Used for weapon icons."""
import sys
from PIL import Image
import numpy as np
from scipy import ndimage

def comps(path, minpx=20):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)[:, :, 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=1))
    out = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        crop = np.array(im)[s].copy()
        crop[lab[s] != i + 1] = 0
        crop[~(crop[:, :, 3] > 0)] = 0
        if (crop[:, :, 3] > 0).sum() >= minpx:
            out.append(((s[1].start, s[0].start), Image.fromarray(crop)))
    return out

def palette_of(im):
    a = np.array(im)
    px = a[a[:, :, 3] > 0][:, :3]
    return np.unique(px, axis=0)

def snap(im, pal):
    a = np.array(im).astype(int)
    m = a[:, :, 3] > 110
    rgb = a[:, :, :3]
    d = ((rgb[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
    idx = d.argmin(-1)
    out = np.zeros_like(a)
    out[:, :, :3] = pal[idx]
    out[:, :, 3] = np.where(m, 255, 0)
    return Image.fromarray(out.astype(np.uint8))

def diag_icon(sprite, size=16, angle=45):
    """Lay a horizontal (barrel/blade right) sprite on the diagonal, fit to size x size."""
    pal = palette_of(sprite)
    big = sprite.resize((sprite.width * 8, sprite.height * 8), Image.NEAREST)
    rot = big.rotate(angle, resample=Image.BICUBIC, expand=True)
    rot = rot.crop(rot.getbbox())
    k = min(size / rot.width, size / rot.height) * 8 if False else None
    s = min((size * 8) / rot.width, (size * 8) / rot.height)
    w, h = max(1, round(rot.width * s / 8)), max(1, round(rot.height * s / 8))
    small = rot.resize((w, h), Image.LANCZOS)
    small = snap(small, pal)
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c.alpha_composite(small, ((size - w) // 2, (size - h) // 2))
    return c


def _lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]

def outline_colour(sprite):
    a = np.array(sprite)
    m = a[:, :, 3] > 0
    # pixels next to transparency are the outline
    pad = np.pad(m, 1)
    edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    cols, cnt = np.unique(a[edge][:, :3], axis=0, return_counts=True)
    return tuple(cols[cnt.argmax()]) if len(cols) else (30, 30, 30)

def shrink(sprite, w, h, cover=0.3, reoutline=True):
    """Pixel-art aware downscale: keeps thin parts (barrels), fills with the block's main colour, re-outlines."""
    a = np.array(sprite).astype(int)
    H, W = a.shape[:2]
    oc = np.array(outline_colour(sprite))
    out = np.zeros((h, w, 4), int)
    for y in range(h):
        y0, y1 = int(y * H / h), max(int(y * H / h) + 1, int((y + 1) * H / h))
        for x in range(w):
            x0, x1 = int(x * W / w), max(int(x * W / w) + 1, int((x + 1) * W / w))
            blk = a[y0:y1, x0:x1].reshape(-1, 4)
            op = blk[blk[:, 3] > 0]
            if len(op) == 0 or len(op) / len(blk) < cover:
                continue
            inner = op[(np.abs(op[:, :3] - oc).sum(1) > 30)]
            src = inner if len(inner) else op
            cols, cnt = np.unique(src[:, :3], axis=0, return_counts=True)
            out[y, x, :3] = cols[cnt.argmax()]
            out[y, x, 3] = 255
    m = out[:, :, 3] > 0
    pad = np.pad(m, 1)
    edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    # outline only where the shape is thick enough to keep some colour inside
    thick = m & pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    if reoutline and thick.sum() > 0:
        out[edge, :3] = oc
    return Image.fromarray(out.astype(np.uint8))

def add_outline(im, oc):
    a = np.array(im).astype(int)
    m = a[:, :, 3] > 0
    pad = np.pad(m, 1)
    ring = ~m & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
    a[ring, :3] = oc
    a[ring, 3] = 255
    return Image.fromarray(a.astype(np.uint8))

def rot45(im, angle=45):
    """Rotate small pixel art: 8x up, rotate nearest, 8x down by majority."""
    big = im.resize((im.width * 8, im.height * 8), Image.NEAREST)
    r = big.rotate(angle, resample=Image.NEAREST, expand=True)
    r = r.crop(r.getbbox())
    w, h = (r.width + 7) // 8, (r.height + 7) // 8
    c = Image.new('RGBA', (w * 8, h * 8), (0, 0, 0, 0))
    c.alpha_composite(r, (0, 0))
    return shrink(c, w, h, cover=0.4, reoutline=False)

def icon16(sprite, angle=45, size=16, inner=False):
    """Sprite pointing right (or tip up with angle=-45) -> fitted diagonal 16x16 icon with a dark outline."""
    oc = outline_colour(sprite)
    a = np.array(sprite).astype(int)
    # drop the pack's own outline, shrink the colours, then draw a fresh 1px outline around the result
    m = a[:, :, 3] > 0
    core = a.copy()
    isout = m & (np.abs(a[:, :, :3] - np.array(oc)).sum(-1) <= 30)
    keep_out = isout.sum() < 0.6 * m.sum()
    if keep_out and not inner:
        core[isout, 3] = 0
    core = Image.fromarray(core.astype(np.uint8))
    bb = core.getbbox() or (0, 0, 1, 1)
    core = core.crop(bb)
    test = core.rotate(angle, expand=True)
    tb = test.getbbox()
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    k = min(1.0, (size - 2) / max(tw, th))
    sp = core if k >= 0.999 else shrink(core, max(1, round(core.width * k)), max(1, round(core.height * k)), cover=0.25, reoutline=False)
    r = rot45(sp, angle) if angle else sp
    r = r.crop(r.getbbox())
    r2 = Image.new('RGBA', (r.width + 2, r.height + 2), (0, 0, 0, 0))
    r2.alpha_composite(r, (1, 1))
    r = add_outline(r2, oc)
    if r.width > size or r.height > size:
        r = shrink(r, min(size, r.width), min(size, r.height), reoutline=False)
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c.alpha_composite(r, ((size - r.width) // 2, (size - r.height) // 2))
    return c
