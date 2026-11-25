#!/usr/bin/env python3
"""Rebuild original geometric BagMarks pictograms (development only: Pillow).

The masks are white with dark outlines for tinting in WoW.
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

    white, dark = (255, 255, 255, 255), (16, 20, 25, 255)
    if kind == "Lock":
        box((3.25, .6, 12.75, 11), dark, 4.5)
        box((4.4, 1.7, 11.6, 10.5), white, 3.4)
        box((6.1, 3.45, 9.9, 8.3), dark, 1.9)
        box((1.5, 6, 14.5, 15.5), dark, 2)
        box((2.8, 7.2, 13.2, 14.25), white, 1)
        box((6.6, 8.7, 9.4, 11.4), dark, 1.35)
        box((7.25, 10, 8.75, 12.75), dark, .4)
    elif kind == "Junk":
        box((2.5, 4, 13.5, 15.4), dark, 2)
        box((3.8, 5.3, 12.2, 14.15), white, 1.2)
        box((5, .8, 11, 4.5), dark, 1.4)
        box((6.2, 1.9, 9.8, 4.5), white, .4)
        box((.8, 3, 15.2, 6.3), dark, 1)
        box((1.9, 4, 14.1, 5.15), white, .5)
        for x in (6.4, 9.6):
            box((x - .55, 7.7, x + .55, 12.35), dark, .4)
    elif kind == "Disenchant":  # Faceted shard and a detached splinter
        shard = [(4, 3), (9, .6), (12, 5), (7, 15.4), (2, 10)]
        draw.polygon([(int(x * SCALE), int(y * SCALE)) for x, y in shard], fill=white)
        line(shard + shard[:1], dark, 1.3)
        line([(9, 1), (6.5, 6.5), (7, 14.5)], dark, 1)
        line([(3, 6), (6.5, 6.5), (11.4, 5)], dark, 1)
        chip = [(13.6, 8.5), (15.5, 11), (11.1, 14), (11.7, 10.4)]
        draw.polygon([(int(x * SCALE), int(y * SCALE)) for x, y in chip], fill=white)
        line(chip + chip[:1], dark, 1)
    else:
        box((.5, 2.5, 15.5, 14), dark, 1.9)
        box((1.85, 3.8, 14.15, 12.7), white, .75)
        line([(1.7, 4.25), (8, 9.4), (14.3, 4.25)], dark, 1.6)
    return image.resize((32, 32), Image.Resampling.LANCZOS)


def themed_icon(theme, kind):
    image = Image.new("RGBA", (16 * SCALE, 16 * SCALE))
    draw = ImageDraw.Draw(image)
    ink, paper = "#10151b", "#ffffff"

    def points(vertices):
        return [(round(x * SCALE), round(y * SCALE)) for x, y in vertices]

    def shape(*vertices):
        path = points(vertices)
        draw.polygon(path, fill=paper)
        draw.line(path + path[:1], fill=ink, width=round(SCALE * 1.25), joint="curve")

    def cut(*vertices):
        draw.line(points(vertices), fill=ink, width=round(SCALE * 1.3), joint="curve")

    def stroke(*vertices, width=2):
        for color, weight in ((ink, width + 1.8), (paper, width)):
            path = points(vertices)
            draw.line(path, fill=color, width=round(SCALE * weight), joint="curve")
            radius = round(SCALE * weight / 2)
            for x, y in (path[0], path[-1]):
                draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)

    def disc(bounds, fill=paper):
        draw.ellipse(tuple(round(v * SCALE) for v in bounds), fill=fill, outline=ink, width=round(SCALE * 1.2))

    if theme == "Heraldry":
        if kind == "Lock":  # Heater shield
            shape((2, 2), (8, 3), (14, 2), (13, 9), (11, 12), (8, 15), (5, 13), (3, 10))
            cut((4.6, 6), (8, 8.4), (11.4, 6))
        elif kind == "Junk":  # Broken sword
            shape((1.3, 1), (6, 2.5), (8, 5.5), (4.5, 7.7), (2, 5))
            stroke((7.4, 8.3), (13.7, 14.1), width=2.3)
            stroke((7.2, 13.1), (12.7, 7.4), width=2)
        elif kind == "Disenchant":  # A heraldic star
            shape((8, .7), (10, 5.7), (15, 7.5), (10.2, 10), (8, 15.3), (5.8, 10), (1, 7.5), (6, 5.7))
            cut((8, 4.4), (8, 10))
        else:  # Messenger's pennant
            stroke((3, 14), (3, 2), width=1.5)
            shape((3, 1.5), (15, 2), (11.5, 6), (15, 9.5), (3, 9))
    elif theme == "Runic":
        if kind == "Lock":
            shape((8, 1), (14, 7), (11, 13), (8, 15), (5, 13), (2, 7))
            cut((5, 8.5), (8, 4.5), (11, 8.5))
        elif kind == "Junk":
            shape((7, 1), (14, 4.5), (10, 5.5), (11, 6.5), (2, 8.5))
            shape((14, 8), (9, 15), (2, 12.5), (6.5, 10.5), (5.5, 9.5))
        elif kind == "Disenchant":  # Forked lightning rune
            shape((9, .7), (14, .7), (9, 6.5), (13.3, 6.5), (3.2, 15.4), (6.9, 9), (2.2, 9))
        else:
            shape((2, 1), (14, 8), (2, 15), (6, 8))
            cut((5, 5), (10, 8), (5, 11))
    elif theme == "Workshop":
        if kind == "Lock":  # Ward key
            stroke((8, 7), (14, 13), (12, 15), width=2)
            disc((1, 1, 10, 10)); disc((3.5, 3.5, 7, 7), ink)
        elif kind == "Junk":  # Damaged gear
            shape((6, 1), (10, 1), (11, 4), (14, 3), (15, 6), (12, 8), (15, 11), (12, 14), (9, 12), (8, 15), (4, 14), (4, 11), (1, 10), (2, 6), (5, 6))
            disc((5, 5, 10, 10), ink)
        elif kind == "Disenchant":  # Jeweler's hammer and crystal
            stroke((3, 14), (8, 5), width=2.1)
            shape((4, 1), (8, 1), (12, 5), (10, 8), (6, 5), (3, 4))
            shape((12.5, 9), (15, 11), (12, 15), (10, 12))
        else:  # Packed crate
            shape((1, 4), (8, 1), (15, 4), (15, 12), (8, 15), (1, 12))
            cut((1, 4), (8, 7.7), (15, 4)); cut((8, 7.7), (8, 14))
    elif theme == "Ledger":
        if kind == "Lock":
            stroke((2.3, 8.3), (6.1, 12), (13.7, 3.6), width=3.2)
        elif kind == "Junk":
            shape((3.5, 1.2), (8, 5.8), (12.5, 1.2), (14.8, 3.5), (10.2, 8), (14.8, 12.5), (12.5, 14.8), (8, 10.2), (3.5, 14.8), (1.2, 12.5), (5.8, 8), (1.2, 3.5))
        elif kind == "Disenchant":  # Asterisk
            stroke((8, 2), (8, 14), width=2.3)
            stroke((2.6, 4.7), (13.4, 11.3), width=2.3)
            stroke((2.6, 11.3), (13.4, 4.7), width=2.3)
        else:
            shape((1, 7), (15, 1), (11, 15), (7, 11), (5, 14), (5, 9))
            cut((5.1, 9.5), (11.8, 4.5))
    elif theme == "Nautical":
        if kind == "Lock":
            stroke((8, 5), (8, 13), width=2)
            shape((1, 7), (5, 10), (4, 11), (8, 12), (12, 11), (11, 10), (15, 7), (14, 12), (8, 15), (2, 12))
            disc((4.7, .8, 11.3, 7.4)); disc((6.7, 2.8, 9.3, 5.4), ink)
        elif kind == "Junk":  # Fish bones
            stroke((3, 8), (12, 8), width=1.8)
            stroke((6, 4), (8, 8), (6, 12), width=2)
            shape((10, 3.5), (15.4, 8), (10, 12.5))
            shape((.8, 4.5), (5.5, 8), (.8, 11.5))
        elif kind == "Disenchant":  # Compass rose
            disc((2.3, 2.3, 13.7, 13.7))
            shape((11.7, .7), (10, 10), (4.3, 15.3), (6, 6))
            cut((6, 6), (10, 10))
        else:
            shape((8.5, .8), (8.5, 10), (1.5, 10)); shape((10, 4), (14.7, 10), (10, 10))
            shape((.8, 11.5), (15.2, 11.5), (12, 15), (4, 15))
    elif theme == "Postage":
        if kind == "Lock":  # Wax seal
            shape((5, 8), (12, 8), (14, 15), (10, 13), (8, 15), (6, 12), (2, 14))
            disc((2, .8, 13.5, 12)); cut((4.6, 6), (7, 8.4), (10.6, 4.5))
        elif kind == "Junk":  # Rejected tag
            shape((1, 6), (6, 1), (15, 10), (10, 15))
            disc((4, 3.8, 6.5, 6.3), ink); cut((7.7, 11.4), (11.4, 7.7))
        elif kind == "Disenchant":  # Diamond on a perforated stamp
            shape((1.5, 1.5), (5, 1.5), (6, 3), (8, 1.5), (10, 3), (11, 1.5), (14.5, 1.5),
                  (14.5, 14.5), (11, 14.5), (10, 13), (8, 14.5), (6, 13), (5, 14.5), (1.5, 14.5))
            draw.polygon(points(((8, 4), (11.5, 8), (8, 12), (4.5, 8))), fill=ink)
        else:  # Postcard and stamp
            shape((1, 2), (15, 2), (15, 14), (1, 14))
            cut((3.5, 10), (8.5, 10))
            draw.rectangle((10*SCALE, 4*SCALE, 13*SCALE, 7*SCALE), fill=ink)
    elif theme == "Letters":
        # Single paths keep the colored strokes continuous inside their dark outline.
        letters = {
            "Mail": ((2.5, 13.5), (2.5, 2.5), (8, 8.8), (13.5, 2.5), (13.5, 13.5)),
            "Junk": ((7, 2.5), (12, 2.5), (12, 9.3), (11.5, 11.4),
                     (10, 13), (8, 13.5), (6, 13.3), (4.4, 12.2), (3.5, 10.3)),
            "Disenchant": ((3.5, 2.5), (8, 2.5), (10.5, 3.2), (12.1, 4.7), (13, 7), (13, 9),
                           (12.1, 11.3), (10.5, 12.8), (8, 13.5), (3.5, 13.5), (3.5, 2.5)),
            "Lock": ((4, 2.5), (4, 13.5), (12.5, 13.5)),
        }
        stroke(*letters[kind], width=2.8)
    return image.resize((32, 32), Image.Resampling.LANCZOS)


def color_masks(media):
    # All marks use the same silhouette. WoW applies the state color.
    edge = 32 * SCALE - 1
    bounds = (0, 0, edge, edge)
    ink = "#10151b"
    border = Image.new("RGBA", (edge + 1, edge + 1))
    draw = ImageDraw.Draw(border)
    draw.rounded_rectangle(bounds, radius=3 * SCALE, outline=ink, width=4 * SCALE)
    draw.rounded_rectangle(bounds, radius=3 * SCALE, outline="white", width=3 * SCALE)
    border.resize((32, 32), Image.Resampling.LANCZOS).save(media / "Border.tga", compression=None)

    circle = Image.new("RGBA", border.size)
    draw = ImageDraw.Draw(circle)
    draw.ellipse((SCALE, SCALE, edge - SCALE, edge - SCALE), fill="white", outline=ink, width=2 * SCALE)
    circle.resize((32, 32), Image.Resampling.LANCZOS).save(media / "Circles.tga", compression=None)


if __name__ == "__main__":
    media = ROOT / "Media"
    media.mkdir(exist_ok=True)
    # Toggle track and thumb share one atlas to keep the control crisp at UI scale.
    atlas = Image.new("RGBA", (64 * SCALE, 32 * SCALE))
    draw = ImageDraw.Draw(atlas)
    draw.rounded_rectangle((0, 0, 32 * SCALE - 1, 16 * SCALE - 1), 8 * SCALE, fill="white")
    draw.ellipse((32 * SCALE, 0, 48 * SCALE - 1, 16 * SCALE - 1), fill="white")
    draw.line([(x * SCALE, y * SCALE) for x, y in ((51, 6), (56, 10.5), (61, 6))],
              fill="white", width=2 * SCALE, joint="curve")
    atlas.resize((64, 32), Image.Resampling.LANCZOS).save(media / "Toggle.tga", compression=None)
    color_masks(media)
    for name in ("Lock", "Junk", "Mail", "Disenchant"):
        icon(name).save(media / f"{name}.tga", compression=None)
        for theme in ("Heraldry", "Runic", "Workshop", "Ledger", "Nautical", "Postage", "Letters"):
            themed_icon(theme, name).save(media / f"{theme}{name}.tga", compression=None)
    print("Built the BagMarks 32x32 RGBA icon sets.")
