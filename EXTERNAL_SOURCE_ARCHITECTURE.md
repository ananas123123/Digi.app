# Digi external application sources

The stable executable loads its application implementation from this folder. Application backend/frontend code is not bundled as a fallback.

## Editable files
- `app.py`: application window and frontend/backend bridge.
- `backend/`: Python application functionality.
- `frontend/`: HTML, CSS, JavaScript and assets.
- `updater/`: update checker scripts.
- `requirements.txt`: dependency reference; changing it does not install packages automatically.

## Workflow
1. Edit files in this folder.
2. Restart Digi after Python changes.
3. Reload the frontend or restart Digi after HTML/CSS/JavaScript changes.
4. Required files missing or empty cause a startup error. Digi does not silently use stale bundled source.

## Limitations
The executable bundles Python/PySide and native runtime dependencies. Compatible ordinary Python source and frontend changes do not require rebuilding. New packages, runtime changes, or compiled/native components may require installation or a new build.

Persistent user data stays under `%LOCALAPPDATA%\Digi`, separate from this folder.
