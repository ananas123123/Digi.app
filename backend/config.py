from pathlib import Path
import ctypes
import sys

APP_VERSION = "1.0.0.0"
SUPPORTED = {".pdf", ".doc", ".docx"}
APP_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parents[1]
PROGRAM_FILES = Path("C:/Program Files")
DEPENDENCIES_ROOT = PROGRAM_FILES / "Digi Dependencies"
SEARCH_REPOSITORY = DEPENDENCIES_ROOT / "Search Repository"
CACHE_DIR = DEPENDENCIES_ROOT / "Cache"
VERSION_MANAGER = DEPENDENCIES_ROOT / "Version manager"
DB_PATH = CACHE_DIR / "digi.db"
LIBRARY_CONFIG = CACHE_DIR / "library_folder.txt"
DEFAULT_INCOMING = SEARCH_REPOSITORY / "Incoming"

def ensure_directories():
    try:
        for p in (SEARCH_REPOSITORY, CACHE_DIR, VERSION_MANAGER, DEFAULT_INCOMING):
            p.mkdir(parents=True, exist_ok=True)
        return
    except PermissionError:
        if getattr(sys, "frozen", False) and "--dependency-repair" not in sys.argv:
            try:
                if ctypes.windll.shell32.ShellExecuteW(None,"runas",str(Path(sys.executable).resolve()),"--dependency-repair",str(Path(sys.executable).resolve().parent),1)>32:
                    raise SystemExit(0)
            except Exception:
                pass
        raise

def get_library_root():
    ensure_directories()
    try:
        p=Path(LIBRARY_CONFIG.read_text(encoding="utf-8").strip()).resolve()
        if p.is_dir() and p != CACHE_DIR.resolve() and CACHE_DIR.resolve() not in p.parents:
            return p
    except (OSError,ValueError):
        pass
    return SEARCH_REPOSITORY.resolve()
