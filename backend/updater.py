"""Safe, user-approved full-package updater for packaged Digi builds.

Release metadata is treated as untrusted input. The package is downloaded to a
private staging directory, checked against its declared size and SHA-256, and
validated before a separate elevated helper replaces application files.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse

from PySide6.QtCore import QThread, Signal

PRODUCT = "Digi"
SCHEMA_VERSION = 1
LATEST_URL = (
    "https://raw.githubusercontent.com/"
    "ananas123123/digiwebversionreleases/main/latest.json"
)
RELEASE_URL_TEMPLATE = (
    "https://raw.githubusercontent.com/"
    "ananas123123/digiwebversionreleases/main/releases/{version}/release.json"
)
MAX_METADATA_BYTES = 1024 * 1024
MAX_PACKAGE_BYTES = 1024 * 1024 * 1024
MAX_UNPACKED_BYTES = 2 * 1024 * 1024 * 1024
MAX_ARCHIVE_ENTRIES = 50000
REQUIRED_SOURCE_FILES = (
    "app.py",
    "backend/__init__.py",
    "backend/api.py",
    "frontend/index.html",
    "frontend/app.js",
    "frontend/styles.css",
    "updater/update_checker.js",
)
FORBIDDEN_PARTS = {
    ".venv", "venv", "__pycache__", "cache", "build", "dist",
    "search repository", "version manager", "incoming", "digi dependencies",
}


class UpdateError(RuntimeError):
    """A safe, user-displayable update failure."""


def compare_versions(left: str, right: str) -> int:
    """Compare dotted numeric versions without lexicographic ordering."""
    pattern = r"^\d+(?:\.\d+){0,7}$"
    if not isinstance(left, str) or not isinstance(right, str):
        raise UpdateError("The release contains an invalid version.")
    if not re.fullmatch(pattern, left) or not re.fullmatch(pattern, right):
        raise UpdateError("The release contains an invalid version.")
    a = [int(part) for part in left.split(".")]
    b = [int(part) for part in right.split(".")]
    length = max(len(a), len(b))
    a.extend([0] * (length - len(a)))
    b.extend([0] * (length - len(b)))
    return (a > b) - (a < b)


def _read_https(url: str, limit: int, timeout: int = 15) -> bytes:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise UpdateError("Update metadata and packages must use HTTPS.")
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Digi-User-Approved-Updater",
            "Cache-Control": "no-cache",
            "Accept": "application/json, application/octet-stream, */*",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            final_url = urlparse(response.geturl())
            if final_url.scheme != "https":
                raise UpdateError("The download redirected away from HTTPS.")
            length = response.headers.get("Content-Length")
            if length and int(length) > limit:
                raise UpdateError("The update download exceeds the permitted size.")
            data = response.read(limit + 1)
    except UpdateError:
        raise
    except Exception as exc:
        raise UpdateError("Could not download update information or package.") from exc
    if len(data) > limit:
        raise UpdateError("The downloaded content exceeds the permitted size.")
    return data


def _read_json(url: str) -> dict:
    try:
        result = json.loads(_read_https(url, MAX_METADATA_BYTES).decode("utf-8"))
    except UpdateError:
        raise
    except Exception as exc:
        raise UpdateError("The release metadata is not valid JSON.") from exc
    if not isinstance(result, dict):
        raise UpdateError("The release metadata has an unexpected format.")
    return result


def _package_details(release: dict) -> tuple[str, int, str]:
    package = release.get("package")
    if not isinstance(package, dict):
        packages = release.get("packages")
        package = packages.get("full") if isinstance(packages, dict) else None
    if not isinstance(package, dict):
        raise UpdateError("This release has no full application package.")

    url = package.get("download_url") or package.get("url")
    size = package.get("size_bytes")
    digest = package.get("sha256")
    if not isinstance(url, str) or not url.startswith("https://"):
        raise UpdateError("The release does not provide a valid HTTPS package URL.")
    if isinstance(size, bool) or not isinstance(size, int) or not (1 <= size <= MAX_PACKAGE_BYTES):
        raise UpdateError("The release package size is missing or invalid.")
    if not isinstance(digest, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", digest):
        raise UpdateError("The release package SHA-256 checksum is missing or invalid.")
    return url, size, digest.lower()


def _safe_archive_path(name: str) -> tuple[str, ...]:
    # ZIP uses POSIX separators even on Windows. Reject ambiguous or traversing paths.
    if not name or "\\" in name or name.startswith("/") or "\x00" in name:
        raise UpdateError("The package contains an unsafe file path.")
    path = PurePosixPath(name)
    parts = path.parts
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise UpdateError("The package contains an unsafe file path.")
    if any(":" in part for part in parts):
        raise UpdateError("The package contains an unsafe file path.")
    if parts[0] not in ("Digi Search Engine.exe", "Digi Source"):
        raise UpdateError("The package contains an unexpected top-level item.")
    if parts[0] == "Digi Search Engine.exe" and len(parts) != 1:
        raise UpdateError("The package contains an invalid executable path.")
    if parts[0] == "Digi Source":
        if len(parts) == 1:
            return parts
        if any(part.casefold() in FORBIDDEN_PARTS for part in parts[1:]):
            raise UpdateError("The package includes a prohibited data or build directory.")
    return parts


def _stage_archive(archive_path: Path, payload_dir: Path) -> None:
    payload_dir.mkdir(parents=True, exist_ok=False)
    seen: set[str] = set()
    total_unpacked = 0
    try:
        with zipfile.ZipFile(archive_path, "r") as archive:
            entries = archive.infolist()
            if not entries or len(entries) > MAX_ARCHIVE_ENTRIES:
                raise UpdateError("The package has an invalid number of entries.")
            for info in entries:
                parts = _safe_archive_path(info.filename.rstrip("/"))
                normalized = "/".join(parts).casefold()
                if normalized in seen:
                    raise UpdateError("The package contains duplicate file paths.")
                seen.add(normalized)
                mode = (info.external_attr >> 16) & 0xFFFF
                if mode and (mode & 0o170000) == 0o120000:
                    raise UpdateError("The package contains a symbolic link.")
                if info.is_dir():
                    if parts == ("Digi Search Engine.exe",):
                        raise UpdateError("The executable path is a directory.")
                    continue
                total_unpacked += info.file_size
                if total_unpacked > MAX_UNPACKED_BYTES:
                    raise UpdateError("The unpacked package exceeds the permitted size.")
                destination = payload_dir.joinpath(*parts)
                destination.parent.mkdir(parents=True, exist_ok=True)
                # Copy file data rather than using extract(), preventing ZIP path traversal.
                with archive.open(info, "r") as source, destination.open("xb") as target:
                    shutil.copyfileobj(source, target, length=1024 * 1024)
    except UpdateError:
        raise
    except Exception as exc:
        raise UpdateError("The update package is not a valid ZIP archive.") from exc

    exe = payload_dir / "Digi Search Engine.exe"
    source_root = payload_dir / "Digi Source"
    if not exe.is_file() or exe.stat().st_size == 0 or not source_root.is_dir():
        raise UpdateError("The package is missing the executable or Digi Source directory.")
    for relative in REQUIRED_SOURCE_FILES:
        candidate = source_root / relative
        if not candidate.is_file() or candidate.stat().st_size == 0:
            raise UpdateError("The package is missing a required Digi source file.")


def _powershell_script() -> str:
    # This script only replaces the two explicitly designated application targets.
    return r'''param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$InstallRoot,
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$Version
)
$ErrorActionPreference = 'Stop'
$StageRoot = [IO.Path]::GetFullPath($StageRoot)
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$DataRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Digi'))
$stageFull = $StageRoot.TrimEnd('\') + '\'
$dataFull = $DataRoot.TrimEnd('\') + '\'
if ($stageFull.StartsWith($dataFull, [StringComparison]::OrdinalIgnoreCase) -eq $false) {
    throw 'Staging directory is outside Digi updater storage.'
}
if ($InstallRoot.StartsWith($DataRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to install application files inside user-data storage.'
}
$payloadExe = Join-Path $StageRoot 'payload\Digi Search Engine.exe'
$payloadSource = Join-Path $StageRoot 'payload\Digi Source'
$targetExe = Join-Path $InstallRoot 'Digi Search Engine.exe'
$targetSource = Join-Path $InstallRoot 'Digi Source'
if (!(Test-Path -LiteralPath $payloadExe -PathType Leaf) -or
    !(Test-Path -LiteralPath $payloadSource -PathType Container)) {
    throw 'Staged update payload is incomplete.'
}
$backupBase = Join-Path $DataRoot 'Updater\Backups'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$backup = Join-Path $backupBase ($Version + '-' + $stamp)
New-Item -ItemType Directory -Force -Path $backupBase | Out-Null
New-Item -ItemType Directory -Path $backup | Out-Null
$oldExe = Join-Path $backup 'Digi Search Engine.exe'
$oldSource = Join-Path $backup 'Digi Source'
$changedExe = $false
$changedSource = $false
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while ([DateTime]::UtcNow -lt $deadline) {
        try { Get-Process -Id $ParentPid -ErrorAction Stop | Out-Null; Start-Sleep -Milliseconds 250 }
        catch { break }
    }
    try { Get-Process -Id $ParentPid -ErrorAction Stop | Out-Null; throw 'Digi did not close in time.' } catch {
        if ($_.Exception.Message -eq 'Digi did not close in time.') { throw }
    }
    if (!(Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        throw 'The application installation directory no longer exists.'
    }
    if (Test-Path -LiteralPath $targetExe -PathType Leaf) {
        Move-Item -LiteralPath $targetExe -Destination $oldExe
        $changedExe = $true
    }
    if (Test-Path -LiteralPath $targetSource -PathType Container) {
        Move-Item -LiteralPath $targetSource -Destination $oldSource
        $changedSource = $true
    }
    Copy-Item -LiteralPath $payloadExe -Destination $targetExe
    Copy-Item -LiteralPath $payloadSource -Destination $targetSource -Recurse
    $process = Start-Process -FilePath $targetExe -WorkingDirectory $InstallRoot -PassThru
    Start-Sleep -Seconds 15
    $process.Refresh()
    if ($process.HasExited) { throw 'The updated application did not remain running after launch.' }
    # Keep the old files in the backup directory until a later cleanup policy is defined.
    Remove-Item -LiteralPath $StageRoot -Recurse -Force
    exit 0
}
catch {
    try {
        Get-Process -Name 'Digi Search Engine' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $oldExe -PathType Leaf) {
            if (Test-Path -LiteralPath $targetExe -PathType Leaf) { Remove-Item -LiteralPath $targetExe -Force }
            Move-Item -LiteralPath $oldExe -Destination $targetExe
        }
        if (Test-Path -LiteralPath $oldSource -PathType Container) {
            if (Test-Path -LiteralPath $targetSource -PathType Container) { Remove-Item -LiteralPath $targetSource -Recurse -Force }
            Move-Item -LiteralPath $oldSource -Destination $targetSource
        }
        if (Test-Path -LiteralPath $targetExe -PathType Leaf) {
            Start-Process -FilePath $targetExe -WorkingDirectory $InstallRoot
        }
    } catch {
        # Leave the backup directory intact for manual recovery if rollback itself fails.
    }
    exit 1
}
'''


def _quote_windows_arg(value: str) -> str:
    # Quote a Windows command-line argument, including embedded quotes and backslashes.
    value = str(value)
    return '"' + re.sub(r'(\\*)"', r'\1\1\"', value).replace(
        "\\", "\\"
    ) + '"'


def _launch_elevated_helper(stage_root: Path, install_root: Path, version: str) -> None:
    if os.name != "nt" or not getattr(sys, "frozen", False):
        raise UpdateError("Installing updates is available only in the packaged Windows application.")
    import ctypes

    windows = Path(os.environ.get("WINDIR", r"C:\Windows"))
    powershell = windows / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    if not powershell.is_file():
        raise UpdateError("Windows PowerShell could not be found.")
    helper_dir = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Digi" / "Updater"
    helper_dir.mkdir(parents=True, exist_ok=True)
    helper = helper_dir / "apply-update.ps1"
    helper.write_text(_powershell_script(), encoding="utf-8")
    parameters = " ".join((
        "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
        _quote_windows_arg(str(helper)),
        "-StageRoot", _quote_windows_arg(str(stage_root)),
        "-InstallRoot", _quote_windows_arg(str(install_root)),
        "-ParentPid", str(os.getpid()),
        "-Version", _quote_windows_arg(version),
    ))
    result = ctypes.windll.shell32.ShellExecuteW(
        None, "runas", str(powershell), parameters, None, 1
    )
    if result <= 32:
        raise UpdateError("Windows did not start the update helper. No application files were changed.")


class UpdateWorker(QThread):
    """Download, validate, stage, and request an explicitly approved update."""
    progress = Signal(int, str)
    finishedResult = Signal(str)

    def __init__(self, requested_version: str, installed_version: str,
                 install_root: Path, user_data_root: Path, parent=None):
        super().__init__(parent)
        self.requested_version = requested_version
        self.installed_version = installed_version
        self.install_root = Path(install_root).resolve()
        self.user_data_root = Path(user_data_root).resolve()

    def _emit_result(self, ok: bool, message: str, version: str = "") -> None:
        self.finishedResult.emit(json.dumps({
            "ok": ok, "message": message, "version": version,
        }))

    def run(self):
        stage_root: Path | None = None
        try:
            self.progress.emit(5, "Validating release metadata…")
            latest = _read_json(LATEST_URL)
            if latest.get("product") != PRODUCT or latest.get("schema_version") != SCHEMA_VERSION:
                raise UpdateError("The release manifest is not supported.")
            if latest.get("channel", "stable") != "stable":
                raise UpdateError("Only stable Digi releases can be installed.")
            if latest.get("release_status") != "published":
                raise UpdateError("This Digi release is not published.")
            latest_version = latest.get("latest_version")
            if latest_version != self.requested_version:
                raise UpdateError("The available version changed. Check for updates again.")
            if compare_versions(latest_version, self.installed_version) <= 0:
                raise UpdateError("The requested release is not newer than this installation.")

            self.progress.emit(10, "Verifying release package details…")
            release_url = RELEASE_URL_TEMPLATE.format(version=latest_version)
            release = _read_json(release_url)
            if release.get("product") != PRODUCT or release.get("schema_version") != SCHEMA_VERSION:
                raise UpdateError("The release package metadata is not supported.")
            release_version = release.get("version")
            if release_version != latest_version:
                raise UpdateError("The release metadata version does not match latest.json.")
            status = release.get("release_status", release.get("status"))
            if status != "published":
                raise UpdateError("The release package has not been marked as published.")
            package_url, expected_size, expected_hash = _package_details(release)

            if not getattr(sys, "frozen", False):
                raise UpdateError("Updates can only be installed from a packaged Digi build.")
            if not (self.install_root / "Digi Search Engine.exe").is_file():
                raise UpdateError("The installed Digi executable could not be verified.")
            source_root = self.install_root / "Digi Source"
            for relative in REQUIRED_SOURCE_FILES:
                if not (source_root / relative).is_file():
                    raise UpdateError("The installed Digi Source directory is incomplete.")

            update_root = self.user_data_root / "Updater" / "Staging"
            update_root.mkdir(parents=True, exist_ok=True)
            stage_root = update_root / (latest_version + "-" + str(int(time.time() * 1000)))
            stage_root.mkdir(parents=False, exist_ok=False)
            package_path = stage_root / "package.zip"
            self.progress.emit(15, "Downloading the update…")
            digest = hashlib.sha256()
            received = 0
            request = urllib.request.Request(
                package_url,
                headers={"User-Agent": "Digi-User-Approved-Updater",
                         "Accept": "application/octet-stream"},
            )
            with urllib.request.urlopen(request, timeout=30) as response, package_path.open("xb") as target:
                if urlparse(response.geturl()).scheme != "https":
                    raise UpdateError("The package download redirected away from HTTPS.")
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    received += len(chunk)
                    if received > expected_size or received > MAX_PACKAGE_BYTES:
                        raise UpdateError("The package is larger than its published size.")
                    digest.update(chunk)
                    target.write(chunk)
                    self.progress.emit(min(70, 15 + int(55 * received / expected_size)),
                                       "Downloading the update…")
            if received != expected_size:
                raise UpdateError("The downloaded package size does not match release metadata.")
            if digest.hexdigest().lower() != expected_hash:
                raise UpdateError("The downloaded package checksum does not match release metadata.")

            self.progress.emit(75, "Checking package contents…")
            _stage_archive(package_path, stage_root / "payload")
            package_path.unlink()
            self.progress.emit(90, "Preparing the installer…")
            _launch_elevated_helper(stage_root, self.install_root, latest_version)
            self.progress.emit(100, "Update helper started. Digi will close and restart.")
            self._emit_result(True, "The update helper has started. Digi will now close and restart.", latest_version)
        except UpdateError as exc:
            if stage_root and stage_root.exists():
                shutil.rmtree(stage_root, ignore_errors=True)
            self._emit_result(False, str(exc))
        except Exception:
            if stage_root and stage_root.exists():
                shutil.rmtree(stage_root, ignore_errors=True)
            self._emit_result(False, "The update could not be prepared. Your installed application was not changed.")
