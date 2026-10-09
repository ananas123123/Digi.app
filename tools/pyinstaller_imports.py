"""Discover imports used by the editable Digi Python source for PyInstaller.

Prints PyInstaller --hidden-import options for non-Digi imports found in app.py
and backend/**/*.py. Local backend imports are intentionally excluded so the
editable application modules are not copied into the executable.
"""
from __future__ import annotations

import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILES = [ROOT / "app.py", *sorted((ROOT / "backend").rglob("*.py"))]
LOCAL_PREFIXES = {"backend", "app", "digi_search_engine"}
IGNORED = {"__future__"}


def module_from_import(node: ast.AST, current_package: str) -> set[str]:
    found: set[str] = set()
    if isinstance(node, ast.Import):
        for alias in node.names:
            found.add(alias.name)
    elif isinstance(node, ast.ImportFrom):
        if node.level:
            parts = current_package.split(".") if current_package else []
            keep = max(0, len(parts) - node.level + 1)
            base = ".".join(parts[:keep])
            if node.module:
                base = ".".join(part for part in (base, node.module) if part)
        else:
            base = node.module or ""
        if base:
            found.add(base)
        for alias in node.names:
            if alias.name != "*":
                found.add(".".join(part for part in (base, alias.name) if part))
    return found


def main() -> int:
    if not (ROOT / "app.py").is_file() or not (ROOT / "backend").is_dir():
        print("ERROR: app.py or backend/ is missing", file=sys.stderr)
        return 2

    imports: set[str] = set()
    for path in SOURCE_FILES:
        try:
            tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
        except (OSError, SyntaxError, UnicodeError) as exc:
            print(f"ERROR: cannot analyse {path}: {exc}", file=sys.stderr)
            return 2
        package = "backend" + ("." + ".".join(path.relative_to(ROOT / "backend").parts[:-1]) if path.parent != ROOT / "backend" else "")
        if path.name == "__init__.py":
            package = package.rsplit(".", 1)[0] if "." in package else "backend"
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                imports.update(module_from_import(node, package))

    external = set()
    for name in imports:
        if not name or name in IGNORED:
            continue
        if any(name == prefix or name.startswith(prefix + ".") for prefix in LOCAL_PREFIXES):
            continue
        external.add(name)

    # One line so build.bat can pass the discovered imports to PyInstaller.
    print(" ".join(f'--hidden-import="{name}"' for name in sorted(external)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
