#!/usr/bin/env python3
"""Verify a release tag's commit; create a missing tag only on explicit request."""
import argparse
import json
import re
import subprocess

from release import VERSION

SHA = r"[0-9a-f]{40}"


def github_api(endpoint, payload=None):
    command = ["gh", "api", "--method", "POST" if payload is not None else "GET", endpoint]
    if payload is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


def ensure_tag(repository, tag, commit, create=False, api=github_api):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must be a GitHub owner/name")
    if not re.fullmatch(VERSION, tag) or not re.fullmatch(SHA, commit):
        raise ValueError("A plain version tag and full tested commit SHA are required")
    base = f"repos/{repository}/git"
    target = f"refs/tags/{tag}"
    refs = api(f"{base}/matching-refs/tags/{tag}")
    if not isinstance(refs, list) or any(not isinstance(ref, dict) for ref in refs):
        raise ValueError("Could not verify the existing GitHub tags")
    matches = [ref for ref in refs if ref.get("ref") == target]
    if not matches:
        if not create:
            raise ValueError(f"Tag {tag} no longer exists; refusing to recreate a pushed tag")
        # POST creates only a new reference. A concurrent creation fails rather
        # than moving somebody else's tag to this build's commit.
        created = api(f"{base}/refs", {"ref": target, "sha": commit})
        if not isinstance(created, dict) or created.get("ref") != target:
            raise ValueError("Could not verify the newly created tag")
        matches = [created]
    if len(matches) != 1:
        raise ValueError("Ambiguous release tag")
    obj = matches[0].get("object")
    seen = set()
    for _ in range(10):
        if not isinstance(obj, dict) or not isinstance(obj.get("sha"), str) or not re.fullmatch(SHA, obj["sha"]):
            raise ValueError("Unreadable release tag object")
        if obj.get("type") == "commit":
            if obj["sha"] != commit:
                raise ValueError(f"Tag {tag} points to a different commit; no tag was moved")
            return
        if obj.get("type") != "tag" or obj["sha"] in seen:
            raise ValueError("Release tag does not resolve to a commit")
        seen.add(obj["sha"])
        data = api(f"{base}/tags/{obj['sha']}")
        obj = data.get("object") if isinstance(data, dict) else None
    raise ValueError("Release tag nesting is too deep")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--create", action="store_true", help="Create the tag if it does not exist")
    args = parser.parse_args()
    try:
        ensure_tag(args.repository, args.tag, args.commit, args.create)
    except subprocess.CalledProcessError as error:
        parser.error("GitHub tag request failed: " + (error.stderr or str(error)).strip())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(f"Verified tag {args.tag} at tested commit {args.commit}")


if __name__ == "__main__":
    main()
