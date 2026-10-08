from datetime import date
from pathlib import Path
from PySide6.QtCore import QThread, Signal
from .config import DEFAULT_INCOMING, CACHE_DIR, SUPPORTED
from .database import Database

try:
    import fitz
except ImportError:
    fitz = None
try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None

class IndexWorker(QThread):
    finished_scan = Signal(object, object)
    failed = Signal(str)
    def __init__(self, root, cached, incoming):
        super().__init__()
        self.root, self.cached, self.incoming = Path(root), cached, Path(incoming).resolve()
    def run(self):
        found, metadata = set(), {}
        try:
            for p in self.root.rglob("*"):
                if not p.is_file() or p.suffix.lower() not in SUPPORTED: continue
                p = p.resolve()
                if self._excluded(p): continue
                try: modified = p.stat().st_mtime
                except OSError: continue
                old = self.cached.get(str(p))
                pages = old[1] if old and old[0] == modified else None
                if pages is None and p.suffix.lower() == ".pdf" and fitz:
                    try:
                        with fitz.open(str(p)) as doc: pages = len(doc)
                    except Exception: pages = None
                found.add(str(p)); metadata[str(p)] = (p, modified, pages)
            self.finished_scan.emit(found, metadata)
        except Exception as exc:
            self.failed.emit(str(exc))
    def _excluded(self, p):
        for blocked in (CACHE_DIR.resolve(), self.incoming):
            if p == blocked or blocked in p.parents: return True
        return False

class SearchService:
    def __init__(self):
        self.db = Database(); self.root = None; self.incoming = DEFAULT_INCOMING
        self.cache = []; self.worker = None
    def configure(self, root, incoming):
        self.root, self.incoming = Path(root).resolve(), Path(incoming).resolve()
        self.cache = self.db.rows()
    def scan(self, done, failed):
        if self.worker and self.worker.isRunning(): return
        cached = {r[0]: (r[3], r[4]) for r in self.db.rows()}
        self.worker = IndexWorker(self.root, cached, self.incoming)
        self.worker.finished_scan.connect(lambda found, meta: self._finish(found, meta, done))
        self.worker.failed.connect(failed); self.worker.start()
    def _finish(self, found, meta, done):
        self.db.replace_index(found, meta); self.cache = self.db.rows(); done()
    def query(self, text, typ, status, source, method, sort):
        if not text.strip(): return []
        candidates = self.db.search(text) if method == "Normal" else self.cache
        q = text.casefold(); rows = []
        for row in candidates:
            path = Path(row[0])
            if not path.exists() or path.suffix.lower() not in SUPPORTED: continue
            if typ == "PDF" and row[2] != ".pdf": continue
            if typ == "Word" and row[2] not in {".doc", ".docx"}: continue
            parts = {x.casefold() for x in path.parts}
            if source == "ExamPro" and "exampro" not in parts: continue
            if source == "PMT" and "pmt" not in parts: continue
            effective = self._status(row)
            if status != "All statuses" and effective != status: continue
            score = self._score(path, q, method)
            if score < 45: continue
            rows.append({"path":str(path),"name":path.stem,"ext":row[2],"modified":row[3],
                         "pages":row[4],"status":effective,"due_date":row[6],
                         "priority":row[7],"score":score,"tags":self.db.tags(path)})
        key = lambda x: x["name"].casefold()
        if sort == "Name A-Z": rows.sort(key=key)
        elif sort == "Name Z-A": rows.sort(key=key, reverse=True)
        elif sort == "Newest modified": rows.sort(key=lambda x:x["modified"], reverse=True)
        elif sort == "Oldest modified": rows.sort(key=lambda x:x["modified"])
        elif sort == "Most pages": rows.sort(key=lambda x:x["pages"] or 0, reverse=True)
        elif sort == "Fewest pages": rows.sort(key=lambda x:x["pages"] or 0)
        else: rows.sort(key=lambda x:(-x["score"], x["name"].casefold()))
        return rows[:300]
    def _score(self, path, q, method):
        target = str(path).casefold()
        if method == "Normal": return 1000 - target.find(q) if q in target else 0
        if not fuzz: return 0
        return max(fuzz.WRatio(q,path.stem.casefold()), fuzz.token_set_ratio(q,target),
                   max((fuzz.WRatio(q,p.casefold()) for p in path.parts), default=0))
    @staticmethod
    def _status(row):
        status,due=row[5],row[6]
        if due and status != "Finished":
            today=date.today().isoformat()
            if due < today:return "Due late"
            if due == today:return "Due"
        return status
