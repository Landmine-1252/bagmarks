"""Version and release-note checks used by local builds and tag-triggered CI."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import release


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("BagMarks.toc", "## Interface: 16001\n## Version: 1.0.0\nCore.lua\n")
        self.write("Core.lua", 'A.version = "1.0.0"\n')
        self.write("README.md", "# BagMarks\n\nMark items to keep, sell, or mail.\n")
        self.write("CHANGELOG.md", "# Changelog\n\n## 1.0.0 - Initial release\n\n### Added\n\n- Item marks.\n")

    def write(self, name, content):
        (self.root / name).write_text(content, encoding="utf-8")

    def test_matching_plain_tag_yields_version_and_changelog_body(self):
        version, notes = release.read_release(self.root, "1.0.0")
        self.assertEqual(version, "1.0.0")
        self.assertEqual(notes, "### Added\n\n- Item marks.\n")

    def test_branch_build_checks_versions_without_requiring_a_tag(self):
        self.assertEqual(release.read_release(self.root)[0], "1.0.0")

    def test_mismatched_tag_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "does not match addon version"):
            release.read_release(self.root, "1.0.1")

    def test_nonrelease_tag_formats_are_rejected(self):
        for tag in ("v1.0.0", "1.0", "01.0.0", "1.0.0-beta", "1.0.0+build", "1.0.0\nother=1", "main"):
            with self.subTest(tag=tag), self.assertRaisesRegex(ValueError, "plain versions"):
                release.read_release(self.root, tag)

    def test_core_version_must_match_the_tagged_manifest(self):
        self.write("Core.lua", 'A.version = "0.9.0"\n')
        with self.assertRaisesRegex(ValueError, "Version mismatch"):
            release.read_release(self.root, "1.0.0")

    def test_readme_content_does_not_supply_release_metadata(self):
        for text in ("# BagMarks\n\nAlt + Right Click an item.\n",
                     "# BagMarks\n\n**Version 0.9.0**\n",
                     "# BagMarks\n\nSee the changelog for versions 0.9.0 and 1.0.0.\n"):
            with self.subTest(text=text):
                self.write("README.md", text)
                version, notes = release.read_release(self.root, "1.0.0")
                self.assertEqual(version, "1.0.0")
                self.assertEqual(notes, "### Added\n\n- Item marks.\n")

    def test_duplicate_or_missing_manifest_version_is_rejected(self):
        for text in ("## Title: BagMarks\n", "## Version: 1.0.0\n## Version: 1.0.0\n", "## Version: 1.0.0-beta\n"):
            self.write("BagMarks.toc", text)
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, "exactly one version"):
                release.read_release(self.root)

    def test_missing_or_empty_changelog_section_is_rejected(self):
        for text in ("# Changelog\n", "## 1.0.1\n\nNew release\n", "## 1.0.0\n\n"):
            self.write("CHANGELOG.md", text)
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, "nonempty"):
                release.read_release(self.root)

    def test_duplicate_changelog_version_is_rejected(self):
        self.write("CHANGELOG.md", "## 1.0.0\n\nOne\n\n## 1.0.0 - Again\n\nTwo\n")
        with self.assertRaisesRegex(ValueError, "exactly one"):
            release.read_release(self.root)

    def test_notes_stop_at_the_next_release_and_exclude_unreleased_changes(self):
        self.write("CHANGELOG.md", "# Changelog\n\n## Unreleased\n\nFuture\n\n## 1.0.0 - Initial\n\n### Added\n\nCurrent\n\n## 0.9.0\n\nOld\n")
        self.assertEqual(release.read_release(self.root)[1], "### Added\n\nCurrent\n")

    def test_release_links_point_to_the_matching_tag_and_keep_external_links(self):
        self.write("CHANGELOG.md", "## 1.0.0\n\n[Limits](docs/API.md#limits) [License](LICENSE) "
                   "[Site](https://example.com) [Email](mailto:author@example.com) [Local](#added)\n")
        notes = release.read_release(self.root, "1.0.0", "Landmine-1252/bagmarks")[1]
        self.assertIn("(https://github.com/Landmine-1252/bagmarks/blob/1.0.0/docs/API.md#limits)", notes)
        self.assertIn("(https://github.com/Landmine-1252/bagmarks/blob/1.0.0/LICENSE)", notes)
        for target in ("https://example.com", "mailto:author@example.com", "#added"):
            self.assertIn(f"({target})", notes)

    def test_invalid_repository_or_outside_link_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "owner/name"):
            release.read_release(self.root, repository="https://github.com/owner/repo")
        self.write("CHANGELOG.md", "## 1.0.0\n\n[Outside](../private.md)\n")
        with self.assertRaisesRegex(ValueError, "leaves the repository"):
            release.read_release(self.root, repository="owner/repo")

    def test_command_writes_notes_and_appends_the_validated_actions_output(self):
        notes, output = self.root / "dist/notes.md", self.root / "output"
        output.write_text("existing=value\n", encoding="utf-8")
        with mock.patch.object(release, "ROOT", self.root), contextlib.redirect_stdout(io.StringIO()):
            release.main(["--tag", "1.0.0", "--notes-file", str(notes), "--github-output", str(output)])
        self.assertIn("Item marks.", notes.read_text())
        self.assertEqual(output.read_text(), "existing=value\nversion=1.0.0\n")

    def test_command_fails_before_writing_any_release_output_on_a_bad_tag(self):
        notes, output = self.root / "dist/notes.md", self.root / "output"
        with mock.patch.object(release, "ROOT", self.root), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                release.main(["--tag", "1.0.1", "--notes-file", str(notes), "--github-output", str(output)])
        self.assertEqual(result.exception.code, 2)
        self.assertFalse(notes.exists())
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
