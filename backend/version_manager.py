from pathlib import Path
import ctypes
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

# These are the only protected runtime templates. They live in the executable
# as Python data, not in a second recovery directory on disk.
TEMPLATE_FILES = {
    "Version manager/version.txt": lambda: expected_version() + "\n",
    "Version manager/.version_initialized": lambda: "initialized\n",
}

EXPECTED_DIRECTORIES = (
    "Search Repository",
    "Search Repository/Incoming",
    "Search Repository/Digi Notes",
    "Cache",
    "Version manager",
)

CACHE_ARTEFACT_NAMES = {
    "study_index",
    "study_index.db",
    "study_index.db-shm",
    "study_index.db-wal",
    "library_folder.txt",
}

# Win32 sharing constants. A handle that does not include FILE_SHARE_DELETE
# prevents rename/move/delete of that object while the handle is alive.
GENERIC_READ = 0x80000000
FILE_LIST_DIRECTORY = 0x0001
FILE_READ_ATTRIBUTES = 0x0080
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
FILE_SHARE_DELETE = 0x00000004
OPEN_EXISTING = 3
FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


def expected_version():
    return APP_VERSION.strip()


def _write_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".digi-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            try:
                os.unlink(temp_name)
            except OSError:
                pass


def _template_bytes(relative_path):
    return TEMPLATE_FILES[relative_path]().encode("utf-8")


def _candidate_roots():
    parent = USER_DATA_ROOT.parent
    try:
        return [
            p for p in parent.iterdir()
            if p.is_dir() and p != DEPENDENCIES_ROOT
        ]
    except OSError:
        return []


def _looks_like_digi_root(path):
    try:
        return sum((path / name).is_dir() for name in (
            "Search Repository", "Cache", "Version manager"
        )) >= 2
    except OSError:
        return False


def _restore_root_if_renamed():
    if DEPENDENCIES_ROOT.is_dir():
        return False

    for candidate in _candidate_roots():
        if _looks_like_digi_root(candidate):
            DEPENDENCIES_ROOT.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(candidate), str(DEPENDENCIES_ROOT))
            return True

    DEPENDENCIES_ROOT.mkdir(parents=True, exist_ok=True)
    return True


def _folder_candidates(name):
    try:
        return [p for p in DEPENDENCIES_ROOT.iterdir() if p.is_dir()]
    except OSError:
        return []


def _looks_like_folder(name, candidate):
    try:
        if name == "Version manager":
            return (
                (candidate / VERSION_FILE_NAME).exists()
                or (candidate / MARKER_FILE_NAME).exists()
            )
        if name == "Cache":
            return any((candidate / item).exists() for item in CACHE_ARTEFACT_NAMES)
        if name == "Search Repository":
            return (
                (candidate / "Incoming").is_dir()
                or (candidate / "Digi Notes").is_dir()
            )
    except OSError:
        return False
    return False


def _restore_folder(name):
    target = DEPENDENCIES_ROOT / name
    if target.is_dir():
        return False

    for candidate in _folder_candidates(name):
        if candidate.name == name:
            continue
        if _looks_like_folder(name, candidate):
            shutil.move(str(candidate), str(target))
            return True

    target.mkdir(parents=True, exist_ok=True)
    return True


def _ensure_template_file(relative_path):
    target = DEPENDENCIES_ROOT / relative_path
    data = _template_bytes(relative_path)

    if target.exists():
        try:
            if target.read_bytes() == data:
                return False
        except OSError:
            pass

    _write_atomic(target, data)
    return True


def _clean_version_manager():
    changed = False
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)

    for child in list(VERSION_MANAGER.iterdir()):
        if child.name in {VERSION_FILE_NAME, MARKER_FILE_NAME}:
            continue
        try:
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink()
            changed = True
        except OSError:
            pass

    return changed


def _move_cache_artefacts_out_of_search_repository():
    changed = False
    if not SEARCH_REPOSITORY.is_dir():
        return False

    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    for child in list(SEARCH_REPOSITORY.iterdir()):
        if child.name not in CACHE_ARTEFACT_NAMES:
            continue

        destination = CACHE_DIR / child.name
        try:
            if destination.exists():
                if child.is_dir():
                    shutil.rmtree(child)
                else:
                    child.unlink()
            else:
                shutil.move(str(child), str(destination))
            changed = True
        except OSError:
            pass

    return changed


def repair_all():
    if not IS_FROZEN:
        return False

    changed = _restore_root_if_renamed()

    for name in ("Search Repository", "Cache", "Version manager"):
        changed = _restore_folder(name) or changed

    for relative_path in (
        "Search Repository/Incoming",
        "Search Repository/Digi Notes",
    ):
        target = DEPENDENCIES_ROOT / relative_path
        if not target.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            changed = True

    changed = _move_cache_artefacts_out_of_search_repository() or changed
    changed = _clean_version_manager() or changed

    for relative_path in TEMPLATE_FILES:
        changed = _ensure_template_file(relative_path) or changed

    return changed


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


def _init_win32():
    global _kernel32, _close_handle, _create_file
    if _kernel32 is not None:
        return True
    if os.name != "nt":
        return False

    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _create_file = _kernel32.CreateFileW
    _create_file.argtypes = [
        ctypes.c_wchar_p,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_void_p,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_void_p,
    ]
    _create_file.restype = ctypes.c_void_p

    _close_handle = _kernel32.CloseHandle
    _close_handle.argtypes = [ctypes.c_void_p]
    _close_handle.restype = ctypes.c_int
    return True


def _open_directory_lock(path):
    handle = _create_file(
        str(path),
        FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        None,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        None,
    )
    if handle == INVALID_HANDLE_VALUE:
        return None
    return _ProtectedHandle(path, handle)


def _open_file_lock(path):
    handle = _create_file(
        str(path),
        GENERIC_READ,
        FILE_SHARE_READ,
        None,
        OPEN_EXISTING,
        0,
        None,
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

        # Version-manager files are immutable while Digi is running.
        for file_path in (VERSION_FILE, MARKER_FILE):
            if file_path.is_file():
                lock = _open_file_lock(file_path)
                if lock:
                    self.handles.append(lock)

        # Lock cache artefacts against rename/delete. The live SQLite database
        # remains writable by Digi itself; SQLite already coordinates its
        # database/WAL access. The directory itself stays protected.
        if CACHE_DIR.is_dir():
            for child in CACHE_DIR.iterdir():
                if not child.is_file() or child.name == "library_folder.txt":
                    continue
                lock = _open_file_lock(child)
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
        repair_all()
        _PROTECTED_LOCK.acquire()
        ok, _ = version_integrity()
        return ok
    except (OSError, ValueError, RuntimeError):
        return False


def version_integrity():
    if not IS_FROZEN:
        return True, "ok"

    required = (
        (USER_DATA_ROOT, "digi_root"),
        (SEARCH_REPOSITORY, "search_repository"),
        (CACHE_DIR, "cache"),
        (VERSION_MANAGER, "version_manager"),
        (VERSION_FILE, "version_file"),
        (MARKER_FILE, "version_marker"),
    )

    for path, problem in required:
        if not path.exists():
            return False, problem

    try:
        contents = {p.name for p in VERSION_MANAGER.iterdir()}
    except OSError:
        return False, "version_manager"

    if contents != {VERSION_FILE_NAME, MARKER_FILE_NAME}:
        return False, "version_manager_contents"

    for relative_path in TEMPLATE_FILES:
        path = DEPENDENCIES_ROOT / relative_path
        try:
            if path.read_bytes() != _template_bytes(relative_path):
                return False, relative_path
        except OSError:
            return False, relative_path

    return True, "ok"


def recalibrate_version():
    if not IS_FROZEN:
        return True
    try:
        _PROTECTED_LOCK.release()
        repair_all()
        _PROTECTED_LOCK.acquire()
        ok, _ = version_integrity()
        return ok
    except (OSError, ValueError, RuntimeError):
        return False


def repair_after_close():
    if not IS_FROZEN:
        return
    try:
        _PROTECTED_LOCK.release()
        repair_all()
    except (OSError, ValueError, RuntimeError):
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
