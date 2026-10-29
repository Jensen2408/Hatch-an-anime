"""Build the My Plot menu art straight from the mockup (assets/ui/plot/plot_reference.png).

usage (from the project root):
    python -I assets/ui/plot/build_plot_atlas.py assets/ui/plot/plot_reference.png assets/ui/plot src/client/UI/Screens/GameMenus/PlotAtlas.luau

Outputs, all stored at SCALE (Roblox keeps uploaded images at most 1024 px):
    plot_background.png  the panel with the scene behind it removed and every changing part painted out
    plot_pieces.png      atlas of the parts drawn on top (card frames, locks, coins, buttons, tab variants, ...)
    PlotAtlas.luau       generated: piece rects in atlas pixels + their size in mockup pixels
Coordinates below are mockup pixels (1382 x 837 image).
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REF, OUT_DIR, OUT_LUA = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
ref_img = Image.open(REF).convert("RGB")
REF_A = np.asarray(ref_img).astype(np.int32)
H, W = REF_A.shape[:2]
CANVAS = (1382, 822)  # the panel ends on the floor at y 822
SCALE = 1024 / CANVAS[0]
PX, PY = 25, 26  # stud pattern period inside the cards and tiles


# ---------- helpers ----------
def box_mask(shape, boxes):
    m = np.zeros(shape, bool)
    for x0, y0, x1, y1 in boxes:
        m[y0:y1, x0:x1] = True
    return m


def shift_fill(img, hole, region, shifts=None):
    """Fill `hole` pixels with pixels one or more stud periods away that are inside `region` and not holes."""
    img = img.copy()
    todo = hole.copy()
    clean = region & ~hole
    if shifts is None:
        shifts = []
        for k in range(1, 16):
            shifts += [(k * PX, 0), (-k * PX, 0)]
        for k in range(1, 10):
            shifts += [(0, k * PY), (0, -k * PY)]
            for j in range(1, 10):
                shifts += [(j * PX, k * PY), (-j * PX, k * PY), (j * PX, -k * PY), (-j * PX, -k * PY)]
    ys, xs = np.nonzero(todo)
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


def row_fill(img, box, sample_cols):
    """Replace box with the per-row median of the sample columns (for flat or vertically shaded faces)."""
    img = img.copy()
    x0, y0, x1, y1 = box
    cols = [x for a, b in sample_cols for x in range(a, b)]
    for y in range(y0, y1):
        img[y, x0:x1] = np.median(img[y, cols], axis=0)
    return img


def face_fill(img, box, cols, lum=(30, 110)):
    """Replace box with, per row, the median of the face pixels in `cols` (bright text and dark outlines skipped)."""
    img = img.copy()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        px = img[y, cols[0] : cols[1]]
        light = px.mean(axis=1)
        face = px[(light >= lum[0]) & (light <= lum[1])]
        img[y, x0:x1] = np.median(face if len(face) else px, axis=0)
    return img


def matte(orig, clean, box, low=12, high=40):
    """RGBA piece: the mockup's pixels, alpha from how far they are from the painted-out background."""
    x0, y0, x1, y1 = box
    o, c = orig[y0:y1, x0:x1], clean[y0:y1, x0:x1]
    diff = np.abs(o - c).max(axis=2)
    alpha = np.clip((diff - low) / (high - low), 0, 1)
    rgba = np.dstack([o, (alpha * 255).astype(np.int32)])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def crop(img, box):
    x0, y0, x1, y1 = box
    return Image.fromarray(img[y0:y1, x0:x1].astype(np.uint8), "RGB").convert("RGBA")


# ---------- 1. panel mask (the scene behind the mockup) ----------
def panel_mask():
    a = REF_A
    white = (a.min(2) > 175) & ((a.max(2) - a.min(2)) < 60)
    bottom, base = 822, (798, 2, 1362)  # the dark base under the white outline: rows 798-821, x 2-1361
    barrier = white.copy()
    barrier[bottom - 1, :] = True
    barrier[base[0] : bottom, base[1] : base[2]] = True
    outside = np.zeros((H, W), bool)
    q = deque([(y, x) for x in range(W) for y in (0, H - 1)] + [(y, x) for y in range(H) for x in (0, W - 1)])
    while q:
        y, x = q.popleft()
        if outside[y, x] or (barrier[y, x] and y < bottom):
            continue
        outside[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and not outside[ny, nx]:
                q.append((ny, nx))
    outside[bottom:, :] = True
    outside[base[0] : bottom, base[1] : base[2]] = False
    keep = np.zeros((H, W), bool)
    q = deque([(H // 2, W // 2)])
    while q:
        y, x = q.popleft()
        if keep[y, x] or outside[y, x]:
            continue
        keep[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and not keep[ny, nx]:
                q.append((ny, nx))
    m = Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    return m.crop((0, 0) + CANVAS)


# ---------- 2. background: paint out everything that changes ----------
bg = REF_A.copy()
# stat values ($25/s, 1, 1 / 3): stud texture of each tile
for hole, tile in (
    ((232, 171, 377, 228), (232, 171, 476, 228)),
    ((628, 171, 671, 228), (628, 171, 862, 228)),
    ((1008, 171, 1121, 228), (1008, 171, 1232, 228)),
):
    bg = shift_fill(bg, box_mask(bg.shape[:2], [hole]), box_mask(bg.shape[:2], [tile]), [(k * PX * s, 0) for k in range(1, 16) for s in (1, -1)])

GAP_COLOUR = np.array([8, 22, 70])
# the whole grid area one flat colour (the Upgrades tab shows it between its rows); the sub-panel's border stays
bg[302:717, 56:797] = GAP_COLOUR

# footer: "1 / 12 slots unlocked" and the blue fill
bg = row_fill(bg, (62, 732, 302, 768), [(300, 309)])
bg[738:763, 312:376] = bg[738:763, 412:476]
# right column: price (coin + text) and button of each row, from the row's face left of them
RIGHT_ROWS = [  # row rect, price box, button box
    ((822, 275, 1286, 388), (1152, 290, 1262, 323), (1139, 324, 1283, 381)),
    ((822, 400, 1290, 512), (1148, 412, 1270, 447), (1139, 447, 1290, 504)),
    ((822, 525, 1298, 638), (1162, 535, 1270, 570), (1144, 572, 1297, 630)),
]
for row, price, button in RIGHT_ROWS:
    for x0, y0, x1, y1 in (price, button):  # grown a little: the button's drop shadow reaches past it
        bg = face_fill(bg, (x0 - 2, y0 - 4, x1, y1 + 5), (1112, 1134))
# milestone dots
bg = row_fill(bg, (1005, 726, 1190, 756), [(1037, 1042), (1075, 1080), (1113, 1118), (1151, 1156)])

# ---------- 3. pieces ----------
pieces = {}  # name -> (RGBA image at mockup size, note)


def add(name, image):
    pieces[name] = image


# card frame (card 4 painted empty: number, lock, coin, price)
c4 = (619, 304, 795, 528)
card4 = REF_A.copy()
card_region = box_mask(card4.shape[:2], [(627, 312, 788, 520)])
card4 = row_fill(card4, (639, 318, 659, 346), [(634, 638), (661, 664)])  # the digit, inside its badge
lock_hole = box_mask(card4.shape[:2], [(676, 350, 746, 436), (658, 438, 758, 480)])
card4 = shift_fill(card4, lock_hole, card_region & ~box_mask(card4.shape[:2], [(629, 312, 668, 352)]))
add("Card", crop(card4, c4))
add("LockGrey", matte(REF_A, card4, (676, 350, 746, 436)))
add("CoinGrey", matte(REF_A, card4, (662, 442, 695, 475)))

# next-slot highlight: card 2's glowing frame, centre cut out (laid over a plain card)
c2 = (250, 301, 433, 528)
glow = crop(REF_A, c2)
ga = np.asarray(glow).copy()
inset = 11
ga[inset:-inset, inset:-inset, 3] = 0
add("Glow", Image.fromarray(ga, "RGBA"))
# card 2's and card 1's contents, matted against the plain card colour (they are far brighter / darker)
CARD_COLOUR = np.median(card4[330:510, 700:780].reshape(-1, 3), axis=0)


def matte_flat(box, low=24, high=48):
    flat = np.broadcast_to(CARD_COLOUR, REF_A.shape).astype(np.int32)
    return matte(REF_A, flat, box, low, high)


add("LockGold", matte_flat((306, 336, 374, 412)))
add("NextSlot", matte_flat((284, 413, 397, 441)))
add("CoinGreen", matte_flat((288, 441, 320, 474)))
add("UnlockButton", matte_flat((261, 476, 419, 517)))
add("RemoveButton", matte_flat((74, 503, 234, 544)))

# right column buttons and coins (matted against the painted-out rows)
add("PurchaseButton", matte(REF_A, bg, (1139, 447, 1290, 504)))
grey = row_fill(REF_A, (1156, 331, 1266, 374), [(1146, 1156), (1266, 1276)])
add("GreyButton", matte(grey, bg, (1139, 324, 1283, 381)))
add("CoinGreySmall", matte(REF_A, bg, (1156, 291, 1188, 323)))
add("CoinGreenSmall", matte(REF_A, bg, (1151, 414, 1184, 447)))
# footer fill, milestone dots
add("BarFill", crop(REF_A, (312, 738, 376, 763)))
add("DotOn", matte(REF_A, bg, (1006, 727, 1035, 755)))
add("DotOff", matte(REF_A, bg, (1044, 727, 1073, 755)))
# a blank upgrade row (Add Incubator, everything painted out) + its egg, for the Upgrades tab
def flat_face(img, box, cols, tolerance=7):
    """Per row: median of the pixels within `tolerance` of the face colour (skips text, icons and studs)."""
    img = img.copy()
    x0, y0, x1, y1 = box
    face = np.median(img[y0:y1, cols[0] : cols[1]].reshape(-1, 3), axis=0)
    for y in range(y0, y1):
        px = img[y, cols[0] : cols[1]]
        near = px[np.abs(px - face).max(axis=1) <= tolerance]
        img[y, x0:x1] = np.median(near, axis=0) if len(near) else face
    return img


row3 = flat_face(bg, (836, 531, 1284, 633), (930, 1284))
add("RowBlank", crop(row3, (822, 525, 1298, 638)))
add("Egg", matte(REF_A, row3, (836, 532, 920, 630)))


# tab variants: Character Slots inactive (blue -> purple), Upgrades active (purple -> blue)
def recolour(box, src, dst):
    piece = REF_A[box[1] : box[3], box[0] : box[2]].astype(float)
    sat = piece.max(2) - piece.min(2)
    weight = np.clip((sat - 40) / 60, 0, 1)[..., None]  # only the coloured face, not the white / black text
    lum = piece.mean(2, keepdims=True) / np.mean(src)
    out = piece * (1 - weight) + np.clip(lum * np.array(dst, float), 0, 255) * weight
    return Image.fromarray(out.astype(np.uint8), "RGB").convert("RGBA")


TAB_SLOTS, TAB_UPGRADES = (86, 238, 506, 293), (505, 238, 803, 293)
add("TabSlotsOff", recolour(TAB_SLOTS, (32, 162, 252), (83, 24, 183)))
add("TabUpgradesOn", recolour(TAB_UPGRADES, (83, 24, 183), (32, 162, 252)))

# ---------- 4. keystone: the mockup's sides lean out towards the bottom; make them vertical ----------
mask = panel_mask()
alpha = np.asarray(mask).astype(np.float64)
rows = np.arange(130, 795, 5)
left = np.array([np.nonzero(alpha[y] > 128)[0][0] for y in rows])
right = np.array([np.nonzero(alpha[y] > 128)[0][-1] for y in rows])
L_SLOPE, L_OFF = np.polyfit(rows, left, 1)
R_SLOPE, R_OFF = np.polyfit(rows, right, 1)
TARGET_Y = 800  # the sides become vertical at their width here (the bottom of the frame)
L_T, R_T = L_OFF + L_SLOPE * TARGET_Y, R_OFF + R_SLOPE * TARGET_Y

rgba = np.dstack([bg[: CANVAS[1], : CANVAS[0]].astype(np.float64), alpha])
rgba[..., :3] *= rgba[..., 3:] / 255  # premultiplied, so the transparent outside does not bleed in
xs_out = np.arange(CANVAS[0], dtype=np.float64)
warped = np.zeros_like(rgba)
for y in range(CANVAS[1]):
    lo, hi = L_OFF + L_SLOPE * y, R_OFF + R_SLOPE * y
    src_x = lo + (xs_out - L_T) * (hi - lo) / (R_T - L_T)
    for c in range(4):
        warped[y, :, c] = np.interp(src_x, np.arange(CANVAS[0]), rgba[y, :, c], left=0, right=0)
a = warped[..., 3:]
warped[..., :3] = np.where(a > 0, warped[..., :3] * 255 / np.maximum(a, 1e-6), 0)
background = Image.fromarray(np.clip(warped, 0, 255).astype(np.uint8), "RGBA")

# ---------- 5. write images (scaled) + atlas ----------
size = (round(CANVAS[0] * SCALE), round(CANVAS[1] * SCALE))
background.resize(size, Image.LANCZOS).save(OUT_DIR / "plot_background.png")

# shelf-pack the scaled pieces (2 px apart)
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
atlas.save(OUT_DIR / "plot_pieces.png")

lines = [
    "-- GameMenus.PlotAtlas  (ModuleScript, client) -- GENERATED by assets/ui/plot/build_plot_atlas.py, do not edit.",
    "-- Pieces of plot_pieces.png: Rect = { X, Y, W, H } in atlas pixels, Size = drawn size in mockup pixels.",
    "-- Keystone: in the mockup row y spans Left(y)..Right(y) (Offset + Slope * y); the background maps it onto",
    "-- Target (vertical sides), so a mockup point (x, y) is drawn at Target.X + (x - Left(y)) * width ratio.",
    "return {",
    "    Canvas = Vector2.new(%d, %d)," % CANVAS,
    "    Keystone = {",
    "        Left = { Offset = %.3f, Slope = %.5f }," % (L_OFF, L_SLOPE),
    "        Right = { Offset = %.3f, Slope = %.5f }," % (R_OFF, R_SLOPE),
    "        Target = Vector2.new(%.3f, %.3f)," % (L_T, R_T),
    "    },",
    "    Pieces = {",
]
for n in sorted(rects):
    r, im = rects[n], pieces[n]
    lines.append("        %s = { Rect = { %d, %d, %d, %d }, Size = Vector2.new(%d, %d) }," % (n, *r, im.width, im.height))
lines += ["    },", "}", ""]
OUT_LUA.write_bytes("\n".join(lines).encode("utf-8"))  # LF as .stylua.toml asks (write_text gives CRLF on Windows)
print("background", size, "atlas", atlas.size, "pieces", len(rects))
