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

[Build and release](../.github/workflows/release.yml) runs automatically when a version tag such as `1.0.0` is pushed. It tests and builds the tagged addon, then publishes a GitHub release with the installable ZIP attached after the checks pass. Ordinary commits and pull requests do not start the workflow. The manual **Run workflow** button remains available for releases and retries.

First commit and push the workflow, build scripts, and addon changes to the repository's default branch, `main`. The workflow must be on that branch for GitHub to show its manual run button.

To release entirely through the GitHub website:

1. Open the repository's **Actions** tab.
2. Select **Build and release** in the sidebar.
3. Click **Run workflow** and choose **main**, or the branch containing the version you want to release.
4. Enter **`1.0.0`** in the version field.
5. Click **Run workflow** to start the checks and release build.

This uses GitHub's [manual workflow form](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow). For a new version, the workflow tests the selected branch's commit, creates its version tag, uploads the ZIP, and publishes the release. If that tag already exists, the workflow builds the tagged addon files using the updated release workflow from the selected branch. This lets you repair publishing after `main` has advanced, while keeping the release tied to its original source. The workflow never moves tags. Failed checks create neither a tag nor a release.

The Actions form can handle the whole release. If you already used GitHub's **Releases → Draft a new release** form, run this workflow for the same version to attach its addon ZIP. Existing titles and notes are preserved. An interrupted draft is published after its ZIP is verified.

You can also keep using terminal tags. From the committed version you want to release:

```sh
git tag -a 1.0.0 -m "BagMarks 1.0.0"
git push origin 1.0.0
```

Use a plain `major.minor.patch` tag, such as **`1.0.0`**, without a `v` prefix or prerelease suffix. The tag must match the versions in `BagMarks.toc`, `Core.lua`, and the README, and there must be a nonempty `## 1.0.0` section in `CHANGELOG.md`. The workflow stops if these disagree. It does not change version numbers for you.

After the checks pass, the workflow creates or completes the version's entry on the repository's **Releases** page and attaches **`BagMarks-1.0.0.zip`**. New release titles use **BagMarks 1.0.0**. New release notes come from that version's changelog section, with documentation links pointing to the same tag. Download the named addon ZIP from the release assets for installation or CurseForge submission; GitHub's automatic source archives contain the repository.

Follow the run in the repository's **Actions** tab. Builds run with read access, and only the publishing job receives `contents: write`. The workflow uses GitHub's automatic token, so no personal access token or new repository secret is needed. GitHub Actions must be enabled, and any organization policy must allow the publishing job's permission. The official checkout and artifact actions are pinned to verified commit hashes.

Only a pushed version tag or an explicit manual release request can publish. The publishing job uses the exact artifact produced by its successful build and verifies the tag's commit. The release tools are tested from the workflow's own commit before an existing tag is checked out. Only the manual path may create a missing tag; the push path refuses to recreate a tag removed during the build. Publishing is serialized per version. Existing ZIPs are checked by size and SHA-256, downloading the asset if GitHub has no digest. Matching assets need no upload; different or incomplete assets stop publishing for review. No asset is automatically deleted or replaced.

### Retry the failed 1.0.0 release

The November 15 run built and downloaded the addon successfully, then failed with **“a release with the same tag name already exists: 1.0.0.”** The existing release can be completed without deleting it or moving its tag.

1. Commit and push the updated workflow and release tools to **main**.
2. Open **Actions → Build and release → Run workflow**.
3. Choose **main**, enter **`1.0.0`**, and start a new run.
4. Once it succeeds, open the existing **1.0.0** release and download **`BagMarks-1.0.0.zip`**.

Start a new manual run after a workflow fix. GitHub's **Re-run failed jobs** button uses the original run's workflow and commit, so it would repeat the old publishing error. See GitHub's [rerun behavior](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).

For later retries, the workflow attaches a missing ZIP, verifies an existing ZIP, or completes an interrupted draft. An [immutable published release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) can only be verified; GitHub does not allow adding a missing asset to it. The workflow reports that case without changing the release. The corrected publication path has offline regression coverage and still needs a successful hosted run.

This automates GitHub releases. CurseForge submission remains the separate upload step below. GitHub's [tag-trigger documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push), [release command reference](https://cli.github.com/manual/gh_release_create), and [asset upload reference](https://cli.github.com/manual/gh_release_upload) describe the trigger and publication behavior used here.

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
