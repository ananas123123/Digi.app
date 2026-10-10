"""Separate Windows helper for replacing Digi's installed executable.

The application must download and verify the candidate first, then launch this helper
and exit. The helper independently verifies the candidate, stages it beside the target,
backs up the old executable, replaces it, and waits for an explicit startup confirmation.
It never touches Digi's persistent user-data directory.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import ctypes
import hashlib
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time


APP_EXE_NAME = "Digi Search Engine.exe"
HELPER_EXE_NAME = "DigiUpdater.exe"
CONFIRM_ENV = "DIGI_UPDATE_CONFIRMATION_FILE"
TOKEN_ENV = "DIGI_UPDATE_CONFIRMATION_TOKEN"
WAIT_FOR_APP_SECONDS = 180
STARTUP_CONFIRM_SECONDS = 30
POLL_SECONDS = 0.25
CHUNK_SIZE = 1024 * 1024


def log_event(level: str, message: str) -> None:
    """Write helper diagnostics where the Digi console can display them."""
    try:
        root = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))).resolve() / "Digi" / "Logs"
        root.mkdir(parents=True, exist_ok=True)
        line = f"{datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds')} [{level}] {str(message).replace(chr(10), ' | ')}\n"
        with (root / "updater.log").open("a", encoding="utf-8") as stream:
            stream.write(line)
    except OSError:
        pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(CHUNK_SIZE)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def validate_pe_executable(path: Path) -> None:
    """Reject a non-Windows executable before it can replace the installed app."""
    with path.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise ValueError("The update candidate is not a Windows executable.")
        stream.seek(0x3C)
        raw_offset = stream.read(4)
        if len(raw_offset) != 4:
            raise ValueError("The update candidate has an invalid executable header.")
        pe_offset = int.from_bytes(raw_offset, "little")
        if pe_offset < 64 or pe_offset > 16 * 1024 * 1024:
            raise ValueError("The update candidate has an invalid executable header.")
        stream.seek(pe_offset)
        if stream.read(4) != b"PE\x00\x00":
            raise ValueError("The update candidate has an invalid PE signature.")


def expected_install_dir(local_app_data: Path) -> Path:
    return (local_app_data / "Digi").resolve()


def validate_paths(
    helper_path: Path,
    target_path: Path,
    candidate_path: Path,
    local_app_data: Path,
) -> tuple[Path, Path, Path]:
    """Reject targets outside the fixed installation directory."""
    install_dir = expected_install_dir(local_app_data)
    helper = helper_path.resolve()
    target = target_path.resolve()
    candidate = candidate_path.resolve()

    if helper != install_dir / HELPER_EXE_NAME:
        raise ValueError("Updater helper is not running from Digi's stable installation directory.")
    if target != install_dir / APP_EXE_NAME:
        raise ValueError("Update target is not Digi's expected executable path.")
    if not target.is_file():
        raise FileNotFoundError("The installed Digi executable was not found.")
    if not candidate.is_file():
        raise FileNotFoundError("The verified update candidate was not found.")
    if candidate == target or candidate == helper:
        raise ValueError("The update candidate cannot be an installed application file.")
    data_root = (local_app_data / "Digi").resolve()
    expected_parent = data_root / "update dependencies" / "package installer"
    if candidate.suffix.lower() != ".exe" or candidate.parent.parent != expected_parent:
        raise ValueError("The update candidate must be an .exe inside Digi's versioned package-installer folder.")
    if not candidate.parent.name or any(ch not in "0123456789." for ch in candidate.parent.name):
        raise ValueError("The update candidate version folder is invalid.")
    try:
        candidate.relative_to(expected_parent)
    except ValueError as exc:
        raise ValueError("The update candidate is outside Digi's package-installer folder.") from exc
    return install_dir, target, candidate


def wait_for_process_exit(pid: int, timeout: float = WAIT_FOR_APP_SECONDS) -> None:
    """Wait using Windows process handles; never use os.kill(pid, 0) on Windows."""
    if os.name != "nt":
        raise OSError("Digi's executable updater can only run on Windows.")
    if pid <= 0 or pid == os.getpid():
        raise ValueError("The Digi process ID is invalid.")

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    open_process = kernel32.OpenProcess
    open_process.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    open_process.restype = ctypes.c_void_p
    wait_for_single_object = kernel32.WaitForSingleObject
    wait_for_single_object.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    wait_for_single_object.restype = ctypes.c_uint32
    close_handle = kernel32.CloseHandle
    close_handle.argtypes = [ctypes.c_void_p]
    close_handle.restype = ctypes.c_int

    SYNCHRONIZE = 0x00100000
    WAIT_OBJECT_0 = 0x00000000
    WAIT_TIMEOUT = 0x00000102
    handle = open_process(SYNCHRONIZE, False, pid)
    if not handle:
        error = ctypes.get_last_error()
        # ERROR_INVALID_PARAMETER means the process no longer exists.
        if error == 87:
            return
        raise OSError(error, "Could not safely open Digi's process to wait for exit.")

    try:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            remaining_ms = max(1, min(1000, int((deadline - time.monotonic()) * 1000)))
            result = wait_for_single_object(handle, remaining_ms)
            if result == WAIT_OBJECT_0:
                return
            if result != WAIT_TIMEOUT:
                raise OSError(ctypes.get_last_error(), "Could not safely wait for Digi to exit.")
        raise TimeoutError("Digi did not close in time. The installed executable was not changed.")
    finally:
        close_handle(handle)


def wait_for_confirmation(marker: Path, token: str, timeout: float = STARTUP_CONFIRM_SECONDS) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if marker.is_file() and marker.read_text(encoding="utf-8").strip() == token:
                return True
        except OSError:
            pass
        time.sleep(POLL_SECONDS)
    return False




def refresh_digi_shortcuts(target: Path, install_dir: Path) -> bool:
    """Repair existing Digi shortcuts in standard Windows locations and create Desktop shortcut."""
    if os.name != "nt":
        return False

    # Only rewrite links that clearly target a Digi executable. Do not touch
    # unrelated shortcuts, and keep all shortcuts pointing at one stable target.
    script = r"""
$ErrorActionPreference = 'Stop'
$target = [IO.Path]::GetFullPath($env:DIGI_SHORTCUT_TARGET)
$work = [IO.Path]::GetFullPath($env:DIGI_SHORTCUT_WORKDIR)
$shell = New-Object -ComObject WScript.Shell
$folders = @(
  [Environment]::GetFolderPath('Desktop'),
  [Environment]::GetFolderPath('CommonDesktopDirectory'),
  [Environment]::GetFolderPath('Programs'),
  [Environment]::GetFolderPath('CommonPrograms'),
  (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch'),
  (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$seen = @{}
foreach ($folder in $folders) {
  Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
      if ($seen.ContainsKey($_.FullName)) { return }
      $seen[$_.FullName] = $true
      try {
        $link = $shell.CreateShortcut($_.FullName)
        $linkTarget = [string]$link.TargetPath
        $leaf = [IO.Path]::GetFileName($linkTarget)
        if ($leaf -ieq 'Digi Search Engine.exe' -or $leaf -ieq 'Digi.exe' -or $leaf -ieq 'Digi Search Engine') {
          if ([IO.Path]::GetFullPath($linkTarget) -ine $target) {
            $link.TargetPath = $target
            $link.WorkingDirectory = $work
            $link.IconLocation = $target + ',0'
            $link.Description = 'Launch Digi Search Engine'
            $link.Save()
          }
        }
      } catch {
        Write-Output ('WARNING: Could not update shortcut ' + $_.FullName + ': ' + $_.Exception.Message)
      }
    }
}
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop) { throw 'Windows did not provide the Desktop folder.' }
$desktopLink = Join-Path $desktop 'Digi.lnk'
$link = $shell.CreateShortcut($desktopLink)
$link.TargetPath = $target
$link.WorkingDirectory = $work
$link.IconLocation = $target + ',0'
$link.Description = 'Launch Digi Search Engine'
$link.Save()
"""
    environment = os.environ.copy()
    environment["DIGI_SHORTCUT_TARGET"] = str(target.resolve())
    environment["DIGI_SHORTCUT_WORKDIR"] = str(install_dir.resolve())
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
            env=environment, capture_output=True, text=True, timeout=60, check=False,
        )
        for line in (result.stdout or "").splitlines():
            log_event("SHORTCUT", line)
        if result.returncode:
            log_event("WARNING", "Shortcut refresh failed: " + (result.stderr or result.stdout or f"exit {result.returncode}"))
            return False
        log_event("SUCCESS", "Digi shortcuts refreshed to the stable executable path.")
        return True
    except (OSError, subprocess.SubprocessError) as exc:
        log_event("WARNING", f"Shortcut refresh could not run: {type(exc).__name__}: {exc}")
        return False

def install_update(
    *,
    helper_path: Path,
    target_path: Path,
    candidate_path: Path,
    local_app_data: Path,
    parent_pid: int,
    expected_sha256: str,
    version: str,
    startup_timeout: float = STARTUP_CONFIRM_SECONDS,
) -> None:
    if len(expected_sha256) != 64 or any(ch not in "0123456789abcdefABCDEF" for ch in expected_sha256):
        raise ValueError("Expected SHA-256 is invalid.")
    if not version or any(ch not in "0123456789." for ch in version):
        raise ValueError("Update version is invalid.")

    log_event("INFO", f"Helper started for version {version}; helper={helper_path}; target={target_path}; candidate={candidate_path}; parent_pid={parent_pid}")
    install_dir, target, candidate = validate_paths(
        helper_path, target_path, candidate_path, local_app_data
    )
    log_event("INFO", f"Path validation passed; install_dir={install_dir}")
    if candidate.parent.name != version:
        raise ValueError("The update candidate folder does not match the requested version.")
    expected = expected_sha256.lower()
    if sha256_file(candidate) != expected:
        raise ValueError("The update candidate failed SHA-256 verification.")
    validate_pe_executable(candidate)

    wait_for_process_exit(parent_pid)

    stage = install_dir / f".Digi-update-{os.getpid()}.staging.exe"
    backup = install_dir / f".Digi-rollback-{version}-{os.getpid()}.exe"
    marker = install_dir / f".Digi-startup-{secrets.token_hex(16)}.confirm"
    token = secrets.token_urlsafe(32)

    replaced = False
    confirmed = False
    try:
        # Stage on the same volume as the target so the final rename is not cross-volume.
        with candidate.open("rb") as source, stage.open("xb") as destination:
            shutil.copyfileobj(source, destination, length=CHUNK_SIZE)
        if sha256_file(stage) != expected:
            raise ValueError("The staged update failed SHA-256 verification.")
        validate_pe_executable(stage)

        # Never overwrite an existing recovery file.
        if backup.exists():
            raise FileExistsError(f"Recovery file already exists: {backup.name}")
        log_event("INFO", f"Staged and verified candidate; creating rollback copy {backup}")
        os.replace(target, backup)
        try:
            os.replace(stage, target)
            replaced = True
        except Exception:
            os.replace(backup, target)
            raise

        environment = os.environ.copy()
        environment[CONFIRM_ENV] = str(marker)
        environment[TOKEN_ENV] = token
        log_event("INFO", "Replacement completed; launching updated Digi for startup confirmation")
        process = subprocess.Popen([str(target)], cwd=str(install_dir), env=environment)

        if not wait_for_confirmation(marker, token, timeout=startup_timeout):
            try:
                process.terminate()
                process.wait(timeout=5)
            except Exception:
                pass
            raise RuntimeError(
                "The updated Digi did not confirm startup. The previous executable will be restored."
            )
        confirmed = True
        log_event("SUCCESS", f"Version {version} confirmed startup successfully")

        # Record the new installed version only after the replacement executable
        # has launched and confirmed startup. This is version metadata, not user data.
        version_file = local_app_data / "Digi" / "Version manager" / "version.txt"
        version_marker = local_app_data / "Digi" / "Version manager" / ".version_initialized"
        try:
            if version_marker.is_file() and version_marker.read_text(encoding="utf-8").strip() == "initialized":
                temporary_version = version_file.with_name(version_file.name + ".update-tmp")
                temporary_version.write_text(version + "\n", encoding="utf-8")
                os.replace(temporary_version, version_file)
        except OSError:
            # Do not undo a confirmed executable update because optional version
            # bookkeeping could not be written. The app still uses the same user data.
            pass

        # Startup was confirmed. Repair known Digi shortcuts before removing
        # recovery/download copies; shortcut repair is best-effort and cannot undo
        # an otherwise successful executable update.
        refresh_digi_shortcuts(target, install_dir)

        # Remove redundant package and rollback copies only after successful startup.
        # If cleanup fails, keep the file and record its exact location for recovery.
        for redundant in (backup, candidate):
            try:
                redundant.unlink(missing_ok=True)
                log_event("CLEANUP", f"Removed confirmed-update artifact: {redundant}")
            except OSError as cleanup_error:
                log_event("WARNING", f"Could not remove confirmed-update artifact {redundant}: {cleanup_error}")
    except Exception as exc:
        log_event("ERROR", f"Helper update failed: {type(exc).__name__}: {exc}")
        if replaced and not confirmed and backup.exists():
            try:
                if target.exists():
                    failed_dir = install_dir / "Logs" / "failed-updates"
                    failed_dir.mkdir(parents=True, exist_ok=True)
                    failed = failed_dir / f"Digi-failed-{version}-{os.getpid()}.exe"
                    os.replace(target, failed)
                    log_event("ROLLBACK", f"Retained failed candidate for diagnosis at {failed}")
                os.replace(backup, target)
                log_event("ROLLBACK", f"Restored previous executable from {backup}")
            except OSError as rollback_error:
                raise RuntimeError(
                    f"Update failed and automatic rollback could not complete. "
                    f"Recovery copy retained at {backup}: {rollback_error}"
                )
        if not replaced and stage.exists():
            try:
                stage.unlink()
            except OSError:
                pass
        raise
    finally:
        try:
            marker.unlink(missing_ok=True)
        except OSError:
            pass
        try:
            stage.unlink(missing_ok=True)
        except OSError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Safely replace Digi's installed executable.")
    parser.add_argument("--refresh-shortcuts", action="store_true",
                        help="Repair existing Digi shortcuts without performing an update.")
    parser.add_argument("--parent-pid", type=int)
    parser.add_argument("--target-exe")
    parser.add_argument("--candidate-exe")
    parser.add_argument("--sha256")
    parser.add_argument("--version")
    args = parser.parse_args()

    local_app_data_value = os.environ.get("LOCALAPPDATA")
    if not local_app_data_value:
        log_event("ERROR", "LOCALAPPDATA is unavailable; Digi was not updated.")
        print("FATAL: LOCALAPPDATA is unavailable; Digi was not updated.", file=sys.stderr)
        return 2

    helper_path = Path(sys.executable).resolve()
    install_dir = expected_install_dir(Path(local_app_data_value))
    if args.refresh_shortcuts:
        target = install_dir / APP_EXE_NAME
        if not target.is_file():
            log_event("ERROR", f"Cannot refresh shortcuts because the installed app is missing: {target}")
            return 1
        return 0 if refresh_digi_shortcuts(target, install_dir) else 1

    missing = [
        name for name, value in (
            ("--parent-pid", args.parent_pid),
            ("--target-exe", args.target_exe),
            ("--candidate-exe", args.candidate_exe),
            ("--sha256", args.sha256),
            ("--version", args.version),
        ) if value is None
    ]
    if missing:
        parser.error("required unless --refresh-shortcuts is used: " + ", ".join(missing))

    try:
        install_update(
            helper_path=helper_path,
            target_path=Path(args.target_exe),
            candidate_path=Path(args.candidate_exe),
            local_app_data=Path(local_app_data_value),
            parent_pid=args.parent_pid,
            expected_sha256=args.sha256,
            version=args.version,
        )
        print("Update completed and startup was confirmed.")
        return 0
    except Exception as exc:
        log_event("ERROR", f"Update failed: {type(exc).__name__}: {exc}")
        print(f"Update failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
