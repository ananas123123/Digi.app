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

## Status
The modular shell and starter service interfaces are being established. Notes, PDF functionality, persistent storage and ink rendering are not implemented yet. Build and runtime validation are required after each milestone.
