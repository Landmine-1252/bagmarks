# Building and uploading BagMarks

The initial release remains **1.0.0**. The rejected CurseForge upload was not a published CurseForge release, so the reusable-item fix and archive changes are included in the same version.

## Build the upload file

From the repository root, run:

```sh
make package
```

This requires Python 3, Lua 5.1 and its compiler. If Lua is installed elsewhere:

```sh
make package LUA=/path/to/lua5.1 LUAC=/path/to/luac5.1
```

The result is **`dist/BagMarks-1.0.0.zip`**. The command runs static checks, the mocked addon tests, archive regression tests, and validation of the finished ZIP. A failed package validation leaves the previous ZIP intact. No game installation, other addon, or SavedVariables file is changed.

`python3 tools/package.py` creates and validates the ZIP without running the Lua checks or regression suites. Use `make package` for a release.

## Release from GitHub

[Build and release](../.github/workflows/release.yml) runs tests and builds the addon on branch pushes and pull requests. A version-tag push or a manual release request from the Actions page also publishes a GitHub release with the installable ZIP attached after the checks pass. Ordinary branch and pull-request builds only save a downloadable Actions artifact.

First commit and push the workflow, build scripts, and addon changes to the repository's default branch, `main`. The workflow must be on that branch for GitHub to show its manual run button.

To release entirely through the GitHub website:

1. Open the repository's **Actions** tab.
2. Select **Build and release** in the sidebar.
3. Click **Run workflow** and choose **main**, or the branch containing the version you want to release.
4. Enter **`1.0.0`** in the version field.
5. Click **Run workflow** to start the checks and release build.

This uses GitHub's [manual workflow form](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow). After a successful build, the workflow creates the version tag at the exact commit it tested, then uploads the ZIP and publishes the release. An existing tag must already point to that commit; the workflow never moves tags. Failed checks create neither a tag nor a release.

Use this Actions form for the automated release. GitHub's separate **Releases → Draft a new release** form creates a release itself, which conflicts with this workflow's release-creation step. The Actions form lets the ZIP finish building before the release is published.

You can also keep using terminal tags. From the committed version you want to release:

```sh
git tag -a 1.0.0 -m "BagMarks 1.0.0"
git push origin 1.0.0
```

Use a plain `major.minor.patch` tag, such as **`1.0.0`**, without a `v` prefix or prerelease suffix. The tag must match the versions in `BagMarks.toc`, `Core.lua`, and the README, and there must be a nonempty `## 1.0.0` section in `CHANGELOG.md`. The workflow stops if these disagree. It does not change version numbers for you.

After the checks pass, the workflow creates **BagMarks 1.0.0** in the repository's **Releases** page and attaches **`BagMarks-1.0.0.zip`**. Release notes come from that version's changelog section, with documentation links pointing to the same tag. Download the named addon ZIP from the release assets for installation or CurseForge submission; GitHub's automatic source archives contain the repository.

Follow the run in the repository's **Actions** tab. Builds run with read access, and only the publishing job receives `contents: write`. The workflow uses GitHub's automatic token, so no personal access token or new repository secret is needed. GitHub Actions must be enabled, and any organization policy must allow the publishing job's permission. The official checkout and artifact actions are pinned to verified commit hashes.

Only a pushed version tag or an explicit manual release request can publish. The publishing job uses the exact artifact produced by its successful build and verifies the tag's commit. Only the manual path may create a missing tag; the push path refuses to recreate a tag removed during the build. Publishing is serialized per version, and existing GitHub releases are not replaced. If an upload fails after tagging or leaves a draft, inspect that tag, draft and the Actions log before retrying. Hosted event delivery and repository permissions still need verification on the first real GitHub run.

This automates GitHub releases. CurseForge submission remains the separate upload step below. GitHub's [tag-trigger documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push) and [release command reference](https://cli.github.com/manual/gh_release_create) describe the trigger and publication behavior used here.

## Upload to CurseForge

1. Open the existing BagMarks project for World of Warcraft.
2. Upload **`dist/BagMarks-1.0.0.zip`**, or the identically named addon asset from a successful GitHub release. Do not upload GitHub's source ZIP or the outer Actions artifact ZIP.
3. Select the matching **Forever 1.60.1** game version in the upload form. The addon declares `Interface: 16001`; it is not a Classic Era or Retail build. If Forever is unavailable in that form, ask CurseForge support about the project configuration instead of choosing an unrelated client version.
4. Use the version 1.0.0 notes in [CHANGELOG.md](../CHANGELOG.md) as the Markdown changelog. Keep the status as awaiting approval until CurseForge accepts the file.

The archive has one top-level `BagMarks/` folder, with `BagMarks.toc` directly inside it. This follows CurseForge's [WoW archive guidance](https://support.curseforge.com/support/solutions/articles/9000196615-known-issues) and [TOC naming requirements](https://support.curseforge.com/support/solutions/articles/9000209856).

```text
BagMarks/
  BagMarks.toc
  Bindings.xml
  Core.lua
  ...other addon Lua files
  README.md
  CHANGELOG.md
  LICENSE
  Media/
  docs/
```

The ZIP includes runtime files, artwork, the license, and documentation. Build scripts, tests, Git metadata, older ZIPs, and SavedVariables are excluded. All directories have explicit ZIP records; regular files and directories have standard Unix file types and permissions, with DOS directory flags for compatibility. Files use ordinary Deflate compression, with no encryption or ZIP64. Archive paths, required TOC files and assets, versions, checksums, and exact source bytes are checked after writing.

## About the rejected archive

The reported message was **“Failed to verify archive.”** The previous `dist/BagMarks-1.0.0.zip` passed local CRC checks and contained the correct `BagMarks/BagMarks.toc` path. Its packager omitted explicit directory records and the regular-file type bits in its ZIP metadata. The revised packager supplies both to avoid relying on archive readers inferring them.

The rejection does not identify which check failed. These packaging changes address local compatibility concerns, but they do not prove why CurseForge rejected the previous file or guarantee approval. Local tests cannot reproduce CurseForge's private verifier or check the game-version tags selected in its upload form.

If the corrected upload is rejected too, keep the existing project and request details from CurseForge support. Include the filename, project/file ID, exact rejection, and selected game version. Their [moderation policy](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies) advises against deleting a rejected project or file and starting over.

Once 1.0.0 is actually released, future patch releases can increment the final version number. Update `BagMarks.toc`, `Core.lua`, the README, and changelog together before building. Packaging never changes the version automatically.
