"""Fills transparent holes the image model cut into enclosed areas (egg highlights, potion glass).
Usage: python -I fill_holes.py <folder>. Run once after generating; the PNGs here are already filled.
rain_egg is also flattened onto its shell colour: a falling egg must not show the world through it."""
import sys
from collections import deque
from PIL import Image

# file -> colour of the enclosed see-through pixels
FILLS = {
    "rain_egg": (250, 232, 200, 255),
    "potion_cash": (255, 236, 170, 120),
    "potion_hatch": (235, 255, 225, 120),
    "potion_legendary": (240, 215, 255, 120),
}
SOLID = 40  # alpha above this blocks the flood from outside


def fill(path, colour):
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    outside = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        queue.extend([(0, y), (width - 1, y)])
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        if outside[y * width + x] or pixels[x, y][3] > SOLID:
            continue
        outside[y * width + x] = 1
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    filled = 0
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] <= SOLID and not outside[y * width + x]:
                pixels[x, y] = colour
                filled += 1
    if colour[3] == 255:
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                r, g, b, a = pixels[x, y]
                near_edge = any(outside[j * width + i] for i, j in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
                if a < 255 and not outside[y * width + x] and not near_edge:
                    t = a / 255
                    pixels[x, y] = (
                        round(r * t + colour[0] * (1 - t)),
                        round(g * t + colour[1] * (1 - t)),
                        round(b * t + colour[2] * (1 - t)),
                        255,
                    )
    image.save(path)
    return filled


def close_cork_gap(path):
    """potion_cash came out with an empty band between the cork and the neck: repeat the row above it."""
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    for y in range(1, height // 3):
        if max(pixels[x, y][3] for x in range(width)) <= SOLID and max(pixels[x, y - 1][3] for x in range(width)) > SOLID:
            for x in range(width):
                pixels[x, y] = pixels[x, y - 1]
    image.save(path)


folder = sys.argv[1]
for name, colour in FILLS.items():
    print(name, fill(f"{folder}/{name}.png", colour))
close_cork_gap(f"{folder}/potion_cash.png")
