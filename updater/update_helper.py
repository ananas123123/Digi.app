"""Separate Windows helper for replacing Digi's installed executable.

The application must download and verify the candidate first, then launch this helper
and exit. The helper independently verifies the candidate, stages it beside the target,
backs up the old executable, replaces it, and waits for an explicit startup confirmation.
It never touches Digi's persistent user-data directory.
"""
from __future__ import annotations

import argparse
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
        if stream.read(4) != b"PE\\x00\\x00":
            raise ValueError("The update candidate has an invalid PE signature.")


def expected_install_dir(local_app_data: Path) -> Path:
    return (local_app_data / "Programs" / "Digi").resolve()


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

    install_dir, target, candidate = validate_paths(
        helper_path, target_path, candidate_path, local_app_data
    )
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

        # Keep the rollback copy after success for now. A later cleanup policy may
        # remove it only after the startup confirmation has been observed and recorded.
    except Exception:
        if replaced and not confirmed and backup.exists():
            try:
                if target.exists():
                    failed = install_dir / f".Digi-failed-{version}-{os.getpid()}.exe"
                    os.replace(target, failed)
                os.replace(backup, target)
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
    parser.add_argument("--parent-pid", type=int, required=True)
    parser.add_argument("--target-exe", required=True)
    parser.add_argument("--candidate-exe", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    local_app_data_value = os.environ.get("LOCALAPPDATA")
    if not local_app_data_value:
        print("FATAL: LOCALAPPDATA is unavailable; Digi was not updated.", file=sys.stderr)
        return 2

    helper_path = Path(sys.executable).resolve()
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
        print(f"Update failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
