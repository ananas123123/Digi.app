from pathlib import Path
import ctypes
import sys

APP_VERSION = "1.0.0.0"
SUPPORTED = {".pdf", ".doc", ".docx"}

# Source/development builds must never require administrator access or write to
# Program Files. Frozen/distributed builds keep the existing Program Files
# dependency layout and can elevate only when that layout must be repaired.
APP_DIR = (
    Path(sys.executable).resolve().parent
    if getattr(sys, "frozen", False)
    else Path(__file__).resolve().parents[1]
)

if getattr(sys, "frozen", False):
    DEPENDENCIES_ROOT = Path(
        Path("C:/Program Files") / "Digi Dependencies"
    )
else:
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
        # Only distributed builds use the protected Program Files layout.
        # Relaunch elevated once so the dependency repair can complete.
        if getattr(sys, "frozen", False) and "--dependency-repair" not in sys.argv:
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
