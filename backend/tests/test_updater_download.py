"""Tests for safe temporary update downloads."""
import hashlib
import os
import tempfile
import unittest
from unittest.mock import Mock

from backend.updater_download import download_package_to_temp


class FakeResponse:
    def __init__(self, payload, url="https://downloads.example.com/Digi.exe"):
        self.payload = payload
        self.url = url
        self.offset = 0

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def geturl(self):
        return self.url

    def read(self, size=-1):
        if size < 0:
            size = len(self.payload)
        part = self.payload[self.offset:self.offset + size]
        self.offset += len(part)
        return part


class FakeOpener:
    def __init__(self, response):
        self.response = response
        self.called = False

    def open(self, request, timeout=None):
        self.called = True
        return self.response


def manifest(payload, **package_overrides):
    package = {
        "url": "https://downloads.example.com/Digi.exe",
        "size_bytes": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
    }
    package.update(package_overrides)
    return {
        "schema_version": 1,
        "product": "Digi",
        "channel": "stable",
        "latest_version": "1.2.0.0",
        "release_status": "published",
        "release": {"version": "1.2.0.0", "package": package},
    }


class UpdaterDownloadTests(unittest.TestCase):
    def test_downloads_to_new_temporary_file_without_installing(self):
        payload = b"sample-package-bytes"
        opener = FakeOpener(FakeResponse(payload))
        with tempfile.TemporaryDirectory() as directory:
            path = download_package_to_temp(manifest(payload), directory, opener)
            try:
                self.assertTrue(os.path.isfile(path))
                self.assertEqual(open(path, "rb").read(), payload)
                self.assertTrue(os.path.basename(path).startswith("digi-update-"))
                self.assertTrue(path.endswith(".download"))
            finally:
                os.remove(path)

    def test_rejects_missing_package_before_network_request(self):
        opener = FakeOpener(FakeResponse(b"x"))
        value = manifest(b"x")
        value["release"].pop("package")
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "No downloadable package"):
                download_package_to_temp(value, directory, opener)
        self.assertFalse(opener.called)

    def test_rejects_http_url_before_network_request(self):
        payload = b"x"
        opener = FakeOpener(FakeResponse(payload))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "HTTPS"):
                download_package_to_temp(manifest(payload, url="http://downloads.example.com/Digi.exe"), directory, opener)
        self.assertFalse(opener.called)

    def test_rejects_invalid_size_and_checksum_before_network_request(self):
        for override in ({"size_bytes": 0}, {"sha256": "bad"}):
            opener = FakeOpener(FakeResponse(b"x"))
            with tempfile.TemporaryDirectory() as directory:
                with self.subTest(override=override), self.assertRaises(ValueError):
                    download_package_to_temp(manifest(b"x", **override), directory, opener)
            self.assertFalse(opener.called)

    def test_removes_partial_file_when_download_size_is_wrong(self):
        payload = b"short"
        opener = FakeOpener(FakeResponse(payload))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "size does not match"):
                download_package_to_temp(manifest(payload + b"extra"), directory, opener)
            self.assertEqual(os.listdir(directory), [])

    def test_removes_file_if_server_sends_more_than_expected(self):
        opener = FakeOpener(FakeResponse(b"longer"))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "larger than"):
                download_package_to_temp(manifest(b"x"), directory, opener)
            self.assertEqual(os.listdir(directory), [])

    def test_rejects_insecure_final_url_and_cleans_partial_file(self):
        opener = FakeOpener(FakeResponse(b"x", url="http://downloads.example.com/Digi.exe"))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "unsafe URL"):
                download_package_to_temp(manifest(b"x"), directory, opener)
            self.assertEqual(os.listdir(directory), [])

    def test_rejects_checksum_mismatch_and_removes_download(self):
        payload = b"sample-package-bytes"
        opener = FakeOpener(FakeResponse(payload))
        wrong_hash = "0" * 64
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "SHA-256 does not match"):
                download_package_to_temp(manifest(payload, sha256=wrong_hash), directory, opener)
            self.assertEqual(os.listdir(directory), [])

    def test_rejects_malformed_checksum_before_network_request(self):
        opener = FakeOpener(FakeResponse(b"x"))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "checksum is invalid"):
                download_package_to_temp(manifest(b"x", sha256="not-a-checksum"), directory, opener)
        self.assertFalse(opener.called)


if __name__ == "__main__":
    unittest.main()
