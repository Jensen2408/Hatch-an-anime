# Cuts the magenta screen out of a Studio booth capture and saves a square transparent PNG icon.
# usage: python3 key_icon.py <capture.jpg> <out.png> [size]
import sys
from PIL import Image, ImageFilter
import numpy as np
src, out = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 420
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
# magenta-ness: high red and blue, low green
mag = np.minimum(r, b) - g
alpha = np.clip(1.0 - (mag - 60) / 120.0, 0, 1)           # >180 = background, <60 = subject
# despill: pull leftover magenta out of edge pixels
spill = np.clip(np.minimum(r, b) - g, 0, None) * (1 - alpha) * 0.9
r2 = np.clip(r - spill, 0, 255); b2 = np.clip(b - spill, 0, 255)
rgba = np.dstack([r2, g, b2, alpha * 255]).astype(np.uint8)
img = Image.fromarray(rgba, "RGBA")
a = img.split()[3].filter(ImageFilter.MinFilter(3))         # shave the 1px fringe
img.putalpha(a)
bbox = img.split()[3].point(lambda v: 255 if v > 20 else 0).getbbox()
img = img.crop(bbox)
w, h = img.size
side = int(max(w, h) * 1.06)
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
canvas.paste(img, ((side - w) // 2, (side - h) // 2))
canvas = canvas.resize((size, size), Image.LANCZOS)
canvas.save(out)
print(out, canvas.size)
