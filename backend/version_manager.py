from pathlib import Path

from .config import APP_VERSION, VERSION_MANAGER, IS_FROZEN

VERSION_FILE_NAME = "version.txt"
VERSION_FILE = VERSION_MANAGER / VERSION_FILE_NAME


def expected_version():
    return APP_VERSION.strip()


def ensure_version_file():
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)
    if not VERSION_FILE.exists():
        VERSION_FILE.write_text(expected_version() + "\n", encoding="utf-8")
        return True
    try:
        current = VERSION_FILE.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return False
    return current == expected_version()


def version_integrity():
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)
    if not VERSION_FILE.exists():
        return False, "missing"
    try:
        current = VERSION_FILE.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return False, "modified"
    if current != expected_version():
        return False, "modified"
    return True, "ok"


def recalibrate_version():
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)
    VERSION_FILE.write_text(expected_version() + "\n", encoding="utf-8")
    return True
