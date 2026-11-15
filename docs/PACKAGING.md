# Building and uploading BagMarks

The initial release remains **1.0.0**. The rejected upload was not a published release, so the reusable-item fix and archive changes are included in the same version.

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

## Upload to CurseForge

1. Open the existing BagMarks project for World of Warcraft.
2. Upload **`dist/BagMarks-1.0.0.zip`**. Do not upload GitHub's source ZIP or zip the repository yourself.
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
