from pathlib import Path
import os, subprocess, shutil

class FileService:
    @staticmethod
    def open_file(path):
        p = Path(path).resolve()
        if not p.is_file():
            raise FileNotFoundError("The selected file no longer exists: " + str(p))

        # On Windows, explicitly open the existing DOCX path in Word. This avoids
        # accidentally creating/activating a blank Doc1 document when shell
        # association handling is misconfigured. If COM automation is unavailable,
        # fall back to the normal operating-system file association.
        if os.name == "nt" and p.suffix.lower() == ".docx":
            try:
                import win32com.client
                word = win32com.client.Dispatch("Word.Application")
                word.Visible = True
                word.Documents.Open(str(p))
                return
            except Exception:
                # The shell association remains the supported fallback.
                pass

        if hasattr(os, "startfile"):
            os.startfile(str(p))
        else:
            subprocess.Popen(["xdg-open", str(p)])
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
