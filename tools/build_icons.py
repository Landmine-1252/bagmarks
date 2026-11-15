#!/usr/bin/env python3
"""Rebuild original geometric BagMarks pictograms (development only: Pillow).

The masks are white with dark outlines, so WoW can tint all three themes without
extra textures. No downloaded artwork, fonts, or game files are embedded.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SCALE = 8


def icon(kind):
    image = Image.new("RGBA", (16 * SCALE, 16 * SCALE))
    draw = ImageDraw.Draw(image)

    def line(points, fill, width=1):
        draw.line([(int(x * SCALE), int(y * SCALE)) for x, y in points], fill=fill,
                  width=int(width * SCALE), joint="curve")

    def box(bounds, fill, radius=0):
        draw.rounded_rectangle(tuple(int(v * SCALE) for v in bounds),
                               radius=int(radius * SCALE), fill=fill)

    white, dark = (255, 255, 255, 255), (15, 15, 15, 245)
    if kind == "Lock":
        draw.arc((4 * SCALE, 1 * SCALE, 12 * SCALE, 12 * SCALE), 180, 360, fill=dark, width=3 * SCALE)
        draw.arc((5 * SCALE, 2 * SCALE, 11 * SCALE, 12 * SCALE), 180, 360, fill=white, width=SCALE)
        box((2, 6, 14, 15), dark, 1.5)
        box((3, 7, 13, 14), white, 1)
        box((7, 9, 9, 11), dark, 1)
        box((7.5, 10, 8.5, 12.5), dark)
    elif kind == "Junk":
        box((3, 4, 13, 15), dark, 1)
        box((4, 5, 12, 14), white, .8)
        box((5, 1, 11, 4), dark, 1)
        box((6, 2, 10, 4), white)
        box((1, 3, 15, 6), dark, .6)
        box((2, 4, 14, 5), white)
        for x in (6, 8, 10):
            line([(x, 7), (x, 12)], dark, .8)
    else:
        box((1, 3, 15, 14), dark, 1)
        box((2, 4, 14, 13), white, .5)
        line([(2, 12.5), (6, 8.5)], dark, .8)
        line([(14, 12.5), (10, 8.5)], dark, .8)
        line([(2, 4.5), (8, 9), (14, 4.5)], dark, 1)
    return image.resize((32, 32), Image.Resampling.LANCZOS)


if __name__ == "__main__":
    media = ROOT / "Media"
    media.mkdir(exist_ok=True)
    for name in ("Lock", "Junk", "Mail"):
        icon(name).save(media / f"{name}.tga", compression=None)
    print("Built three original 32x32 RGBA TGA textures.")
