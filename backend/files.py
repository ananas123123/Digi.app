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
            try:
                import win32com.client
                word = win32com.client.DispatchEx("Word.Application")
                word.Visible = True
                document = word.Documents.Open(
                    FileName=str(p),
                    ReadOnly=False,
                    AddToRecentFiles=True,
                    ConfirmConversions=False,
                    OpenAndRepair=False,
                    NoEncodingDialog=True,
                )
                opened_path = Path(str(document.FullName)).resolve()
                print("[Digi Open] Word reports opened path:", str(opened_path), flush=True)
                if os.path.normcase(str(opened_path)) != os.path.normcase(str(p)):
                    raise RuntimeError(
                        "Word opened a different document. Requested: "
                        + str(p) + "; opened: " + str(opened_path)
                    )
                return
            except Exception as exc:
                print("[Digi Open] Direct Word open FAILED:", repr(exc), flush=True)
                raise RuntimeError(
                    "Digi could not open this existing DOCX directly in Word. "
                    "The file was not replaced or modified. Requested path: "
                    + str(p) + ". Details: " + str(exc)
                ) from exc
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
    def create_document(parent,name,kind):
        p=Path(parent); ext={"docx":".docx","doc":".doc","pdf":".pdf"}[kind]
        target=p/(name if name.lower().endswith(ext) else name+ext)
        if kind=="docx":
            from docx import Document; Document().save(str(target))
        elif kind=="pdf":
            import fitz; pdf=fitz.open(); pdf.save(str(target)); pdf.close()
        else: raise RuntimeError("Legacy .doc creation requires Microsoft Word.")
        return str(target)
    @staticmethod
    def delete_folder(path):
        p=Path(path)
        if p.exists() and p.is_dir(): shutil.rmtree(p)
