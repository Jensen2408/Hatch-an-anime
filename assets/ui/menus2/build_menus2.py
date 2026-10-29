"""Cut the GPT Image window art (gpt_settings / gpt_quests / gpt_inventory.png) into backgrounds + one piece atlas.

usage (from the project root):
    python -I assets/ui/menus2/build_menus2.py assets/ui/menus2 src/shared/UI/MenuArt/MenuArtAtlas.luau

The art was generated from text-free layout sketches of the old windows (Settings / Quests: the 1160 x 730
StudTheme canvas; Inventory: its own 660 x 402 canvas). Outputs (pieces stored at canvas size):
    settings_bg.png, quests_bg.png, inventory_bg.png   the window, outside transparent, changing parts painted out
    menu_pieces.png                                    sliders, toggles, tabs, row cards, buttons, item cell, ...
    MenuArtAtlas.luau                                  generated: piece rects (atlas pixels = canvas pixels)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DIR, OUT_LUA = Path(sys.argv[1]), Path(sys.argv[2])


def load(name, box, size):
    g = Image.open(DIR / f"gpt_{name}.png").convert("RGB").crop(box).resize(size, Image.LANCZOS)
    return np.asarray(g).astype(np.int32)


SETTINGS = load("settings", (0, 29, 1536, 995), (1160, 730))
QUESTS = load("quests", (0, 29, 1536, 995), (1160, 730))
INVENTORY = load("inventory", (50, 73, 1485, 947), (660, 402))


def window_mask(img):
    """Per row: everything between the leftmost and rightmost pixel of the white outline."""
    white = (img.min(2) > 190) & ((img.max(2) - img.min(2)) < 60)
    h, w = white.shape
    keep = np.zeros((h, w), bool)
    for y in range(h):
        xs = np.nonzero(white[y])[0]
        if len(xs) >= 2 and xs[-1] - xs[0] > w * 0.5:
            keep[y, xs[0] : xs[-1] + 1] = True
    return Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def flat_face(img, box, cols, tolerance=14):
    """Per row: the median of the sample columns' pixels near their face colour (skips art details)."""
    x0, y0, x1, y1 = box
    c0, c1 = cols
    face = np.median(img[y0:y1, c0:c1].reshape(-1, 3), axis=0)
    for y in range(y0, y1):
        px = img[y, c0:c1]
        near = px[np.abs(px - face).max(axis=1) <= tolerance]
        img[y, x0:x1] = np.median(near, axis=0) if len(near) else face


def stud_fill(img, box, clean, period=24):
    """Fills box with pixels a whole number of stud periods away, from the clean x range (keeps the studs)."""
    x0, y0, x1, y1 = box
    c0, c1 = clean
    for x in range(x0, x1):
        k = 1
        while True:
            for sx in (x - k * period, x + k * period):
                if c0 <= sx < c1:
                    img[y0:y1, x] = img[y0:y1, sx]
                    break
            else:
                k += 1
                continue
            break


def stud_panel(img, box, base, period=24, stud=14):
    """Paints box as the panel face: the base colour with a lighter stud (and a darker shadow edge) every period."""
    x0, y0, x1, y1 = box
    base = np.asarray(base, float)
    img[y0:y1, x0:x1] = base
    off = (period - stud) // 2
    for sy in range(y0 - (y0 % period), y1, period):
        for sx in range(x0 - (x0 % period), x1, period):
            ax, ay = sx + off, sy + off
            for (dx0, dy0, dx1, dy1, k) in ((0, 0, stud, stud, 0.80), (0, 0, stud - 2, stud - 2, 1.14)):
                ya, yb = max(ay + dy0, y0), min(ay + dy1, y1)
                xa, xb = max(ax + dx0, x0), min(ax + dx1, x1)
                if ya < yb and xa < xb:
                    img[ya:yb, xa:xb] = np.clip(base * k, 0, 255)


def tile_rows(img, box, band):
    """Fills box by repeating the rows of band (y0, y1) (keeps the studs of the panel face)."""
    x0, y0, x1, y1 = box
    b0, b1 = band
    for y in range(y0, y1):
        img[y, x0:x1] = img[b0 + (y - y0) % (b1 - b0), x0:x1]


def rounded(size, radius, scale=4):
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return big.resize(size, Image.LANCZOS)


def piece(img, box, radius=None, alpha=None):
    x0, y0, x1, y1 = box
    rgba = Image.fromarray(img[y0:y1, x0:x1].astype(np.uint8), "RGB").convert("RGBA")
    if alpha is not None:
        rgba.putalpha(alpha)
    elif radius is not None:
        rgba.putalpha(rounded((x1 - x0, y1 - y0), radius))
    return rgba


def recolour(rgba, target, keep_light=True):
    """Same shading, another colour: luminance x target (bright highlights kept)."""
    a = np.asarray(rgba).astype(np.float64)
    lum = a[..., :3].mean(axis=2, keepdims=True) / 150
    out = np.clip(lum * np.array(target, float), 0, 255)
    if keep_light:
        light = (a[..., :3].min(axis=2, keepdims=True) > 200).astype(float)
        out = out * (1 - light) + a[..., :3] * light
    a[..., :3] = out
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def ring(rgba, width):
    a = np.asarray(rgba).copy()
    a[width:-width, width:-width, 3] = 0
    return Image.fromarray(a, "RGBA")


pieces = {}

# ---------- SETTINGS ----------
s = SETTINGS.copy()
pieces["SliderFill"] = piece(s, (378, 195, 916, 212), radius=7)
pieces["SliderTrack"] = recolour(pieces["SliderFill"], (34, 26, 70), keep_light=False)
knob = piece(s, (914, 185, 947, 219))
cm = Image.new("L", (33 * 4, 34 * 4), 0)
ImageDraw.Draw(cm).ellipse((0, 0, 33 * 4 - 1, 34 * 4 - 1), fill=255)
knob.putalpha(cm.resize((33, 34), Image.LANCZOS))
pieces["SliderKnob"] = knob
pieces["ToggleOn"] = piece(s, (976, 408, 1069, 453), radius=22)
off = recolour(pieces["ToggleOn"].transpose(Image.FLIP_LEFT_RIGHT), (120, 110, 150))
pieces["ToggleOff"] = off
for y0, y1 in ((184, 224), (304, 344)):  # the baked sliders: studs from the row's clean left part
    stud_fill(s, (370, y0, 952, y1), (90, 362))
settings_bg = Image.fromarray(s.astype(np.uint8), "RGB").convert("RGBA")
settings_bg.putalpha(window_mask(SETTINGS))

# ---------- QUESTS ----------
q = QUESTS.copy()
tab_on = q[133:197, 66:397].copy()
tab_on[:, -60:] = tab_on[:, :60][:, ::-1]  # the badge covered its right end: the left end mirrored
pieces["TabOn"] = piece(tab_on, (0, 0, tab_on.shape[1], tab_on.shape[0]), radius=8)
pieces["TabOff"] = piece(q, (410, 133, 752, 197), radius=8)
pieces["Badge"] = piece(q, (352, 126, 402, 160), radius=8)
pieces["IconTile"] = piece(q, (78, 370, 165, 453), radius=10)
pieces["RewardPill"] = piece(q, (706, 373, 890, 443), radius=10)
pieces["ButtonBlue"] = piece(q, (906, 378, 1080, 438), radius=10)
pieces["ButtonGreen"] = piece(q, (906, 247, 1080, 307), radius=10)
pieces["ButtonGrey"] = recolour(pieces["ButtonGreen"], (120, 120, 132))
pieces["Track"] = piece(q, (183, 432, 597, 452), radius=9)
pieces["Fill"] = piece(q, (184, 302, 596, 320), radius=8)
card = q.copy()
# tile, track, pill and button painted out with the card's own studs (clean between x 190 and 690)
card[428:456, 180:600] = card[404:432, 180:600]  # the track first: the studs one period up
stud_fill(card, (70, 364, 182, 462), (190, 690))
stud_fill(card, (700, 364, 1092, 462), (190, 690))
pieces["RowCard"] = piece(card, (62, 357, 1098, 470), radius=12)
pieces["RowGlow"] = ring(piece(q, (52, 212, 1108, 347), radius=14), 12)
stud_panel(q, (40, 116, 1112, 610), np.median(q[473:484, 80:1080].reshape(-1, 3), axis=0))  # tab row + list
quests_bg = Image.fromarray(q.astype(np.uint8), "RGB").convert("RGBA")
quests_bg.putalpha(window_mask(QUESTS))

# ---------- INVENTORY ----------
v = INVENTORY.copy()
pieces["InvTabOn"] = piece(v, (223, 17, 348, 52), radius=6)
pieces["InvTabOff"] = piece(v, (352, 17, 476, 52), radius=6)
pieces["SellRed"] = recolour(piece(v, (507, 68, 638, 101), radius=7), (230, 50, 44))
cell = v.copy()
cell[119:140, 23:44] = cell[119:140, 127:148][:, ::-1]  # the number badge: the top-right corner mirrored
flat_face(cell, (30, 200, 142, 208), (60, 120), tolerance=30)  # the rarity line
pieces["Cell"] = piece(cell, (23, 119, 148, 218), radius=6)
tile_rows(v, (18, 110, 648, 396), (330, 392))  # the grid area: the empty bottom band repeated
inventory_bg = Image.fromarray(v.astype(np.uint8), "RGB").convert("RGBA")
inventory_bg.putalpha(window_mask(INVENTORY))

# ---------- write ----------
settings_bg.resize((1024, 644), Image.LANCZOS).save(DIR / "settings_bg.png")
quests_bg.resize((1024, 644), Image.LANCZOS).save(DIR / "quests_bg.png")
inventory_bg.save(DIR / "inventory_bg.png")
# the atlas is stored at SCALE (Roblox keeps uploads at most 1024 px wide); Size = drawn size in canvas pixels
SCALE = 0.9
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
for n, (px, py, _, _) in rects.items():
    atlas.alpha_composite(scaled[n], (px, py))
atlas.save(DIR / "menu_pieces.png")
lines = [
    "-- ReplicatedStorage.MenuArt.MenuArtAtlas  (ModuleScript, client) -- GENERATED by assets/ui/menus2/build_menus2.py,",
    "-- do not edit. Pieces of menu_pieces.png: Rect = { X, Y, W, H } in atlas pixels (the atlas is the pieces at",
    "-- Scale), Size = drawn size in canvas pixels of their window.",
    "return {",
    "    Scale = %s," % SCALE,
    "    Pieces = {",
]
for n in sorted(rects):
    lines.append("        %s = { Rect = { %d, %d, %d, %d }, Size = Vector2.new(%d, %d) }," % (n, *rects[n], pieces[n].width, pieces[n].height))
lines += ["    },", "}", ""]
OUT_LUA.parent.mkdir(parents=True, exist_ok=True)
OUT_LUA.write_bytes("\n".join(lines).encode("utf-8"))
print("atlas", atlas.size, "pieces", len(rects))
