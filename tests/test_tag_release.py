"""Mocked GitHub API calls for browser-based release tagging. No network writes."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from tag_release import ensure_tag, github_api, main, resolve_source

COMMIT = "a" * 40
TAG_OBJECT = "b" * 40
BASE = "repos/Landmine-1252/bagmarks/git"


def ref(sha=COMMIT, kind="commit", name="1.0.0"):
    return {"ref": "refs/tags/" + name, "object": {"type": kind, "sha": sha}}


class ReleaseTagTests(unittest.TestCase):
    def test_browser_run_creates_a_missing_tag_at_the_tested_commit(self):
        api = mock.Mock(side_effect=[[], ref()])
        ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_args_list, [
            mock.call(BASE + "/matching-refs/tags/1.0.0"),
            mock.call(BASE + "/refs", {"ref": "refs/tags/1.0.0", "sha": COMMIT}),
        ])

    def test_push_run_never_recreates_a_deleted_tag(self):
        api = mock.Mock(return_value=[])
        with self.assertRaisesRegex(ValueError, "refusing to recreate"):
            ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, api=api)
        self.assertEqual(api.call_count, 1)

    def test_existing_lightweight_tag_is_verified_without_writes(self):
        api = mock.Mock(return_value=[ref()])
        ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_count, 1)

    def test_annotated_tag_resolves_to_the_tested_commit(self):
        api = mock.Mock(side_effect=[[ref(TAG_OBJECT, "tag")], {"object": ref()["object"]}])
        ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, api=api)
        self.assertEqual(api.call_args_list[-1], mock.call(BASE + "/tags/" + TAG_OBJECT))

    def test_a_tag_at_another_commit_is_never_moved(self):
        api = mock.Mock(return_value=[ref("c" * 40)])
        with self.assertRaisesRegex(ValueError, "different commit"):
            ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_count, 1)

    def test_similar_tag_prefix_does_not_select_a_different_version(self):
        api = mock.Mock(side_effect=[[ref(name="1.0.01")], ref()])
        ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_args_list[-1], mock.call(BASE + "/refs", {"ref": "refs/tags/1.0.0", "sha": COMMIT}))

    def test_failed_lookup_is_not_treated_as_a_missing_tag(self):
        api = mock.Mock(side_effect=subprocess.CalledProcessError(1, ["gh", "api"], stderr="request failed"))
        with self.assertRaises(subprocess.CalledProcessError):
            ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_count, 1)

    def test_failed_creation_is_not_retried_or_replaced_with_an_update(self):
        api = mock.Mock(side_effect=[[], subprocess.CalledProcessError(1, ["gh", "api"], stderr="reference exists")])
        with self.assertRaises(subprocess.CalledProcessError):
            ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
        self.assertEqual(api.call_count, 2)

    def test_invalid_release_inputs_never_reach_github(self):
        for repository, tag, commit in (("owner/repo/other", "1.0.0", COMMIT),
                                        ("owner/repo", "v1.0.0", COMMIT),
                                        ("owner/repo", "1.0.0", "main")):
            api = mock.Mock()
            with self.subTest(tag=tag, commit=commit), self.assertRaises(ValueError):
                ensure_tag(repository, tag, commit, create=True, api=api)
            api.assert_not_called()

    def test_unreadable_or_noncommit_tag_is_rejected(self):
        for result in (None, {}, [ref(kind="tree")], [ref(sha="not-a-sha")], [ref(), ref()]):
            api = mock.Mock(return_value=result)
            with self.subTest(result=result), self.assertRaises(ValueError):
                ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, create=True, api=api)
            self.assertEqual(api.call_count, 1)

    def test_cyclic_annotated_tag_stops_without_writes(self):
        api = mock.Mock(side_effect=[[ref(TAG_OBJECT, "tag")], {"object": ref(TAG_OBJECT, "tag")["object"]}])
        with self.assertRaisesRegex(ValueError, "does not resolve"):
            ensure_tag("Landmine-1252/bagmarks", "1.0.0", COMMIT, api=api)
        self.assertEqual(api.call_count, 2)

    def test_api_adapter_uses_structured_json_for_tag_creation(self):
        payload = {"ref": "refs/tags/1.0.0", "sha": COMMIT}
        result = subprocess.CompletedProcess([], 0, stdout=json.dumps(ref()))
        with mock.patch("tag_release.subprocess.run", return_value=result) as run:
            self.assertEqual(github_api(BASE + "/refs", payload), ref())
        self.assertEqual(run.call_args.args[0], ["gh", "api", "--method", "POST", BASE + "/refs", "--input", "-"])
        self.assertEqual(json.loads(run.call_args.kwargs["input"]), payload)
        self.assertTrue(run.call_args.kwargs["check"])


class ReleaseSourceTests(unittest.TestCase):
    def test_retry_uses_the_existing_tag_when_main_has_advanced(self):
        api = mock.Mock(return_value=[ref()])
        self.assertEqual(resolve_source("Landmine-1252/bagmarks", "1.0.0", "c" * 40, api), COMMIT)
        self.assertEqual(api.call_args_list, [mock.call(BASE + "/matching-refs/tags/1.0.0")])

    def test_new_release_uses_the_selected_commit_without_creating_a_tag(self):
        api = mock.Mock(return_value=[])
        self.assertEqual(resolve_source("Landmine-1252/bagmarks", "1.0.0", COMMIT, api), COMMIT)
        self.assertEqual(api.call_count, 1)

    def test_retry_resolves_an_annotated_tag_to_its_original_commit(self):
        api = mock.Mock(side_effect=[[ref(TAG_OBJECT, "tag")], {"object": ref()["object"]}])
        self.assertEqual(resolve_source("Landmine-1252/bagmarks", "1.0.0", "c" * 40, api), COMMIT)
        self.assertEqual(api.call_count, 2)

    def test_similar_version_is_not_used_for_the_retry(self):
        api = mock.Mock(return_value=[ref("c" * 40, name="1.0.01")])
        self.assertEqual(resolve_source("Landmine-1252/bagmarks", "1.0.0", COMMIT, api), COMMIT)

    def test_failed_source_lookup_does_not_fall_back_to_main(self):
        api = mock.Mock(side_effect=subprocess.CalledProcessError(1, ["gh", "api"], stderr="request failed"))
        with self.assertRaises(subprocess.CalledProcessError):
            resolve_source("Landmine-1252/bagmarks", "1.0.0", COMMIT, api)

    def test_invalid_source_inputs_never_reach_github(self):
        api = mock.Mock()
        with self.assertRaises(ValueError):
            resolve_source("Landmine-1252/bagmarks", "1.0.0\ncommit=main", COMMIT, api)
        api.assert_not_called()

    def test_resolve_cli_writes_only_the_selected_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            arguments = ["tag_release.py", "--resolve", "--repository", "Landmine-1252/bagmarks",
                         "--tag", "1.0.0", "--commit", "c" * 40, "--github-output", str(output)]
            with mock.patch.object(sys, "argv", arguments), mock.patch("tag_release.resolve_source", return_value=COMMIT):
                main()
            self.assertEqual(output.read_text(), f"commit={COMMIT}\n")


if __name__ == "__main__":
    unittest.main()
