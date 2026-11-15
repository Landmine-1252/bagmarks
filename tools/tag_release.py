#!/usr/bin/env python3
"""Resolve or verify release tags; create a missing tag only on explicit request."""
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


def validate_target(repository, tag, commit):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must be a GitHub owner/name")
    if not re.fullmatch(VERSION, tag) or not re.fullmatch(SHA, commit):
        raise ValueError("A plain version tag and full tested commit SHA are required")


def find_tag(repository, tag, api):
    target = f"refs/tags/{tag}"
    refs = api(f"repos/{repository}/git/matching-refs/tags/{tag}")
    if not isinstance(refs, list) or any(not isinstance(ref, dict) for ref in refs):
        raise ValueError("Could not verify the existing GitHub tags")
    matches = [ref for ref in refs if ref.get("ref") == target]
    if len(matches) > 1:
        raise ValueError("Ambiguous release tag")
    return matches[0] if matches else None


def tag_commit(repository, ref, api):
    obj = ref.get("object")
    seen = set()
    for _ in range(10):
        if not isinstance(obj, dict) or not isinstance(obj.get("sha"), str) or not re.fullmatch(SHA, obj["sha"]):
            raise ValueError("Unreadable release tag object")
        if obj.get("type") == "commit":
            return obj["sha"]
        if obj.get("type") != "tag" or obj["sha"] in seen:
            raise ValueError("Release tag does not resolve to a commit")
        seen.add(obj["sha"])
        data = api(f"repos/{repository}/git/tags/{obj['sha']}")
        obj = data.get("object") if isinstance(data, dict) else None
    raise ValueError("Release tag nesting is too deep")


def resolve_source(repository, tag, commit, api=github_api):
    """A retry builds the existing tag, even if the workflow branch has advanced."""
    validate_target(repository, tag, commit)
    ref = find_tag(repository, tag, api)
    return tag_commit(repository, ref, api) if ref is not None else commit


def ensure_tag(repository, tag, commit, create=False, api=github_api):
    validate_target(repository, tag, commit)
    ref = find_tag(repository, tag, api)
    if ref is None:
        if not create:
            raise ValueError(f"Tag {tag} no longer exists; refusing to recreate a pushed tag")
        # POST only creates a new reference. Never move an existing tag.
        target = f"refs/tags/{tag}"
        ref = api(f"repos/{repository}/git/refs", {"ref": target, "sha": commit})
        if not isinstance(ref, dict) or ref.get("ref") != target:
            raise ValueError("Could not verify the newly created tag")
    if tag_commit(repository, ref, api) != commit:
        raise ValueError(f"Tag {tag} points to a different commit; no tag was moved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--create", action="store_true", help="Create the tag if it does not exist")
    mode.add_argument("--resolve", action="store_true", help="Select the existing tag's source, or --commit for a new tag")
    parser.add_argument("--github-output", help="Append the resolved commit to this Actions output file")
    args = parser.parse_args()
    try:
        if args.github_output and not args.resolve:
            raise ValueError("--github-output requires --resolve")
        if args.resolve:
            commit = resolve_source(args.repository, args.tag, args.commit)
            if args.github_output:
                with open(args.github_output, "a", encoding="utf-8") as output:
                    output.write(f"commit={commit}\n")
            print(f"Selected source for {args.tag}: {commit}")
        else:
            ensure_tag(args.repository, args.tag, args.commit, args.create)
            print(f"Verified tag {args.tag} at tested commit {args.commit}")
    except subprocess.CalledProcessError as error:
        parser.error("GitHub tag request failed: " + (error.stderr or str(error)).strip())
    except (ValueError, OSError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
