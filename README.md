# Argon — native app

## Stack
- **Frontend:** Qt Quick / QML
- **Core and performance-sensitive code:** C++20
- **Build:** CMake and Qt's CMake integration
- **Initial target:** Windows 64-bit, Qt 6.12.0, MinGW 13.1.0

## Run locally
The scripts expect Qt at `C:\Qt\6.12.0\mingw_64` and MinGW at `C:\Qt\Tools\mingw1310_64`.
Double-click `run.bat` to configure, build and launch Argon. Build output is placed in `build\`.

## Architecture
- `src/app/`: application-wide services and lifecycle integration.
- `src/documents/`: document domain and document operations.
- `src/ink/`: reserved for the dedicated stylus/ink engine.
- `src/pdf/`: reserved for PDF integration.
- `src/services/`: reserved for cross-cutting services.
- `qml/components/`: reusable visual controls.
- `qml/pages/`: individual workspace screens.
- `qml/themes/`: central visual tokens.
- `qml/Main.qml`: application shell and page composition.

QML owns presentation and UI interaction. C++ owns application logic and performance-sensitive functionality. Keep components independently testable and avoid putting filesystem, database or document logic into UI files.

## Per-user directory layout

At startup, Argon creates its writable runtime layout under `%LOCALAPPDATA%\\Argon` on Windows. The directory path is centralized in `src/app/AppPaths.*`.

```text
%LOCALAPPDATA%\\Argon\\
├── App\\                 # Installed Argon executable and Qt files (installer-owned)
├── Updater\\             # ArgonUpdater.exe (added by updater packaging)
├── Bootstrap\\           # ArgonBootstrap.exe (added by updater packaging)
├── UserData\\
│   ├── Settings\\
│   ├── Cache\\
│   ├── Search QR\\      # Search and explorer share this root
│   ├── Documents\\
│   ├── Accounts\\
│   └── Analytics\\Daily\\
├── Updates\\
│   ├── Downloads\\
│   ├── Staging\\
│   └── Backups\\
└── Logs\\                # Includes argon-runtime.log
```

The application provisions folders but does not copy its own executable into `App\\`; the installer will own installation of binaries. Existing Search QR content and daily analytics are copied non-destructively from their previous locations when found. Original files are retained, existing destination files are never overwritten, and migration markers prevent repeated copying.

## Status
The modular shell and starter service interfaces are being established. Notes, PDF functionality, persistent storage and ink rendering are not implemented yet. Build and runtime validation are required after each milestone.
