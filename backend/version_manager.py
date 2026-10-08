from .config import APP_VERSION, VERSION_MANAGER

VERSION_FILE_NAME = "version.txt"
VERSION_FILE = VERSION_MANAGER / VERSION_FILE_NAME
INITIALIZED_MARKER = VERSION_MANAGER / ".version_initialized"


def expected_version():
    return APP_VERSION.strip()


def initialize_version_file():
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)
    if not VERSION_FILE.exists() and not INITIALIZED_MARKER.exists():
        VERSION_FILE.write_text(expected_version() + "\n", encoding="utf-8")
        INITIALIZED_MARKER.write_text("initialized\n", encoding="utf-8")
        return True
    return VERSION_FILE.exists()


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
    INITIALIZED_MARKER.write_text("initialized\n", encoding="utf-8")
    return True
