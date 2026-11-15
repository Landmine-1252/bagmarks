#!/usr/bin/env python3
"""Check namespaced API presence against a local Blizzard source export.

This verifies names, not signatures, restrictions, or runtime behavior.
Use the pinned baseline in docs/API_COMPATIBILITY.md for reproducibility.
"""
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path, help="Root containing Interface/AddOns")
args = parser.parse_args()
docs = args.source / "Interface" / "AddOns" / "Blizzard_APIDocumentationGenerated"
assert docs.is_dir(), docs
systems = {}
for path in docs.glob("*.lua"):
    text = path.read_text()
    namespace = re.search(r'Namespace = "([^"]+)"', text)
    if namespace:
        systems.setdefault(namespace[1], set()).update(re.findall(r'Name = "([^"]+)"', text))
root = Path(__file__).resolve().parents[1]
code = "\n".join(path.read_text() for path in root.glob("*.lua"))
used = sorted(set(re.findall(r"\b(C_\w+)\.(\w+)", code)))
missing = []
for namespace, name in used:
    present = name in systems.get(namespace, set())
    print(("FOUND " if present else "MISSING ") + namespace + "." + name)
    if not present:
        missing.append(namespace + "." + name)
assert not missing, missing
print(f"{len(used)} namespaced APIs found. Inspect signatures and UI source separately.")
