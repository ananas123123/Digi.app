from pathlib import Path
import ctypes
import os
import sys

APP_VERSION = "1.0.0.0"
SUPPORTED = {".pdf", ".doc", ".docx"}

IS_FROZEN = bool(getattr(sys, "frozen", False))

# Development/source execution stays entirely inside the repository.
APP_DIR = (
    Path(sys.executable).resolve().parent
    if IS_FROZEN
    else Path(__file__).resolve().parents[1]
)

if IS_FROZEN:
    # Installed application files belong in Program Files, while all
    # persistent user data belongs in LOCALAPPDATA.
    INSTALL_ROOT = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Digi"
    USER_DATA_ROOT = Path(
        os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
    ) / "Digi"

    DEPENDENCIES_ROOT = USER_DATA_ROOT
else:
    # Never redirect source/test execution into the production data location.
    INSTALL_ROOT = APP_DIR
    DEPENDENCIES_ROOT = APP_DIR / "Digi Dependencies"

SEARCH_REPOSITORY = DEPENDENCIES_ROOT / "Search Repository"
CACHE_DIR = DEPENDENCIES_ROOT / "Cache"
VERSION_MANAGER = DEPENDENCIES_ROOT / "Version manager"
DB_PATH = CACHE_DIR / "study_index.db"
LIBRARY_CONFIG = CACHE_DIR / "library_folder.txt"
DEFAULT_INCOMING = SEARCH_REPOSITORY / "Incoming"


def _create_dependency_layout():
    for path in (
        SEARCH_REPOSITORY,
        CACHE_DIR,
        VERSION_MANAGER,
        DEFAULT_INCOMING,
    ):
        path.mkdir(parents=True, exist_ok=True)


def ensure_directories():
    try:
        _create_dependency_layout()
        return
    except PermissionError:
        # Source/test mode must never elevate.
        # In the installed application, user data should normally be writable
        # without elevation. Elevation is retained only as a compatibility
        # fallback for an installation/data layout that still requires repair.
        if IS_FROZEN and "--dependency-repair" not in sys.argv:
            try:
                executable = str(Path(sys.executable).resolve())
                result = ctypes.windll.shell32.ShellExecuteW(
                    None,
                    "runas",
                    executable,
                    "--dependency-repair",
                    str(Path(executable).parent),
                    1,
                )
                if result > 32:
                    raise SystemExit(0)
            except SystemExit:
                raise
            except Exception:
                pass
        raise


def get_library_root():
    ensure_directories()
    try:
        configured = Path(
            LIBRARY_CONFIG.read_text(encoding="utf-8").strip()
        ).resolve()
        if (
            configured.is_dir()
            and configured != CACHE_DIR.resolve()
            and CACHE_DIR.resolve() not in configured.parents
        ):
            return configured
    except (OSError, ValueError):
        pass
    return SEARCH_REPOSITORY.resolve()
