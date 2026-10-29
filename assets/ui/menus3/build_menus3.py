"""Cut the GPT Image art for Feedback, Offline Earnings, the Mutation Drop board and the egg name tag.

usage (from the project root):
    python -I assets/ui/menus3/build_menus3.py assets/ui/menus3 src/shared/UI/MenuArt/MenuArt3Atlas.luau

Outputs:
    feedback_bg.png   the Feedback window on the 1160 x 730 StudTheme canvas (tabs painted out), at 0.883
    offline_bg.png    the Offline Earnings window on its 560 x 540 canvas (buttons painted out), at 1.8
    board_art.png     the Mutation Drop sign (extra buttons / X removed), 1024 x 512 for the 1040 x 520 SurfaceGui
    menu3_pieces.png  tabs, offline buttons + badge, egg tags per rarity
    MenuArt3Atlas.luau generated: Rect = atlas pixels, Size = drawn size in canvas pixels
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DIR, OUT_LUA = Path(sys.argv[1]), Path(sys.argv[2])


def load(name):
    return np.asarray(Image.open(DIR / f"gpt_{name}.png").convert("RGB")).astype(np.int32)


def rounded(size, radius, scale=4):
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return big.resize(size, Image.LANCZOS)


def window_mask(img):
    """Per row: everything between the leftmost and rightmost pixel of the white outline (and the rows between)."""
    white = (img.min(2) > 190) & ((img.max(2) - img.min(2)) < 60)
    h, w = white.shape
    keep = np.zeros((h, w), bool)
    rows = [y for y in range(h) if white[y].sum() > 2]
    for y in range(h):
        xs = np.nonzero(white[y])[0]
        if len(xs) >= 2 and xs[-1] - xs[0] > w * 0.5:
            keep[y, xs[0] : xs[-1] + 1] = True
    return Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def stud_panel(img, box, base, period=24, stud=14):
    """Paints box as a panel face: base colour with a lighter stud every period."""
    x0, y0, x1, y1 = box
    base = np.asarray(base, float)
    img[y0:y1, x0:x1] = base
    off = (period - stud) // 2
    for sy in range(y0 - (y0 % period), y1, period):
        for sx in range(x0 - (x0 % period), x1, period):
            ax, ay = sx + off, sy + off
            for dx0, dy0, dx1, dy1, k in ((0, 0, stud, stud, 0.82), (0, 0, stud - 2, stud - 2, 1.12)):
                ya, yb = max(ay + dy0, y0), min(ay + dy1, y1)
                xa, xb = max(ax + dx0, x0), min(ax + dx1, x1)
                if ya < yb and xa < xb:
                    img[ya:yb, xa:xb] = np.clip(base * k, 0, 255)


def to_image(img, alpha=None):
    rgba = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    if alpha is not None:
        rgba.putalpha(alpha)
    return rgba


def crop_piece(img, box, radius):
    x0, y0, x1, y1 = box
    return to_image(img[y0:y1, x0:x1], rounded((x1 - x0, y1 - y0), radius))


pieces = {}  # name -> (image at its stored size, drawn size in canvas pixels)


def add(name, image, canvas_size):
    pieces[name] = (image, canvas_size)


# ---------- FEEDBACK (window x 43..1492, y 33..990 -> the 1160 x 730 canvas) ----------
fb = load("feedback")
FB_BOX, FB_SIZE = (43, 33, 1493, 991), (1160, 730)
fsx, fsy = FB_SIZE[0] / (FB_BOX[2] - FB_BOX[0]), FB_SIZE[1] / (FB_BOX[3] - FB_BOX[1])
TABS = [(118, 336, 515, 412), (550, 336, 963, 412), (998, 336, 1411, 412)]


def fb_size(box):
    return (round((box[2] - box[0]) * fsx), round((box[3] - box[1]) * fsy))


add("FbTabOn", crop_piece(fb, TABS[0], 12), fb_size(TABS[0]))
add("FbTabOff", crop_piece(fb, TABS[1], 12), fb_size(TABS[1]))
for x0, y0, x1, y1 in TABS:  # the tab row painted out with the panel face 80 px above it
    fb[y0 - 10 : y1 + 8, x0 - 8 : x1 + 8] = fb[y0 - 106 : y1 - 88, x0 - 8 : x1 + 8]
fb_mask = window_mask(load("feedback")).crop(FB_BOX)
fb_img = to_image(fb[FB_BOX[1] : FB_BOX[3], FB_BOX[0] : FB_BOX[2]], fb_mask)
fb_img.resize((1024, 644), Image.LANCZOS).save(DIR / "feedback_bg.png")

# ---------- OFFLINE EARNINGS (window x 16..1007, y 30..990 -> the 560 x 540 canvas) ----------
off = load("offline")
OFF_BOX, OFF_SIZE = (16, 30, 1007, 990), (560, 540)
osx, osy = OFF_SIZE[0] / (OFF_BOX[2] - OFF_BOX[0]), OFF_SIZE[1] / (OFF_BOX[3] - OFF_BOX[1])


def off_size(box):
    return (round((box[2] - box[0]) * osx), round((box[3] - box[1]) * osy))


GREEN, GOLD, BADGE = (83, 753, 507, 932), (516, 753, 941, 932), (843, 710, 977, 777)
add("OffGreen", crop_piece(off, GREEN, 18), off_size(GREEN))
badge_art = crop_piece(off, BADGE, 14)  # cut before the corner under it is repaired
# the badge overlapped the gold button: the top edge carried on from a clean column, its other corner mirrored
off[748:784, 828:905] = off[748:784, 815:816]
off[748:784, 905:941] = off[748:784, 516:552][:, ::-1]
add("OffBadge", badge_art, off_size(BADGE))
add("OffGold", crop_piece(off, GOLD, 18), off_size(GOLD))


def hue_shift(rgba, hue, min_sat=0.2):
    """The saturated pixels moved to `hue` (0..1), keeping saturation / value (the white bevel stays)."""
    import colorsys

    a = np.asarray(rgba).astype(np.float64) / 255
    out = a.copy()
    flat, res = a[..., :3].reshape(-1, 3), out[..., :3].reshape(-1, 3)
    for i, (r, g, b) in enumerate(flat):
        h, s_, v = colorsys.rgb_to_hsv(r, g, b)
        if s_ >= min_sat:
            res[i] = colorsys.hsv_to_rgb(hue, s_, v)
    out[..., :3] = res.reshape(a[..., :3].shape)
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


add("CardPink", hue_shift(pieces["OffGold"][0], 0.9), off_size(GOLD))  # the welcome card (JoinArrival)
face = np.median(off[880:950, 950:985].reshape(-1, 3), axis=0)
stud_panel(off, (38, 746, 988, 950), face)  # below the glow
stud_panel(off, (835, 704, 988, 746), face)  # the badge
off_mask = rounded((OFF_BOX[2] - OFF_BOX[0], OFF_BOX[3] - OFF_BOX[1]), 22)  # the header has no side outline
off_img = to_image(off[OFF_BOX[1] : OFF_BOX[3], OFF_BOX[0] : OFF_BOX[2]], off_mask)
off_img.resize((round(OFF_SIZE[0] * 1.8), round(OFF_SIZE[1] * 1.8)), Image.LANCZOS).save(DIR / "offline_bg.png")

# ---------- MUTATION DROP board: header + inner panel (tabs / bottom buttons / X dropped) ----------
bd = load("board")
header = bd[80:216, 40:1500].copy()
header[:, 1290:1460] = header[:, 0:170][:, ::-1]  # the X: the header's left end mirrored
panel = bd[300:722, 40:1500]
bottom = bd[905:946, 40:1500]  # only the bottom border (the generated buttons sit above it)
W = 1460
panel_h = W // 2 - header.shape[0] - bottom.shape[0]
panel = np.asarray(Image.fromarray(panel.astype(np.uint8)).resize((W, panel_h), Image.LANCZOS)).astype(np.int32)
board = np.concatenate([header, panel, bottom], axis=0)
board_mask = rounded((board.shape[1], board.shape[0]), 22)
to_image(board, board_mask).resize((1024, 512), Image.LANCZOS).save(DIR / "board_art.png")
print("board header share", header.shape[0] / board.shape[0], "bottom share", bottom.shape[0] / board.shape[0])

# ---------- egg name tag: the grey plate + its pointer, tinted per rarity ----------
eg = load("egglabel")
PLATE = (112, 275, 1424, 724)
px0, py0, px1, py1 = PLATE
alpha = Image.new("L", (px1 - px0, py1 - py0), 0)
alpha.paste(rounded((px1 - px0, 692 - py0), 20), (0, 0))
ImageDraw.Draw(alpha).polygon([(738 - px0, 684 - py0), (800 - px0, 684 - py0), (769 - px0, 722 - py0)], fill=255)
plate = eg[py0:py1, px0:px1].astype(np.float64)
TAG_SIZE = (202, 69)  # drawn size: the plate 202 x 64 + the pointer
TINTS = {  # rarity -> plate colour (top of the old gradient, a touch darker)
    "Common": (150, 156, 172),
    "Uncommon": (60, 200, 72),
    "Rare": (52, 108, 240),
    "Epic": (150, 90, 240),
    "Legendary": (245, 196, 52),
    "Mythic": (235, 66, 66),
}
grey_lum = np.median(plate[40:380, 100:1200].mean(axis=2))
for rarity, tint in TINTS.items():
    lum = plate.mean(axis=2, keepdims=True) / grey_lum
    light = (plate.min(axis=2, keepdims=True) > 190).astype(float)  # the white rim stays white
    out = np.clip(lum * np.array(tint, float), 0, 255) * (1 - light) + plate * light
    tag = to_image(out, alpha).resize((TAG_SIZE[0] * 2, TAG_SIZE[1] * 2), Image.LANCZOS)
    add("Tag" + rarity, tag, TAG_SIZE)

# ---------- atlas (each piece stored at 2x its canvas size, at most its source size) ----------
stored = {}
for n, (im, size) in pieces.items():
    k = min(2.0, im.width / size[0])
    stored[n] = im.resize((round(size[0] * k), round(size[1] * k)), Image.LANCZOS)
order = sorted(stored, key=lambda n: -stored[n].height)
atlas_w, x, y, shelf, rects = 1024, 0, 0, 0, {}
for n in order:
    im = stored[n]
    if x + im.width > atlas_w:
        x, y, shelf = 0, y + shelf + 2, 0
    rects[n] = (x, y, im.width, im.height)
    x += im.width + 2
    shelf = max(shelf, im.height)
atlas = Image.new("RGBA", (atlas_w, y + shelf), (0, 0, 0, 0))
for n, (px, py, _, _) in rects.items():
    atlas.alpha_composite(stored[n], (px, py))
atlas.save(DIR / "menu3_pieces.png")
lines = [
    "-- ReplicatedStorage.MenuArt.MenuArt3Atlas  (ModuleScript, client) -- GENERATED by",
    "-- assets/ui/menus3/build_menus3.py, do not edit. Pieces of menu3_pieces.png: Rect = atlas pixels,",
    "-- Size = drawn size in canvas pixels of their window.",
    "return {",
    "    Pieces = {",
]
for n in sorted(rects):
    lines.append("        %s = { Rect = { %d, %d, %d, %d }, Size = Vector2.new(%d, %d) }," % (n, *rects[n], *pieces[n][1]))
lines += ["    },", "}", ""]
OUT_LUA.write_bytes("\n".join(lines).encode("utf-8"))
print("atlas", atlas.size, "pieces", len(rects))
