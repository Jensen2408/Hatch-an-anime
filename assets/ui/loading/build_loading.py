"""Cleans the GPT Image loading art: white areas come back partly transparent, so everything enclosed by the
silhouette is made opaque again. Soft edges, glow and motion lines outside it stay as they are.

usage (from the project root): python -I assets/ui/loading/build_loading.py assets/ui/loading
Outputs: loading_logo.png, loading_runner.png
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

DIR = Path(sys.argv[1])


def fill_enclosed(rgba, threshold):
    a = rgba[..., 3]
    solid = a >= threshold
    h, w = solid.shape
    outside = np.zeros_like(solid)
    queue = deque()
    for x in range(w):
        queue.extend(((0, x), (h - 1, x)))
    for y in range(h):
        queue.extend(((y, 0), (y, w - 1)))
    while queue:
        y, x = queue.popleft()
        if 0 <= y < h and 0 <= x < w and not solid[y, x] and not outside[y, x]:
            outside[y, x] = True
            queue.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    inside = ~outside
    # keep the antialiased rim: only pixels 2 px away from the outside become opaque
    near = outside.copy()
    for _ in range(2):
        near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
    out = rgba.copy()
    out[..., 3] = np.where(inside & ~near, 255, a)
    return out


for source, target, threshold in (("gpt_logo", "loading_logo", 170), ("gpt_runner", "loading_runner", 110)):
    image = np.asarray(Image.open(DIR / f"{source}.png").convert("RGBA")).copy()
    result = fill_enclosed(image, threshold)
    Image.fromarray(result, "RGBA").save(DIR / f"{target}.png")
    print(target, result.shape, "opaque %.1f%%" % ((result[..., 3] == 255).mean() * 100))
