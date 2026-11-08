# Contact sheet of icons on a dark slot background (to eyeball them). usage: python3 sheet.py out.png name1 name2 ...
import sys
from PIL import Image, ImageDraw
out, names = sys.argv[1], sys.argv[2:]
cols = 6; cell = 140
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell, rows * (cell + 18)), (24, 24, 28, 255))
d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    x, y = (i % cols) * cell, (i // cols) * (cell + 18)
    d.rounded_rectangle((x + 4, y + 4, x + cell - 4, y + cell - 4), 10, fill=(48, 48, 54, 255))
    try:
        im = Image.open(f"png/{n}.png").resize((cell - 16, cell - 16), Image.LANCZOS)
        sheet.alpha_composite(im, (x + 8, y + 8))
    except Exception:
        d.text((x + 10, y + 60), "missing", fill=(255, 80, 80, 255))
    d.text((x + 8, y + cell), n[:20], fill=(220, 220, 220, 255))
sheet.save(out)
