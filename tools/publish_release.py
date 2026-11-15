#!/usr/bin/env python3
"""Create or finish a GitHub release without moving tags or replacing assets."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import zipfile

from package import validate_archive
from tag_release import ensure_tag, github_api


def run_gh(arguments):
    subprocess.run(["gh"] + arguments, text=True, capture_output=True, check=True)


def download_asset(repository, asset_id):
    result = subprocess.run(
        ["gh", "api", f"repos/{repository}/releases/assets/{asset_id}",
         "--header", "Accept: application/octet-stream"],
        capture_output=True, check=True)
    return result.stdout


def find_release(repository, tag, api):
    # Listing includes drafts with the publisher's write token. Failed requests
    # must propagate, never be mistaken for a release that does not exist.
    page = 1
    while True:
        releases = api(f"repos/{repository}/releases?per_page=100&page={page}")
        if not isinstance(releases, list) or any(not isinstance(item, dict) for item in releases):
            raise ValueError("Could not read the existing GitHub releases")
        matches = [item for item in releases if item.get("tag_name") == tag]
        if len(matches) > 1:
            raise ValueError(f"Multiple releases found for {tag}")
        if matches:
            release = matches[0]
            if not isinstance(release.get("draft"), bool) or not isinstance(release.get("assets"), list):
                raise ValueError("Unreadable release state")
            return release
        if len(releases) < 100:
            return None
        page += 1


def matching_asset(release, name):
    assets = release["assets"]
    if any(not isinstance(asset, dict) for asset in assets):
        raise ValueError("Unreadable release assets")
    matches = [asset for asset in assets if asset.get("name") == name]
    if len(matches) > 1:
        raise ValueError(f"Multiple release assets named {name}")
    return matches[0] if matches else None


def verify_asset(repository, asset, content, download):
    if asset.get("state") != "uploaded" or asset.get("size") != len(content):
        raise ValueError("Existing addon ZIP is incomplete or differs from this build; it was not replaced")
    digest = asset.get("digest")
    if not digest:
        # Older assets may lack GitHub's SHA-256 field. Compare downloaded bytes.
        asset_id = asset.get("id")
        if type(asset_id) is not int or asset_id <= 0:
            raise ValueError("Cannot verify the existing addon ZIP's identity")
        digest = "sha256:" + hashlib.sha256(download(repository, asset_id)).hexdigest()
    if digest != "sha256:" + hashlib.sha256(content).hexdigest():
        raise ValueError("Existing addon ZIP differs from this build; it was not replaced")


def publish_release(repository, tag, commit, archive, notes, create_tag=False,
                    api=github_api, run=run_gh, download=download_asset):
    archive, notes = Path(archive).resolve(), Path(notes).resolve()
    if archive.name != f"BagMarks-{tag}.zip":
        raise ValueError("The addon ZIP filename must match the release tag")
    validate_archive(archive)
    with zipfile.ZipFile(archive) as package:
        toc = package.read("BagMarks/BagMarks.toc").decode("utf-8")
    if re.findall(r"^## Version: ([^\r\n]+)", toc, re.MULTILINE) != [tag]:
        raise ValueError("The packaged addon version must match the release tag")
    if not notes.read_text(encoding="utf-8").strip():
        raise ValueError("Release notes must not be empty")
    content = archive.read_bytes()
    ensure_tag(repository, tag, commit, create=create_tag, api=api)
    release = find_release(repository, tag, api)
    if release is None:
        # Create a draft first so all assets are verified before publication,
        # including on repositories with immutable releases enabled.
        run(["release", "create", tag, "--repo", repository, "--verify-tag", "--draft",
             "--title", f"BagMarks {tag}", "--notes-file", str(notes)])
        release = find_release(repository, tag, api)
        if release is None:
            raise ValueError("Could not find the newly created draft; retry to finish the release")
    asset = matching_asset(release, archive.name)
    if asset is None:
        if release.get("immutable"):
            raise ValueError("This published release is immutable and has no addon ZIP; GitHub does not allow adding one")
        # No --clobber: a rerun must never delete an existing download.
        run(["release", "upload", tag, str(archive), "--repo", repository])
        release = find_release(repository, tag, api)
        asset = matching_asset(release, archive.name) if release is not None else None
        if asset is None:
            raise ValueError("Could not confirm the uploaded addon ZIP; retry to verify the release")
    verify_asset(repository, asset, content, download)
    if release["draft"]:
        run(["release", "edit", tag, "--repo", repository, "--draft=false"])
    return f"Release {tag} is ready with verified {archive.name}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--notes-file", type=Path, required=True)
    parser.add_argument("--create-tag", action="store_true")
    args = parser.parse_args()
    try:
        print(publish_release(args.repository, args.tag, args.commit, args.archive,
                              args.notes_file, args.create_tag))
    except subprocess.CalledProcessError as error:
        detail = error.stderr or str(error)
        if isinstance(detail, bytes):
            detail = detail.decode("utf-8", errors="replace")
        parser.error("GitHub release request failed: " + detail.strip())
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
