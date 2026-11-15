"""Exercise release creation, browser-created releases, and interrupted reruns offline."""
import copy
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from package import build_archive, release_files
from publish_release import download_asset, find_release, publish_release, run_gh

REPOSITORY = "Landmine-1252/bagmarks"
COMMIT = "a" * 40


class ReleasePublishingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        source = Path(cls.directory.name) / "source"
        # Keep this fixture at 1.0.0 when the real addon's version is bumped.
        for name, content in release_files(ROOT).items():
            path = source / Path(name).relative_to("BagMarks")
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.name == "BagMarks.toc":
                content = re.sub(rb"^## Version: [^\r\n]+", b"## Version: 1.0.0", content, flags=re.MULTILINE)
            elif path.name == "Core.lua":
                content = re.sub(rb'^A.version = "[^"]+"', b'A.version = "1.0.0"', content, flags=re.MULTILINE)
            path.write_bytes(content)
        cls.archive = build_archive(source, Path(cls.directory.name) / "BagMarks-1.0.0.zip")
        cls.content = cls.archive.read_bytes()

    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.notes = Path(self.work.name) / "notes.md"
        self.notes.write_text("Release notes\n", encoding="utf-8")
        self.tag = {"ref": "refs/tags/1.0.0", "object": {"type": "commit", "sha": COMMIT}}
        self.release = {"id": 123, "tag_name": "1.0.0", "draft": False, "immutable": False,
                        "name": "My release title", "body": "My release notes", "assets": []}
        self.api = mock.Mock(side_effect=self.api_request)
        self.run = mock.Mock(side_effect=self.command)
        self.download = mock.Mock(return_value=self.content)

    def asset(self):
        return {"id": 456, "name": "BagMarks-1.0.0.zip", "state": "uploaded",
                "size": len(self.content), "digest": "sha256:" + hashlib.sha256(self.content).hexdigest()}

    def api_request(self, endpoint, payload=None):
        if endpoint.endswith("/matching-refs/tags/1.0.0"):
            return [copy.deepcopy(self.tag)] if self.tag is not None else []
        if endpoint.endswith("/git/refs"):
            self.assertEqual(payload, {"ref": "refs/tags/1.0.0", "sha": COMMIT})
            self.tag = {"ref": payload["ref"], "object": {"type": "commit", "sha": payload["sha"]}}
            return copy.deepcopy(self.tag)
        self.assertEqual(endpoint, f"repos/{REPOSITORY}/releases?per_page=100&page=1")
        return [copy.deepcopy(self.release)] if self.release is not None else []

    def command(self, arguments):
        self.assertEqual(arguments[0], "release")
        self.assertEqual(arguments[2], "1.0.0")
        self.assertIn("--repo", arguments)
        self.assertIn(REPOSITORY, arguments)
        if arguments[1] == "create":
            self.assertIsNone(self.release)
            self.assertIn("--draft", arguments)
            self.assertIn("--verify-tag", arguments)
            self.release = {"id": 123, "tag_name": "1.0.0", "draft": True, "immutable": False,
                            "name": "BagMarks 1.0.0", "body": self.notes.read_text(), "assets": []}
        elif arguments[1] == "upload":
            self.assertNotIn("--clobber", arguments)
            self.assertEqual(Path(arguments[3]).read_bytes(), self.content)
            self.release["assets"].append(self.asset())
        elif arguments[1] == "edit":
            self.assertEqual(arguments, ["release", "edit", "1.0.0", "--repo", REPOSITORY, "--draft=false"])
            self.assertEqual(self.release["assets"], [self.asset()])
            self.release["draft"] = False
        else:
            self.fail(f"Unexpected GitHub mutation: {arguments}")

    def publish(self, **options):
        return publish_release(REPOSITORY, "1.0.0", COMMIT, self.archive, self.notes,
                               api=self.api, run=self.run, download=self.download, **options)

    def operations(self):
        return [call.args[0][1] for call in self.run.call_args_list]

    def test_browser_created_release_receives_zip_without_duplicate_creation(self):
        before = copy.deepcopy(self.release)
        self.assertIn("is ready", self.publish())
        self.assertEqual(self.operations(), ["upload"])
        self.assertEqual(self.release, {**before, "assets": [self.asset()]})

    def test_new_release_is_a_draft_until_the_uploaded_zip_is_verified(self):
        self.release = None
        self.publish()
        self.assertEqual(self.operations(), ["create", "upload", "edit"])
        self.assertFalse(self.release["draft"])

    def test_manual_release_can_create_a_missing_tag_at_the_tested_commit(self):
        self.tag, self.release = None, None
        self.publish(create_tag=True)
        self.assertEqual(self.tag["object"]["sha"], COMMIT)
        self.assertEqual(self.operations(), ["create", "upload", "edit"])

    def test_rerun_with_an_identical_zip_performs_no_writes(self):
        self.release["assets"] = [self.asset()]
        self.publish()
        self.run.assert_not_called()
        self.download.assert_not_called()

    def test_old_asset_without_digest_is_verified_by_download(self):
        asset = self.asset()
        asset.pop("digest")
        self.release["assets"] = [asset]
        self.publish()
        self.download.assert_called_once_with(REPOSITORY, 456)
        self.run.assert_not_called()

    def test_different_existing_zip_is_never_replaced(self):
        self.release["assets"] = [{**self.asset(), "digest": "sha256:" + "0" * 64}]
        with self.assertRaisesRegex(ValueError, "differs.*not replaced"):
            self.publish()
        self.run.assert_not_called()

    def test_partial_or_wrong_size_asset_is_never_replaced(self):
        for changes in ({"state": "starter"}, {"size": 0}):
            self.release["assets"] = [{**self.asset(), **changes}]
            with self.subTest(changes=changes), self.assertRaisesRegex(ValueError, "incomplete or differs"):
                self.publish()
        self.run.assert_not_called()

    def test_downloaded_bytes_must_match_when_digest_is_missing(self):
        self.release["assets"] = [{**self.asset(), "digest": None}]
        self.download.return_value = b"Different ZIP bytes"
        with self.assertRaisesRegex(ValueError, "differs.*not replaced"):
            self.publish()
        self.run.assert_not_called()

    def test_missing_zip_in_an_immutable_release_reports_the_limit(self):
        self.release["immutable"] = True
        with self.assertRaisesRegex(ValueError, "immutable.*no addon ZIP"):
            self.publish()
        self.run.assert_not_called()

    def test_completed_immutable_release_is_a_successful_rerun(self):
        self.release.update(immutable=True, assets=[self.asset()])
        self.publish()
        self.run.assert_not_called()

    def test_interrupted_draft_with_uploaded_zip_can_be_published(self):
        self.release.update(draft=True, assets=[self.asset()])
        self.publish()
        self.assertEqual(self.operations(), ["edit"])

    def test_interrupted_draft_without_zip_can_be_completed(self):
        self.release["draft"] = True
        self.publish()
        self.assertEqual(self.operations(), ["upload", "edit"])

    def test_failed_release_lookup_is_not_treated_as_absent(self):
        self.api.side_effect = [[self.tag], subprocess.CalledProcessError(1, ["gh", "api"], stderr="request failed")]
        with self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.run.assert_not_called()

    def test_failed_upload_keeps_the_draft_and_can_be_retried(self):
        self.release["draft"] = True
        self.run.side_effect = subprocess.CalledProcessError(1, ["gh", "release", "upload"], stderr="connection lost")
        with self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.assertTrue(self.release["draft"])
        self.assertEqual(self.release["assets"], [])
        self.run.reset_mock(side_effect=True)
        self.run.side_effect = self.command
        self.publish()
        self.assertEqual(self.operations(), ["upload", "edit"])

    def test_failed_creation_does_not_attempt_upload(self):
        self.release = None
        self.run.side_effect = subprocess.CalledProcessError(1, ["gh", "release", "create"], stderr="request failed")
        with self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.assertEqual(self.operations(), ["create"])

    def test_unconfirmed_upload_cannot_publish_a_draft(self):
        self.release["draft"] = True
        self.run.side_effect = None
        with self.assertRaisesRegex(ValueError, "confirm the uploaded"):
            self.publish()
        self.assertEqual(self.operations(), ["upload"])

    def test_corrupted_upload_cannot_publish_a_draft(self):
        self.release["draft"] = True
        def corrupt_upload(arguments):
            self.command(arguments)
            self.release["assets"][0]["digest"] = "sha256:" + "0" * 64
        self.run.side_effect = corrupt_upload
        with self.assertRaisesRegex(ValueError, "differs"):
            self.publish()
        self.assertEqual(self.operations(), ["upload"])
        self.assertTrue(self.release["draft"])

    def test_moved_tag_is_rejected_before_release_changes(self):
        self.tag["object"]["sha"] = "b" * 40
        with self.assertRaisesRegex(ValueError, "different commit"):
            self.publish(create_tag=True)
        self.run.assert_not_called()
        self.assertEqual(self.api.call_count, 1)

    def test_push_release_cannot_recreate_a_missing_tag(self):
        self.tag = None
        with self.assertRaisesRegex(ValueError, "refusing to recreate"):
            self.publish()
        self.run.assert_not_called()
        self.assertEqual(self.api.call_count, 1)

    def test_renamed_zip_cannot_publish_as_a_different_version(self):
        renamed = Path(self.work.name) / "BagMarks-1.0.1.zip"
        shutil.copyfile(self.archive, renamed)
        with self.assertRaisesRegex(ValueError, "packaged addon version"):
            publish_release(REPOSITORY, "1.0.1", COMMIT, renamed, self.notes, api=self.api, run=self.run)
        self.api.assert_not_called()
        self.run.assert_not_called()

    def test_empty_notes_prevent_any_github_changes(self):
        self.notes.write_text(" \n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "notes must not be empty"):
            self.publish(create_tag=True)
        self.api.assert_not_called()
        self.run.assert_not_called()

    def test_release_lookup_includes_later_pages_and_drafts(self):
        self.release["draft"] = True
        api = mock.Mock(side_effect=[[{"tag_name": f"0.0.{index}"} for index in range(100)], [self.release]])
        self.assertEqual(find_release(REPOSITORY, "1.0.0", api), self.release)
        self.assertEqual(api.call_args.args[0], f"repos/{REPOSITORY}/releases?per_page=100&page=2")

    def test_malformed_release_data_is_not_treated_as_absent(self):
        for result in (None, {}, [None], [{"tag_name": "1.0.0"}], [self.release, self.release]):
            api = mock.Mock(return_value=result)
            with self.subTest(result=result), self.assertRaises(ValueError):
                find_release(REPOSITORY, "1.0.0", api)

    def test_cli_adapters_check_failures_and_preserve_binary_asset_bytes(self):
        with mock.patch("publish_release.subprocess.run", return_value=subprocess.CompletedProcess([], 0, stdout=self.content)) as run:
            self.assertEqual(download_asset(REPOSITORY, 456), self.content)
            self.assertEqual(run.call_args.args[0], ["gh", "api", f"repos/{REPOSITORY}/releases/assets/456",
                                                   "--header", "Accept: application/octet-stream"])
            self.assertTrue(run.call_args.kwargs["check"])
            run_gh(["release", "upload", "1.0.0", str(self.archive), "--repo", REPOSITORY])
            self.assertEqual(run.call_args.args[0][0:4], ["gh", "release", "upload", "1.0.0"])
            self.assertTrue(run.call_args.kwargs["check"])


if __name__ == "__main__":
    unittest.main()
