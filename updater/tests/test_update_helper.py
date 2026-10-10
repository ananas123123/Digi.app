import hashlib
import tempfile
import unittest
from pathlib import Path

from updater.update_helper import (
    expected_install_dir,
    sha256_file,
    validate_paths,
)


class UpdateHelperPathTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.local_app_data = Path(self.temp.name) / "LocalAppData"
        self.install_dir = expected_install_dir(self.local_app_data)
        self.install_dir.mkdir(parents=True)
        self.helper = self.install_dir / "DigiUpdater.exe"
        self.target = self.install_dir / "Digi Search Engine.exe"
        self.candidate = Path(self.temp.name) / "digi-update.download"
        self.helper.write_bytes(b"helper")
        self.target.write_bytes(b"old-app")
        self.candidate.write_bytes(b"new-app")

    def test_accepts_expected_install_paths_and_download_candidate(self):
        install_dir, target, candidate = validate_paths(
            self.helper, self.target, self.candidate, self.local_app_data
        )
        self.assertEqual(install_dir, self.install_dir.resolve())
        self.assertEqual(target, self.target.resolve())
        self.assertEqual(candidate, self.candidate.resolve())

    def test_rejects_target_outside_stable_install_directory(self):
        outside_target = Path(self.temp.name) / "Other.exe"
        outside_target.write_bytes(b"not Digi")
        with self.assertRaisesRegex(ValueError, "expected executable path"):
            validate_paths(self.helper, outside_target, self.candidate, self.local_app_data)

    def test_rejects_helper_outside_stable_install_directory(self):
        outside_helper = Path(self.temp.name) / "DigiUpdater.exe"
        outside_helper.write_bytes(b"helper")
        with self.assertRaisesRegex(ValueError, "stable installation directory"):
            validate_paths(outside_helper, self.target, self.candidate, self.local_app_data)

    def test_rejects_missing_candidate(self):
        with self.assertRaises(FileNotFoundError):
            validate_paths(
                self.helper, self.target, self.candidate.with_name("missing.download"),
                self.local_app_data
            )

    def test_sha256_matches_file_contents(self):
        self.assertEqual(
            sha256_file(self.candidate),
            hashlib.sha256(b"new-app").hexdigest()
        )


if __name__ == "__main__":
    unittest.main()
