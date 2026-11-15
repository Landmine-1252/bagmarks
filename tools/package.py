#!/usr/bin/env python3
"""Create an installable archive with a correctly capitalized BagMarks directory."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
version = re.search(r"^## Version: ([0-9.]+)$", (root / "BagMarks.toc").read_text(), re.MULTILINE)[1]
output = root / "dist" / f"BagMarks-{version}.zip"
output.parent.mkdir(exist_ok=True)
files = [root / name for name in ("BagMarks.toc", "Bindings.xml", "README.md", "CHANGELOG.md", "LICENSE")]
files += sorted(root.glob("*.lua")) + sorted((root / "Media").glob("*.tga"))
files += sorted((root / "Media").glob("*.png")) + sorted((root / "docs").glob("*.md"))
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        info = zipfile.ZipInfo("BagMarks/" + path.relative_to(root).as_posix(), (2026, 11, 14, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        archive.writestr(info, path.read_bytes())
print(output)
