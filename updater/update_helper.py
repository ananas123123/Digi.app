"""Separate Windows helper for replacing Digi's installed executable.

The application must download and verify the candidate first, then launch this helper
and exit. The helper independently verifies the candidate, stages it beside the target,
backs up the old executable, replaces it, and waits for an explicit startup confirmation.
It never touches Digi's persistent user-data directory.
"""
from __future__ import annotations

import argparse
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
    if candidate.suffix.lower() != ".exe":
        raise ValueError("The update candidate must be an executable.")
    return install_dir, target, candidate


def wait_for_process_exit(pid: int, timeout: float = WAIT_FOR_APP_SECONDS) -> None:
    if pid <= 0 or pid == os.getpid():
        raise ValueError("The Digi process ID is invalid.")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        except PermissionError:
            # The process exists but is inaccessible; do not replace its executable.
            time.sleep(POLL_SECONDS)
        else:
            time.sleep(POLL_SECONDS)
    raise TimeoutError("Digi did not close in time. The installed executable was not changed.")


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

    wait_for_process_exit(parent_pid)

    stage = install_dir / f".Digi-update-{os.getpid()}.staging.exe"
    backup = install_dir / f".Digi-rollback-{version}-{os.getpid()}.exe"
    marker = install_dir / f".Digi-startup-{secrets.token_hex(16)}.confirm"
    token = secrets.token_urlsafe(32)

    replaced = False
    try:
        # Stage on the same volume as the target so the final rename is not cross-volume.
        shutil.copyfile(candidate, stage)
        if sha256_file(stage) != expected:
            raise ValueError("The staged update failed SHA-256 verification.")

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
            if target.exists():
                failed = install_dir / f".Digi-failed-{version}-{os.getpid()}.exe"
                os.replace(target, failed)
            os.replace(backup, target)
            raise RuntimeError(
                "The updated Digi did not confirm startup. The previous executable was restored."
            )

        # Keep the rollback copy for now. A later cleanup policy may remove it only
        # after successful confirmation has been observed and recorded.
    except Exception:
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
