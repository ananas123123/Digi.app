"""Persistent diagnostics for Digi's release updater."""
from datetime import datetime, timezone
import os
from pathlib import Path
import threading

_LOG_LOCK = threading.Lock()


def log_path() -> Path:
    local_app_data = Path(
        os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
    ).resolve()
    return local_app_data / "Digi" / "Logs" / "updater.log"


def log_updater_event(level: str, message: str) -> None:
    """Append a timestamped, best-effort diagnostic line without affecting app work."""
    try:
        target = log_path()
        target.parent.mkdir(parents=True, exist_ok=True)
        safe_message = str(message).replace("\\r", " ").replace("\\n", " | ")
        line = f"{datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds')} [{level.upper()}] {safe_message}\\n"
        with _LOG_LOCK:
            with target.open("a", encoding="utf-8") as stream:
                stream.write(line)
    except OSError:
        # Diagnostics must never crash or block the updater.
        pass


def read_updater_log(max_bytes: int = 262144) -> str:
    """Return the most recent log text, including a useful location if absent."""
    target = log_path()
    try:
        with target.open("rb") as stream:
            stream.seek(0, os.SEEK_END)
            size = stream.tell()
            stream.seek(max(0, size - max_bytes), os.SEEK_SET)
            raw = stream.read(max_bytes)
        text = raw.decode("utf-8", errors="replace")
        if size > max_bytes:
            text = "[Earlier log content omitted; showing the latest 256 KiB.]\\n" + text
        return text or "[LOG] The updater log exists but is empty."
    except FileNotFoundError:
        return (
            "[INFO] No updater errors have been recorded yet.\\n"
            f"[INFO] Log location: {target}\\n"
            "[INFO] Click Retry update to capture the next diagnostic."
        )
    except OSError as exc:
        return f"[ERROR] Could not read updater log: {type(exc).__name__}: {exc}\\n[INFO] Expected location: {target}"
