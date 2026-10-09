import json
import time
import urllib.request
from pathlib import Path
from PySide6.QtCore import QObject,Signal,Slot,QThread
from PySide6.QtWidgets import QFileDialog
from .config import APP_VERSION,DEFAULT_INCOMING,LIBRARY_CONFIG,get_library_root,ensure_directories
from .database import Database
from .search import SearchService
from .files import FileService
from .conversion import ConversionWorker
from .incoming import IncomingService
from .notes import NotesService
from .version_manager import initialize_version_file,version_integrity,recalibrate_version

class ReleaseManifestWorker(QThread):
    resultReady=Signal(str)
    # Prefer GitHub's Contents API over raw.githubusercontent.com. The raw
    # endpoint may serve a stale CDN copy even when latest.json has changed.
    # The API response includes the file's current base64 content.
    URLS=(
        "https://api.github.com/repos/ananas123123/digiwebversionreleases/contents/latest.json?ref=main",
        "https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/latest.json",
    )
    def run(self):
        # Add a unique query parameter and explicit no-cache headers so a
        # CDN/proxy cannot keep serving an older latest.json during checks.
        cache_buster=str(int(time.time() * 1000))
        for index,base_url in enumerate(self.URLS):
            try:
                separator="&" if "?" in base_url else "?"
                url=base_url+separator+"_digi_check="+cache_buster
                request=urllib.request.Request(url,headers={
                    "Accept":"application/vnd.github+json",
                    "User-Agent":"Digi-Update-Checker",
                    "Cache-Control":"no-cache, no-store, max-age=0",
                    "Pragma":"no-cache",
                })
                with urllib.request.urlopen(request,timeout=8) as response:
                    payload=response.read()
                if "api.github.com" in base_url:
                    import base64
                    envelope=json.loads(payload.decode("utf-8"))
                    if envelope.get("encoding") != "base64" or not envelope.get("content"):
                        raise ValueError("GitHub API did not return base64 file content")
                    payload=base64.b64decode(envelope["content"])
                manifest=json.loads(payload.decode("utf-8"))
                self.resultReady.emit(json.dumps({"ok":True,"manifest":manifest}))
                return
            except Exception:
                continue
        self.resultReady.emit(json.dumps({"ok":False,"manifest":None}))


class DigiBridge(QObject):
    indexUpdated=Signal()
    releaseManifestResult=Signal(str)
    conversionProgress=Signal(str,int)
    conversionFinished=Signal(bool,str,str)
    error=Signal(str)
    def __init__(self,parent=None):
        super().__init__(parent)
        initialize_version_file()
        self.version_ok,self.version_problem=version_integrity()
        self.db=None; self.search_service=None; self.incoming=None; self.notes=None; self.worker=None; self.release_worker=None
        if self.version_ok:
            try:
                ensure_directories()
                self._initialize_services()
            except Exception as exc:
                self.version_ok=False
                self.version_problem=f"initialization_failed: {exc}"
                self.error.emit(self.version_problem)

    def _initialize_services(self):
        """Create backend services once the runtime layout passes integrity checks."""
        self.db=Database()
        root=get_library_root()
        saved=self.db.setting("incoming_folder")
        incoming=Path(saved) if saved else DEFAULT_INCOMING
        self.search_service=SearchService()
        self.search_service.configure(root,incoming)
        self.incoming=IncomingService(self.db,root,incoming)
        self.notes=NotesService(root)
        self.start_scan()

    @Slot()
    def checkReleaseManifest(self):
        if self.release_worker and self.release_worker.isRunning():
            return
        self.release_worker=ReleaseManifestWorker(self)
        self.release_worker.resultReady.connect(self.releaseManifestResult.emit)
        self.release_worker.start()

    @Slot(result=str)
    def state(self):
        return json.dumps({"library":str(self.search_service.root) if self.search_service else "","incoming":str(self.incoming.incoming_folder) if self.incoming else "","version":APP_VERSION,"version_ok":self.version_ok,"version_problem":self.version_problem,"ready":bool(self.db and self.search_service and self.incoming and self.notes)})
    @Slot(result=bool)
    def recalibrateVersion(self):
        self.version_ok=recalibrate_version()
        self.version_problem="ok" if self.version_ok else "modified"
        if self.version_ok:
            try:
                ensure_directories()
                self._initialize_services()
            except Exception as exc:
                self.version_ok=False
                self.version_problem=f"initialization_failed: {exc}"
                self.error.emit(self.version_problem)
        return self.version_ok
    @Slot(str,str,str,str,str,str,result=str)
    def search(self,q,typ,status,source,method,sort):
        if not self.search_service:
            return json.dumps([])
        return json.dumps(self.search_service.query(q,typ,status,source,method,sort))
    @Slot(str,result=str)
    def tags(self,path): return json.dumps(self.db.tags(path)) if self.db else "[]"
    @Slot(str,str,result=bool)
    def addTag(self,path,name):
        if not self.db: return False
        self.db.add_tag(path,name); return True
    @Slot(str,str,result=bool)
    def removeTag(self,path,name):
        if not self.db: return False
        self.db.remove_tag(path,name); return True
    @Slot(str,str,result=bool)
    def setStatus(self,path,value):
        if not self.db: return False
        self.db.update(path,"status",value); return True
    @Slot(str,str,result=bool)
    def setDueDate(self,path,value):
        if not self.db: return False
        self.db.update(path,"due_date",value); return True
    @Slot(str,result=bool)
    def openFile(self,path):
        if not self.incoming: return False
        self.incoming.remember_origin(path); FileService.open_file(path); return True
    @Slot(str,result=bool)
    def openFolder(self,path): FileService.open_folder(path); return True
    @Slot(result=str)
    def chooseLibraryFolder(self):
        if not self.search_service: return ""
        return QFileDialog.getExistingDirectory(None,"Choose Digi Search Engine library folder",str(self.search_service.root))
    @Slot(str,result=bool)
    def setLibraryFolder(self,path):
        if not all((self.search_service,self.incoming,self.db)): return False
        root=Path(path).resolve()
        self.search_service.configure(root,self.incoming.incoming_folder)
        self.db.set_setting("library_folder",str(root))
        LIBRARY_CONFIG.write_text(str(root),encoding="utf-8")
        self.incoming.set_folders(root,self.incoming.incoming_folder)
        self.notes=NotesService(root)
        self.start_scan()
        return True
    @Slot(result=str)
    def chooseIncomingFolder(self):
        if not all((self.search_service,self.incoming,self.db)): return ""
        folder=QFileDialog.getExistingDirectory(None,"Choose Incoming folder",str(self.incoming.incoming_folder))
        if folder:
            self.incoming.set_folders(self.search_service.root,folder)
            self.search_service.incoming=Path(folder).resolve()
            self.db.set_setting("incoming_folder",folder)
        return folder or ""
    @Slot(result=bool)
    def processIncoming(self):
        if not self.incoming: return False
        self.incoming.process(); self.start_scan(); return True
    @Slot(str,str,str,result=str)
    def createDocument(self,parent,name,kind):
        if not self.search_service: return ""
        result=FileService.create_document(parent,name,kind); self.start_scan(); return result
    @Slot(str,str,result=str)
    def createFolder(self,parent,name):
        if not self.search_service: return ""
        result=FileService.create_folder(parent,name); self.start_scan(); return result
    @Slot(str,result=bool)
    def deleteFolder(self,path):
        if not self.search_service: return False
        FileService.delete_folder(path); self.start_scan(); return True
    @Slot(str,str,result=bool)
    def convert(self,path,target):
        if self.worker and self.worker.isRunning(): return False
        self.worker=ConversionWorker(path,target)
        self.worker.progress.connect(lambda value: self.conversionProgress.emit(str(path),value))
        self.worker.finished.connect(lambda ok,msg,out: self.conversionFinished.emit(ok,msg,str(path)))
        self.worker.start(); return True
    @Slot(result=str)
    def notesTree(self): return json.dumps(self.notes.tree()) if self.notes else "[]"
    @Slot(str,str,result=str)
    def createNotebook(self,parent,name): return self.notes.create_notebook(name) if self.notes else ""
    @Slot(str,str,result=str)
    def createNoteFolder(self,parent,name): return self.notes.create_folder(parent,name) if self.notes else ""
    @Slot(str,str,result=str)
    def createNotePage(self,parent,name): return self.notes.create_page(parent,name) if self.notes else ""
    @Slot(str,str,result=str)
    def saveNote(self,path,data): return self.notes.save(path,data) if self.notes else ""
    @Slot(str,result=str)
    def loadNote(self,path): return self.notes.load(path) if self.notes else ""
    @Slot(str,result=bool)
    def deleteNote(self,path):
        if not self.notes: return False
        self.notes.delete(path); return True
    @Slot(str,str,result=str)
    def renameNote(self,path,name): return self.notes.rename(path,name) if self.notes else ""
    @Slot(result=str)
    def recentSearches(self): return json.dumps(self.db.recents()) if self.db else "[]"
    @Slot(str,result=bool)
    def rememberSearch(self,q):
        if not self.db: return False
        self.db.add_recent(q); return True
    @Slot(result=bool)
    def scan(self):
        if not self.search_service: return False
        self.start_scan(); return True
    def start_scan(self):
        if self.search_service:
            self.search_service.scan(lambda:self.indexUpdated.emit(),lambda m:self.error.emit(m))
