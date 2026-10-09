from pathlib import Path
import ctypes
import os
import re

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

EXPECTED_DIRECTORIES = (
    SEARCH_REPOSITORY,
    SEARCH_REPOSITORY / "Incoming",
    SEARCH_REPOSITORY / "Digi Notes",
    CACHE_DIR,
    VERSION_MANAGER,
)

VERSION_PATTERN = re.compile(r"^\\d+(?:\\.\\d+){1,4}$")


def expected_version():
    return APP_VERSION.strip()


def _looks_like_digi_root(path):
    try:
        return sum(
            (path / name).is_dir()
            for name in ("Search Repository", "Cache", "Version manager")
        ) >= 2
    except OSError:
        return False


def _unexpected_existing_root():
    """Find a likely renamed Digi data root without moving or modifying it."""
    parent = USER_DATA_ROOT.parent
    try:
        return next(
            (
                candidate
                for candidate in parent.iterdir()
                if candidate.is_dir()
                and candidate.resolve() != USER_DATA_ROOT.resolve()
                and _looks_like_digi_root(candidate)
            ),
            None,
        )
    except OSError:
        return None


def _bootstrap_first_run():
    """Create the initial data layout only when no Digi data root exists."""
    unexpected = _unexpected_existing_root()
    if unexpected is not None:
        raise RuntimeError(
            f"Digi data was found at an unexpected location: {unexpected}. "
            "Digi did not move or change it. Contact Digi support for guidance."
        )

    USER_DATA_ROOT.mkdir(parents=True, exist_ok=False)
    for path in EXPECTED_DIRECTORIES:
        path.mkdir(parents=True, exist_ok=False)

    VERSION_FILE.write_text(expected_version() + "\\n", encoding="utf-8")
    MARKER_FILE.write_text("initialized\\n", encoding="utf-8")


def _integrity_problem():
    if not USER_DATA_ROOT.is_dir():
        unexpected = _unexpected_existing_root()
        if unexpected is not None:
            return (
                f"Digi data was found at an unexpected location: {unexpected}. "
                "Digi did not move or change it. Contact Digi support for guidance."
            )
        return "Digi data folder is missing."

    for path in EXPECTED_DIRECTORIES:
        if not path.is_dir():
            return f"Required folder is missing: {path}"

    if not VERSION_FILE.is_file():
        return f"Version metadata is missing: {VERSION_FILE}"
    if not MARKER_FILE.is_file():
        return f"Version marker is missing: {MARKER_FILE}"

    try:
        version_text = VERSION_FILE.read_text(encoding="utf-8").strip()
        marker_text = MARKER_FILE.read_text(encoding="utf-8").strip()
        manager_contents = {item.name for item in VERSION_MANAGER.iterdir()}
    except OSError as exc:
        return f"Could not inspect Digi version metadata: {exc}"

    # This records the version that first initialized the data layout. It is
    # intentionally not compared with APP_VERSION: app upgrades/downgrades must
    # reuse the same user data without rewriting this file.
    if not VERSION_PATTERN.fullmatch(version_text):
        return f"Version metadata is invalid: {VERSION_FILE}"
    if marker_text != "initialized":
        return f"Version marker is invalid: {MARKER_FILE}"
    expected_contents = {VERSION_FILE_NAME, MARKER_FILE_NAME}
    if manager_contents != expected_contents:
        unexpected = sorted(manager_contents - expected_contents)
        missing = sorted(expected_contents - manager_contents)
        details = []
        if unexpected:
            details.append("unexpected items: " + ", ".join(unexpected))
        if missing:
            details.append("missing items: " + ", ".join(missing))
        return "Version manager contents are unexpected (" + "; ".join(details) + ")."

    return None


# Retained for compatibility with callers; this function no longer repairs,
# moves, deletes, creates, or overwrites anything in an existing data root.
def repair_all():
    if not IS_FROZEN:
        return False
    return False


class _ProtectedHandle:
    def __init__(self, path, handle):
        self.path = Path(path)
        self.handle = handle

    def close(self):
        if self.handle and self.handle != INVALID_HANDLE_VALUE:
            _close_handle(self.handle)
            self.handle = None


_kernel32 = None
_close_handle = None
_create_file = None
GENERIC_READ = 0x80000000
FILE_LIST_DIRECTORY = 0x0001
FILE_READ_ATTRIBUTES = 0x0080
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
OPEN_EXISTING = 3
FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


def _init_win32():
    global _kernel32, _close_handle, _create_file
    if _kernel32 is not None:
        return True
    if os.name != "nt":
        return False
    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _create_file = _kernel32.CreateFileW
    _create_file.argtypes = [
        ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
    ]
    _create_file.restype = ctypes.c_void_p
    _close_handle = _kernel32.CloseHandle
    _close_handle.argtypes = [ctypes.c_void_p]
    _close_handle.restype = ctypes.c_int
    return True


def _open_directory_lock(path):
    handle = _create_file(
        str(path), FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS, None,
    )
    if handle == INVALID_HANDLE_VALUE:
        return None
    return _ProtectedHandle(path, handle)


def _open_file_lock(path):
    handle = _create_file(
        str(path), GENERIC_READ, FILE_SHARE_READ, None, OPEN_EXISTING, 0, None,
    )
    if handle == INVALID_HANDLE_VALUE:
        return None
    return _ProtectedHandle(path, handle)


class ProtectedDataLock:
    def __init__(self):
        self.handles = []

    def acquire(self):
        if not IS_FROZEN or not _init_win32():
            return
        self.release()
        for directory in (CACHE_DIR, VERSION_MANAGER):
            if directory.is_dir():
                lock = _open_directory_lock(directory)
                if lock:
                    self.handles.append(lock)
        for file_path in (VERSION_FILE, MARKER_FILE):
            if file_path.is_file():
                lock = _open_file_lock(file_path)
                if lock:
                    self.handles.append(lock)

    def release(self):
        for handle in self.handles:
            handle.close()
        self.handles.clear()


_PROTECTED_LOCK = ProtectedDataLock()


def initialize_version_file():
    if not IS_FROZEN:
        return True
    try:
        if not USER_DATA_ROOT.exists():
            _bootstrap_first_run()
        problem = _integrity_problem()
        if problem:
            return False
        _PROTECTED_LOCK.acquire()
        return True
    except (OSError, ValueError, RuntimeError):
        return False


def version_integrity():
    if not IS_FROZEN:
        return True, "ok"
    try:
        problem = _integrity_problem()
    except (OSError, ValueError, RuntimeError) as exc:
        return False, str(exc)
    return (False, problem) if problem else (True, "ok")


def recalibrate_version():
    # Re-check only. Recovery is deliberately manual; never mutate user data.
    if not IS_FROZEN:
        return True
    ok, _ = version_integrity()
    return ok


def repair_after_close():
    # Kept for compatibility with any existing caller. No automatic repair.
    _PROTECTED_LOCK.release()


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
