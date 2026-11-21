# Building and uploading BagMarks

The current build is **1.1.0**, with a searchable item rule manager, complete character names in the recipient picker, and three mark sizes.

## Build the upload file

From the repository root, run:

```sh
make package
```

This requires Python 3, Lua 5.1 and its compiler. If Lua is installed elsewhere:

```sh
make package LUA=/path/to/lua5.1 LUAC=/path/to/luac5.1
```

The result is **`dist/BagMarks-1.1.0.zip`**. The command runs static checks, the mocked addon tests, archive regression tests, and validation of the finished ZIP. A failed package validation leaves the previous ZIP intact. No game installation, other addon, or SavedVariables file is changed.

`python3 tools/package.py` creates and validates the ZIP without running the Lua checks or regression suites. Use `make package` for a release.

## Release from GitHub

1. Update `BagMarks.toc`, `Core.lua`, and `CHANGELOG.md` for the new version. Commit and push the changes to `main`, including the release workflow.
2. Create and push a plain version tag such as `1.1.1` at that commit. You can leave the tag there until you are ready to release.
3. On GitHub, open **Releases → Draft a new release**, select the existing tag, and enter the title and release notes.
4. Click **Publish release** to start CI. Follow **Build and release** on the **Actions** tab. [Release workflow](../.github/workflows/release.yml)

The workflow subscribes only to `release.published`. It tests the tagged commit, checks that the tag matches the addon version and changelog, and builds the installable ZIP. After the checks pass, it attaches the ZIP to the published GitHub release and uploads the same build to CurseForge with that version’s changelog. Published prereleases appear as Beta on CurseForge. [GitHub release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release)

### One-time setup

- Save a CurseForge API token under **Settings → Secrets and variables → Actions → New repository secret** as `CURSEFORGE_TOKEN`. The GitHub release asset uses the built-in workflow token. [CurseForge API tokens](https://www.curseforge.com/account/api-tokens)
- Disable or delete the old direct CurseForge packaging webhook in **Settings → Webhooks**. Revoke its old token. The new workflow uploads directly to BagMarks project **1806693** for **WoW Forever 1.60.1**. [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api)

### Retry an upload

Open the original publication run in **Actions** and choose **Re-run failed jobs**. The GitHub job verifies an existing ZIP by size and SHA-256. If the repository uses immutable releases, attach the locally built ZIP to the draft before publishing so CI can verify it. [GitHub release immutability](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

The CurseForge job reports the file ID after a successful upload and skips a previously successful upload on a rerun of that publication. If the connection dropped before it received a response, check the project’s files before retrying. [BagMarks files](https://www.curseforge.com/wow/addons/bagmarks/files/all)

## Manual upload to CurseForge

1. Open the existing BagMarks project for World of Warcraft.
2. Upload **`dist/BagMarks-1.1.0.zip`**, or the identically named addon asset from a successful GitHub release. Do not upload GitHub's source ZIP or the outer Actions artifact ZIP.
3. Select the matching **Forever 1.60.1** game version in the upload form. The addon declares `Interface: 16001`; it is not a Classic Era or Retail build. If Forever is unavailable in that form, ask CurseForge support about the project configuration instead of choosing an unrelated client version.
4. Use the version 1.1.0 notes in [CHANGELOG.md](../CHANGELOG.md) as the Markdown changelog. Keep the status as awaiting approval until CurseForge accepts the file.

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

For future patch releases, increment the final version number. Update `BagMarks.toc`, `Core.lua`, and changelog together before building. Update the README when usage or settings change. Packaging never changes the version automatically.
