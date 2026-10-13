# Digi — native rebuild

This branch is the clean development starting point for the native Digi application.

## Initial stack

- **UI:** Qt Quick / QML
- **Core logic and performance-sensitive components:** C++20
- **Build system:** CMake with Qt's CMake integration
- **Initial target:** Windows 64-bit, Qt 6.12.0, MinGW 13.1.0

## Local setup

The current scripts expect the Qt installation at `C:\Qt\6.12.0\mingw_64` and the Qt MinGW toolchain at `C:\Qt\Tools\mingw1310_64`.

1. Open the repository's local folder in File Explorer.
2. Double-click `run.bat`.
3. The script configures, builds, and launches Digi. Build output is placed in `build\`.

If the scripts report that Qt or MinGW cannot be found, update the paths near the top of `build.bat` and `run.bat` to match the installed directories.

## Architecture rules

- Keep UI components, application services, document models, and rendering/ink code separated.
- QML is responsible for presentation and interaction; C++ owns application logic and performance-sensitive work.
- Do not put business logic into large QML files or make QML directly responsible for filesystem/database operations.
- Add dependencies deliberately, document why they exist, and keep components independently testable.
- Validate each milestone with a build and a focused manual test before adding the next subsystem.

## Current status

This is a starter test window, not a completed note-taking application. The build scripts and application have not yet been verified on the developer's machine.
