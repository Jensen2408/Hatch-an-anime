"""Build the quest HUD atlas straight from the reference mockup (text removed, bars rebuilt full / empty).

usage (from the project root): python -I assets/ui/quests/build_atlas.py assets/ui/quests/quest_reference.png assets/ui/quests
Atlas layout (pixels): panel 252x196 at (0,0); empty track 170x22 at (0,196); full fill 170x22 at (0,218);
round chevron button 31x31 at (172,196).
"""
import sys
from pathlib import Path
from statistics import median
from PIL import Image, ImageDraw

ref = Image.open(sys.argv[1]).convert("RGB")
out_dir = Path(sys.argv[2])
W, H = ref.size  # 249 x 195
src = ref.copy()
px = src.load()


def row_fill(x0, x1, y0, y1, samples):
    """Replace x0..x1 / y0..y1 (inclusive) with the per-row median of the sample columns."""
    for y in range(y0, y1 + 1):
        cols = [x for a, b in samples for x in range(a, b + 1)]
        colour = tuple(int(median(ref.getpixel((x, y))[c] for x in cols)) for c in range(3))
        for x in range(x0, x1 + 1):
            px[x, y] = colour


# 1. remove the text (header has horizontal stripes, cards are flat: a per-row median looks untouched)
row_fill(22, 148, 6, 45, [(150, 200)])  # QUESTS
for top in (51, 121):  # card 1 / card 2
    row_fill(10, 176, top + 5, top + 33, [(178, 238)])  # description
    row_fill(186, 238, top + 35, top + 58, [(184, 185), (236, 239)])  # count


# 2. bars: empty track and full fill, both 170 x 22, from bar 1 (x 13-182, y 86-107; mirror axis x = 195 - x)
def bar(build):
    img = Image.new("RGB", (170, 22))
    for y in range(22):
        for x in range(170):
            img.putpixel((x, y), build(13 + x, 86 + y))
    return img


def mid(xs, y):
    return tuple(int(median(ref.getpixel((x, y))[c] for x in xs)) for c in range(3))


track = bar(lambda x, y: ref.getpixel((x, y)) if x >= 108 else ref.getpixel((195 - x, y)) if x <= 33 else mid(range(112, 166), y))
fill = bar(lambda x, y: ref.getpixel((x, y)) if x <= 98 else ref.getpixel((195 - x, y)) if x >= 162 else mid(range(40, 96), y))

# 3. the screenshot crop cut the left outline off: add the right edge's last 3 columns mirrored, and one top row
panel = Image.new("RGB", (W + 3, H + 1))
panel.paste(src, (3, 1))
for i, x in enumerate((248, 247, 246)):
    panel.paste(src.crop((x, 0, x + 1, H)), (i, 1))
panel.paste(panel.crop((0, 1, W + 3, 2)), (0, 0))
PW, PH = panel.size  # 252 x 196

# 4. cut the corners: the game background behind the mockup shows there
scale = 4
mask = Image.new("L", (PW * scale, PH * scale), 0)
c = 9 * scale
w, h = PW * scale - 1, PH * scale - 1
ImageDraw.Draw(mask).polygon([(c, 0), (w - c, 0), (w, c), (w, h - c), (w - c, h), (c, h), (0, h - c), (0, c)], fill=255)
mask = mask.resize((PW, PH), Image.LANCZOS)
panel = panel.convert("RGBA")
panel.putalpha(mask)

# 5. round chevron button (centre 224,27 in panel pixels), so it can rotate over the header's own copy
box = (209, 12, 240, 43)
chevron = panel.crop(box)
cm = Image.new("L", (31 * scale, 31 * scale), 0)
cx, cy, r = (224 - box[0] + 0.5) * scale, (27 - box[1] + 0.5) * scale, 14.8 * scale
ImageDraw.Draw(cm).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
chevron.putalpha(cm.resize((31, 31), Image.LANCZOS))

atlas = Image.new("RGBA", (PW, 240), (0, 0, 0, 0))
atlas.alpha_composite(panel, (0, 0))
atlas.alpha_composite(track.convert("RGBA"), (0, 196))
atlas.alpha_composite(fill.convert("RGBA"), (0, 218))
atlas.alpha_composite(chevron, (172, 196))
atlas.save(out_dir / "quest_atlas.png")
print("atlas", atlas.size)
