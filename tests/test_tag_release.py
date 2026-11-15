"""Mocked GitHub API calls for browser-based release tagging. No network writes."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from tag_release import ensure_tag, github_api

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


if __name__ == "__main__":
    unittest.main()
