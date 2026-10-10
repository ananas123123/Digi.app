"""Isolated tests for Digi's release-manifest HTTP worker.

These tests mock urllib responses and never contact GitHub or change release metadata.
Run from the repository root with:
    python -m unittest backend.tests.test_release_manifest_worker -v
"""
import base64
import json
import unittest
from unittest.mock import patch

from backend.api import ReleaseManifestWorker


MANIFEST = {
    "schema_version": 1,
    "product": "Digi",
    "channel": "stable",
    "latest_version": "1.2.0.0",
    "release_status": "published",
}


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return self.body


def api_envelope(manifest):
    encoded = base64.b64encode(json.dumps(manifest).encode("utf-8")).decode("ascii")
    return json.dumps({"encoding": "base64", "content": encoded}).encode("utf-8")


class ReleaseManifestWorkerTests(unittest.TestCase):
    def run_worker(self, side_effect):
        worker = ReleaseManifestWorker()
        emitted = []
        worker.resultReady.connect(emitted.append)
        with patch("backend.api.urllib.request.urlopen", side_effect=side_effect):
            worker.run()
        self.assertEqual(len(emitted), 1, "worker should emit exactly one result")
        return json.loads(emitted[0])

    def test_api_success_decodes_base64_manifest(self):
        result = self.run_worker([FakeResponse(api_envelope(MANIFEST))])

        self.assertEqual(result, {"ok": True, "manifest": MANIFEST})

    def test_api_failure_uses_raw_url_fallback(self):
        result = self.run_worker([
            OSError("simulated GitHub API outage"),
            FakeResponse(json.dumps(MANIFEST).encode("utf-8")),
        ])

        self.assertEqual(result, {"ok": True, "manifest": MANIFEST})

    def test_both_endpoints_failing_returns_failure_result(self):
        result = self.run_worker([
            OSError("API unavailable"),
            OSError("raw endpoint unavailable"),
        ])

        self.assertEqual(result, {"ok": False, "manifest": None})

    def test_malformed_json_from_both_endpoints_returns_failure(self):
        result = self.run_worker([
            FakeResponse(b"{not valid JSON"),
            FakeResponse(b"{not valid JSON"),
        ])

        self.assertEqual(result, {"ok": False, "manifest": None})

    def test_invalid_api_envelope_falls_back_to_raw_url(self):
        invalid_envelope = json.dumps({
            "encoding": "utf-8",
            "content": json.dumps(MANIFEST),
        }).encode("utf-8")
        result = self.run_worker([
            FakeResponse(invalid_envelope),
            FakeResponse(json.dumps(MANIFEST).encode("utf-8")),
        ])

        self.assertEqual(result, {"ok": True, "manifest": MANIFEST})

    def test_invalid_base64_content_falls_back_to_raw_url(self):
        invalid_envelope = json.dumps({
            "encoding": "base64",
            "content": "%%%not-base64%%%",
        }).encode("utf-8")
        result = self.run_worker([
            FakeResponse(invalid_envelope),
            FakeResponse(json.dumps(MANIFEST).encode("utf-8")),
        ])

        self.assertEqual(result, {"ok": True, "manifest": MANIFEST})


if __name__ == "__main__":
    unittest.main()
