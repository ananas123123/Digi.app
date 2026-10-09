"""Stable PyInstaller entry point for the external Digi source tree."""
from __future__ import annotations
import importlib.util
import os
import sys
import traceback
from pathlib import Path

REQUIRED_FILES = (
    Path("app.py"), Path("backend/__init__.py"), Path("backend/api.py"),
    Path("frontend/index.html"), Path("frontend/app.js"),
    Path("frontend/styles.css"), Path("updater/update_checker.js"),
)

def executable_directory() -> Path:
    return Path(sys.executable).resolve().parent

def source_directory() -> Path:
    # Development mode loads the repository source directly. A packaged EXE
    # loads the editable source tree beside the executable.
    configured = os.environ.get("DIGI_SOURCE_DIR")
    if configured:
        return Path(configured).expanduser().resolve()
    if not getattr(sys, "frozen", False):
        return Path(__file__).resolve().parent
    return executable_directory() / "Digi Source"

def validate_sources(root: Path) -> list[str]:
    if not root.is_dir():
        return [f"External source directory is missing: {root}"]
    problems = []
    for relative in REQUIRED_FILES:
        target = root / relative
        if not target.is_file():
            problems.append(f"Required source file is missing: {target}")
        elif target.stat().st_size == 0:
            problems.append(f"Required source file is empty: {target}")
    return problems

def show_fatal_error(title: str, details: str) -> None:
    try:
        from PySide6.QtWidgets import QApplication, QMessageBox
        app = QApplication.instance() or QApplication(sys.argv[:1])
        box = QMessageBox()
        box.setIcon(QMessageBox.Icon.Critical)
        box.setWindowTitle("Digi Search Engine — Startup Error")
        box.setText(title)
        box.setInformativeText(details)
        box.setDetailedText(details)
        box.exec()
    except Exception:
        try:
            sys.stderr.write(title + "\n\n" + details + "\n")
        except Exception:
            pass

def main() -> int:
    root = source_directory()
    problems = validate_sources(root)
    if problems:
        show_fatal_error(
            "Digi cannot start because its external application sources are missing or invalid.",
            "\n".join(problems) + "\n\nRestore the required files in the Digi Source folder. "
            "Digi did not repair or replace them automatically.",
        )
        return 2
    sys.path.insert(0, str(root))
    try:
        spec = importlib.util.spec_from_file_location("digi_external_app", root / "app.py")
        if spec is None or spec.loader is None:
            raise ImportError(f"Could not load external entry point: {root / 'app.py'}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        entry = getattr(module, "main", None)
        if not callable(entry):
            raise ImportError(f"External app.py must define main(): {root / 'app.py'}")
        entry()
        return 0
    except SystemExit as exc:
        return int(exc.code or 0) if isinstance(exc.code, int) or exc.code is None else 1
    except Exception:
        show_fatal_error("Digi could not load its external application code.",
                         f"External source: {root}\n\n{traceback.format_exc()}")
        return 3

if __name__ == "__main__":
    raise SystemExit(main())
