"""Regression tests for the installed Digi data-layout bootstrap."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend import version_manager as vm


class VersionManagerBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "Digi"
        self.root.mkdir()
        (self.root / "Logs").mkdir()
        self.search = self.root / "Search Repository"
        self.notes = self.search / "Digi Notes"
        self.cache = self.root / "Cache"
        self.manager = self.root / "Version manager"
        self.version_file = self.manager / "version.txt"
        self.marker_file = self.manager / ".version_initialized"
        self.patches = [
            patch.object(vm, "IS_FROZEN", True),
            patch.object(vm, "USER_DATA_ROOT", self.root),
            patch.object(vm, "SEARCH_REPOSITORY", self.search),
            patch.object(vm, "CACHE_DIR", self.cache),
            patch.object(vm, "VERSION_MANAGER", self.manager),
            patch.object(vm, "VERSION_FILE", self.version_file),
            patch.object(vm, "MARKER_FILE", self.marker_file),
            patch.object(vm, "EXPECTED_DIRECTORIES", (self.search, self.notes, self.cache, self.manager)),
            patch.object(vm, "expected_version", return_value="1.2.0.0"),
            patch.object(vm, "_unexpected_existing_root", return_value=None),
            patch.object(vm._PROTECTED_LOCK, "acquire"),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def test_bootstraps_when_builder_created_root_first(self):
        existing_log = self.root / "Logs" / "updater.log"
        existing_log.write_text("keep me", encoding="utf-8")

        self.assertTrue(vm.initialize_version_file())
        self.assertTrue(self.search.is_dir())
        self.assertTrue(self.notes.is_dir())
        self.assertTrue(self.cache.is_dir())
        self.assertTrue(self.manager.is_dir())
        self.assertEqual(self.version_file.read_text(encoding="utf-8"), "1.2.0.0\n")
        self.assertEqual(self.marker_file.read_text(encoding="utf-8"), "initialized\n")
        self.assertEqual(existing_log.read_text(encoding="utf-8"), "keep me")

    def test_does_not_overwrite_partial_existing_version_metadata(self):
        self.manager.mkdir()
        self.version_file.write_text("1.0.0.0\n", encoding="utf-8")

        self.assertFalse(vm.initialize_version_file())
        self.assertEqual(self.version_file.read_text(encoding="utf-8"), "1.0.0.0\n")
        self.assertFalse(self.marker_file.exists())

    def test_preserves_existing_search_repository_contents(self):
        self.search.mkdir()
        existing = self.search / "student-notes.docx"
        existing.write_bytes(b"existing user data")

        self.assertTrue(vm.initialize_version_file())
        self.assertEqual(existing.read_bytes(), b"existing user data")


if __name__ == "__main__":
    unittest.main()
