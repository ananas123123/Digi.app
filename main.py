from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import threading
import tkinter as tk
import uuid
from pathlib import Path
from tkinter import messagebox, ttk

APP_TITLE = "Word to PDF"
WORD_EXTENSIONS = {".doc", ".docx", ".docm", ".dot", ".dotx", ".dotm"}
BASE_DIR = Path(__file__).resolve().parent
REPOSITORY_DIR = BASE_DIR / "repository"


def find_documents() -> list[Path]:
    if not REPOSITORY_DIR.is_dir():
        return []
    return sorted(
        (p for p in REPOSITORY_DIR.rglob("*") if p.is_file() and p.suffix.lower() in WORD_EXTENSIONS),
        key=lambda p: str(p).casefold(),
    )


def validate_pdf(path: Path) -> int:
    import pymupdf
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError("The converter did not produce a usable PDF.")
    with pymupdf.open(path) as pdf:
        if pdf.page_count < 1:
            raise RuntimeError("The converter produced a PDF with no pages.")
        return pdf.page_count


def convert_one(source: Path, staging: Path, log) -> int:
    """Prefer native Word export; retry with SaveAs2 and then LibreOffice."""
    errors = []
    try:
        import gc
        import pythoncom
        import win32com.client
        pythoncom.CoInitialize()
        word = None
        document = None
        try:
            log(f"Using Microsoft Word: {source.name}")
            word = win32com.client.DispatchEx("Word.Application")
            word.Visible = False
            word.DisplayAlerts = 0
            word.AutomationSecurity = 3
            document = word.Documents.Open(
                str(source.resolve()), ConfirmConversions=False, ReadOnly=True,
                AddToRecentFiles=False, Visible=False, OpenAndRepair=True,
                NoEncodingDialog=True,
            )
            try:
                document.ExportAsFixedFormat(
                    OutputFileName=str(staging.resolve()), ExportFormat=17,
                    OpenAfterExport=False, OptimizeFor=0, Range=0, Item=0,
                    IncludeDocProps=False, KeepIRM=False, CreateBookmarks=0,
                    DocStructureTags=False, BitmapMissingFonts=True, UseISO19005_1=False,
                )
            except Exception as export_error:
                log(f"ExportAsFixedFormat failed; retrying with Word SaveAs2: {source.name}")
                staging.unlink(missing_ok=True)
                document.SaveAs2(FileName=str(staging.resolve()), FileFormat=17, AddToRecentFiles=False)
            document.Close(False)
            document = None
            word.Quit(False)
            word = None
            gc.collect()
        finally:
            if document is not None:
                try: document.Close(False)
                except Exception: pass
            if word is not None:
                try: word.Quit(False)
                except Exception: pass
            document = None
            word = None
            gc.collect()
            pythoncom.CoUninitialize()
        return validate_pdf(staging)
    except Exception as exc:
        errors.append(f"Microsoft Word: {exc}")
        try: staging.unlink(missing_ok=True)
        except OSError: pass

    libre = shutil.which("soffice") or shutil.which("libreoffice")
    if libre:
        try:
            log(f"Word export failed; trying LibreOffice: {source.name}")
            with tempfile.TemporaryDirectory(prefix="digi-convert-") as temp_name:
                result = subprocess.run(
                    [libre, "--headless", "--convert-to", "pdf", "--outdir", temp_name, str(source)],
                    capture_output=True, text=True, timeout=180,
                )
                generated = Path(temp_name) / (source.stem + ".pdf")
                if result.returncode != 0 or not generated.is_file() or generated.stat().st_size == 0:
                    raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "LibreOffice produced no PDF.")
                shutil.copy2(generated, staging)
            return validate_pdf(staging)
        except Exception as exc:
            errors.append(f"LibreOffice: {exc}")
    raise RuntimeError("Conversion methods failed. " + " | ".join(errors))


def convert_documents(log, progress) -> tuple[int, int, int]:
    documents = find_documents()
    converted = failed = skipped = 0
    total = len(documents)
    if not documents:
        log("No Word documents found in repository.")
        return converted, failed, skipped
    log(f"Found {total} Word document(s). Using the main-branch conversion algorithm.")
    for index, source in enumerate(documents, start=1):
        destination = source.with_suffix(".pdf")
        progress(index - 1, total)
        if destination.exists():
            skipped += 1
            log(f"SKIPPED: {source.relative_to(REPOSITORY_DIR)} — PDF already exists; Word file kept.")
            progress(index, total)
            continue
        staging = REPOSITORY_DIR / f".digi-staging-{uuid.uuid4().hex}.pdf"
        try:
            log(f"[{index}/{total}] Converting: {source.relative_to(REPOSITORY_DIR)}")
            page_count = convert_one(source, staging, log)
            try:
                os.link(staging, destination)
            except FileExistsError:
                skipped += 1
                log(f"SKIPPED: {source.name} — destination PDF appeared; Word file kept.")
                continue
            except OSError as exc:
                raise RuntimeError("Could not safely install PDF without overwriting another file; source preserved.") from exc
            try:
                # Legacy .doc files may carry the Windows read-only attribute.
                original_mode = source.stat().st_mode
                was_readonly = not bool(original_mode & 0o200)
                if was_readonly:
                    os.chmod(source, original_mode | 0o200)
                try:
                    source.unlink()
                except OSError:
                    if was_readonly and source.exists():
                        os.chmod(source, original_mode)
                    raise
            except OSError as exc:
                try:
                    if (destination.stat().st_dev, destination.stat().st_ino) == (staging.stat().st_dev, staging.stat().st_ino):
                        destination.unlink()
                except OSError:
                    pass
                raise RuntimeError("PDF created, but the Word source could not be removed. Check locks and permissions.") from exc
            converted += 1
            log(f"CONVERTED: {source.relative_to(REPOSITORY_DIR)} -> {destination.name} ({page_count} page(s))")
        except Exception as exc:
            failed += 1
            log(f"FAILED: {source.relative_to(REPOSITORY_DIR)} — {exc}")
        finally:
            try:
                staging.unlink(missing_ok=True)
            except OSError:
                pass
            progress(index, total)
    return converted, failed, skipped


class ConverterApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title(APP_TITLE)
        self.root.geometry("760x560")
        self.root.minsize(620, 460)
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
            text="Convert Word documents directly to PDF using Microsoft Word, with LibreOffice as a fallback. "
                 "Documents are read from repository, including nested folders.",
            font=("Segoe UI", 10), bg="#f4f5f7", fg="#596273",
            wraplength=700, justify="left",
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
            bg="#ffffff", fg="#596273", wraplength=680, justify="left",
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
            text="Uses native PDF export first, with LibreOffice as a fallback. Existing PDFs are skipped; "
                 "Word files are removed only after validation.",
            font=("Segoe UI", 9), bg="#f4f5f7", fg="#6a7280",
            wraplength=700, justify="left",
        ).pack(anchor="w", pady=(10, 0))

    def _log(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _refresh_status(self) -> None:
        REPOSITORY_DIR.mkdir(parents=True, exist_ok=True)
        count = len(find_documents())
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

        if not messagebox.askyesno(
            "Replace Word files?",
            f"{len(documents)} Word document(s) were found under repository.\n\n"
            "The PDF will be validated before the Word source is removed. "
            "Existing PDFs will not be overwritten.\n\nContinue?",
        ):
            return

        self.running = True
        self.start_button.configure(state="disabled")
        self.refresh_button.configure(state="disabled")
        self.progress.configure(value=0, maximum=max(1, len(documents)))
        self._log(f"Starting Word-to-PDF conversion in {REPOSITORY_DIR}")

        def worker() -> None:
            result = convert_documents(
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
