from pathlib import Path
import base64,re,shutil

class NotesService:
    def __init__(self,root):
        self.root=Path(root)/"Digi Notes"; self.root.mkdir(parents=True,exist_ok=True)
    def tree(self):
        def walk(folder):
            out=[]
            for p in sorted(folder.iterdir(),key=lambda x:(not x.is_dir(),x.name.casefold())):
                if p.is_dir(): out.append({"type":"folder","name":p.name,"path":str(p),"children":walk(p)})
                elif p.suffix.lower()==".png": out.append({"type":"page","name":p.stem,"path":str(p)})
            return out
        return walk(self.root)
    def _safe(self,name,fallback):
        return re.sub(r'[<>:"/\\|?*]','_',name.strip()).strip('. ') or fallback
    def create_notebook(self,name):
        p=self.root/self._safe(name,"Notebook"); p.mkdir(); return str(p)
    def create_folder(self,parent,name):
        p=Path(parent)/self._safe(name,"Folder"); p.mkdir(); return str(p)
    def create_page(self,parent,name):
        p=(Path(parent)/self._safe(name,"Untitled")).with_suffix(".png"); p.touch(exist_ok=False); return str(p)
    def save(self,path,data):
        raw=data.split(",",1)[1] if "," in data else data
        Path(path).parent.mkdir(parents=True,exist_ok=True); Path(path).write_bytes(base64.b64decode(raw)); return str(path)
    def load(self,path):
        return "data:image/png;base64,"+base64.b64encode(Path(path).read_bytes()).decode()
    def delete(self,path):
        p=Path(path); shutil.rmtree(p) if p.is_dir() else p.unlink()
    def rename(self,path,name):
        p=Path(path); safe=self._safe(name,p.stem); target=p.parent/(safe+p.suffix if p.is_file() else safe); p.rename(target); return str(target)
