from __future__ import annotations

import gc
import tempfile
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

APP_TITLE = "Word to PDF (PNG pages)"
WORD_EXTENSIONS = {".doc", ".docx", ".docm", ".dot", ".dotx", ".dotm"}
BASE_DIR = Path(__file__).resolve().parent
REPOSITORY_DIR = BASE_DIR / "repository"
RENDER_DPI = 300


def find_documents() -> list[Path]:
    """Find supported Word documents anywhere inside repository/."""
    if not REPOSITORY_DIR.is_dir():
        return []
    return sorted(
        (
            path for path in REPOSITORY_DIR.rglob("*")
            if path.is_file() and path.suffix.lower() in WORD_EXTENSIONS
        ),
        key=lambda path: str(path).casefold(),
    )


def render_word_to_intermediate_pdf(source: Path, output_pdf: Path) -> None:
    """Use Microsoft Word's own layout engine to paginate and export the document.

    This PDF is temporary only. The final PDF is built from rendered PNG page
    images, so the delivered PDF pages are raster images rather than live text.
    """
    try:
        import pythoncom
        import win32com.client
    except ImportError as exc:
        raise RuntimeError(
            "Microsoft Word automation requires pywin32. Install dependencies with "
            "'py -m pip install -r requirements.txt'."
        ) from exc

    pythoncom.CoInitialize()
    word = None
    document = None
    try:
        word = win32com.client.DispatchEx("Word.Application")
        word.Visible = False
        word.DisplayAlerts = 0
        # Disable macros for documents opened by the converter.
        word.AutomationSecurity = 3
        document = word.Documents.Open(
            str(source.resolve()),
            ConfirmConversions=False,
            ReadOnly=True,
            AddToRecentFiles=False,
            Visible=False,
            OpenAndRepair=True,
            NoEncodingDialog=True,
        )
        # wdExportFormatPDF = 17. This is only an internal intermediate so
        # Word can calculate the exact pagination and layout.
        document.ExportAsFixedFormat(
            OutputFileName=str(output_pdf.resolve()),
            ExportFormat=17,
            OpenAfterExport=False,
            OptimizeFor=0,
            Range=0,
            Item=0,
            IncludeDocProps=False,
            KeepIRM=False,
            CreateBookmarks=0,
            DocStructureTags=False,
            BitmapMissingFonts=True,
            UseISO19005_1=False,
        )
    finally:
        if document is not None:
            try:
                document.Close(False)
            except Exception:
                pass
        if word is not None:
            try:
                word.Quit(False)
            except Exception:
                pass
        # Release COM proxies before the temporary directory is cleaned up.
        document = None
        word = None
        gc.collect()
        pythoncom.CoUninitialize()
        # Word can briefly retain a handle to its exported PDF after Quit().
        # The caller retries cleanup if Windows has not released the file yet.


def build_image_pdf(intermediate_pdf: Path, final_pdf: Path, temp_dir: Path) -> int:
    """Rasterize each Word-rendered page to a lossless PNG and embed it in a PDF."""
    try:
        import pymupdf
        from reportlab.lib.utils import ImageReader
        from reportlab.pdfgen import canvas
    except ImportError as exc:
        raise RuntimeError(
            "PNG rendering dependencies are missing. Install them with "
            "'py -m pip install -r requirements.txt'."
        ) from exc

    with pymupdf.open(intermediate_pdf) as document:
        page_count = document.page_count
        if page_count < 1:
            raise RuntimeError("Word produced a document with no pages.")

        first_rect = document.load_page(0).rect
        pdf_canvas = canvas.Canvas(
            str(final_pdf),
            pagesize=(first_rect.width, first_rect.height),
            pageCompression=1,
            invariant=1,
        )
        zoom = RENDER_DPI / 72.0

        for page_number in range(page_count):
            page = document.load_page(page_number)
            rect = page.rect
            pixmap = page.get_pixmap(
                matrix=pymupdf.Matrix(zoom, zoom),
                colorspace=pymupdf.csRGB,
                alpha=False,
                annots=True,
            )
            png_path = temp_dir / f"page_{page_number + 1:05d}.png"
            pixmap.save(str(png_path))

            pdf_canvas.setPageSize((rect.width, rect.height))
            pdf_canvas.drawImage(
                ImageReader(str(png_path)),
                0,
                0,
                width=rect.width,
                height=rect.height,
                preserveAspectRatio=False,
                mask=None,
            )
            pdf_canvas.showPage()
            png_path.unlink(missing_ok=True)

        pdf_canvas.save()
        return page_count

def remove_temp_directory_safely(path: Path, attempts: int = 8) -> None:
    """Remove temporary files with retries for transient Windows file locks."""
    import shutil
    import time

    last_error = None
    for attempt in range(attempts):
        try:
            shutil.rmtree(path)
            return
        except PermissionError as exc:
            last_error = exc
            gc.collect()
            time.sleep(0.25 * (attempt + 1))
    if last_error is not None:
        raise last_error


def convert_documents(log, progress) -> tuple[int, int, int]:
    documents = find_documents()
    converted = failed = skipped = 0
    total = len(documents)

    if not documents:
        log("No Word documents found in the repository folder.")
        return converted, failed, skipped

    log(f"Found {total} Word document(s). Rendering at {RENDER_DPI} DPI.")
    for index, source in enumerate(documents, start=1):
        destination = source.with_suffix(".pdf")
        progress(index - 1, total)

        if destination.exists():
            skipped += 1
            log(f"SKIPPED: {source.relative_to(REPOSITORY_DIR)} — PDF already exists; Word file kept.")
            continue

        staging = source.with_name(f".{source.stem}.digi-staging.pdf")
        try:
            temp_dir = Path(tempfile.mkdtemp(prefix="digi_word_png_"))
            try:
                intermediate = temp_dir / "word_layout_intermediate.pdf"

                render_word_to_intermediate_pdf(source, intermediate)
                if not intermediate.is_file() or intermediate.stat().st_size == 0:
                    raise RuntimeError("Microsoft Word did not create its intermediate layout file.")

                page_count = build_image_pdf(intermediate, staging, temp_dir)
                if not staging.is_file() or staging.stat().st_size == 0:
                    raise RuntimeError("The image-based PDF was not created.")

                # Confirm the final PDF opens and contains the expected page count.
                import pymupdf
                with pymupdf.open(staging) as check_pdf:
                    if check_pdf.page_count != page_count:
                        raise RuntimeError("Final PDF page-count verification failed.")
                    if any(page.get_images(full=True) == [] for page in check_pdf):
                        raise RuntimeError("At least one PDF page is missing its embedded page image.")

                # Install the completed PDF first, then remove the source document.
                staging.replace(destination)
                source.unlink()
                converted += 1
                log(
                    f"CONVERTED: {source.relative_to(REPOSITORY_DIR)} "
                    f"→ {destination.name} ({page_count} PNG page(s), {RENDER_DPI} DPI)"
                )
            finally:
                remove_temp_directory_safely(temp_dir)
        except Exception as exc:
            failed += 1
            log(f"FAILED: {source.relative_to(REPOSITORY_DIR)} — {exc}")
        finally:
            if staging.exists():
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
            text="Each Word page becomes a lossless PNG image embedded as a PDF page. "
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
        self.start_button = ttk.Button(actions, text="Convert to image-based PDF", command=self._start)
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
            text="Final PDFs contain one lossless PNG image per page at 300 DPI. Text will not be selectable or searchable. "
                 "Existing PDFs are skipped and their Word files are kept.",
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

        try:
            import win32com.client  # noqa: F401
            import pymupdf  # noqa: F401
            import reportlab  # noqa: F401
        except ImportError:
            messagebox.showerror(
                "Dependencies missing",
                "Install the Python dependencies first:\n\npy -m pip install -r requirements.txt",
            )
            return

        try:
            import win32com.client
            word = win32com.client.DispatchEx("Word.Application")
            word.Quit(False)
        except Exception as exc:
            messagebox.showerror(
                "Microsoft Word required",
                "This version uses Microsoft Word's own layout engine to render the pages. "
                "Install desktop Microsoft Word and ensure it is activated.\n\n"
                f"Details: {exc}",
            )
            return

        if not messagebox.askyesno(
            "Replace Word files?",
            f"{len(documents)} Word document(s) were found under repository.\n\n"
            "Every page will be rendered to a lossless PNG at 300 DPI and embedded in a PDF. "
            "After verification, the PDF will replace its Word source.\n"
            "Existing PDFs will not be overwritten. Text in the final PDF will be image-based.\n\nContinue?",
        ):
            return

        self.running = True
        self.start_button.configure(state="disabled")
        self.refresh_button.configure(state="disabled")
        self.progress.configure(value=0, maximum=max(1, len(documents)))
        self._log(f"Starting image-based conversion in {REPOSITORY_DIR}")

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
