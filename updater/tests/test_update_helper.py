import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from updater.update_helper import (
    expected_install_dir,
    install_update,
    sha256_file,
    validate_paths,
    validate_pe_executable,
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
        self.candidate = (
            self.install_dir / "update dependencies" / "package installer"
            / "1.2.0.0" / "Digi Search Engine.exe"
        )
        self.helper.write_bytes(b"helper")
        self.target.write_bytes(b"old-app")
        self.candidate.parent.mkdir(parents=True)
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

    def test_rejects_non_pe_candidate(self):
        with self.assertRaisesRegex(ValueError, "not a Windows executable"):
            validate_pe_executable(self.candidate)

    def test_accepts_minimal_pe_header(self):
        data = bytearray(128)
        data[0:2] = b"MZ"
        data[0x3C:0x40] = (64).to_bytes(4, "little")
        data[64:68] = b"PE\x00\x00"
        self.candidate.write_bytes(data)
        validate_pe_executable(self.candidate)

    def test_sha256_matches_file_contents(self):
        self.assertEqual(
            sha256_file(self.candidate),
            hashlib.sha256(b"new-app").hexdigest()
        )

    def _write_valid_pe_candidate(self):
        data = bytearray(128)
        data[0:2] = b"MZ"
        data[0x3C:0x40] = (64).to_bytes(4, "little")
        data[64:68] = b"PE\\x00\\x00"
        self.candidate.write_bytes(data)
        return bytes(data)

    def test_successful_update_removes_download_and_rollback_copy(self):
        candidate_bytes = self._write_valid_pe_candidate()
        version_manager = self.install_dir / "Version manager"
        version_manager.mkdir()
        (version_manager / "version.txt").write_text("1.1.0.0\\n", encoding="utf-8")
        (version_manager / ".version_initialized").write_text("initialized\\n", encoding="utf-8")

        with patch("updater.update_helper.wait_for_process_exit"), \\
             patch("updater.update_helper.wait_for_confirmation", return_value=True), \\
             patch("updater.update_helper.refresh_digi_shortcuts", return_value=True), \\
             patch("updater.update_helper.subprocess.Popen"):
            install_update(
                helper_path=self.helper,
                target_path=self.target,
                candidate_path=self.candidate,
                local_app_data=self.local_app_data,
                parent_pid=12345,
                expected_sha256=hashlib.sha256(candidate_bytes).hexdigest(),
                version="1.2.0.0",
            )

        self.assertEqual(self.target.read_bytes(), candidate_bytes)
        self.assertFalse(self.candidate.exists())
        self.assertEqual(
            (version_manager / "version.txt").read_text(encoding="utf-8"),
            "1.2.0.0\\n",
        )
        self.assertEqual(list(self.install_dir.glob(".Digi-rollback-*.exe")), [])

    def test_failed_startup_restores_old_app_and_retains_candidate(self):
        self._write_valid_pe_candidate()
        old_bytes = self.target.read_bytes()

        with patch("updater.update_helper.wait_for_process_exit"), \\
             patch("updater.update_helper.wait_for_confirmation", return_value=False), \\
             patch("updater.update_helper.subprocess.Popen"):
            with self.assertRaisesRegex(RuntimeError, "previous executable will be restored"):
                install_update(
                    helper_path=self.helper,
                    target_path=self.target,
                    candidate_path=self.candidate,
                    local_app_data=self.local_app_data,
                    parent_pid=12345,
                    expected_sha256=sha256_file(self.candidate),
                    version="1.2.0.0",
                    startup_timeout=0.01,
                )

        self.assertEqual(self.target.read_bytes(), old_bytes)
        self.assertTrue(self.candidate.is_file())
        failed_files = list((self.install_dir / "Logs" / "failed-updates").glob("Digi-failed-1.2.0.0-*.exe"))
        self.assertEqual(len(failed_files), 1)
        self.assertEqual(list(self.install_dir.glob(".Digi-rollback-*.exe")), [])


if __name__ == "__main__":
    unittest.main()
