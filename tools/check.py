#!/usr/bin/env python3
"""Offline manifest, Lua 5.1 syntax, bindings XML, texture and safety checks."""
import argparse
from pathlib import Path
import re
import struct
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument("--luac", default="luac5.1")
args = parser.parse_args()
version = subprocess.run([args.luac, "-v"], check=True, capture_output=True, text=True)
assert "Lua 5.1" in version.stdout + version.stderr, "Use a Lua 5.1 compiler"
root = Path(__file__).resolve().parents[1]
toc = (root / "BagMarks.toc").read_text()
assert "## Interface: 16001" in toc
assert "## SavedVariables: BagMarksDB" in toc
assert "## SavedVariablesPerCharacter: BagMarksCharDB" in toc
addon_version = re.search(r"^## Version: ([0-9.]+)$", toc, re.MULTILINE)[1]
assert f'A.version = "{addon_version}"' in (root / "Core.lua").read_text()
minimap_code = (root / "Minimap.lua").read_text()
for callback in re.findall(r"^## AddonCompartment\w*: (\w+)$", toc, re.MULTILINE):
    assert f"function {callback}(" in minimap_code, callback
manifest = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert len(manifest) == len(set(manifest))
for name in manifest:
    assert (root / name).is_file(), name
assert set(manifest) == {path.name for path in root.glob("*.lua")}
for path in sorted(root.glob("*.lua")) + sorted((root / "tests").glob("*.lua")):
    subprocess.run([args.luac, "-p", str(path)], check=True)
    source = path.read_text()
    if path.parent == root:
        assert not re.search(r"\b(?:SendMail|DeleteCursorItem|RunMacroText)\s*\(", source), path
        assert not re.search(r"(?:C_Container\.\w+|C_Item\.\w+|ContainerFrameItemButton_OnClick)\s*=", source), path
        assert "SetOverrideBinding" not in source
for path in list(root.glob("*.lua")) + list(root.rglob("*.md")):
    assert chr(0x2014) not in path.read_text(), path
bindings = ET.parse(root / "Bindings.xml").getroot()
assert bindings.tag == "Bindings"
binding = bindings.find("Binding")
assert binding is not None and binding.attrib["name"] == "BAGMARKS_TOGGLE_MODE"
assert "BagMarks_ToggleMarkingMode();" in binding.text
for name, size in (("Lock", 32), ("Junk", 32), ("Mail", 32), ("BagMarks", 64)):
    data = (root / "Media" / f"{name}.tga").read_bytes()
    width, height, depth = struct.unpack_from("<HHB", data, 12)
    assert (width, height, depth) == (size, size, 32)
    assert data[2] == 2, "Textures must be uncompressed true-color TGA"
    alpha = data[18 + 3:18 + width * height * 4:4]
    assert min(alpha) == 0 and max(alpha) == 255, "Texture needs transparent and opaque pixels"
icon_path = re.search(r"^## IconTexture: (.+)$", toc, re.MULTILINE)[1]
assert icon_path.startswith("Interface\\AddOns\\BagMarks\\")
assert (root / icon_path.removeprefix("Interface\\AddOns\\BagMarks\\").replace("\\", "/")).is_file()
readme = (root / "README.md").read_text()
for link in re.findall(r'\]\(([^)]+)\)|src="([^"]+)"', readme):
    target = next(part for part in link if part)
    if not target.startswith(("https://", "http://", "#")):
        assert (root / target).is_file(), target
print("Static checks passed: manifest, Lua 5.1 syntax, XML, textures, and safety rules.")
