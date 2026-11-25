#!/usr/bin/env python3
"""Build and validate the installable ZIP, including explicit folder records."""
from pathlib import Path
import re
import stat
import tempfile
import zipfile

ADDON = "BagMarks"
TIMESTAMP = (2026, 11, 14, 0, 0, 0)  # Reproducible; independent of local file mtimes.


def release_files(root):
    """Ship runtime files and documentation, not the repository or build tools."""
    files = [root / name for name in ("BagMarks.toc", "Bindings.xml", "README.md", "CHANGELOG.md", "LICENSE")]
    files += list(root.glob("*.lua")) + list((root / "Media").glob("*.tga"))
    files += list((root / "Media").glob("*.png")) + list((root / "docs").glob("*.md"))
    payload = {}
    for path in sorted(files):
        # Capture source bytes once. The finished archive must match this exact
        # payload, including files added locally before the next commit.
        if path.is_symlink():
            raise ValueError(f"Release files must not be symlinks: {path}")
        payload[f"{ADDON}/{path.relative_to(root).as_posix()}"] = path.read_bytes()
    return payload


def zip_entry(name, directory=False):
    info = zipfile.ZipInfo(name, TIMESTAMP)
    info.create_system = 3  # Unix metadata with explicit directory/regular types.
    info.compress_type = zipfile.ZIP_STORED if directory else zipfile.ZIP_DEFLATED
    mode = (stat.S_IFDIR | 0o755) if directory else (stat.S_IFREG | 0o644)
    info.external_attr = (mode << 16) | (0x10 if directory else 0)
    return info


def validate_archive(path, expected=None):
    """Check our release format locally. This does not emulate CurseForge moderation."""
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        # WoW installations often use case-insensitive filesystems. Two entries
        # that differ only in case would collide when a player extracts them.
        if len(names) != len({name.casefold() for name in names}):
            raise ValueError("Duplicate or case-colliding archive paths")
        entries = {entry.filename: entry for entry in archive.infolist()}
        payload = {}
        for name, entry in entries.items():
            parts = name.rstrip("/").split("/")
            if parts[0] != ADDON or any(part in ("", ".", "..") for part in parts) or "\\" in name or ":" in name:
                raise ValueError(f"Invalid addon path: {name}")
            if entry.flag_bits & 1 or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                raise ValueError(f"Unsupported ZIP encryption/compression: {name}")
            mode = entry.external_attr >> 16
            if entry.create_system != 3 or not (stat.S_ISDIR(mode) if entry.is_dir() else stat.S_ISREG(mode)):
                raise ValueError(f"Missing or unsupported file-type metadata: {name}")
            if entry.is_dir():
                if not entry.external_attr & 0x10 or entry.file_size:
                    raise ValueError(f"Invalid directory record: {name}")
            else:
                if len(parts) < 2 or (len(parts) > 2 and parts[1] not in ("Media", "docs")):
                    raise ValueError(f"Unexpected release content: {name}")
                if parts[-1] != "LICENSE" and Path(name).suffix not in (".lua", ".toc", ".xml", ".md", ".tga", ".png"):
                    raise ValueError(f"Unexpected release file type: {name}")
                payload[name] = archive.read(entry)
            for index in range(1, len(parts)):
                parent = "/".join(parts[:index]) + "/"
                if parent not in entries or not entries[parent].is_dir():
                    raise ValueError(f"Missing explicit directory: {parent}")
        if f"{ADDON}/" not in entries or not entries[f"{ADDON}/"].is_dir():
            raise ValueError("Missing addon root directory")
        toc = payload.get(f"{ADDON}/{ADDON}.toc", b"").decode("utf-8")
        if not re.search(r"^## Interface: 16001\s*$", toc, re.MULTILINE):
            raise ValueError("Missing matching TOC or Forever interface number")
        version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)\s*$", toc, re.MULTILINE)
        if not version or f'A.version = "{version[1]}"'.encode() not in payload.get(f"{ADDON}/Core.lua", b""):
            raise ValueError("Missing or inconsistent release version")
        required = {f"{ADDON}/{line.strip()}" for line in toc.splitlines() if line.strip() and not line.startswith("#")}
        required.update(f"{ADDON}/{name}" for name in ("Bindings.xml", "README.md", "CHANGELOG.md", "LICENSE"))
        required.update(f"{ADDON}/Media/{name}.tga" for name in ("BagMarks", "Lock", "Junk", "Mail", "Disenchant"))
        missing = required - payload.keys()
        if missing:
            raise ValueError("Missing required release files: " + ", ".join(sorted(missing)))
        if archive.testzip() is not None:
            raise ValueError("ZIP checksum validation failed")
        if expected is not None and payload != expected:
            raise ValueError("Packaged files differ from the source payload")
        return len(payload)


def build_archive(root, output=None):
    payload = release_files(root)
    toc = payload[f"{ADDON}/{ADDON}.toc"].decode("utf-8")
    match = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)\s*$", toc, re.MULTILINE)
    if not match:
        raise ValueError("Missing release version in BagMarks.toc")
    output = output or root / "dist" / f"{ADDON}-{match[1]}.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    directories = {f"{ADDON}/"}
    # Emit real folder records as well as files. A valid single-root install
    # should not depend on the extractor inventing omitted parent directories.
    for name in payload:
        parts = name.split("/")
        directories.update("/".join(parts[:index]) + "/" for index in range(1, len(parts)))
    # A failed build must not replace a previous usable archive.
    with tempfile.TemporaryDirectory(prefix=".bagmarks-", dir=output.parent) as temp:
        draft = Path(temp) / output.name
        with zipfile.ZipFile(draft, "w", zipfile.ZIP_DEFLATED, allowZip64=False) as archive:
            for name in sorted(directories):
                archive.writestr(zip_entry(name, directory=True), b"")
            for name, content in payload.items():
                archive.writestr(zip_entry(name), content)
        validate_archive(draft, payload)
        draft.replace(output)
    return output


if __name__ == "__main__":
    result = build_archive(Path(__file__).resolve().parents[1])
    print(f"Validated release ZIP: {result}")
