"""Turn the GPT Image page art (page_<tab>.png, generated from text-free layout sketches) into the shop's
BOOSTS / PASSES / CASH / DAILY page images.

usage (from the project root, after build_shop_atlas.py):
    python -I assets/ui/shop_art/build_shop_pages.py assets/ui/shop_art

Each page_<tab>.png is 1536 x 1024 with the 1092 x 679 sketch scaled into 1536 x 955 at y 34. The page image is
the canvas below the tab row (y 183..679, full width), with the panel's alpha from shop_background.png, a few
generated details the game draws itself painted out, and stored at 1024 px wide (drawn at 1092 x 496).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

DIR = Path(sys.argv[1])
CANVAS = (1092, 679)
TOP = 183
alpha = np.asarray(Image.open(DIR / "shop_background.png").convert("RGBA").resize(CANVAS, Image.LANCZOS))[..., 3]


def load(tab):
    g = Image.open(DIR / f"page_{tab}.png").convert("RGB")
    return np.asarray(g.crop((0, 34, 1536, 34 + 955)).resize(CANVAS, Image.LANCZOS)).astype(np.int32)


def row_fill(img, box, cols):
    """Each row of box becomes the median of the sample columns (cols = list of (x0, x1))."""
    x0, y0, x1, y1 = box
    xs = [x for a, b in cols for x in range(a, b)]
    for y in range(y0, y1):
        img[y, x0:x1] = np.median(img[y, xs], axis=0)


def shift(img, box, dx, dy=0):
    """Copies the pixels dx / dy away into box (a patch of the same frame / face)."""
    x0, y0, x1, y1 = box
    img[y0:y1, x0:x1] = img[y0 + dy : y1 + dy, x0 + dx : x1 + dx].copy()


def save(tab, img):
    rgba = np.dstack([np.clip(img, 0, 255), alpha.astype(np.int32)]).astype(np.uint8)
    page = Image.fromarray(rgba[TOP:], "RGBA")
    page.resize((1024, round(page.height * 1024 / page.width)), Image.LANCZOS).save(DIR / f"shop_page_{tab}.png")


save("boosts", load("boosts"))

passes = load("passes")
row_fill(passes, (590, 444, 1018, 487), [(572, 588), (1020, 1032)])  # the generated level squares (11, not 10)
# the faint coin silhouette in the money card's bottom-right corner: that corner of the card mirrored from its left
# (card x 553..1045: x mirrors to 1598 - x)
passes[486:537, 916:986] = passes[486:537, 612:682][:, ::-1].copy()
passes[520:604, 984:1032] = passes[520:604, 566:614][:, ::-1].copy()
save("passes", passes)

cash = load("cash")
row_fill(cash, (56, 196, 180, 240), [(182, 220)])  # the small pack has no badge
save("cash", cash)

daily = load("daily")
# day 7 = the crown: card 8's middle into card 7, then card 8 painted out with the page's dark face
daily[400:532, 572:772] = daily[400:532, 820:1020].copy()
daily[380:550, 794:1046] = np.median(daily[552:592, 800:1040].reshape(-1, 3), axis=0)
# padlocks (the game marks claimed / locked days itself): each card's top-right corner becomes its top-left
# corner mirrored (the cards are symmetric)
CARDS = [(62, 290, 225), (305, 540, 225), (555, 787, 225), (803, 1035, 225), (62, 290, 391), (305, 540, 391), (555, 787, 391)]
for left, right, top in CARDS:
    w = 48
    corner = daily[top - 10 : top + 44, left - 2 : left - 2 + w].copy()
    daily[top - 10 : top + 44, right + 2 - w : right + 2] = corner[:, ::-1]
save("daily", daily)
print("pages ok")
