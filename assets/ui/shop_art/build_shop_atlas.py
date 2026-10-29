"""Build the Halloween Shop menu art from the mockup (with the LIMITED egg already painted out).

usage (from the project root):
    python -I assets/ui/shop_art/patch_limited.py assets/ui/shop_art/shop_reference.png assets/ui/shop_art/limited_scene_gpt.png assets/ui/shop_art/shop_reference_noegg.png
    python -I assets/ui/shop_art/build_shop_atlas.py assets/ui/shop_art/shop_reference_noegg.png assets/ui/shop_art src/client/UI/Screens/GameMenus/ShopAtlas.luau

Outputs:
    shop_background.png  panel, header, tab row (covered by tab pieces) and an empty content area (at BG_SCALE)
    shop_featured.png    the FEATURED page (content area) with every changing text painted out (full size)
    shop_pieces.png      atlas: tabs, card blanks, buttons, pills, icons, badge (full size)
    ShopAtlas.luau       generated: piece rects in atlas pixels + their size in mockup pixels
Coordinates are mockup pixels (1092 x 679).
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REF, OUT_DIR, OUT_LUA = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
REF_A = np.asarray(Image.open(REF).convert("RGB")).astype(np.int32)
H, W = REF_A.shape[:2]
CANVAS = (W, H)
BG_SCALE = 1024 / W
CONTENT = (45, 188, 1050, 633)  # the cards area under the tabs


def flat_face(img, box, cols=None, tolerance=18):
    """Per row: median of the pixels within `tolerance` of the area's face colour (skips text and icons)."""
    img = img.copy()
    x0, y0, x1, y1 = box
    c0, c1 = cols or (x0, x1)
    face = np.median(img[y0:y1, c0:c1].reshape(-1, 3), axis=0)
    for y in range(y0, y1):
        px = img[y, c0:c1]
        near = px[np.abs(px - face).max(axis=1) <= tolerance]
        img[y, x0:x1] = np.median(near, axis=0) if len(near) else face
    return img


def crop(img, box, alpha=None):
    x0, y0, x1, y1 = box
    rgba = Image.fromarray(img[y0:y1, x0:x1].astype(np.uint8), "RGB").convert("RGBA")
    if alpha is not None:
        rgba.putalpha(alpha)
    return rgba


def rounded_alpha(size, radius, scale=4):
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return big.resize(size, Image.LANCZOS)


def flood_outside(barrier):
    h, w = barrier.shape
    outside = np.zeros((h, w), bool)
    q = deque([(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)])
    while q:
        y, x = q.popleft()
        if outside[y, x] or barrier[y, x]:
            continue
        outside[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx]:
                q.append((ny, nx))
    return outside


def outline_matte(img, box, dark=45, min_area=30, close=1):
    """RGBA piece cut along its dark outline (everything enclosed by it is kept); specks dropped.
    close > 1 thickens the outline first, so small gaps in it don't let the outside in."""
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1]
    barrier = region.mean(axis=2) < dark
    if close > 1:
        barrier = np.asarray(Image.fromarray((barrier * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(close))) > 0
    keep = ~flood_outside(barrier)
    h, w = keep.shape
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


def icon_matte(img, box, low=30, high=60):
    """RGBA icon on a flat face: alpha from the distance to the face colour (the median of the box's edge pixels),
    holes inside the icon filled. Unlike outline_matte it needs no closed outline."""
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1].astype(np.float64)
    edge = np.concatenate([region[0], region[-1], region[:, 0], region[:, -1]])
    face = np.median(edge, axis=0)
    diff = np.abs(region - face).max(axis=2)
    alpha = np.clip((diff - low) / (high - low), 0, 1)
    solid = ~flood_outside(alpha > 0.5)  # the icon plus everything it encloses
    alpha = np.maximum(alpha, solid.astype(np.float64))
    a = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.4))
    return crop(img, box, a)


def icon_key(img, box):
    """Icon on a dark purple tab: keeps its near-black outline and its bright / saturated colours (the tab face and
    its stud shadows are neither), fills what the outline encloses, keeps the biggest blob."""
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1].astype(np.float64)
    lum = region.mean(axis=2)
    sat = region.max(axis=2) - region.min(axis=2)
    solid = ((lum < 34) & (sat < 20)) | ((sat > 95) & (region.max(axis=2) > 130)) | (lum > 190)
    solid = ~flood_outside(solid)
    a = Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5))
    return keep_largest(crop(img, box, a))


def keep_largest(rgba):
    """Drops every alpha blob but the biggest (stray bits of neighbouring text / specks)."""
    arr = np.asarray(rgba).copy()
    solid = arr[..., 3] > 40
    h, w = solid.shape
    seen = np.zeros((h, w), bool)
    parts = []
    for sy, sx in zip(*np.nonzero(solid)):
        if seen[sy, sx]:
            continue
        part, q = [], deque([(sy, sx)])
        seen[sy, sx] = True
        while q:
            y, x = q.popleft()
            part.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        parts.append(part)
    parts.sort(key=len, reverse=True)
    for part in parts[1:]:
        for y, x in part:
            arr[y, x, 3] = 0
    return Image.fromarray(arr, "RGBA")


def blank(box, inset, tolerance=18, radius=10):
    """A card / button / pill with its inside (inset px in) flattened per row; rounded corners transparent."""
    x0, y0, x1, y1 = box
    img = flat_face(REF_A, (x0 + inset, y0 + inset, x1 - inset, y1 - inset), tolerance=tolerance)
    return crop(img, box, rounded_alpha((x1 - x0, y1 - y0), radius))


def panel_mask():
    """Per row: everything between the leftmost and rightmost pixel of the white outline."""
    a = REF_A
    white = (a.min(2) > 185) & ((a.max(2) - a.min(2)) < 60)
    keep = np.zeros((H, W), bool)
    for y in range(H):
        xs = np.nonzero(white[y, 8 : W - 8])[0] + 8
        if len(xs) >= 2 and xs[-1] - xs[0] > 20:
            keep[y, xs[0] : xs[-1] + 1] = True
    return Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def blank_card(box, exclude, ring=12, radius=12, edges=None):
    """Card art with its inside rebuilt from what is left outside `exclude` boxes: a per-row median, rows with
    nothing left taken from their neighbours, then smoothed vertically. The outer `ring` px stay the mockup's."""
    x0, y0, x1, y1 = box
    ix0, iy0, ix1, iy1 = x0 + ring, y0 + ring, x1 - ring, y1 - ring
    free = np.ones((iy1 - iy0, ix1 - ix0), bool)
    for ex0, ey0, ex1, ey1 in exclude:
        free[max(ey0 - iy0, 0) : max(ey1 - iy0, 0), max(ex0 - ix0, 0) : max(ex1 - ix0, 0)] = False
    rows = np.full((iy1 - iy0, 3), np.nan)
    for r in range(iy1 - iy0):
        px = REF_A[iy0 + r, ix0:ix1][free[r]]
        if len(px) >= 3:
            rows[r] = np.median(px, axis=0)
    idx = np.arange(len(rows))
    good = ~np.isnan(rows[:, 0])
    for c in range(3):
        rows[:, c] = np.interp(idx, idx[good], rows[good, c])
    kernel = np.ones(9) / 9
    for c in range(3):
        rows[:, c] = np.convolve(np.pad(rows[:, c], 4, mode="edge"), kernel, mode="valid")
    img = REF_A.copy()
    img[iy0:iy1, ix0:ix1] = rows[:, None, :].round().astype(np.int32)
    # the border ring: each side rebuilt from a clean stretch of it (corners stay the mockup's)
    if edges:
        cx0, cx1 = edges["x"]  # clean columns for the top / bottom rows
        cy0, cy1 = edges["y"]  # clean rows for the left / right columns
        for y in list(range(y0, iy0)) + list(range(iy1, y1)):
            img[y, ix0:ix1] = np.median(REF_A[y, cx0:cx1], axis=0)
        for x in range(ix1, x1):
            img[iy0:iy1, x] = np.median(REF_A[cy0:cy1, x], axis=0)
        for i, x in enumerate(range(x0, ix0)):
            if edges.get("mirror"):
                img[iy0:iy1, x] = img[iy0:iy1, x1 - 1 - i]
            else:
                img[iy0:iy1, x] = np.median(REF_A[cy0:cy1, x], axis=0)
        if edges.get("mirror"):  # left corners from the right ones too (the icon covers the left ones)
            for i, x in enumerate(range(x0, ix0)):
                img[y0:iy0, x] = img[y0:iy0, x1 - 1 - i]
                img[iy1:y1, x] = img[iy1:y1, x1 - 1 - i]
    return crop(img, box, rounded_alpha((x1 - x0, y1 - y0), radius))


pieces = {}


def add(name, image):
    pieces[name] = image


# ---------- tabs ----------
TABS = {
    "Featured": ((42, 125, 250, 182), (63, 130, 107, 175), (107, 138, 222, 170)),
    "Boosts": ((257, 125, 444, 182), (283, 130, 320, 177), (335, 138, 415, 170)),
    "Passes": ((450, 125, 643, 182), (468, 136, 518, 170), (528, 138, 610, 170)),
    "Cash": ((647, 125, 845, 182), (675, 131, 730, 170), (743, 138, 802, 170)),
    "Daily": ((852, 125, 1050, 182), (885, 128, 927, 172), (948, 138, 1012, 170)),
}
add("TabOn", blank(TABS["Featured"][0], 7, tolerance=24, radius=8))
add("TabOff", blank(TABS["Boosts"][0], 7, tolerance=24, radius=8))
for key, (_, icon, label) in TABS.items():
    add("TabIcon" + key, icon_matte(REF_A, icon) if key == "Featured" else icon_key(REF_A, icon))
    add("TabLabel" + key, outline_matte(REF_A, label))

# ---------- featured page: the content area with its changing texts painted out ----------
TEXTS = [  # (area to flatten, sample columns) - every text the game writes itself
    ((400, 211, 543, 238), (400, 543)),  # timer
    ((140, 562, 448, 616), (140, 448)),  # BUY · R$ 180
    ((818, 302, 1004, 341), (818, 1004)),  # VIP price
    ((689, 429, 797, 447), (689, 797)),  # 2x money text
    ((705, 480, 794, 511), (705, 794)),  # 2x money price
    ((924, 429, 1036, 447), (924, 1036)),  # 2x hatch text
    ((936, 480, 1034, 511), (936, 1034)),  # 2x hatch price
    ((679, 592, 874, 616), (679, 874)),  # starter text
    ((913, 581, 1034, 616), (913, 1034)),  # starter price
]
featured = REF_A.copy()
for box, cols in TEXTS:
    featured = flat_face(featured, box, cols, tolerance=26)
add_featured = crop(featured, CONTENT)

# ---------- card blanks / buttons / pills (other pages) ----------
add("CardPurple", blank_card((565, 192, 1049, 356), [(598, 198, 778, 352), (792, 200, 1030, 352), (925, 194, 1046, 272)],
    edges={"x": (575, 596), "y": (282, 338)}))
add("CardGreen", blank_card((565, 362, 809, 526), [(565, 376, 692, 516), (672, 382, 806, 522)],
    edges={"x": (700, 790), "y": (392, 470), "mirror": True}))
add("CardGold", blank_card((815, 362, 1049, 526), [(826, 376, 926, 516), (914, 382, 1046, 522)],
    edges={"x": (930, 1030), "y": (392, 470), "mirror": True}))
add("CardBrown", blank_card((565, 532, 1049, 631), [(580, 538, 672, 628), (670, 536, 1046, 628)],
    edges={"x": (690, 860), "y": (548, 618)}))
add("ButtonGreen", blank((802, 296, 1020, 346), 9, tolerance=30, radius=8))
add("PillDark", blank((795, 265, 966, 290), 4, tolerance=20, radius=8))
add("PillTimer", blank((366, 205, 547, 243), 5, tolerance=24, radius=10))
add("BadgeLimited", blank((60, 209, 193, 251), 8, tolerance=40, radius=9))  # the red badge, LIMITED painted out
add("IconClock", outline_matte(REF_A, (372, 209, 402, 239)))

# ---------- icons ----------
add("IconCrown", outline_matte(REF_A, (603, 205, 772, 347), dark=80, close=3))
add("IconCoins", keep_largest(icon_matte(REF_A, (570, 377, 681, 512))))
add("IconBolt", keep_largest(outline_matte(REF_A, (830, 381, 920, 510), dark=80, close=3)))
add("IconStar", outline_matte(REF_A, (584, 542, 667, 624), dark=60, close=3))
add("IconPotions", icon_matte(REF_A, (880, 538, 960, 577)))

# ---------- background: tabs stay baked (covered by the tab pieces), the content area emptied ----------
bg = REF_A.copy()
x0, y0, x1, y1 = CONTENT
for y in range(y0, y1):
    bg[y, x0:x1] = np.median(REF_A[y, 552:562], axis=0)
mask = panel_mask()
background = Image.fromarray(bg.astype(np.uint8), "RGB").convert("RGBA")
background.putalpha(mask)
background.resize((round(W * BG_SCALE), round(H * BG_SCALE)), Image.LANCZOS).save(OUT_DIR / "shop_background.png")
add_featured.save(OUT_DIR / "shop_featured.png")

# ---------- atlas (full size, shelf-packed) ----------
order = sorted(pieces, key=lambda n: -pieces[n].height)
atlas_w, x, y, shelf, rects = 1024, 0, 0, 0, {}
for n in order:
    im = pieces[n]
    if x + im.width > atlas_w:
        x, y, shelf = 0, y + shelf + 2, 0
    rects[n] = (x, y, im.width, im.height)
    x += im.width + 2
    shelf = max(shelf, im.height)
atlas = Image.new("RGBA", (atlas_w, y + shelf), (0, 0, 0, 0))
for n, (px_, py_, _, _) in rects.items():
    atlas.alpha_composite(pieces[n], (px_, py_))
atlas.save(OUT_DIR / "shop_pieces.png")

lines = [
    "-- GameMenus.ShopAtlas  (ModuleScript, client) -- GENERATED by assets/ui/shop_art/build_shop_atlas.py, do not edit.",
    "-- Pieces of shop_pieces.png: Rect = { X, Y, W, H } in atlas pixels (= mockup pixels, the atlas is full size).",
    "return {",
    "    Canvas = Vector2.new(%d, %d)," % CANVAS,
    "    Content = { %d, %d, %d, %d }, -- the FEATURED page image's rect on the canvas" % (x0, y0, x1 - x0, y1 - y0),
    "    Pieces = {",
]
for n in sorted(rects):
    lines.append("        %s = { %d, %d, %d, %d }," % (n, *rects[n]))
lines += ["    },", "}", ""]
OUT_LUA.write_bytes("\n".join(lines).encode("utf-8"))  # LF as .stylua.toml asks
print("background", background.size, "featured", add_featured.size, "atlas", atlas.size, "pieces", len(rects))
