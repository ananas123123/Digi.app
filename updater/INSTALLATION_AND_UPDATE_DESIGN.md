# Installation and self-update contract

Status: implementation contract for `updater-install-layout-logging`. The Windows build and end-to-end update still require runtime validation.

## 1. Runtime installation layout

The installed application uses a stable directory:

```text
%LOCALAPPDATA%\Digi\
├── Digi Search Engine.exe
├── DigiUpdater.exe
├── Logs\
├── Search Repository\
├── Cache\
├── Version manager\
└── update dependencies\
    └── package installer\
        └── <version>\
            └── Digi Search Engine.exe
```

The executable and helper currently live directly in `%LOCALAPPDATA%\Digi`. The desktop shortcut and repaired Digi shortcuts target the stable `Digi Search Engine.exe` path. Updates replace that executable in place; they do not create a version-specific installed application directory. The versioned package folder is only a download/staging source.

The builder creates the root, `Logs`, `Search Repository`, `Search Repository/Digi Notes`, and `Cache` before the app's first launch. It deliberately does not create `Version manager`, so the first-run bootstrap can initialise version metadata safely. The bootstrap also handles an already-existing root without overwriting existing user data.

## 2. Persistent user data

All existing user data remains outside the installation directory under:

```text
%LOCALAPPDATA%\Digi\
├── Search Repository\
├── Cache\
└── Version manager\
```

The updater must never move, delete, rename, replace, or clean these persistent data folders. Cleanup is limited to verified update packages, staging files, and recovery copies after confirmed startup. The existing version marker intentionally records the initial data-layout version and is not rewritten just because the application executable is updated.

## 3. Release asset contract

A published application update consists of the new `Digi Search Engine.exe` asset plus release metadata containing the exact HTTPS download URL, byte size, SHA-256 digest, and version. The executable must be built before its size and digest are calculated.

The installed `DigiUpdater.exe` is a separate, stable helper. It is not replaced by an ordinary application update. A first-install bundle must install both executables. Do not publish an app-only update as installable on systems that do not yet have the helper.

## 4. Update lifecycle

1. Digi fetches the trusted release manifest and validates its schema, published status, version consistency, HTTPS URL, byte size, and SHA-256 format.
2. Digi downloads the announced executable to a unique temporary file and verifies the exact size and SHA-256. Failed downloads are deleted.
3. Digi verifies that the stable installation path and helper are present. If they are not, it must stop and explain that this installation cannot yet self-update; it must not attempt a direct self-replacement.
4. Digi starts `DigiUpdater.exe` with the current process ID, target executable path, verified download path, expected SHA-256, and version, then exits normally.
5. The helper validates arguments and path boundaries, waits for Digi to exit, copies the candidate into a staging file inside the installation directory, and verifies the staged copy again.
6. The helper preserves a rollback copy of the existing executable, replaces the target, and launches the new executable.
7. The helper keeps the rollback copy until the new process passes a defined startup confirmation. If replacement or startup confirmation fails, it restores the previous executable and reports failure. The helper never modifies persistent user data.
8. After successful startup confirmation, the helper repairs existing Digi shortcuts in standard Desktop/Start-menu/Quick Launch/pinned-shortcut locations, then removes the downloaded package and rollback copy. Failed candidates are retained under `Logs/failed-updates`; failed updates keep the downloaded package available for retry.

## 5. Safety requirements

- Never replace an executable while Digi is running.
- Never install an unverified candidate.
- Never trust a caller-provided target path without validating it against the stable installation directory.
- Never delete the old executable before a verified candidate and recovery path exist.
- Treat a process merely existing as insufficient proof that the application started successfully; define an explicit startup-confirmation mechanism before enabling automatic rollback-copy deletion.
- Do not use the local test feed or fixture as a real release.
- Keep this work on `updater-install-layout-logging`; do not merge into `main` or modify `getdigi.fun` or the live release metadata.

## 6. Implementation order

1. Keep helper path validation, staging, replacement, rollback, process-wait, and startup-confirmation tests aligned with the current implementation.
2. Build `DigiUpdater.exe` as a separate PyInstaller executable on Windows.
3. Validate the app-to-helper handoff and startup readiness on the installed build.
4. Exercise success, invalid hash, interrupted download, replacement failure, failed startup, rollback, shortcut repair, and user-data preservation before publishing anything.
