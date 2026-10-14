from __future__ import annotations

import shutil
import subprocess
import tempfile
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

APP_TITLE = "Word to PDF"
WORD_EXTENSIONS = {".doc", ".docx", ".docm", ".dot", ".dotx", ".dotm"}
BASE_DIR = Path(__file__).resolve().parent
REPOSITORY_DIR = BASE_DIR / "repository"


def find_libreoffice() -> str | None:
    executable = shutil.which("soffice") or shutil.which("libreoffice")
    if executable:
        return executable

    candidates = (
        Path(r"C:\Program Files\LibreOffice\program\soffice.exe"),
        Path(r"C:\Program Files (x86)\LibreOffice\program\soffice.exe"),
    )
    return next((str(path) for path in candidates if path.is_file()), None)


def find_documents() -> list[Path]:
    """Find supported Word files anywhere inside repository/."""
    if not REPOSITORY_DIR.is_dir():
        return []
    return sorted(
        (
            path for path in REPOSITORY_DIR.rglob("*")
            if path.is_file() and path.suffix.lower() in WORD_EXTENSIONS
        ),
        key=lambda path: str(path).casefold(),
    )


def convert_documents(executable: str, log, progress) -> tuple[int, int, int]:
    documents = find_documents()
    converted = failed = skipped = 0
    total = len(documents)

    if total == 0:
        log("No Word documents found in the repository folder.")
        return converted, failed, skipped

    log(f"Found {total} Word document(s).")
    for index, source in enumerate(documents, start=1):
        destination = source.with_suffix(".pdf")
        progress(index - 1, total)

        # Never replace an existing PDF or delete its source document.
        if destination.exists():
            skipped += 1
            log(f"SKIPPED: {source.relative_to(REPOSITORY_DIR)} — PDF already exists; Word file kept.")
            continue

        staging: Path | None = None
        try:
            with tempfile.TemporaryDirectory(prefix="digi_pdf_") as temp:
                profile = (Path(temp) / "profile").resolve().as_uri()
                output = Path(temp) / "output"
                output.mkdir()
                result = subprocess.run(
                    [
                        executable,
                        f"-env:UserInstallation={profile}",
                        "--headless",
                        "--convert-to", "pdf",
                        "--outdir", str(output),
                        str(source),
                    ],
                    capture_output=True,
                    text=True,
                    timeout=180,
                    check=False,
                )
                generated = output / f"{source.stem}.pdf"
                if result.returncode != 0 or not generated.is_file() or generated.stat().st_size == 0:
                    details = (result.stderr or result.stdout or "No PDF was generated").strip()
                    raise RuntimeError(details)

                staging = source.with_name(f".{source.stem}.digi-staging.pdf")
                shutil.copy2(generated, staging)
                staging.replace(destination)
                # Remove the source only after the finished PDF is in place.
                source.unlink()
                converted += 1
                log(f"CONVERTED: {source.relative_to(REPOSITORY_DIR)}")
        except Exception as exc:
            failed += 1
            log(f"FAILED: {source.relative_to(REPOSITORY_DIR)} — {exc}")
        finally:
            if staging is not None and staging.exists():
                try:
                    staging.unlink()
                except OSError:
                    pass
        progress(index, total)

    return converted, failed, skipped


class ConverterApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title(APP_TITLE)
        self.root.geometry("740x540")
        self.root.minsize(600, 440)
        self.root.configure(bg="#f4f5f7")
        self.running = False

        self._build()
        self._refresh_status()

    def _build(self) -> None:
        style = ttk.Style(self.root)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TProgressbar", thickness=8)
        style.configure("TButton", padding=(12, 8))

        outer = tk.Frame(self.root, bg="#f4f5f7", padx=24, pady=22)
        outer.pack(fill="both", expand=True)

        tk.Label(
            outer, text="Word to PDF", font=("Segoe UI", 22, "bold"),
            bg="#f4f5f7", fg="#20242b",
        ).pack(anchor="w")
        tk.Label(
            outer,
            text="Put your documents inside the repository folder. The converter handles nested folders automatically.",
            font=("Segoe UI", 10), bg="#f4f5f7", fg="#596273",
            wraplength=680, justify="left",
        ).pack(anchor="w", pady=(5, 16))

        panel = tk.Frame(
            outer, bg="#ffffff", highlightbackground="#c7ccd4", highlightthickness=1,
            padx=18, pady=16,
        )
        panel.pack(fill="x")

        tk.Label(
            panel, text="INPUT FOLDER", font=("Segoe UI", 9, "bold"),
            bg="#ffffff", fg="#596273",
        ).pack(anchor="w")
        tk.Label(
            panel, text="repository", font=("Segoe UI", 17, "bold"),
            bg="#ffffff", fg="#20242b",
        ).pack(anchor="w", pady=(4, 2))
        self.path_label = tk.Label(
            panel, text=str(REPOSITORY_DIR), font=("Segoe UI", 9),
            bg="#ffffff", fg="#596273", wraplength=660, justify="left",
        )
        self.path_label.pack(anchor="w")
        self.status_label = tk.Label(
            panel, text="", font=("Segoe UI", 10),
            bg="#ffffff", fg="#303743",
        )
        self.status_label.pack(anchor="w", pady=(10, 0))

        actions = tk.Frame(outer, bg="#f4f5f7")
        actions.pack(fill="x", pady=(12, 12))
        self.refresh_button = ttk.Button(actions, text="Refresh folder", command=self._refresh_status)
        self.refresh_button.pack(side="left")
        self.start_button = ttk.Button(actions, text="Convert to PDF", command=self._start)
        self.start_button.pack(side="right")

        self.progress = ttk.Progressbar(outer, mode="determinate", maximum=100)
        self.progress.pack(fill="x", pady=(0, 12))

        tk.Label(
            outer, text="Activity", font=("Segoe UI", 10, "bold"),
            bg="#f4f5f7", fg="#20242b",
        ).pack(anchor="w", pady=(0, 6))
        log_frame = tk.Frame(outer, bg="#ffffff", highlightbackground="#d9dde3", highlightthickness=1)
        log_frame.pack(fill="both", expand=True)
        self.log = tk.Text(
            log_frame, height=8, wrap="word", state="disabled",
            font=("Consolas", 9), bg="#ffffff", fg="#303743",
            relief="flat", padx=10, pady=8,
        )
        scrollbar = ttk.Scrollbar(log_frame, orient="vertical", command=self.log.yview)
        self.log.configure(yscrollcommand=scrollbar.set)
        self.log.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        tk.Label(
            outer,
            text="PDFs replace their Word files in the same locations. Existing PDFs are skipped, and their Word files are kept.",
            font=("Segoe UI", 9), bg="#f4f5f7", fg="#6a7280",
            wraplength=680, justify="left",
        ).pack(anchor="w", pady=(10, 0))

    def _log(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _refresh_status(self) -> None:
        REPOSITORY_DIR.mkdir(parents=True, exist_ok=True)
        documents = find_documents()
        count = len(documents)
        self.status_label.configure(
            text=f"{count} Word document(s) found" if count else "No Word documents found yet."
        )
        if not self.running:
            self.start_button.configure(state="normal" if count else "disabled")

    def _start(self) -> None:
        if self.running:
            return
        documents = find_documents()
        if not documents:
            self._refresh_status()
            messagebox.showinfo(
                "Nothing to convert",
                f"Put Word documents in this folder, then click Refresh folder:\n\n{REPOSITORY_DIR}",
            )
            return

        executable = find_libreoffice()
        if not executable:
            messagebox.showerror(
                "LibreOffice required",
                "LibreOffice was not found. Install it, then reopen this app. "
                "LibreOffice performs the Word-to-PDF conversion.",
            )
            return

        if not messagebox.askyesno(
            "Replace Word files?",
            f"{len(documents)} Word document(s) were found under repository.\n\n"
            "Each successful PDF will be saved beside its Word file, then the Word file will be removed.\n"
            "Existing PDFs will not be overwritten.\n\nContinue?",
        ):
            return

        self.running = True
        self.start_button.configure(state="disabled")
        self.refresh_button.configure(state="disabled")
        self.progress.configure(value=0, maximum=max(1, len(documents)))
        self._log(f"Starting conversion in {REPOSITORY_DIR}")

        def worker() -> None:
            result = convert_documents(
                executable,
                lambda message: self.root.after(0, self._log, message),
                lambda current, total: self.root.after(
                    0, lambda: self.progress.configure(value=current, maximum=max(1, total))
                ),
            )
            self.root.after(0, self._finish, result)

        threading.Thread(target=worker, daemon=True).start()

    def _finish(self, result: tuple[int, int, int]) -> None:
        converted, failed, skipped = result
        self.running = False
        self.refresh_button.configure(state="normal")
        self.progress.configure(value=self.progress["maximum"])
        self._log(f"Finished — converted: {converted}, failed: {failed}, skipped: {skipped}.")
        self._refresh_status()
        messagebox.showinfo(
            "Conversion finished",
            f"Converted: {converted}\nFailed: {failed}\nSkipped: {skipped}\n\nSee Activity for details.",
        )

    def run(self) -> None:
        self.root.mainloop()


if __name__ == "__main__":
    ConverterApp().run()
