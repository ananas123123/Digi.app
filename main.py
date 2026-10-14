from __future__ import annotations

import queue
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from tkinterdnd2 import DND_FILES, TkinterDnD

APP_TITLE = "Word to PDF"
WORD_EXTENSIONS = {".doc", ".docx", ".docm", ".dot", ".dotx", ".dotm"}


def find_libreoffice() -> str | None:
    """Return the LibreOffice executable if it is installed."""
    found = shutil.which("soffice") or shutil.which("libreoffice")
    if found:
        return found

    # Common Windows installation locations.
    candidates = [
        Path(r"C:\Program Files\LibreOffice\program\soffice.exe"),
        Path(r"C:\Program Files (x86)\LibreOffice\program\soffice.exe"),
    ]
    return next((str(path) for path in candidates if path.is_file()), None)


def convert_folder(folder: Path, libreoffice: str, report) -> tuple[int, int, int]:
    """Convert Word documents recursively, replacing each source only after success.

    PDFs are written beside their source documents. Existing PDFs are never
    overwritten; in that case the source document is kept and reported as skipped.
    """
    documents = sorted(
        (path for path in folder.rglob("*")
         if path.is_file() and path.suffix.lower() in WORD_EXTENSIONS),
        key=lambda path: str(path).casefold(),
    )
    total = len(documents)
    converted = failed = skipped = 0

    if not documents:
        report("info", f"No Word documents found in {folder}")
        return converted, failed, skipped

    report("info", f"Found {total} Word document(s). Folder structure will be preserved.")

    for index, source in enumerate(documents, start=1):
        destination = source.with_suffix(".pdf")
        report("progress", (index - 1, total, source.name))

        if destination.exists():
            skipped += 1
            report("warning", f"Skipped: {source} — {destination.name} already exists; original kept.")
            continue

        try:
            # A unique temporary output directory prevents LibreOffice from
            # writing beside the source or colliding with existing files.
            with tempfile.TemporaryDirectory(prefix="digi_pdf_") as temp_dir:
                profile_dir = Path(temp_dir) / "lo-profile"
                output_dir = Path(temp_dir) / "output"
                output_dir.mkdir()
                command = [
                    libreoffice,
                    f"-env:UserInstallation={profile_dir.resolve().as_uri()}",
                    "--headless",
                    "--convert-to", "pdf",
                    "--outdir", str(output_dir),
                    str(source),
                ]
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    timeout=180,
                    check=False,
                )
                generated = output_dir / f"{source.stem}.pdf"

                if result.returncode != 0 or not generated.is_file() or generated.stat().st_size == 0:
                    detail = (result.stderr or result.stdout or "LibreOffice did not create a PDF").strip()
                    raise RuntimeError(detail)

                # The PDF is first copied to a temporary file beside the source.
                # Only after it is complete do we replace the original document.
                staging = source.with_name(f".{source.stem}.digi-converting.pdf")
                try:
                    shutil.copy2(generated, staging)
                    staging.replace(destination)
                    source.unlink()
                finally:
                    if staging.exists():
                        staging.unlink()

            converted += 1
            report("success", f"Converted: {source} → {destination.name}")
        except Exception as exc:
            failed += 1
            report("error", f"Failed: {source} — {exc}")

        report("progress", (index, total, source.name))

    return converted, failed, skipped


class ConverterApp:
    def __init__(self) -> None:
        self.root = TkinterDnD.Tk()
        self.root.title(APP_TITLE)
        self.root.geometry("760x560")
        self.root.minsize(620, 460)
        self.root.configure(bg="#f4f5f7")

        self.events: queue.Queue = queue.Queue()
        self.selected_folder: Path | None = None
        self.busy = False

        self._build_ui()
        self.root.after(100, self._poll_events)

    def _build_ui(self) -> None:
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
            text="Convert a folder of Word documents while keeping every file in its original folder.",
            font=("Segoe UI", 10), bg="#f4f5f7", fg="#596273",
            wraplength=700, justify="left",
        ).pack(anchor="w", pady=(5, 18))

        self.drop_area = tk.Frame(
            outer, bg="#ffffff", highlightbackground="#c7ccd4",
            highlightthickness=2, height=150,
        )
        self.drop_area.pack(fill="x")
        self.drop_area.pack_propagate(False)
        self.drop_area.drop_target_register(DND_FILES)
        self.drop_area.dnd_bind("<<Drop>>", self._on_drop)

        self.drop_label = tk.Label(
            self.drop_area,
            text="Drop a folder here\n\n—or choose a folder below",
            font=("Segoe UI", 14), bg="#ffffff", fg="#394150",
            justify="center",
        )
        self.drop_label.pack(fill="both", expand=True, padx=12, pady=12)
        self.drop_label.drop_target_register(DND_FILES)
        self.drop_label.dnd_bind("<<Drop>>", self._on_drop)

        folder_row = tk.Frame(outer, bg="#f4f5f7")
        folder_row.pack(fill="x", pady=(12, 8))
        self.folder_label = tk.Label(
            folder_row, text="No folder selected", font=("Segoe UI", 9),
            bg="#f4f5f7", fg="#596273", anchor="w",
        )
        self.folder_label.pack(side="left", fill="x", expand=True)
        self.browse_button = ttk.Button(folder_row, text="Choose folder…", command=self._browse)
        self.browse_button.pack(side="right", padx=(8, 0))
        self.start_button = ttk.Button(
            folder_row, text="Convert to PDF", command=self._start, state="disabled"
        )
        self.start_button.pack(side="right")

        self.progress = ttk.Progressbar(outer, mode="determinate", maximum=100)
        self.progress.pack(fill="x", pady=(5, 10))

        tk.Label(
            outer, text="Activity", font=("Segoe UI", 10, "bold"),
            bg="#f4f5f7", fg="#20242b",
        ).pack(anchor="w", pady=(2, 6))

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
            text="Successful conversions replace the original Word files. Existing PDFs are never overwritten.",
            font=("Segoe UI", 9), bg="#f4f5f7", fg="#6a7280",
            wraplength=700, justify="left",
        ).pack(anchor="w", pady=(10, 0))

    def _write_log(self, message: str, tag: str = "info") -> None:
        self.log.configure(state="normal")
        self.log.insert("end", message + "\n", tag)
        self.log.tag_configure("success", foreground="#18794e")
        self.log.tag_configure("warning", foreground="#986500")
        self.log.tag_configure("error", foreground="#b42318")
        self.log.tag_configure("info", foreground="#394150")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _set_folder(self, path_text: str) -> None:
        path = Path(path_text.strip().strip("{}")).expanduser()
        if not path.exists() or not path.is_dir():
            messagebox.showerror("Invalid folder", "Please drop or choose an existing folder.")
            return
        self.selected_folder = path
        self.folder_label.configure(text=str(path))
        self.start_button.configure(state="normal" if not self.busy else "disabled")

    def _on_drop(self, event) -> None:
        try:
            paths = self.root.tk.splitlist(event.data)
            if paths:
                self._set_folder(paths[0])
        except (tk.TclError, OSError) as exc:
            messagebox.showerror("Could not read drop", str(exc))

    def _browse(self) -> None:
        chosen = filedialog.askdirectory(title="Choose a folder containing Word documents")
        if chosen:
            self._set_folder(chosen)

    def _start(self) -> None:
        if self.busy or not self.selected_folder:
            return

        executable = find_libreoffice()
        if not executable:
            messagebox.showerror(
                "LibreOffice required",
                "LibreOffice was not found. Install LibreOffice, then reopen this app. "
                "It is used to convert Word files to PDF.",
            )
            return

        folder = self.selected_folder
        if not messagebox.askyesno(
            "Replace Word files?",
            f"All supported Word documents inside this folder and its subfolders will be converted.\n\n"
            f"Each successful PDF will be saved beside its source, then the original Word file will be removed.\n\n"
            f"Folder: {folder}\n\nContinue?",
        ):
            return

        self.busy = True
        self.start_button.configure(state="disabled")
        self.browse_button.configure(state="disabled")
        self.progress.configure(value=0, maximum=100)
        self._write_log(f"Starting conversion: {folder}")

        def report(kind, payload):
            self.events.put((kind, payload))

        def worker():
            result = convert_folder(folder, executable, report)
            self.events.put(("finished", result))

        threading.Thread(target=worker, daemon=True).start()

    def _poll_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "progress":
                    current, total, filename = payload
                    self.progress.configure(maximum=total, value=current)
                elif kind in {"info", "success", "warning", "error"}:
                    self._write_log(payload, kind)
                elif kind == "finished":
                    converted, failed, skipped = payload
                    self.busy = False
                    self.browse_button.configure(state="normal")
                    self.start_button.configure(state="normal" if self.selected_folder else "disabled")
                    self.progress.configure(value=self.progress["maximum"])
                    self._write_log(
                        f"Finished — converted: {converted}, failed: {failed}, skipped: {skipped}."
                    )
                    messagebox.showinfo(
                        "Conversion finished",
                        f"Converted: {converted}\nFailed: {failed}\nSkipped: {skipped}\n\n"
                        "See Activity for details.",
                    )
        except queue.Empty:
            pass
        self.root.after(100, self._poll_events)

    def run(self) -> None:
        self.root.mainloop()


if __name__ == "__main__":
    ConverterApp().run()
