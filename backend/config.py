from pathlib import Path
import os
import sys

APP_VERSION = "1.1.0.0"
SUPPORTED = {".pdf", ".doc", ".docx"}

IS_FROZEN = bool(getattr(sys, "frozen", False))

# Development/source execution stays entirely inside the repository.
APP_DIR = (
    Path(sys.executable).resolve().parent
    if IS_FROZEN
    else Path(__file__).resolve().parents[1]
)

USER_DATA_ROOT = Path(
    os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
) / "Digi"

if IS_FROZEN:
    INSTALL_ROOT = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Digi"
    DEPENDENCIES_ROOT = USER_DATA_ROOT
else:
    INSTALL_ROOT = APP_DIR
    DEPENDENCIES_ROOT = APP_DIR / "Digi Dependencies"

SEARCH_REPOSITORY = DEPENDENCIES_ROOT / "Search Repository"
CACHE_DIR = DEPENDENCIES_ROOT / "Cache"
VERSION_MANAGER = DEPENDENCIES_ROOT / "Version manager"
DB_PATH = CACHE_DIR / "study_index.db"
LIBRARY_CONFIG = CACHE_DIR / "library_folder.txt"


def ensure_directories():
    """Prepare development folders, but never repair a packaged user's data."""
    required = (
        SEARCH_REPOSITORY,
        CACHE_DIR,
        VERSION_MANAGER,
    )

    if IS_FROZEN:
        missing = [str(path) for path in required if not path.is_dir()]
        if missing:
            raise FileNotFoundError(
                "Required Digi data folders are missing: " + ", ".join(missing)
            )
        return

    # Source/test mode uses repository-local disposable dependencies only.
    for path in required:
        path.mkdir(parents=True, exist_ok=True)


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
