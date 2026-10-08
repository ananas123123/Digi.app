import sqlite3
from datetime import datetime
from .config import DB_PATH

class Database:
    def __init__(self):
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(DB_PATH)
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.executescript("""
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY, name TEXT NOT NULL, ext TEXT NOT NULL,
            modified REAL NOT NULL, pages INTEGER,
            status TEXT NOT NULL DEFAULT 'Not started', due_date TEXT,
            priority TEXT NOT NULL DEFAULT 'Normal');
        CREATE TABLE IF NOT EXISTS recent_searches (
            query TEXT PRIMARY KEY, last_used REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL);
        CREATE TABLE IF NOT EXISTS file_tags (
            path TEXT NOT NULL, tag_id INTEGER NOT NULL,
            PRIMARY KEY(path, tag_id));
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY, value TEXT NOT NULL);
        """)
        self.conn.commit()

    def rows(self):
        return self.conn.execute("SELECT path,name,ext,modified,pages,status,due_date,priority FROM files").fetchall()

    def search(self, query):
        q = query.strip().lower()
        if not q: return []
        like = "%" + q + "%"
        return self.conn.execute(
            "SELECT path,name,ext,modified,pages,status,due_date,priority FROM files "
            "WHERE lower(name) LIKE ? OR lower(path) LIKE ? LIMIT 500", (like, like)
        ).fetchall()

    def replace_index(self, found, metadata):
        values = [(str(p), p.name, p.suffix.lower(), modified, pages)
                  for p, modified, pages in metadata.values()]
        if values:
            self.conn.executemany("""
            INSERT INTO files(path,name,ext,modified,pages) VALUES(?,?,?,?,?)
            ON CONFLICT(path) DO UPDATE SET name=excluded.name,ext=excluded.ext,
            modified=excluded.modified,pages=excluded.pages""", values)
        existing = {r[0] for r in self.conn.execute("SELECT path FROM files")}
        missing = [(p,) for p in existing - found]
        if missing:
            self.conn.executemany("DELETE FROM files WHERE path=?", missing)
            self.conn.executemany("DELETE FROM file_tags WHERE path=?", missing)
        self.conn.commit()

    def update(self, path, field, value):
        if field in {"status", "due_date", "priority"}:
            self.conn.execute(f"UPDATE files SET {field}=? WHERE path=?", (value, str(path)))
            self.conn.commit()

    def tags(self, path):
        return [r[0] for r in self.conn.execute(
            "SELECT t.name FROM tags t JOIN file_tags ft ON ft.tag_id=t.id "
            "WHERE ft.path=? ORDER BY t.name", (str(path),))]

    def add_tag(self, path, name):
        name = name.strip()
        if not name: return
        self.conn.execute("INSERT OR IGNORE INTO tags(name) VALUES(?)", (name,))
        tid = self.conn.execute("SELECT id FROM tags WHERE name=?", (name,)).fetchone()[0]
        self.conn.execute("INSERT OR IGNORE INTO file_tags(path,tag_id) VALUES(?,?)", (str(path), tid))
        self.conn.commit()

    def remove_tag(self, path, name):
        row = self.conn.execute("SELECT id FROM tags WHERE name=?", (name,)).fetchone()
        if row:
            self.conn.execute("DELETE FROM file_tags WHERE path=? AND tag_id=?", (str(path), row[0]))
            self.conn.commit()

    def setting(self, key, default=None):
        row = self.conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row[0] if row else default

    def set_setting(self, key, value):
        self.conn.execute(
            "INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value))
        self.conn.commit()

    def add_recent(self, query):
        if query.strip():
            self.conn.execute(
                "INSERT INTO recent_searches(query,last_used) VALUES(?,?) "
                "ON CONFLICT(query) DO UPDATE SET last_used=excluded.last_used",
                (query.strip(), datetime.now().timestamp()))
            self.conn.commit()

    def recents(self):
        return [r[0] for r in self.conn.execute(
            "SELECT query FROM recent_searches ORDER BY last_used DESC LIMIT 12")]
