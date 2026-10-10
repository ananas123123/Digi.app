# Controlled updater runtime test

This is a development-only test path on `test/controlled-runtime-metadata`. It does not change the production release repository and does not implement downloading or installation.

## 1. Start the local metadata feed

From the Digi.app repository root, open PowerShell window 1:

```powershell
.\.venv\Scripts\python.exe updater\dev_test_server.py --version 99.0.0.0
```

The server binds to `127.0.0.1:8765` only. It serves fake metadata and has no package or installer endpoint.

## 2. Launch Digi against that feed

Open PowerShell window 2, from the same repository root:

```powershell
$env:DIGI_UPDATER_TEST_MODE = "1"
$env:DIGI_UPDATER_TEST_MANIFEST_URL = "http://127.0.0.1:8765/latest.json"
.\run.bat
```

Expected visible result: a yellow **DEVELOPMENT TEST MODE — LOCAL UPDATE FEED — NO INSTALLS** banner and a red update-status dot because the fake version is `99.0.0.0`.

## 3. Return to normal mode

Close Digi, then in PowerShell window 2 run:

```powershell
Remove-Item Env:DIGI_UPDATER_TEST_MODE -ErrorAction SilentlyContinue
Remove-Item Env:DIGI_UPDATER_TEST_MANIFEST_URL -ErrorAction SilentlyContinue
.\run.bat
```

Or close that PowerShell window and launch Digi normally from a new one. The test feed is disabled by default. Stop the local server with Ctrl+C.

## Safety boundaries

- Test URL is accepted only when explicit test mode is enabled and the URL is HTTP on loopback with an explicit port.
- If test mode is not explicitly enabled, Digi uses its existing production metadata URLs.
- The fake feed only supplies metadata; Digi still does not download, install, replace, or delete anything.
- Do not merge this development test hook into a production release without a separate review.
