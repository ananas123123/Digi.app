# Digi executable architecture

## Packaged build
- `build.bat` creates a single `Digi Search Engine.exe` and a Desktop shortcut.
- The executable bundles the application entry point, backend Python source, frontend files, updater JavaScript, Python runtime, and required native dependencies.
- No external `Digi Source` folder is required.
- The `Incoming` folder and mechanism are not included.
- Build intermediates and the generated PyInstaller spec remain under version-specific folders in `Cache`; existing cache folders are not deleted by the build script.

## Runtime data
Persistent user data is stored under `%LOCALAPPDATA%\Digi`. On first launch, Digi initializes:
- `Search Repository`
- `Search Repository\Digi Notes`
- `Cache`
- `Version manager`

Digi does not create an `Incoming` folder. User data remains separate from the executable so application updates can replace the executable without replacing user data.

## Development workflow
- Run `run.bat` to launch source code from the repository.
- Edit `app.py`, `backend/`, `frontend/`, and `updater/` in the repository.
- Rebuild the executable when changes need to be included in the packaged release.
