"""LimeZu's Modern Office, Kitchen and more, and Serene Village packs (Nov 22).
Run from import_packs.py with SRC, OUT, save and mute, or alone: python3 tools/limezu_more.py <packs> <art>.

Replaces art that came from other packs:
  rock, rock2 (PostApocalypse)          -> Serene Village field rocks
  vending_machine_0-3 (PostApocalypse)  -> Modern Office vending machines, a little dusty
  mailbox_0-3 (Modern Exteriors bird houses, which never looked like mailboxes) -> Serene Village mailboxes

Adds furniture:
  Office:  office_desk_0-3 (2 wide, desk with computer and chair), copier_0-1, water_cooler, filing_cabinet,
           whiteboard_0-2 (2 wide, on a wall), office_plant_0-2, office_sofa (2 wide), certificate_0-2 (wall)
  Kitchen: lounge_chair_0-3 (armchairs in four colours), potted_plant_0-2, wall_tv (2 wide, wall),
           picture_frame_0-2 (wall), microwave (on a counter)
  Serene:  planter_0-3 (flower boxes for Brightwater's streets)
"""
import os
import sys
from PIL import Image, ImageEnhance

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

    def mute(im, amt=0.15):
        return im

OFFICE = os.path.join(SRC, "Modern_Office_Revamped_v1.2", "4_Modern_Office_singles", "16x16")
KITCHEN = os.path.join(SRC, "Kitchen_and_more_tileset_16x16", "Kitchen and more tileset [16x16]", "tileset.png")
SERENE = os.path.join(SRC, "Serene_Village_revamped_v1.9", "SERENE_VILLAGE_REVAMPED", "Serene_Village_16x16.png")


def trim(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def office(n):
    return trim(Image.open(os.path.join(OFFICE, "Modern_Office_Singles_%d.png" % n)).convert("RGBA"))


def blob(sheet, px, py, box=None):
    """The connected piece of art (8-way, by alpha) that holds pixel (px, py), inside box if given."""
    a = sheet.load()
    x0, y0, x1, y1 = box or (0, 0, sheet.width, sheet.height)
    seen = {(px, py)}
    todo = [(px, py)]
    while todo:
        x, y = todo.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q in seen or not (x0 <= q[0] < x1 and y0 <= q[1] < y1) or a[q][3] == 0:
                    continue
                seen.add(q)
                todo.append(q)
    xs = [q[0] for q in seen]
    ys = [q[1] for q in seen]
    out = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
    for q in seen:
        out.putpixel((q[0] - min(xs), q[1] - min(ys)), a[q])
    return out


def cell(sheet, cx, cy, w=1, h=1):
    """Whole 16 px cells, trimmed."""
    return trim(sheet.crop((cx * 16, cy * 16, (cx + w) * 16, (cy + h) * 16)))


def save4(ims, name):
    """Objects pick a look 0-3 by where they stand: fewer pictures than that are used in turn."""
    for v in range(4):
        save(ims[v % len(ims)], "objects/%s_%d.png" % (name, v))


def dusty(im, amt=0.18):
    """Left alone for months: a little greyer and darker."""
    im = ImageEnhance.Color(im).enhance(1 - amt)
    return ImageEnhance.Brightness(im).enhance(1 - amt / 3)


def first_opaque(sheet, cx, cy):
    """Some opaque pixel inside a cell (blob needs a seed that is art, not air)."""
    a = sheet.load()
    for y in range(cy * 16, cy * 16 + 16):
        for x in range(cx * 16, cx * 16 + 16):
            if a[x, y][3] > 0:
                return x, y
    raise ValueError("empty cell %d,%d" % (cx, cy))


def piece(sheet, cx, cy, box=None):
    x, y = first_opaque(sheet, cx, cy)
    return blob(sheet, x, y, box)


if os.path.isdir(OFFICE):
    for v, n in enumerate([175, 176, 174, 175]):
        im = office(n)
        save(dusty(im) if v != 3 else dusty(im.transpose(Image.FLIP_LEFT_RIGHT), 0.3), "objects/vending_machine_%d.png" % v)
    for v, n in enumerate([324, 320, 326, 322]):
        save(office(n), "objects/office_desk_%d.png" % v)
    save4([office(147), office(150)], "copier")
    save(office(173), "objects/water_cooler.png")
    save(office(168), "objects/filing_cabinet.png")
    save4([office(n) for n in [170, 171, 172]], "whiteboard")
    save4([office(n) for n in [98, 99, 100]], "office_plant")
    save(office(200), "objects/office_sofa.png")
    save4([office(n) for n in [113, 114, 115]], "certificate")

if os.path.isfile(KITCHEN):
    ks = Image.open(KITCHEN).convert("RGBA")
    # armchairs: column 4, one colour every two rows from row 26 (white, grey, green, pink, blue, red)
    for v, row in enumerate([30, 34, 32, 36]):
        save(piece(ks, 4, row, (64, row * 16 - 16, 96, row * 16 + 16)), "objects/lounge_chair_%d.png" % v)
    save4([cell(ks, 0, 15, 1, 2), cell(ks, 1, 16), cell(ks, 2, 15)], "potted_plant")
    save(cell(ks, 5, 15, 2, 1), "objects/wall_tv.png")
    save4([cell(ks, 5, 16), cell(ks, 6, 16), cell(ks, 7, 16)], "picture_frame")
    save(cell(ks, 5, 11, 1, 2), "objects/microwave.png")

if os.path.isfile(SERENE):
    sv = Image.open(SERENE).convert("RGBA")
    save(piece(sv, 1, 15), "objects/rock.png")
    save(cell(sv, 2, 15), "objects/rock2.png")
    for v, (cx, cy) in enumerate([(7, 16), (8, 16), (7, 17), (8, 17)]):
        save(cell(sv, cx, cy), "objects/mailbox_%d.png" % v)
    for v, cx in enumerate([4, 5, 6]):
        save(cell(sv, cx, 18), "objects/planter_%d.png" % v)
    save(cell(sv, 4, 18).transpose(Image.FLIP_LEFT_RIGHT), "objects/planter_3.png")
