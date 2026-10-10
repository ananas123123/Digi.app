"""PyInstaller entry point for the bundled Digi application."""
from __future__ import annotations

import importlib.util
import os
import sys
import traceback
from pathlib import Path

REQUIRED_FILES = (
    Path("app.py"),
    Path("backend/__init__.py"),
    Path("backend/api.py"),
    Path("backend/updater_logging.py"),
    Path("frontend/index.html"),
    Path("frontend/app.js"),
    Path("frontend/styles.css"),
    Path("updater/version_comparison.js"),
    Path("updater/update_checker.js"),
)


def application_directory() -> Path:
    """Return source root in development or PyInstaller's extracted bundle."""
    configured = os.environ.get("DIGI_SOURCE_DIR")
    if configured:
        return Path(configured).expanduser().resolve()
    if getattr(sys, "frozen", False):
        return Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent))
    return Path(__file__).resolve().parent


def validate_sources(root: Path) -> list[str]:
    if not root.is_dir():
        return [f"Application bundle directory is missing: {root}"]
    problems = []
    for relative in REQUIRED_FILES:
        target = root / relative
        if not target.is_file():
            problems.append(f"Required application file is missing: {target}")
        elif target.stat().st_size == 0:
            problems.append(f"Required application file is empty: {target}")
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
    root = application_directory()
    problems = validate_sources(root)
    if problems:
        show_fatal_error(
            "Digi cannot start because required application files are missing or invalid.",
            "\n".join(problems),
        )
        return 2

    sys.path.insert(0, str(root))
    try:
        spec = importlib.util.spec_from_file_location("digi_external_app", root / "app.py")
        if spec is None or spec.loader is None:
            raise ImportError(f"Could not load application entry point: {root / 'app.py'}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        entry = getattr(module, "main", None)
        if not callable(entry):
            raise ImportError("The bundled app.py must define main().")
        entry()
        return 0
    except SystemExit as exc:
        return int(exc.code or 0) if isinstance(exc.code, int) or exc.code is None else 1
    except Exception:
        show_fatal_error(
            "Digi could not load its bundled application code.",
            f"Application bundle: {root}\n\n{traceback.format_exc()}",
        )
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
