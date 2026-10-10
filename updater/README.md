# Digi User-Approved Updater

The updater checks the stable release manifest and waits for an explicit user decision before downloading or applying an update.

## User flow

1. Read the installed version and the public `latest.json` manifest.
2. Show the update prompt only when a newer published stable version is available.
3. If the user selects **No**, remember that decision for that version and do not download or change application files.
4. If the user selects **Yes, update**, fetch the matching `release.json`, validate it, download the full package, verify the exact byte size and SHA-256, and validate the ZIP paths.
5. Stage only the expected application files: `Digi Search Engine.exe` and `Digi Source/`.
6. Request Windows elevation for a separate PowerShell helper. Digi closes before the helper replaces the application files. The helper retains the previous executable and source tree for rollback and attempts to launch the updated application.
7. Never extract over or delete the Search Repository, library, Incoming folder, notes, database, caches, indexes, or other user data.

## Release package contract

The full ZIP must have these items at its root:

- `Digi Search Engine.exe`
- `Digi Source/` containing the required runtime source files

The matching `release.json` must declare `product: "Digi"`, `schema_version: 1`, the matching version, a published status, and `package.download_url`, `package.size_bytes`, and `package.sha256` (or the equivalent fields under `packages.full`). Package URLs must use HTTPS.

## Important limitations before production publishing

- The updater only operates in a frozen/packaged Windows build, not a source checkout.
- The release repository's current `latest.json` and versioned release metadata are inconsistent and there is no package asset attached to the existing GitHub release. Do not mark a release published until those metadata and package defects have been corrected.
- A SHA-256 value stored in the same public repository protects against accidental corruption but does not independently prove publisher identity. Code signing should be added before broad public distribution.
- The update helper keeps the prior application files under `%LOCALAPPDATA%\Digi\Updater\Backups`. A later maintenance policy can remove old backups only after a confirmed successful launch.
- This implementation requires manual testing on a disposable Windows installation before production use, especially elevation, interrupted replacement, and rollback.

## Polling

The status checker polls once per minute while Digi is open.
