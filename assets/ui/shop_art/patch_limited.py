"""Paste the egg-free middle of the GPT edit (limited_scene_gpt.png) into the mockup's LIMITED card.

usage (from the project root):
    python -I assets/ui/shop_art/patch_limited.py assets/ui/shop_art/shop_reference.png assets/ui/shop_art/limited_scene_gpt.png assets/ui/shop_art/shop_reference_noegg.png

Only the egg and the title / subtitle area come from the edit (colour-matched to the mockup around it, feathered
edges); every other pixel stays the mockup's.
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ref = Image.open(sys.argv[1]).convert("RGB")
gpt = Image.open(sys.argv[2]).convert("RGB")
CARD = (45, 190, 550, 630)  # the limited card in the mockup
OFFSET_Y = 66  # the card sat 66 px from the top of the 1024 x 1024 edit input, 1024 px wide
cw, ch = CARD[2] - CARD[0], CARD[3] - CARD[1]
scale = 1024 / cw
edit = gpt.crop((0, OFFSET_Y, 1024, OFFSET_Y + round(ch * scale))).resize((cw, ch), Image.LANCZOS)
orig = ref.crop(CARD)
o = np.asarray(orig).astype(np.float64)
e = np.asarray(edit).astype(np.float64)

# mask: the egg (dark / green pixels in its box, holes filled) + the title and subtitle band
h, w = o.shape[:2]
egg_box = (190 - CARD[0], 214 - CARD[1], 398 - CARD[0], 466 - CARD[1])
lum = o.mean(axis=2)
green = (o[..., 1] > 120) & (o[..., 1] > o[..., 0] + 40) & (o[..., 1] > o[..., 2] + 40)
egg = np.zeros((h, w), bool)
x0, y0, x1, y1 = egg_box
egg[y0:y1, x0:x1] = (lum[y0:y1, x0:x1] < 70) | green[y0:y1, x0:x1]
# keep the biggest blob (the egg), then fill its holes
seen = np.zeros_like(egg)
best = []
for sy, sx in zip(*np.nonzero(egg)):
    if seen[sy, sx]:
        continue
    part, q = [], deque([(sy, sx)])
    seen[sy, sx] = True
    while q:
        y, x = q.popleft()
        part.append((y, x))
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and egg[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    if len(part) > len(best):
        best = part
egg = np.zeros_like(egg)
for y, x in best:
    egg[y, x] = True
outside = np.zeros_like(egg)
q = deque([(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)])
while q:
    y, x = q.popleft()
    if outside[y, x] or egg[y, x]:
        continue
    outside[y, x] = True
    for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
        if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx]:
            q.append((ny, nx))
egg = ~outside
mask_img = Image.fromarray((egg * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(15))
draw = ImageDraw.Draw(mask_img)
draw.rounded_rectangle((108 - CARD[0], 466 - CARD[1], 470 - CARD[0], 553 - CARD[1]), radius=18, fill=255)  # title + subtitle
mask_img = mask_img.filter(ImageFilter.GaussianBlur(7))
m = np.asarray(mask_img).astype(np.float64)[..., None] / 255

# colour match: the edit's ring around the mask to the mockup's ring (per channel mean / std)
ring = (np.asarray(mask_img.filter(ImageFilter.MaxFilter(31))) > 20) & (m[..., 0] < 0.05)
for c in range(3):
    ov, ev = o[..., c][ring], e[..., c][ring]
    e[..., c] = (e[..., c] - ev.mean()) / max(ev.std(), 1) * ov.std() + ov.mean()
out = o * (1 - m) + np.clip(e, 0, 255) * m
patched = ref.copy()
patched.paste(Image.fromarray(out.round().astype(np.uint8)), CARD[:2])
patched.save(sys.argv[3])
print("patched", sys.argv[3])
