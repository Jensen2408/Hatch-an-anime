# Splits one 3x2 booth capture into 6 transparent square icons.
# usage: python3 split_batch.py <capture.jpg> <name1,name2,...> [outdir]
# Item k (1..6) sits at col=(k-1)%3, row=(k-1)//3; the camera faces the booth from the front, so screen col = 2-col.
import sys, os
from PIL import Image, ImageFilter
import numpy as np
src, names = sys.argv[1], [n for n in sys.argv[2].split(",") if n]
outdir = sys.argv[3] if len(sys.argv) > 3 else "png"
full = Image.open(src).convert("RGB")
W, H = full.size
for k, name in enumerate(names, start=1):
    col, row = (k - 1) % 3, (k - 1) // 3
    sc = 2 - col
    box = (sc * W // 3, row * H // 2, (sc + 1) * W // 3, (row + 1) * H // 2)
    im = np.asarray(full.crop(box)).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mag = np.minimum(r, b) - g
    alpha = np.clip(1.0 - (mag - 60) / 120.0, 0, 1)
    spill = np.clip(mag, 0, None) * (1 - alpha) * 0.9
    rgba = np.dstack([np.clip(r - spill, 0, 255), g, np.clip(b - spill, 0, 255), alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    img.putalpha(img.split()[3].filter(ImageFilter.MinFilter(3)))
    # bounding box from the alpha with small specks removed (opening), so a stray dot can't off-centre the icon
    solid = img.split()[3].point(lambda v: 255 if v > 20 else 0)
    cleaned = solid.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))
    bbox = cleaned.getbbox()
    if bbox:
        pad = 6
        bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(img.width, bbox[2] + pad), min(img.height, bbox[3] + pad))
        # drop pixels outside the cleaned shape's box (the specks)
        keep = Image.new("L", img.size, 0); keep.paste(255, bbox)
        img.putalpha(Image.fromarray(np.minimum(np.asarray(img.split()[3]), np.asarray(keep))))
    if not bbox:
        print("EMPTY", name); continue
    img = img.crop(bbox)
    w, h = img.size
    side = int(max(w, h) * 1.06)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2))
    canvas.resize((420, 420), Image.LANCZOS).save(os.path.join(outdir, name + ".png"))
    print(name, (w, h))
