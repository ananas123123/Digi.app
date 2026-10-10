from pathlib import Path
import os
import sys

APP_VERSION = "1.1.0.0"
SUPPORTED = {".pdf", ".doc", ".docx"}

IS_FROZEN = bool(getattr(sys, "frozen", False))

# Development stays in the repository. Packaged user data belongs in LocalAppData.
APP_DIR = (
    Path(sys.executable).resolve().parent
    if IS_FROZEN
    else Path(__file__).resolve().parents[1]
)

USER_DATA_ROOT = Path(
    os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
) / "Digi"

if IS_FROZEN:
    INSTALL_ROOT = USER_DATA_ROOT
    DEPENDENCIES_ROOT = USER_DATA_ROOT
else:
    INSTALL_ROOT = APP_DIR
    DEPENDENCIES_ROOT = APP_DIR / "Digi Dependencies"

SEARCH_REPOSITORY = DEPENDENCIES_ROOT / "Search Repository"
CACHE_DIR = DEPENDENCIES_ROOT / "Cache"
VERSION_MANAGER = DEPENDENCIES_ROOT / "Version manager"
UPDATE_DEPENDENCIES_ROOT = DEPENDENCIES_ROOT / "update dependencies"
PACKAGE_INSTALLER_ROOT = UPDATE_DEPENDENCIES_ROOT / "package installer"
DB_PATH = CACHE_DIR / "study_index.db"
LIBRARY_CONFIG = CACHE_DIR / "library_folder.txt"


def ensure_directories():
    """Create the required runtime folders without touching user files."""
    required = (
        SEARCH_REPOSITORY,
        CACHE_DIR,
        VERSION_MANAGER,
        UPDATE_DEPENDENCIES_ROOT,
        PACKAGE_INSTALLER_ROOT / APP_VERSION,
    )
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
