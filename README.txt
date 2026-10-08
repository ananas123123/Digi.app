DIGI SEARCH ENGINE 1.0.0.0

ARCHITECTURE
The application is now split into three layers.

FRONTEND
- frontend/index.html: UI structure.
- frontend/styles.css: visual styling.
- frontend/tailwind.config.js: Tailwind configuration.
- frontend/app.js: browser-side interaction and UI state.

APPLICATION SHELL
- app.py: minimal native Qt WebEngine host.
- digi_search_engine.py: compatibility entry point.

FUNCTIONAL BACKEND
- backend/config.py: paths and application configuration.
- backend/database.py: SQLite persistence.
- backend/search.py: indexing, normal search, fuzzy search and filtering.
- backend/files.py: operating-system file operations.
- backend/conversion.py: PDF/Word conversion.
- backend/incoming.py: Incoming routing and replacement.
- backend/notes.py: Notes page persistence.
- backend/api.py: the controlled JavaScript/Python bridge.

The frontend does not implement search, conversion, tagging, indexing, Incoming routing, or filesystem operations. The backend does not construct the visual interface.

COMMUNICATION
The HTML frontend communicates with Python through Qt WebChannel. The bridge exposes application operations as explicit commands/signals rather than allowing frontend code to reach backend implementation details directly.

BUILD
Run build.bat. The build packages frontend/ and backend/ into the one-file application and includes Qt WebEngine.

FUNCTIONALITY
The architectural change is intended to preserve the existing Digi search, filtering, tags, file handling, conversion, Incoming, Notes, indexing and folder-management responsibilities while replacing the old widget-based presentation layer.
