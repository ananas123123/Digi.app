from pathlib import Path
import os,shutil
from datetime import datetime
from .config import SUPPORTED

class IncomingService:
    def __init__(self,database,library_root,incoming_folder):
        self.db=database; self.set_folders(library_root,incoming_folder); self.origin={}
    def set_folders(self,library_root,incoming_folder):
        self.library_root=Path(library_root).resolve(); self.incoming_folder=Path(incoming_folder).resolve()
        self.incoming_folder.mkdir(parents=True,exist_ok=True)
    def remember_origin(self,path):
        p=Path(path).resolve()
        if self._repo(p): self.origin[p.name.casefold()]=str(p)
    def process(self):
        results=[]
        for source in list(self.incoming_folder.iterdir()):
            if not source.is_file() or source.suffix.lower() not in SUPPORTED: continue
            target=None; remembered=self.origin.get(source.name.casefold())
            if remembered and Path(remembered).exists(): target=Path(remembered)
            else:
                matches=self._matches(source)
                if len(matches)==1: target=matches[0]
            if target: self.replace(source,target); results.append(str(target))
        return results
    def replace(self,source,target):
        temp=Path(target).with_name("."+Path(target).name+".digi-"+str(os.getpid())+"-"+datetime.now().strftime("%f")+".tmp")
        shutil.copy2(source,temp); os.replace(temp,target); Path(source).unlink()
        self.db.conn.execute("DELETE FROM files WHERE path=?",(str(Path(source).resolve()),)); self.db.conn.commit()
    def _matches(self,source):
        return sorted({p.resolve() for p in self.library_root.rglob(source.name) if p.is_file() and p.suffix.casefold()==source.suffix.casefold()},key=lambda p:str(p).casefold())
    def _repo(self,p):
        try: p.relative_to(self.library_root); return p.is_file()
        except ValueError:return False
