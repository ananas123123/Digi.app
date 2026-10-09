from pathlib import Path
import os, subprocess, shutil

class FileService:
    @staticmethod
    def open_file(path):
        p = Path(path).resolve()
        if not p.is_file():
            raise FileNotFoundError("The selected file no longer exists: " + str(p))

        # Record the exact path and launch route in the development launcher log.
        # This makes it possible to diagnose whether Digi is opening the selected
        # indexed file or an unintended blank document.
        print("[Digi Open] Requested path:", str(p), flush=True)
        if os.name == "nt" and p.suffix.lower() == ".docx":
            word = None
            try:
                import win32com.client
                word = win32com.client.DispatchEx("Word.Application")
                word.Visible = True
                # Use positional COM arguments for compatibility with Word/type-library
                # variants that reject named arguments from pywin32.
                document = word.Documents.Open(str(p), False, False, True)
                opened_path = Path(str(document.FullName)).resolve()
                print("[Digi Open] Word reports opened path:", str(opened_path), flush=True)
                if os.path.normcase(str(opened_path)) != os.path.normcase(str(p)):
                    raise RuntimeError(
                        "Word opened a different document. Requested: "
                        + str(p) + "; opened: " + str(opened_path)
                    )
                print("[Digi Open] Direct Word open succeeded:", str(opened_path), flush=True)
                return
            except Exception as exc:
                print("[Digi Open] Direct Word open FAILED:", repr(exc), flush=True)
                # DispatchEx created a dedicated Word process. If opening failed,
                # Word may have left a blank Document1 behind; close only documents
                # in this dedicated instance without saving, then quit that instance.
                if word is not None:
                    try:
                        for index in range(word.Documents.Count, 0, -1):
                            try:
                                word.Documents(index).Close(SaveChanges=0)
                            except Exception as close_exc:
                                print("[Digi Open] Could not close failed-open document:", repr(close_exc), flush=True)
                        word.Quit(SaveChanges=0)
                        print("[Digi Open] Closed dedicated Word instance after failed open.", flush=True)
                    except Exception as cleanup_exc:
                        print("[Digi Open] Could not fully close dedicated Word instance:", repr(cleanup_exc), flush=True)
                # Fall back to the registered Windows file association after cleaning
                # up the blank automation instance, so it cannot steal focus with
                # an unsaved Doc1 dialog.
                try:
                    os.startfile(str(p), "open")
                    print("[Digi Open] Launched using Windows file association after COM failure:", str(p), flush=True)
                    return
                except Exception as shell_exc:
                    print("[Digi Open] Windows file association FAILED:", repr(shell_exc), flush=True)
                    raise RuntimeError(
                        "Digi could not open the selected DOCX. Requested path: "
                        + str(p) + ". Word automation error: " + str(exc)
                        + ". Windows open error: " + str(shell_exc)
                    ) from shell_exc
        if hasattr(os, "startfile"):
            os.startfile(str(p), "open")
            print("[Digi Open] Launched using Windows file association:", str(p), flush=True)
        else:
            subprocess.Popen(["xdg-open", str(p)])
            print("[Digi Open] Launched using xdg-open:", str(p), flush=True)
    @staticmethod
    def open_folder(path):
        p=Path(path); target=p if p.is_dir() else p.parent
        if hasattr(os,"startfile"): os.startfile(str(target))
        else: subprocess.Popen(["xdg-open",str(target)])
    @staticmethod
    def create_folder(parent,name):
        p=Path(parent)/name.strip(); p.mkdir(); return str(p)
    @staticmethod
    def create_document(parent, name, kind):
        import zipfile

        if kind not in ("docx", "pdf"):
            raise ValueError("Only DOCX and PDF creation are supported.")
        if not name or not name.strip():
            raise ValueError("Enter a file name.")
        cleaned = name.strip()
        if any(ch in cleaned for ch in '<>:"/\\|?*') or cleaned in (".", ".."):
            raise ValueError("The file name contains characters that are not allowed.")

        parent_path = Path(parent).expanduser().resolve()
        if not parent_path.exists() or not parent_path.is_dir():
            raise FileNotFoundError("The configured search repository does not exist. Choose a valid repository folder first.")
        ext = "." + kind
        target = (parent_path / (cleaned if cleaned.lower().endswith(ext) else cleaned + ext)).resolve()
        if target.parent != parent_path:
            raise ValueError("The file must be created inside the configured search repository.")
        if target.exists():
            raise FileExistsError("A file with that name already exists in the search repository.")

        if kind == "docx":
            # Build a minimal valid Office Open XML document without depending
            # on python-docx being installed or discoverable in a frozen build.
            content_types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
            rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
            document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>'
            with zipfile.ZipFile(str(target), "x", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("[Content_Types].xml", content_types)
                archive.writestr("_rels/.rels", rels)
                archive.writestr("word/document.xml", document)
        else:
            import fitz
            pdf = fitz.open()
            try:
                pdf.new_page()
                pdf.save(str(target))
            finally:
                pdf.close()
        return str(target)
    @staticmethod
    def delete_folder(path):
        p=Path(path)
        if p.exists() and p.is_dir(): shutil.rmtree(p)
