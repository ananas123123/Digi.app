from pathlib import Path
import hashlib
import json
import os
import shutil
import tempfile
import time

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

# Recovery data deliberately lives OUTSIDE %LOCALAPPDATA%\Digi so that the
# entire Digi data root can be moved or deleted and still be reconstructed.
RECOVERY_ROOT = USER_DATA_ROOT.parent / "Digi Recovery"
RECOVERY_MANIFEST = RECOVERY_ROOT / "manifest.json"
RECOVERY_VERSION = RECOVERY_ROOT / VERSION_FILE_NAME
RECOVERY_MARKER = RECOVERY_ROOT / MARKER_FILE_NAME

EXPECTED_FOLDERS = {
    "Search Repository": SEARCH_REPOSITORY,
    "Cache": CACHE_DIR,
    "Version manager": VERSION_MANAGER,
}

# These are runtime/cache artefacts. They never belong in Search Repository.
CACHE_ARTEFACT_NAMES = {
    "study_index",
    "study_index.db",
    "study_index.db-shm",
    "study_index.db-wal",
    "library_folder.txt",
}


def expected_version():
    return APP_VERSION.strip()


def _write_atomic(path, data, binary=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".digi-", dir=str(path.parent))
    try:
        mode = "wb" if binary else "w"
        kwargs = {} if binary else {"encoding": "utf-8", "newline": ""}
        with os.fdopen(fd, mode, **kwargs) as handle:
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


def _read_bytes(path):
    try:
        return path.read_bytes()
    except (OSError, ValueError):
        return None


def _digest(path):
    data = _read_bytes(path)
    return hashlib.sha256(data).hexdigest() if data is not None else None


def _creation_ns(path):
    try:
        return int(path.stat().st_ctime_ns)
    except (OSError, ValueError):
        return None


def _load_manifest():
    try:
        return json.loads(RECOVERY_MANIFEST.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError, UnicodeError):
        return {}


def _save_manifest(manifest):
    _write_atomic(
        RECOVERY_MANIFEST,
        json.dumps(manifest, indent=2, sort_keys=True) + "\\n",
    )


def _ensure_recovery_store():
    RECOVERY_ROOT.mkdir(parents=True, exist_ok=True)

    if not RECOVERY_VERSION.exists():
        _write_atomic(RECOVERY_VERSION, (expected_version() + "\\n").encode("utf-8"), binary=True)

    if not RECOVERY_MARKER.exists():
        _write_atomic(RECOVERY_MARKER, b"initialized\\n", binary=True)

    manifest = _load_manifest()
    if manifest.get("format") != 1:
        manifest = {
            "format": 1,
            "version": expected_version(),
            "folders": {},
            "files": {
                VERSION_FILE_NAME: _digest(RECOVERY_VERSION),
                MARKER_FILE_NAME: _digest(RECOVERY_MARKER),
            },
        }

    # The recovery copy is authoritative for the two Version manager files.
    # Never silently replace it because the live files changed.
    manifest["version"] = expected_version()
    manifest["files"] = {
        VERSION_FILE_NAME: _digest(RECOVERY_VERSION),
        MARKER_FILE_NAME: _digest(RECOVERY_MARKER),
    }

    for name, path in EXPECTED_FOLDERS.items():
        if path.is_dir():
            current = manifest.setdefault("folders", {}).get(name, {})
            if not current:
                manifest["folders"][name] = {
                    "creation_ns": _creation_ns(path),
                }

    _save_manifest(manifest)


def _folder_creation_matches(path, expected_creation):
    if expected_creation is None:
        return False
    return _creation_ns(path) == expected_creation


def _candidate_roots():
    parent = USER_DATA_ROOT.parent
    try:
        children = [p for p in parent.iterdir() if p.is_dir()]
    except OSError:
        return []

    candidates = []
    for candidate in children:
        if candidate in {RECOVERY_ROOT}:
            continue
        if candidate == DEPENDENCIES_ROOT:
            continue
        candidates.append(candidate)
    return candidates


def _find_moved_root():
    manifest = _load_manifest()
    expected_creation = manifest.get("root_creation_ns")

    # First choice: the exact recorded creation time. Renaming/moving a
    # directory on the same Windows volume preserves its creation time.
    for candidate in _candidate_roots():
        if _folder_creation_matches(candidate, expected_creation):
            return candidate

    # Second choice: the expected Digi structure. This handles older installs
    # created before the recovery manifest existed.
    for candidate in _candidate_roots():
        try:
            matches = sum((candidate / name).is_dir() for name in EXPECTED_FOLDERS)
        except OSError:
            continue
        if matches >= 2:
            return candidate

    return None


def _find_renamed_folder(name):
    expected = EXPECTED_FOLDERS[name]
    if expected.is_dir():
        return expected

    manifest = _load_manifest()
    expected_creation = manifest.get("folders", {}).get(name, {}).get("creation_ns")

    try:
        candidates = [p for p in DEPENDENCIES_ROOT.iterdir() if p.is_dir()]
    except OSError:
        return None

    # Exact creation timestamp is the reliable rename/move detector.
    for candidate in candidates:
        if _folder_creation_matches(candidate, expected_creation):
            return candidate

    # Compatibility fallback for an older installation.
    for candidate in candidates:
        try:
            if name == "Version manager" and (
                (candidate / VERSION_FILE_NAME).exists()
                or (candidate / MARKER_FILE_NAME).exists()
            ):
                return candidate
            if name == "Cache" and any(
                (candidate / item).exists() for item in CACHE_ARTEFACT_NAMES
            ):
                return candidate
            if name == "Search Repository" and (
                (candidate / "Incoming").is_dir()
                or (candidate / "Digi Notes").is_dir()
            ):
                return candidate
        except OSError:
            continue

    return None


def _restore_root():
    if DEPENDENCIES_ROOT.is_dir():
        return False

    moved_root = _find_moved_root()
    if moved_root and moved_root != DEPENDENCIES_ROOT:
        DEPENDENCIES_ROOT.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(moved_root), str(DEPENDENCIES_ROOT))
        return True

    DEPENDENCIES_ROOT.mkdir(parents=True, exist_ok=True)
    return True


def _restore_expected_folders():
    changed = False
    DEPENDENCIES_ROOT.mkdir(parents=True, exist_ok=True)

    for name, expected in EXPECTED_FOLDERS.items():
        if expected.is_dir():
            continue

        candidate = _find_renamed_folder(name)
        if candidate and candidate != expected:
            shutil.move(str(candidate), str(expected))
        else:
            expected.mkdir(parents=True, exist_ok=True)
        changed = True

    return changed


def _restore_version_file(target, recovery):
    recovery_data = _read_bytes(recovery)
    if recovery_data is None:
        return False

    if target.exists() and _read_bytes(target) == recovery_data:
        return False

    # If the user renamed the file rather than editing it, move that exact
    # file back instead of creating a duplicate.
    try:
        siblings = [p for p in VERSION_MANAGER.iterdir() if p.is_file()]
    except OSError:
        siblings = []

    recovery_digest = hashlib.sha256(recovery_data).hexdigest()
    for candidate in siblings:
        if candidate == target:
            continue
        if _digest(candidate) == recovery_digest:
            if target.exists():
                target.unlink()
            candidate.rename(target)
            return True

    _write_atomic(target, recovery_data, binary=True)
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
            # The integrity failure remains visible if Windows has a live lock.
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
                # The active Cache copy is authoritative. Stale duplicates in
                # Search Repository are not useful and are removed.
                if child.is_dir():
                    shutil.rmtree(child)
                else:
                    child.unlink()
            else:
                shutil.move(str(child), str(destination))
            changed = True
        except OSError:
            # Do not make a cache-file cleanup failure destroy user data.
            pass

    return changed


def _refresh_folder_manifest():
    manifest = _load_manifest()
    manifest["format"] = 1
    manifest["version"] = expected_version()
    manifest["root_creation_ns"] = _creation_ns(DEPENDENCIES_ROOT)
    manifest["folders"] = {
        name: {"creation_ns": _creation_ns(path)}
        for name, path in EXPECTED_FOLDERS.items()
        if path.is_dir()
    }
    manifest["files"] = {
        VERSION_FILE_NAME: _digest(RECOVERY_VERSION),
        MARKER_FILE_NAME: _digest(RECOVERY_MARKER),
    }
    _save_manifest(manifest)


def repair_all():
    if not IS_FROZEN:
        return False

    _ensure_recovery_store()

    changed = _restore_root()
    changed = _restore_expected_folders() or changed

    SEARCH_REPOSITORY.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    VERSION_MANAGER.mkdir(parents=True, exist_ok=True)

    changed = _move_cache_artefacts_out_of_search_repository() or changed
    changed = _clean_version_manager() or changed

    changed = _restore_version_file(VERSION_FILE, RECOVERY_VERSION) or changed
    changed = _restore_version_file(MARKER_FILE, RECOVERY_MARKER) or changed

    _refresh_folder_manifest()
    return changed


def initialize_version_file():
    # This is intentionally silent. It is the first operation performed on
    # installed startup, before Database/Search/Notes services are opened.
    try:
        repair_all()
    except (OSError, ValueError, RuntimeError):
        # Integrity will be checked immediately afterwards. The UI will show
        # Error Code 3 only if the repair could not actually finish.
        pass
    return VERSION_FILE.exists()


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

    # Version manager must contain exactly the two protected files.
    try:
        contents = {p.name for p in VERSION_MANAGER.iterdir()}
    except OSError:
        return False, "version_manager"

    if contents != {VERSION_FILE_NAME, MARKER_FILE_NAME}:
        return False, "version_manager_contents"

    # Byte-for-byte comparison catches EVERY content change: version number,
    # whitespace, newline, encoding, BOM, truncation, or arbitrary edits.
    if _digest(VERSION_FILE) != _digest(RECOVERY_VERSION):
        return False, "version_file"
    if _digest(MARKER_FILE) != _digest(RECOVERY_MARKER):
        return False, "version_marker"

    return True, "ok"


def recalibrate_version():
    try:
        repair_all()
        ok, _ = version_integrity()
        return ok
    except (OSError, ValueError, RuntimeError):
        return False


def repair_after_close():
    try:
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
