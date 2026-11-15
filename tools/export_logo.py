#!/usr/bin/env python3
"""Export the generated logo for WoW and the README (development only: Pillow).

The artwork itself is unchanged. These are alpha-preserving size/format exports
from the full-resolution source, not regenerated illustrations.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "art" / "BagMarks-source.png"
with Image.open(source) as logo:
    assert logo.mode == "RGBA" and logo.width == logo.height
    assert logo.getchannel("A").getextrema() == (0, 255)
    logo.resize((256, 256), Image.Resampling.LANCZOS).save(root / "Media" / "BagMarks.png")
    logo.resize((64, 64), Image.Resampling.LANCZOS).save(root / "Media" / "BagMarks.tga", compression=None)
print("Exported the BagMarks logo: 256px PNG and 64px uncompressed RGBA TGA.")
