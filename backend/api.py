import json
import subprocess
import sys
from pathlib import Path
from PySide6.QtCore import QObject,Signal,Slot,QTimer
from PySide6.QtWidgets import QFileDialog
from .config import APP_VERSION,DEFAULT_INCOMING,LIBRARY_CONFIG,get_library_root,ensure_directories
from .database import Database
from .search import SearchService
from .files import FileService
from .conversion import ConversionWorker
from .incoming import IncomingService
from .notes import NotesService
from .version_manager import initialize_version_file,version_integrity,recalibrate_version,repair_after_close,ERROR_CODE_INTEGRITY

class DigiBridge(QObject):
    indexUpdated=Signal()
    conversionProgress=Signal(str,int)
    conversionFinished=Signal(bool,str,str)
    error=Signal(str)
    integrityViolation=Signal(int,str)
    def __init__(self,parent=None):
        super().__init__(parent); ensure_directories()
        initialize_version_file()
        self.version_ok,self.version_problem=version_integrity()
        self.db=None; self.search_service=None; self.incoming=None; self.notes=None; self.worker=None
        self._integrity_problem=None
        self._integrity_timer=QTimer(self)
        self._integrity_timer.setInterval(750)
        self._integrity_timer.timeout.connect(self._check_integrity)
        self._integrity_timer.start()
        if self.version_ok:
            self.db=Database()
            root=get_library_root(); saved=self.db.setting("incoming_folder"); incoming=Path(saved) if saved else DEFAULT_INCOMING
            self.search_service=SearchService(); self.search_service.configure(root,incoming)
            self.incoming=IncomingService(self.db,root,incoming); self.notes=NotesService(root)
            self.start_scan()
    @Slot(result=str)
    def state(self):
        return json.dumps({"library":str(self.search_service.root) if self.search_service else "","incoming":str(self.incoming.incoming_folder) if self.incoming else "","version":APP_VERSION,"version_ok":self.version_ok,"version_problem":self.version_problem})
    @Slot(result=bool)
    def recalibrateVersion(self):
        self.version_ok=recalibrate_version()
        self.version_problem="ok" if self.version_ok else "modified"
        if self.version_ok:
            self.db=Database()
            root=get_library_root(); saved=self.db.setting("incoming_folder"); incoming=Path(saved) if saved else DEFAULT_INCOMING
            self.search_service=SearchService(); self.search_service.configure(root,incoming)
            self.incoming=IncomingService(self.db,root,incoming); self.notes=NotesService(root)
            self.start_scan()
        return self.version_ok
    def _check_integrity(self):
        ok, problem = version_integrity()
        if not ok and problem != self._integrity_problem:
            self._integrity_problem=problem
            self.version_ok=False
            self.version_problem=problem
            self.integrityViolation.emit(ERROR_CODE_INTEGRITY, problem)
        elif ok and not self.version_ok:
            self._integrity_problem=None
            self.version_ok=True

    @Slot()
    def restartApplication(self):
        subprocess.Popen([sys.executable, *sys.argv[1:]], cwd=str(Path(sys.executable).resolve().parent))
        from PySide6.QtWidgets import QApplication
        QApplication.instance().quit()
    @Slot(str,str,str,str,str,str,result=str)
    def search(self,q,typ,status,source,method,sort): return json.dumps(self.search_service.query(q,typ,status,source,method,sort))
    @Slot(str,result=str)
    def tags(self,path): return json.dumps(self.db.tags(path))
    @Slot(str,str,result=bool)
    def addTag(self,path,name): self.db.add_tag(path,name); return True
    @Slot(str,str,result=bool)
    def removeTag(self,path,name): self.db.remove_tag(path,name); return True
    @Slot(str,str,result=bool)
    def setStatus(self,path,value): self.db.update(path,"status",value); return True
    @Slot(str,str,result=bool)
    def setDueDate(self,path,value): self.db.update(path,"due_date",value); return True
    @Slot(str,result=bool)
    def openFile(self,path): self.incoming.remember_origin(path); FileService.open_file(path); return True
    @Slot(str,result=bool)
    def openFolder(self,path): FileService.open_folder(path); return True
    @Slot(result=str)
    def chooseLibraryFolder(self): return QFileDialog.getExistingDirectory(None,"Choose Digi Search Engine library folder",str(self.search_service.root))
    @Slot(str,result=bool)
    def setLibraryFolder(self,path):
        root=Path(path).resolve(); self.search_service.configure(root,self.incoming.incoming_folder); self.db.set_setting("library_folder",str(root)); LIBRARY_CONFIG.write_text(str(root),encoding="utf-8"); self.incoming.set_folders(root,self.incoming.incoming_folder); self.notes=NotesService(root); self.start_scan(); return True
    @Slot(result=str)
    def chooseIncomingFolder(self):
        folder=QFileDialog.getExistingDirectory(None,"Choose Incoming folder",str(self.incoming.incoming_folder))
        if folder: self.incoming.set_folders(self.search_service.root,folder); self.search_service.incoming=Path(folder).resolve(); self.db.set_setting("incoming_folder",folder)
        return folder or ""
    @Slot(result=bool)
    def processIncoming(self): self.incoming.process(); self.start_scan(); return True
    @Slot(str,str,str,result=str)
    def createDocument(self,parent,name,kind): result=FileService.create_document(parent,name,kind); self.start_scan(); return result
    @Slot(str,str,result=str)
    def createFolder(self,parent,name): result=FileService.create_folder(parent,name); self.start_scan(); return result
    @Slot(str,result=bool)
    def deleteFolder(self,path): FileService.delete_folder(path); self.start_scan(); return True
    @Slot(str,str,result=bool)
    def convert(self,path,target):
        if self.worker and self.worker.isRunning(): return False
        self.worker=ConversionWorker(path,target)
        self.worker.progress.connect(lambda value: self.conversionProgress.emit(str(path),value))
        self.worker.finished.connect(lambda ok,msg,out: self.conversionFinished.emit(ok,msg,str(path)))
        self.worker.start(); return True
    @Slot(result=str)
    def notesTree(self): return json.dumps(self.notes.tree())
    @Slot(str,str,result=str)
    def createNotebook(self,parent,name): return self.notes.create_notebook(name)
    @Slot(str,str,result=str)
    def createNoteFolder(self,parent,name): return self.notes.create_folder(parent,name)
    @Slot(str,str,result=str)
    def createNotePage(self,parent,name): return self.notes.create_page(parent,name)
    @Slot(str,str,result=str)
    def saveNote(self,path,data): return self.notes.save(path,data)
    @Slot(str,result=str)
    def loadNote(self,path): return self.notes.load(path)
    @Slot(str,result=bool)
    def deleteNote(self,path): self.notes.delete(path); return True
    @Slot(str,str,result=str)
    def renameNote(self,path,name): return self.notes.rename(path,name)
    @Slot(result=str)
    def recentSearches(self): return json.dumps(self.db.recents())
    @Slot(str,result=bool)
    def rememberSearch(self,q): self.db.add_recent(q); return True
    @Slot(result=bool)
    def scan(self): self.start_scan(); return True
    def start_scan(self):
        if self.search_service:
            self.search_service.scan(lambda:self.indexUpdated.emit(),lambda m:self.error.emit(m))
