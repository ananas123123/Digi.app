from pathlib import Path
import io,json,shutil,subprocess,zipfile,xml.etree.ElementTree as ET
from PySide6.QtCore import QThread,Signal
try: import fitz
except ImportError: fitz=None

class ConversionWorker(QThread):
    progress=Signal(int)
    finished=Signal(bool,str,str)
    def __init__(self,source,target_kind): super().__init__(); self.source=Path(source); self.target_kind=target_kind
    def _progress(self,value): self.progress.emit(max(0,min(100,int(value))))
    def run(self):
        try:
            self._progress(2)
            if not self.source.exists(): raise FileNotFoundError(self.source)
            target=self.source.with_suffix(".pdf" if self.target_kind=="pdf" else ".docx")
            if target.exists(): target.unlink()
            self._progress(5)
            self.pdf_to_docx(self.source,target) if target.suffix==".docx" else self.docx_to_pdf(self.source,target)
            self._progress(100)
            if not target.exists() or not target.stat().st_size: raise RuntimeError("Conversion produced no usable output.")
            self.finished.emit(True,"Conversion completed successfully.",str(target))
        except Exception as exc: self.finished.emit(False,str(exc),"")
    def pdf_to_docx(self,source,target):
        if fitz is None: raise RuntimeError("PyMuPDF is not installed.")
        from docx import Document
        from docx.shared import Inches
        from docx.enum.text import WD_ALIGN_PARAGRAPH
        from docx.enum.section import WD_SECTION
        pdf=fitz.open(str(source)); records=[]
        try:
            total=max(1,len(pdf))
            for number,page in enumerate(pdf,1):
                pix=page.get_pixmap(matrix=fitz.Matrix(200/72,200/72),alpha=False)
                records.append({"page":number,"width_pt":float(page.rect.width),"height_pt":float(page.rect.height),"png":pix.tobytes("png")})
                self._progress(5 + (number/total)*55)
        finally: pdf.close()
        if not records: raise RuntimeError("The PDF contains no pages.")
        doc=Document()
        total=len(records)
        for i,r in enumerate(records):
            s=doc.sections[0] if i==0 else doc.add_section(WD_SECTION.NEW_PAGE)
            w,h=r["width_pt"]/72,r["height_pt"]/72
            s.page_width,s.page_height=Inches(w),Inches(h)
            s.top_margin=s.bottom_margin=s.left_margin=s.right_margin=Inches(0)
            p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before=p.paragraph_format.space_after=Inches(0)
            p.add_run().add_picture(io.BytesIO(r["png"]),width=Inches(w),height=Inches(h))
            self._progress(60 + ((i+1)/total)*25)
        doc.save(str(target))
        self._progress(88)
        marker={"format":"digi-page-image-docx-v1","dpi":200,"pages":[{"page":r["page"],"width_pt":r["width_pt"],"height_pt":r["height_pt"],"media":f"word/media/image{i+1}.png"} for i,r in enumerate(records)]}
        temp=target.with_suffix(".tmp.docx")
        with zipfile.ZipFile(target,"r") as zin,zipfile.ZipFile(temp,"w",zipfile.ZIP_DEFLATED) as zout:
            items=zin.infolist()
            total_items=max(1,len(items))
            for i,item in enumerate(items,1):
                data=zin.read(item.filename)
                if item.filename=="word/settings.xml":
                    try:
                        root=ET.fromstring(data); ns={"w":"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
                        if root.find("w:doNotCompressPictures",ns) is None: root.append(ET.Element("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}doNotCompressPictures"))
                        data=ET.tostring(root,encoding="utf-8",xml_declaration=True)
                    except Exception: pass
                zout.writestr(item,data)
                self._progress(88 + (i/total_items)*10)
            zout.writestr("word/digi_search_engine_page_images.json",json.dumps(marker).encode())
        temp.replace(target)
    def docx_to_pdf(self,source,target):
        if fitz is None: raise RuntimeError("PyMuPDF is not installed.")
        try:
            with zipfile.ZipFile(source,"r") as zin:
                marker="word/digi_search_engine_page_images.json"
                if marker in zin.namelist():
                    info=json.loads(zin.read(marker).decode()); pages=info.get("pages",[]); total=max(1,len(pages)); pdf=fitz.open()
                    self._progress(10)
                    for i,r in enumerate(pages,1):
                        png=zin.read(r["media"]); page=pdf.new_page(width=float(r["width_pt"]),height=float(r["height_pt"]))
                        page.insert_image(fitz.Rect(0,0,page.rect.width,page.rect.height),stream=png)
                        self._progress(10 + (i/total)*80)
                    pdf.save(str(target),deflate=True,clean=True); pdf.close(); self._progress(95); return
        except Exception: pass
        try:
            import pythoncom,win32com.client
            pythoncom.CoInitialize()
            try:
                word=win32com.client.DispatchEx("Word.Application"); word.Visible=False
                document=word.Documents.Open(str(source.resolve()))
                try: document.ExportAsFixedFormat(str(target.resolve()),17,OpenAfterExport=False,OptimizeFor=0,CreateBookmarks=0)
                finally: document.Close(False); word.Quit()
                self._progress(92)
            finally: pythoncom.CoUninitialize()
            return
        except Exception: pass
        libre=shutil.which("soffice") or shutil.which("libreoffice")
        if not libre: raise RuntimeError("Word-to-PDF requires Microsoft Word or LibreOffice.")
        self._progress(20)
        proc=subprocess.run([libre,"--headless","--convert-to","pdf","--outdir",str(target.parent),str(source)],capture_output=True,text=True,timeout=120)
        if proc.returncode: raise RuntimeError(proc.stderr or "LibreOffice conversion failed.")
        generated=target.parent/(source.stem+".pdf")
        if generated!=target and generated.exists(): generated.replace(target)
        self._progress(92)
