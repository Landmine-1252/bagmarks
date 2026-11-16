#!/usr/bin/env python3
"""Check release versions and extract notes. Publishing stays in GitHub Actions."""
import argparse
from pathlib import Path, PurePosixPath
import re
from urllib.parse import quote, urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[1]
VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def one_version(root, filename, pattern):
    matches = re.findall(pattern, (root / filename).read_text(encoding="utf-8"), re.MULTILINE)
    if len(matches) != 1 or not re.fullmatch(VERSION, matches[0]):
        raise ValueError(f"{filename} must declare exactly one version such as 1.0.0")
    return matches[0]


def read_release(root, tag=None, repository=None):
    version = one_version(root, "BagMarks.toc", r"^## Version: ([^\r\n]+)$")
    core = one_version(root, "Core.lua", r'^A\.version = "([^"\r\n]+)"[ \t]*$')
    # The player guide is independent of release numbers. Runtime metadata
    # must still agree with the tag and the matching changelog section.
    if version != core:
        raise ValueError(f"Version mismatch: TOC {version}, Core.lua {core}")
    if tag is not None:
        if not re.fullmatch(VERSION, tag):
            raise ValueError("Release tags must be plain versions such as 1.0.0 (no v prefix or suffix)")
        if tag != version:
            raise ValueError(f"Tag {tag} does not match addon version {version}")

    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    notes = []
    # Only the matching version becomes release notes. Other versions and an
    # Unreleased section may coexist without leaking into the published entry.
    for section in re.split(r"^##[ \t]+", changelog, flags=re.MULTILINE)[1:]:
        heading, _, body = section.partition("\n")
        if re.fullmatch(re.escape(version) + r"(?:[ \t]+.*)?", heading):
            notes.append(body.strip())
    if len(notes) != 1 or not notes[0]:
        raise ValueError(f"CHANGELOG.md needs exactly one nonempty '## {version}' section")
    notes = notes[0]

    if repository is not None:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+", repository):
            raise ValueError("Repository must be a GitHub owner/name")
        base = f"https://github.com/{repository}/blob/{version}/"

        def absolute_link(match):
            target = match[2]
            url = urlsplit(target)
            if url.scheme or target.startswith(("#", "/")):
                return match[0]
            path = PurePosixPath(url.path)
            if ".." in path.parts:
                raise ValueError(f"Release-note link leaves the repository root: {target}")
            target = base + urlunsplit(("", "", quote(path.as_posix(), safe="/%"), url.query, url.fragment))
            return match[1] + target + match[3]

        # Changelog links are relative to the repository root. Release pages
        # need full links to documentation at the same immutable version tag.
        notes = re.sub(r"(\[[^\]\n]+\]\()([^\s)]+)(\))", absolute_link, notes)
    return version, notes + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Require this exact version tag; empty means a branch/PR build")
    parser.add_argument("--repository", help="GitHub owner/name for links in published release notes")
    parser.add_argument("--notes-file", type=Path, help="Write the matching changelog section here")
    parser.add_argument("--github-output", type=Path, help="Append version to this GitHub Actions output file")
    args = parser.parse_args(argv)
    try:
        version, notes = read_release(ROOT, tag=args.tag or None, repository=args.repository)
        if args.notes_file:
            args.notes_file.parent.mkdir(parents=True, exist_ok=True)
            args.notes_file.write_text(notes, encoding="utf-8")
        if args.github_output:
            with args.github_output.open("a", encoding="utf-8") as output:
                output.write(f"version={version}\n")
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(f"Release metadata verified: BagMarks {version}")


if __name__ == "__main__":
    main()
