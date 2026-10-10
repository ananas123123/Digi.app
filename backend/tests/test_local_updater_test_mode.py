"""Safety tests for the opt-in local updater feed."""
import json
import os
import unittest
from unittest.mock import patch

from backend.api import ReleaseManifestWorker


class FakeResponse:
    def __init__(self, body):
        self.body = body
    def __enter__(self):
        return self
    def __exit__(self, *args):
        return False
    def read(self):
        return self.body


class LocalUpdaterTestModeTests(unittest.TestCase):
    def test_disabled_by_default(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(ReleaseManifestWorker._local_test_url())

    def test_accepts_explicit_loopback_http_url(self):
        with patch.dict(os.environ, {
            "DIGI_UPDATER_TEST_MODE": "1",
            "DIGI_UPDATER_TEST_MANIFEST_URL": "http://127.0.0.1:8765/latest.json",
        }, clear=True):
            self.assertEqual(
                ReleaseManifestWorker._local_test_url(),
                "http://127.0.0.1:8765/latest.json",
            )

    def test_rejects_non_loopback_or_non_http_urls(self):
        for url in (
            "https://example.com/latest.json",
            "http://example.com/latest.json",
            "http://127.0.0.1/latest.json",
            "http://user:pass@127.0.0.1:8765/latest.json",
        ):
            with self.subTest(url=url), patch.dict(os.environ, {
                "DIGI_UPDATER_TEST_MODE": "1",
                "DIGI_UPDATER_TEST_MANIFEST_URL": url,
            }, clear=True):
                self.assertIsNone(ReleaseManifestWorker._local_test_url())

    def test_worker_marks_explicit_local_feed_as_test_mode(self):
        manifest = {
            "schema_version": 1,
            "product": "Digi",
            "latest_version": "99.0.0.0",
            "release_status": "published",
        }
        with patch.dict(os.environ, {
            "DIGI_UPDATER_TEST_MODE": "1",
            "DIGI_UPDATER_TEST_MANIFEST_URL": "http://127.0.0.1:8765/latest.json",
        }, clear=True), patch(
            "backend.api.urllib.request.urlopen",
            return_value=FakeResponse(json.dumps(manifest).encode("utf-8")),
        ):
            worker = ReleaseManifestWorker()
            emitted = []
            worker.resultReady.connect(emitted.append)
            worker.run()
        result = json.loads(emitted[0])
        self.assertTrue(result["ok"])
        self.assertTrue(result["test_mode"])
        self.assertEqual(result["manifest"], manifest)


if __name__ == "__main__":
    unittest.main()
