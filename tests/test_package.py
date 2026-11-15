"""Release format regressions, independent of the WoW runtime mock."""
from pathlib import Path
import shutil
import stat
import sys
import tempfile
import unittest
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from package import build_archive, validate_archive


class ReleaseArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.archive = build_archive(ROOT, self.directory / "release.zip")

    def altered(self, change):
        output = self.directory / "altered.zip"
        with zipfile.ZipFile(self.archive) as source, zipfile.ZipFile(output, "w") as target:
            for entry in source.infolist():
                content = source.read(entry)
                if change(entry):
                    target.writestr(entry, content)
        return output

    def test_extracts_one_installable_folder_with_exact_source_files(self):
        validate_archive(self.archive)
        with zipfile.ZipFile(self.archive) as archive:
            archive.extractall(self.directory / "installed")
        installed = self.directory / "installed"
        self.assertEqual([p.name for p in installed.iterdir()], ["BagMarks"])
        for path in (installed / "BagMarks").rglob("*"):
            if path.is_file():
                relative = path.relative_to(installed / "BagMarks")
                self.assertEqual(path.read_bytes(), (ROOT / relative).read_bytes())
        self.assertTrue((installed / "BagMarks/BagMarks.toc").is_file())
        for excluded in (".git", ".github", "tools", "tests", "dist", "Makefile"):
            self.assertFalse((installed / "BagMarks" / excluded).exists())

    def test_build_is_reproducible(self):
        second = build_archive(ROOT, self.directory / "second.zip")
        self.assertEqual(self.archive.read_bytes(), second.read_bytes())

    def test_requires_explicit_folder_records(self):
        archive = self.altered(lambda entry: not entry.is_dir())
        with self.assertRaisesRegex(ValueError, "Missing explicit directory"):
            validate_archive(archive)

    def test_requires_regular_file_type_metadata(self):
        def old_permissions(entry):
            if not entry.is_dir():
                entry.external_attr = 0o644 << 16
            return True
        with self.assertRaisesRegex(ValueError, "file-type metadata"):
            validate_archive(self.altered(old_permissions))

    def test_rejects_repository_wrapper_folder(self):
        def rename(entry):
            entry.filename = "bagmarks-main/" + entry.filename
            return True
        with self.assertRaisesRegex(ValueError, "Invalid addon path"):
            validate_archive(self.altered(rename))

    def test_rejects_missing_toc_dependency(self):
        archive = self.altered(lambda entry: entry.filename != "BagMarks/API.lua")
        with self.assertRaisesRegex(ValueError, "Missing required release files"):
            validate_archive(archive)

    def test_rejects_symlinks_and_parent_paths(self):
        def symlink(entry):
            if entry.filename == "BagMarks/API.lua":
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            return True
        with self.assertRaisesRegex(ValueError, "file-type metadata"):
            validate_archive(self.altered(symlink))
        def traversal(entry):
            if entry.filename == "BagMarks/API.lua":
                entry.filename = "BagMarks/../API.lua"
            return True
        with self.assertRaisesRegex(ValueError, "Invalid addon path"):
            validate_archive(self.altered(traversal))

    def test_rejects_duplicate_paths(self):
        with zipfile.ZipFile(self.archive, "a") as archive, warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            entry = archive.getinfo("BagMarks/API.lua")
            archive.writestr(entry, archive.read(entry))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            validate_archive(self.archive)

    def test_rejects_truncated_zip(self):
        self.archive.write_bytes(self.archive.read_bytes()[:-100])
        with self.assertRaises(zipfile.BadZipFile):
            validate_archive(self.archive)

    def test_failed_build_preserves_previous_archive(self):
        source = self.directory / "source"
        shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns(".git", "dist", "__pycache__"))
        (source / "API.lua").unlink()
        previous = self.archive.read_bytes()
        with self.assertRaisesRegex(ValueError, "Missing required release files"):
            build_archive(source, self.archive)
        self.assertEqual(self.archive.read_bytes(), previous)
        self.assertFalse(list(self.directory.glob(".bagmarks-*")))


if __name__ == "__main__":
    unittest.main()
