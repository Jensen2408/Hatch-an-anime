"""Build the Character Index menu art straight from the mockup (assets/ui/index/index_reference.png).

usage (from the project root):
    python -I assets/ui/index/build_index_atlas.py assets/ui/index/index_reference.png assets/ui/index src/client/UI/Screens/GameMenus/IndexAtlas.luau

Outputs, all stored at SCALE (Roblox keeps uploaded images at most 1024 px):
    index_background.png  the panel with the scene behind it removed and every changing part painted out
    index_pieces.png      atlas of the parts drawn on top (cards, badges, tabs, buttons, chests, ...)
    IndexAtlas.luau       generated: piece rects in atlas pixels + their size in mockup pixels
Coordinates below are mockup pixels (1270 x 854 image; the canvas is its top 1270 x 840).
"""
import colorsys
import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REF, OUT_DIR, OUT_LUA = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
REF_A = np.asarray(Image.open(REF).convert("RGB")).astype(np.int32)
H, W = REF_A.shape[:2]
CANVAS = (1270, 840)
SCALE = 1024 / CANVAS[0]
PANEL_PX = 25  # stud period of the purple panel (horizontal)
CARD_PX, CARD_PY = 20, 22.6  # stud period inside the cards


# ---------- helpers ----------
def box_mask(boxes, shape=(H, W)):
    m = np.zeros(shape, bool)
    for x0, y0, x1, y1 in boxes:
        m[y0:y1, x0:x1] = True
    return m


def shift_fill(img, hole, region, shifts):
    """Fill `hole` pixels from pixels `shift` away that are inside `region` and not holes (first shift wins)."""
    img = img.copy()
    clean = region & ~hole
    ys, xs = np.nonzero(hole)
    for dx, dy in shifts:
        if not len(ys):
            break
        sx, sy = xs + dx, ys + dy
        ok = (sx >= 0) & (sx < img.shape[1]) & (sy >= 0) & (sy < img.shape[0])
        ok[ok] = clean[sy[ok], sx[ok]]
        img[ys[ok], xs[ok]] = img[sy[ok], sx[ok]]
        ys, xs = ys[~ok], xs[~ok]
    if len(ys):
        print("  shift_fill: %d px left unfilled" % len(ys))
    return img


def panel_shifts(limit=50):
    return [(k * PANEL_PX * s, 0) for k in range(1, limit) for s in (-1, 1)]


def card_shifts():
    out = []
    for m in range(0, 9):
        for k in range(0, 10):
            for sx in (1, -1):
                for sy in (1, -1):
                    if k or m:
                        out.append((sx * k * CARD_PX, sy * round(m * CARD_PY)))
    out = sorted(set(out), key=lambda d: abs(d[0]) + abs(d[1]))
    return out


TAB_PX = 20.85  # stud period of the tab buttons


def stud_blank(tab, hole):
    """The tab with `hole` (icon + label) refilled from its own studs, one or more periods left / right."""
    shifts = [(round(k * TAB_PX) * s, 0) for k in range(1, 20) for s in (-1, 1)]
    x0, y0, x1, y1 = tab
    return shift_fill(REF_A, box_mask([hole]), box_mask([(x0 + 4, y0 + 3, x1 - 4, y1 - 3)]), shifts)


def row_fill(img, box, sample_cols):
    """Replace box with the per-row median of the sample columns."""
    img = img.copy()
    x0, y0, x1, y1 = box
    cols = [x for a, b in sample_cols for x in range(a, b)]
    for y in range(y0, y1):
        img[y, x0:x1] = np.median(img[y, cols], axis=0)
    return img


def flat_face(img, box, cols, tolerance=8):
    """Per row: median of the pixels within `tolerance` of the face colour (skips text, icons and studs)."""
    img = img.copy()
    x0, y0, x1, y1 = box
    face = np.median(img[y0:y1, cols[0] : cols[1]].reshape(-1, 3), axis=0)
    for y in range(y0, y1):
        px = img[y, cols[0] : cols[1]]
        near = px[np.abs(px - face).max(axis=1) <= tolerance]
        img[y, x0:x1] = np.median(near, axis=0) if len(near) else face
    return img


def matte(orig, clean, box, low=14, high=44):
    """RGBA piece: the mockup's pixels, alpha from how far they are from the painted-out background."""
    x0, y0, x1, y1 = box
    o, c = orig[y0:y1, x0:x1], clean[y0:y1, x0:x1]
    diff = np.abs(o - c).max(axis=2)
    alpha = np.clip((diff - low) / (high - low), 0, 1)
    return Image.fromarray(np.dstack([o, (alpha * 255).astype(np.int32)]).astype(np.uint8), "RGBA")


def outline_matte(img, box, dark=40, min_area=30):
    """RGBA piece cut along its dark outline: everything enclosed by (and including) the outline is kept."""
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1]
    h, w = region.shape[:2]
    is_dark = region.mean(axis=2) < dark
    outside = np.zeros((h, w), bool)
    q = deque([(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)])
    while q:
        y, x = q.popleft()
        if outside[y, x] or is_dark[y, x]:
            continue
        outside[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx]:
                q.append((ny, nx))
    keep = ~outside
    # drop specks (dark stud pixels that touch nothing): parts smaller than min_area
    seen = np.zeros((h, w), bool)
    for sy, sx in zip(*np.nonzero(keep)):
        if seen[sy, sx]:
            continue
        part, q = [], deque([(sy, sx)])
        seen[sy, sx] = True
        while q:
            y, x = q.popleft()
            part.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and keep[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(part) < min_area:
            for y, x in part:
                keep[y, x] = False
    alpha = Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5))
    return crop(img, box, alpha)


def matte_flat(box, colour, low=30, high=60):
    flat = np.broadcast_to(np.array(colour), REF_A.shape).astype(np.int32)
    return matte(REF_A, flat, box, low, high)


def crop(img, box, alpha=None):
    x0, y0, x1, y1 = box
    rgba = Image.fromarray(img[y0:y1, x0:x1].astype(np.uint8), "RGB").convert("RGBA")
    if alpha is not None:
        rgba.putalpha(alpha)
    return rgba


def rounded_alpha(size, radius, scale=4):
    from PIL import ImageDraw

    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return big.resize(size, Image.LANCZOS)


def hue_shift(rgba, target_hue, min_sat=0.25):
    """Moves the hue of the saturated pixels to target_hue (0..1), keeping their saturation / value."""
    arr = np.asarray(rgba).astype(np.float64) / 255
    out = arr.copy()
    flat = arr[..., :3].reshape(-1, 3)
    res = out[..., :3].reshape(-1, 3)
    for i, (r, g, b) in enumerate(flat):
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s >= min_sat:
            res[i] = colorsys.hsv_to_rgb(target_hue, s, v)
    out[..., :3] = res.reshape(arr[..., :3].shape)
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


def tint(rgba, src_face, dst_face):
    """Per channel scale so src_face becomes dst_face (keeps the shading / studs)."""
    arr = np.asarray(rgba).astype(np.float64)
    ratio = np.array(dst_face, float) / np.maximum(np.array(src_face, float), 1)
    arr[..., :3] = np.clip(arr[..., :3] * ratio, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def median_colour(box):
    x0, y0, x1, y1 = box
    return np.median(REF_A[y0:y1, x0:x1].reshape(-1, 3), axis=0)


# ---------- 1. panel mask (the scene behind the mockup) ----------
def panel_mask():
    a = REF_A
    white = (a.min(2) > 170) & ((a.max(2) - a.min(2)) < 70)
    barrier = np.asarray(Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    outside = np.zeros((H, W), bool)
    q = deque([(y, x) for x in range(W) for y in (0, H - 1)] + [(y, x) for y in range(H) for x in (0, W - 1)])
    while q:
        y, x = q.popleft()
        if outside[y, x] or barrier[y, x]:
            continue
        outside[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and not outside[ny, nx]:
                q.append((ny, nx))
    keep = ~outside
    # the white outline itself is part of the panel; only keep what touches the centre
    reach = np.zeros((H, W), bool)
    q = deque([(H // 2, W // 2)])
    while q:
        y, x = q.popleft()
        if reach[y, x] or not keep[y, x]:
            continue
        reach[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and not reach[ny, nx]:
                q.append((ny, nx))
    m = Image.fromarray((reach * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    return m.crop((0, 0) + CANVAS)


pieces = {}


def add(name, image):
    pieces[name] = image


bg = REF_A.copy()
panel_region = box_mask([(20, 110, 1250, 765)])

# ---------- 2. season tabs: blanks + icons + labels, the tab row painted to panel ----------
TAB_ORIGINAL, TAB_HALLOWEEN, TAB_WINTER = (77, 124, 433, 180), (443, 120, 834, 182), (843, 124, 1192, 180)
GREY_FACE = median_colour((100, 132, 160, 172))
ORANGE_FACE = median_colour((470, 130, 540, 172))
grey_tab = stud_blank(TAB_ORIGINAL, (160, 128, 356, 177))
orange_tab = stud_blank(TAB_HALLOWEEN, (532, 124, 770, 179))
add("TabOff", crop(grey_tab, TAB_ORIGINAL))
add("TabOn", crop(orange_tab, TAB_HALLOWEEN))
add("IconGlobe", outline_matte(REF_A, (165, 128, 215, 176)))
add("LabelOriginal", outline_matte(REF_A, (228, 134, 350, 170)))
add("IconPumpkin", outline_matte(REF_A, (536, 126, 594, 178)))
add("LabelHalloween", outline_matte(REF_A, (604, 134, 765, 170)))

# ---------- 3. collection bar: text + fill painted out ----------
BAR = (57, 183, 1212, 221)
add("BarFill", crop(REF_A, (60, 187, 204, 215)))
bg = flat_face(bg, (61, 188, 1207, 216), (300, 460), tolerance=10)

# ---------- 4. search box + filters (re-laid out with Uncommon): the whole toolbar painted to panel ----------
SEARCH = (43, 234, 378, 284)
search_blank = flat_face(REF_A, (92, 240, 372, 278), (290, 370), tolerance=8)
add("SearchBox", crop(search_blank, SEARCH))
add("IconSearch", matte(REF_A, search_blank, (54, 242, 88, 276)))
FILTERS = {  # key -> mockup button (text painted out)
    "All": (387, 236, 467, 282),
    "Common": (473, 236, 567, 282),
    "Rare": (574, 236, 656, 282),
    "Epic": (661, 236, 739, 282),
    "Legendary": (745, 236, 854, 282),
}
for key, (x0, y0, x1, y1) in FILTERS.items():
    face_cols = (x0 + 6, x0 + 14)
    blank = flat_face(REF_A, (x0 + 7, y0 + 5, x1 - 7, y1 - 8), face_cols, tolerance=18)
    add("Filter" + key, crop(blank, (x0, y0, x1, y1)))
add("FilterUncommon", hue_shift(pieces["FilterRare"], 0.33))
add("FilterLimited", hue_shift(pieces["FilterRare"], 0.13))
bg = row_fill(bg, (38, 230, 864, 288), [(377, 386), (468, 472), (568, 573), (657, 660), (740, 744)])

# ---------- 5. cards ----------
CARDS = {
    "Selected": (44, 296, 239, 521),
    "Rare": (251, 296, 443, 521),
    "Epic": (455, 296, 646, 521),
    "Locked": (659, 296, 852, 521),
}
CARD_BOX = CARDS["Locked"]
CARD_SIZE = (CARD_BOX[2] - CARD_BOX[0], CARD_BOX[3] - CARD_BOX[1])


def blank_locked():
    """Card 4 (locked) with its silhouette, badge and ??? painted out (stud lattice + flat name strip)."""
    img = REF_A.copy()
    x0, y0, x1, y1 = CARD_BOX
    interior = box_mask([(x0 + 7, y0 + 7, x1 - 7, y0 + 186)])
    lum = img.mean(axis=2)
    silhouette = interior & (lum < 40)
    silhouette = np.asarray(Image.fromarray((silhouette * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    badge = box_mask([(787, 302, 849, 336)])
    img = shift_fill(img, (silhouette | badge) & interior, interior, card_shifts())
    img = flat_face(img, (x0 + 14, y0 + 192, x1 - 14, y0 + 214), (x0 + 14, x0 + 40), tolerance=10)
    return img


locked = blank_locked()
card_grey = crop(locked, CARD_BOX)
add("CardLocked", card_grey)
GREY_CARD_FACE = median_colour((662, 450, 676, 470))


def ring_from(box, width=9):
    """The card's outer frame (border + glow) at CARD_SIZE, its inside transparent."""
    piece = crop(REF_A, box).resize(CARD_SIZE, Image.LANCZOS)
    arr = np.asarray(piece).copy()
    w = arr.shape[1]
    arr[: width + 2, w - 95 : w - 16] = arr[: width + 2, 30:31]  # the rarity badge overlaps the top border
    arr[width:-width, width:-width, 3] = 0
    return Image.fromarray(arr, "RGBA")


def card_variant(face_box, ring_box):
    """Grey card's studs tinted to another card's face colour, under that card's own frame."""
    face = median_colour(face_box)
    out = tint(card_grey, GREY_CARD_FACE, face)
    ring = ring_from(ring_box)
    out.alpha_composite(ring)
    return out


add("CardRare", card_variant((256, 440, 266, 470), CARDS["Rare"]))
add("CardEpic", card_variant((460, 440, 470, 470), CARDS["Epic"]))
add("CardCommon", card_grey)
add("CardUncommon", hue_shift(pieces["CardRare"], 0.33, 0.3))
add("CardLegendary", hue_shift(pieces["CardRare"], 0.07, 0.3))
add("CardLimited", hue_shift(pieces["CardRare"], 0.14, 0.3))
# selected: orange studs with a soft centre glow under the gold glowing frame (drawn a little larger)
sel = tint(card_grey, GREY_CARD_FACE, median_colour((48, 440, 58, 470)))
sa = np.asarray(sel).astype(np.float64)
yy, xx = np.mgrid[0 : CARD_SIZE[1], 0 : CARD_SIZE[0]]
glow = np.clip(1 - np.hypot((xx - CARD_SIZE[0] / 2) / 95, (yy - 100) / 110), 0, 1)[..., None]
sa[..., :3] = np.clip(sa[..., :3] + glow * np.array([40, 60, 0]), 0, 255)
sel = Image.fromarray(sa.astype(np.uint8), "RGBA")
strip_alpha = np.asarray(card_grey)[..., 3]
sel.putalpha(Image.fromarray(strip_alpha))
add("CardSelected", sel)
add("SelectedGlow", ring_from((40, 292, 243, 525), width=12))

# badges (text painted out; sized by their text when drawn)
for name, box in (("BadgeGrey", (153, 302, 236, 334)), ("BadgeBlue", (368, 302, 440, 334)), ("BadgeDark", (787, 304, 848, 334))):
    x0, y0, x1, y1 = box
    blank = flat_face(REF_A, (x0 + 8, y0 + 7, x1 - 8, y1 - 7), (x0 + 6, x0 + 10), tolerance=24)
    add(name, crop(blank, box, rounded_alpha((x1 - x0, y1 - y0), 9)))  # pill shape: no card colour in the corners
add("BadgePurple", hue_shift(pieces["BadgeBlue"], 0.78))
add("BadgeGreen", hue_shift(pieces["BadgeBlue"], 0.33))
add("BadgeOrange", hue_shift(pieces["BadgeBlue"], 0.07))
add("BadgeGold", hue_shift(pieces["BadgeBlue"], 0.13))

# the grid area under the cards: one flat colour per row (from the gaps between the cards)
bg = row_fill(bg, (36, 290, 858, 752), [(446, 452), (649, 655), (854, 858)])

# ---------- 6. detail panel: portrait, badge, name and obtain text painted out ----------
DETAIL = (871, 234, 1230, 637)
centre = np.array([1052.0, 365.0])
HOLE = (918, 244, 1192, 500)  # the portrait area (straight up to the name strip)
CENTRE_GLOW = np.array([255.0, 232.0, 120.0])
hx0, hy0, hx1, hy1 = HOLE
for y in range(hy0, hy1):
    for x in range(hx0, hx1):
        d = np.array([x, y], float) - centre
        r = max(np.hypot(*d), 1e-6)
        u = d / r
        # distance along the ray to the hole's edge
        ts = []
        for edge, comp in ((hx0 - 1, 0), (hx1, 0), (hy0 - 1, 1), (hy1, 1)):
            if abs(u[comp]) > 1e-9:
                t = (edge - centre[comp]) / u[comp]
                if t > 0:
                    ts.append(t)
        R = min(ts) if ts else 1.0  # the centre pixel itself
        edge_colour = None
        for mx, my in ((1, 1), (1, -1), (-1, 1), (-1, -1)):  # mirrored rays when the edge isn't sunburst
            v = np.array([u[0] * mx, u[1] * my])
            ex, ey = (centre + v * (R + 2)).round().astype(int)
            ex, ey = min(max(ex, 874), 1226), min(max(ey, 237), 503)
            c = REF_A[ey, ex]
            if c[0] > 150 and c[0] - c[2] > 70 and not (1120 < ex and ey < 280):
                edge_colour = c.astype(float)
                break
        if edge_colour is None:
            edge_colour = np.array([236.0, 120.0, 20.0])
        t = min(1.0, r / R) ** 1.4
        bg[y, x] = (CENTRE_GLOW * (1 - t) + edge_colour * t).astype(np.int32)
bg = flat_face(bg, (1134, 244, 1216, 268), (1131, 1134), tolerance=26)  # detail badge text (pill stays)
bg = flat_face(bg, (896, 506, 1205, 538), (892, 905), tolerance=10)  # name
bg = flat_face(bg, (950, 598, 1220, 622), (1190, 1220), tolerance=10)  # "Hatch a Pirate Egg"
bg = flat_face(bg, (884, 578, 940, 630), (942, 948), tolerance=10)  # egg icon box -> flat
add("Discovered", matte_flat((982, 538, 1119, 563), median_colour((900, 545, 960, 560)), 20, 50))

# ---------- 7. collection rewards: chests as pieces (so they can glow / dim) ----------
REWARD_ROW = (875, 683, 1226, 738)
reward_clean = flat_face(REF_A, REWARD_ROW, (880, 895), tolerance=14)
CHESTS = {"Chest1": (898, 683, 960, 735), "Chest2": (1018, 680, 1080, 735), "Chest3": (1132, 678, 1222, 737)}
for name, box in CHESTS.items():
    add(name, matte(REF_A, reward_clean, box, 22, 50))
pill = flat_face(REF_A, (1033, 743, 1064, 759), (1030, 1033), tolerance=20)
add("ClaimPill", hue_shift(crop(pill, (1028, 740, 1069, 762)), 0.33, 0.2))

# ---------- 8. bottom tabs: blanks + icons + labels, the strip painted out ----------
BOTTOM = {"Characters": (189, 769, 497, 828), "Eggs": (511, 774, 754, 828), "Mutations": (767, 774, 1079, 828)}
bottom_blank = {}
for key, (x0, y0, x1, y1) in BOTTOM.items():
    holes = {"Characters": (244, 774, 458, 824), "Eggs": (568, 778, 696, 824), "Mutations": (826, 778, 1018, 824)}
    blank = stud_blank((x0, y0, x1, y1), holes[key])
    bottom_blank[key] = blank
    add("Bottom" + key, crop(blank, (x0, y0, x1, y1)))
add("IconCharacters", outline_matte(REF_A, (250, 776, 302, 822)))
add("LabelCharacters", outline_matte(REF_A, (305, 784, 452, 818)))
add("IconEgg", outline_matte(REF_A, (574, 776, 618, 824)))
add("LabelEggs", outline_matte(REF_A, (630, 784, 690, 818)))
add("IconDna", outline_matte(REF_A, (832, 778, 875, 824)))
add("LabelMutations", outline_matte(REF_A, (893, 784, 1012, 818)))
add("BottomOff", hue_shift(pieces["BottomEggs"], 0.66, 0.2))  # replaced below by a grey version
grey = np.asarray(pieces["BottomEggs"]).astype(np.float64)
lumi = grey[..., :3].mean(axis=2, keepdims=True)
grey[..., :3] = np.clip(lumi * (np.array(GREY_FACE, float) / max(np.mean(GREY_FACE), 1)) * 0.95, 0, 255)
add("BottomOff", Image.fromarray(grey.astype(np.uint8), "RGBA"))
bottom_region = box_mask([(22, 768, 1248, 828)])
bg = shift_fill(bg, box_mask([(186, 766, 1082, 830)]), bottom_region, panel_shifts(60))

# ---------- 9. write images (scaled) + atlas ----------
mask = panel_mask()
background = Image.fromarray(bg[: CANVAS[1], : CANVAS[0]].astype(np.uint8), "RGB").convert("RGBA")
background.putalpha(mask)
size = (round(CANVAS[0] * SCALE), round(CANVAS[1] * SCALE))
background.resize(size, Image.LANCZOS).save(OUT_DIR / "index_background.png")

scaled = {n: im.resize((max(1, round(im.width * SCALE)), max(1, round(im.height * SCALE))), Image.LANCZOS) for n, im in pieces.items()}
order = sorted(scaled, key=lambda n: -scaled[n].height)
atlas_w, x, y, shelf, rects = 1024, 0, 0, 0, {}
for n in order:
    im = scaled[n]
    if x + im.width > atlas_w:
        x, y, shelf = 0, y + shelf + 2, 0
    rects[n] = (x, y, im.width, im.height)
    x += im.width + 2
    shelf = max(shelf, im.height)
atlas = Image.new("RGBA", (atlas_w, y + shelf), (0, 0, 0, 0))
for n, (px_, py_, _, _) in rects.items():
    atlas.alpha_composite(scaled[n], (px_, py_))
atlas.save(OUT_DIR / "index_pieces.png")

lines = [
    "-- GameMenus.IndexAtlas  (ModuleScript, client) -- GENERATED by assets/ui/index/build_index_atlas.py, do not edit.",
    "-- Pieces of index_pieces.png: Rect = { X, Y, W, H } in atlas pixels, Size = drawn size in mockup pixels.",
    "return {",
    "    Canvas = Vector2.new(%d, %d)," % CANVAS,
    "    Pieces = {",
]
for n in sorted(rects):
    r, im = rects[n], pieces[n]
    lines.append("        %s = { Rect = { %d, %d, %d, %d }, Size = Vector2.new(%d, %d) }," % (n, *r, im.width, im.height))
lines += ["    },", "}", ""]
OUT_LUA.write_bytes("\n".join(lines).encode("utf-8"))  # LF as .stylua.toml asks
print("background", size, "atlas", atlas.size, "pieces", len(rects))
