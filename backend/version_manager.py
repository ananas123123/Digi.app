from pathlib import Path
import hashlib
import os
import shutil
import tempfile

from .config import (
    APP_VERSION,
    CACHE_DIR,
    DEPENDENCIES_ROOT,
    IS_FROZEN,
    SEARCH_REPOSITORY,
    USER_DATA_ROOT,
    VERSION_MANAGER,
)

ERROR_CODE_INTEGRITY = 3
VERSION_FILE_NAME = "version.txt"
MARKER_FILE_NAME = ".version_initialized"

VERSION_FILE = VERSION_MANAGER / VERSION_FILE_NAME
MARKER_FILE = VERSION_MANAGER / MARKER_FILE_NAME
RECOVERY_ROOT = USER_DATA_ROOT.parent / "Digi Recovery"
RECOVERY_VERSION = RECOVERY_ROOT / VERSION_FILE_NAME
RECOVERY_MARKER = RECOVERY_ROOT / MARKER_FILE_NAME
IDENTITY_FILE = USER_DATA_ROOT.parent / ".Digi.identity"
ROOT_IDENTITY_FILE = DEPENDENCIES_ROOT / ".digi_identity"
EXPECTED_FOLDERS = ("Search Repository", "Cache", "Version manager")


def expected_version():
    return APP_VERSION.strip()


def _write_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".digi-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _file_digest(path):
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except (OSError, ValueError):
        return None


def _ensure_recovery_store():
    RECOVERY_ROOT.mkdir(parents=True, exist_ok=True)
    if not RECOVERY_VERSION.exists():
        _write_atomic(RECOVERY_VERSION, expected_version() + "\\n")
    if not RECOVERY_MARKER.exists():
        _write_atomic(RECOVERY_MARKER, "initialized\\n")


def _ensure_identity():
    if not IDENTITY_FILE.exists():
        _write_atomic(IDENTITY_FILE, "Digi-local-data-root-v1\\n")
    if DEPENDENCIES_ROOT.is_dir() and not ROOT_IDENTITY_FILE.exists():
        _write_atomic(ROOT_IDENTITY_FILE, IDENTITY_FILE.read_text(encoding="utf-8"))


def _copy_recovery_files_to_version_manager():
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)
    for source, target in (
        (RECOVERY_VERSION, VERSION_FILE),
        (RECOVERY_MARKER, MARKER_FILE),
    ):
        data = source.read_text(encoding="utf-8")
        _write_atomic(target, data)


def _same_file(path, expected):
    return path.exists() and _file_digest(path) == _file_digest(expected)


def _find_identity_root():
    if not IDENTITY_FILE.exists():
        return None
    try:
        identity = IDENTITY_FILE.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return None
    for candidate in USER_DATA_ROOT.parent.rglob(".digi_identity"):
        try:
            if candidate.read_text(encoding="utf-8") == identity:
                return candidate.parent
        except (OSError, UnicodeError):
            continue
    return None


def _find_renamed_folder(name):
    expected = DEPENDENCIES_ROOT / name
    if expected.is_dir():
        return expected
    parent = DEPENDENCIES_ROOT
    candidates = []
    try:
        candidates = [p for p in parent.iterdir() if p.is_dir()]
    except OSError:
        return None

    for candidate in candidates:
        if name == "Version manager" and (
            (candidate / VERSION_FILE_NAME).exists()
            or (candidate / MARKER_FILE_NAME).exists()
        ):
            return candidate
        if name == "Search Repository" and (
            (candidate / "Incoming").is_dir() or any(candidate.iterdir())
        ):
            return candidate
        if name == "Cache" and (
            (candidate / "study_index.db").exists()
            or (candidate / "library_folder.txt").exists()
        ):
            return candidate
    return None


def _restore_root():
    if DEPENDENCIES_ROOT.is_dir():
        return False

    moved_root = _find_identity_root()
    if moved_root and moved_root != DEPENDENCIES_ROOT:
        DEPENDENCIES_ROOT.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(moved_root), str(DEPENDENCIES_ROOT))
        return True

    DEPENDENCIES_ROOT.mkdir(parents=True, exist_ok=True)
    return True


def _restore_expected_folders():
    changed = False
    DEPENDENCIES_ROOT.mkdir(parents=True, exist_ok=True)

    for name in EXPECTED_FOLDERS:
        expected = DEPENDENCIES_ROOT / name
        if expected.is_dir():
            continue
        candidate = _find_renamed_folder(name)
        if candidate and candidate != expected:
            shutil.move(str(candidate), str(expected))
            changed = True
        else:
            expected.mkdir(parents=True, exist_ok=True)
            changed = True
    return changed


def repair_all():
    if not IS_FROZEN:
        return False

    _ensure_recovery_store()
    _ensure_identity()
    changed = _restore_root()
    _ensure_identity()
    changed = _restore_expected_folders() or changed

    SEARCH_REPOSITORY.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)

    if not _same_file(VERSION_FILE, RECOVERY_VERSION):
        _copy_recovery_files_to_version_manager()
        changed = True

    return changed


def initialize_version_file():
    # Startup is deliberately silent: any previous incomplete/declined repair
    # is completed before the application becomes usable.
    repair_all()
    return VERSION_FILE.exists()


def version_integrity():
    if not IS_FROZEN:
        return True, "ok"

    checks = (
        (USER_DATA_ROOT, "digi_root"),
        (SEARCH_REPOSITORY, "search_repository"),
        (CACHE_DIR, "cache"),
        (VERSION_MANAGER, "version_manager"),
        (VERSION_FILE, "version_file"),
        (MARKER_FILE, "version_marker"),
    )

    for path, name in checks:
        if not path.exists():
            return False, name

    if not _same_file(VERSION_FILE, RECOVERY_VERSION):
        return False, "version_file"
    if not _same_file(MARKER_FILE, RECOVERY_MARKER):
        return False, "version_marker"

    return True, "ok"


def recalibrate_version():
    return repair_all()


def repair_after_close():
    # Closing is always a repair point. This makes a declined runtime repair
    # recover automatically before the next launch.
    try:
        repair_all()
    except Exception:
        pass


def snapshot_state():
    ok, problem = version_integrity()
    return {
        "ok": ok,
        "problem": problem,
        "error_code": None if ok else ERROR_CODE_INTEGRITY,
        "version": expected_version(),
        "paths": {
            "root": str(USER_DATA_ROOT),
            "search_repository": str(SEARCH_REPOSITORY),
            "cache": str(CACHE_DIR),
            "version_manager": str(VERSION_MANAGER),
            "version_file": str(VERSION_FILE),
        },
    }
