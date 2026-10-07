
import os
import sys
import sqlite3
import subprocess
import shutil
import zipfile
import json
import io
import hashlib
import threading
from pathlib import Path
from datetime import datetime, date

from PySide6.QtCore import Qt, QDate, QTimer, QThread, Signal, QFileSystemWatcher, QPropertyAnimation, QEasingCurve, QEvent, QPointF, QRectF
from PySide6.QtGui import QPainter, QPen, QFont, QFontMetrics, QPalette, QIcon, QPixmap, QImage, QColor
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLineEdit, QListWidget, QListWidgetItem, QLabel, QPushButton,
    QMessageBox, QComboBox, QDateEdit, QDialog, QFormLayout,
    QTextEdit,
    QInputDialog, QFileDialog, QSplitter, QGroupBox, QTextBrowser,
    QSizePolicy, QGridLayout, QStyledItemDelegate, QStyle, QStackedLayout,
    QGraphicsOpacityEffect, QTreeWidget, QTreeWidgetItem, QCheckBox, QMenu, QToolButton
)

try:
    import fitz
except ImportError:
    fitz = None

try:
    from rapidfuzz import fuzz, process
except ImportError:
    fuzz = None

SUPPORTED = {".pdf", ".doc", ".docx"}
APP_VERSION = "1.0.0.0"

# Update Log: 1.0.0.0 — Fixed folder-browser results regression introduced by the search-performance cache refactor.


VERSION_FOLDER_NAME = "Digi SE 1.0.0.0"


def app_folder():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def ensure_version_folder_location():
    """
    Keep a frozen Digi executable self-organised without imposing a relocation
    cost on normal launches.

    If the EXE is already inside its current version folder, startup proceeds
    normally. If the EXE has been moved elsewhere (for example to the Desktop),
    create the version folder and its standard subfolders, then hand the EXE
    off to a tiny Windows helper which moves the running file after this
    process exits and relaunches it from the correct location.
    """
    if not getattr(sys, "frozen", False):
        return False

    try:
        exe_path = Path(sys.executable).resolve()
        current_parent = exe_path.parent

        if current_parent.name.casefold() == VERSION_FOLDER_NAME.casefold():
            return False

        target_dir = current_parent / VERSION_FOLDER_NAME
        target_dir.mkdir(parents=True, exist_ok=True)
        for folder_name in ("Search Repository", "Incoming", "Cache"):
            (target_dir / folder_name).mkdir(parents=True, exist_ok=True)

        target_exe = target_dir / exe_path.name
        helper_path = target_dir / ".digi_relocate.cmd"

        src = str(exe_path)
        dst = str(target_exe)
        target = str(target_dir)

        helper = (
            "@echo off\n"
            "setlocal\n"
            f'set "SRC={src}"\n'
            f'set "DST={dst}"\n'
            f'set "TARGETDIR={target}"\n'
            ":retry\n"
            'move /Y "%SRC%" "%DST%" >nul 2>&1\n'
            'if exist "%SRC%" (\n'
            "    timeout /t 1 /nobreak >nul\n"
            "    goto retry\n"
            ")\n"
            'start "" "%DST%"\n'
            'del "%~f0" >nul 2>&1\n'
            "endlocal\n"
        )

        helper_path.write_text(helper, encoding="utf-8")
        creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        subprocess.Popen(
            ["cmd.exe", "/c", str(helper_path)],
            cwd=str(target_dir),
            creationflags=creationflags,
            close_fds=True,
        )
        return True
    except Exception:
        return False


def resource_path(name):
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / name
    return APP_DIR / name


if ensure_version_folder_location():
    # The helper will move and relaunch this EXE after the current process
    # exits. Do not initialise the GUI or database from the temporary location.
    raise SystemExit(0)

APP_DIR = app_folder()
# User-writable application data is kept in a dedicated Cache folder so the
# folder containing the EXE stays clean. The cache stores the SQLite index and
# remembered library-folder setting; it is NOT searched as part of the library.
CACHE_DIR = APP_DIR / "Cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = CACHE_DIR / "study_index.db"
DEFAULT_ROOT = APP_DIR / "Search Repository"
DEFAULT_INCOMING = APP_DIR / "Incoming"
LIBRARY_CONFIG = CACHE_DIR / "library_folder.txt"

def load_library_root():
    try:
        if LIBRARY_CONFIG.exists():
            candidate = Path(LIBRARY_CONFIG.read_text(encoding="utf-8").strip()).expanduser()
            if candidate.exists() and candidate.is_dir():
                return candidate.resolve()
    except Exception:
        pass
    return DEFAULT_ROOT.resolve()

ROOT = load_library_root()
try:
    DEFAULT_ROOT.mkdir(parents=True, exist_ok=True)
    DEFAULT_INCOMING.mkdir(parents=True, exist_ok=True)
except OSError:
    pass


def open_file(path):
    """Open a document with its Windows default application, with a fallback."""
    path = Path(path)
    try:
        os.startfile(str(path), "open")
        return True
    except Exception:
        try:
            subprocess.Popen(["explorer.exe", str(path)])
            return True
        except Exception:
            return False


def open_folder(path):
    """Open the containing folder in Windows Explorer."""
    path = Path(path)
    try:
        os.startfile(str(path.parent), "open")
        return True
    except Exception:
        try:
            subprocess.Popen(["explorer.exe", str(path.parent)])
            return True
        except Exception:
            return False


class DB:
    def __init__(self):
        self.conn = sqlite3.connect(DB_PATH)
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS files (
                path TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                ext TEXT NOT NULL,
                modified REAL NOT NULL,
                pages INTEGER,
                status TEXT NOT NULL DEFAULT 'Not started',
                due_date TEXT,
                priority TEXT NOT NULL DEFAULT 'Normal'
            )
        """)
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS recent_searches (
                query TEXT PRIMARY KEY,
                last_used REAL NOT NULL
            )
        """)
        # Kept for compatibility with older versions. V2 no longer uses
        # saved custom filters.
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS saved_filters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                conditions TEXT NOT NULL
            )
        """)
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL
            )
        """)
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS file_tags (
                path TEXT NOT NULL,
                tag_id INTEGER NOT NULL,
                PRIMARY KEY(path, tag_id)
            )
        """)
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
        self.conn.commit()

    def upsert(self, p, modified, pages):
        s = str(p)
        self.conn.execute("""
            INSERT INTO files(path,name,ext,modified,pages)
            VALUES(?,?,?,?,?)
            ON CONFLICT(path) DO UPDATE SET
                name=excluded.name,
                ext=excluded.ext,
                modified=excluded.modified,
                pages=excluded.pages
        """, (s, p.name, p.suffix.lower(), modified, pages))

    def delete_missing(self, found):
        rows = self.conn.execute("SELECT path FROM files").fetchall()
        missing = [(path,) for (path,) in rows if path not in found]
        if missing:
            self.conn.executemany(
                "DELETE FROM files WHERE path=?", missing
            )
            self.conn.executemany(
                "DELETE FROM file_tags WHERE path=?", missing
            )
        self.conn.commit()

    def commit(self):
        self.conn.commit()

    def search_rows(self, query):
        q = query.strip().lower()
        if not q:
            return []
        like = f"%{q}%"
        return self.conn.execute("""
            SELECT path,name,ext,modified,pages,status,due_date,priority
            FROM files
            WHERE lower(name) LIKE ? OR lower(path) LIKE ?
            LIMIT 500
        """, (like, like)).fetchall()

    def rows(self):
        return self.conn.execute("""
            SELECT path,name,ext,modified,pages,status,due_date,priority
            FROM files
        """).fetchall()

    def get_file(self, path):
        return self.conn.execute("""
            SELECT path,name,ext,modified,pages,status,due_date,priority
            FROM files WHERE path=?
        """, (str(path),)).fetchone()

    def update(self, path, field, value):
        if field not in {"status", "due_date", "priority"}:
            return
        self.conn.execute(
            f"UPDATE files SET {field}=? WHERE path=?", (value, str(path))
        )
        self.conn.commit()

    def add_recent(self, query):
        if not query.strip():
            return
        self.conn.execute("""
            INSERT INTO recent_searches(query,last_used)
            VALUES(?,?)
            ON CONFLICT(query) DO UPDATE SET last_used=excluded.last_used
        """, (query.strip(), datetime.now().timestamp()))
        self.conn.commit()

    def recents(self):
        return self.conn.execute(
            "SELECT query FROM recent_searches ORDER BY last_used DESC LIMIT 12"
        ).fetchall()

    def get_tags(self, path):
        return [
            r[0] for r in self.conn.execute("""
                SELECT t.name
                FROM tags t JOIN file_tags ft ON ft.tag_id=t.id
                WHERE ft.path=? ORDER BY t.name
            """, (str(path),)).fetchall()
        ]

    def add_tag(self, path, name):
        name = name.strip()
        if not name:
            return
        self.conn.execute("INSERT OR IGNORE INTO tags(name) VALUES(?)", (name,))
        tag_id = self.conn.execute(
            "SELECT id FROM tags WHERE name=?", (name,)
        ).fetchone()[0]
        self.conn.execute(
            "INSERT OR IGNORE INTO file_tags(path,tag_id) VALUES(?,?)",
            (str(path), tag_id)
        )
        self.conn.commit()

    def remove_tag(self, path, name):
        row = self.conn.execute(
            "SELECT id FROM tags WHERE name=?", (name,)
        ).fetchone()
        if row:
            self.conn.execute(
                "DELETE FROM file_tags WHERE path=? AND tag_id=?",
                (str(path), row[0])
            )
            self.conn.commit()

    def setting(self, key, default=None):
        row = self.conn.execute(
            "SELECT value FROM settings WHERE key=?", (key,)
        ).fetchone()
        return row[0] if row else default

    def set_setting(self, key, value):
        self.conn.execute("""
            INSERT INTO settings(key,value) VALUES(?,?)
            ON CONFLICT(key) DO UPDATE SET value=excluded.value
        """, (key, value))
        self.conn.commit()



class ScanWorker(QThread):
    finished_scan = Signal(object, object)  # found set, metadata dict
    failed = Signal(str)

    def __init__(self, cached):
        super().__init__()
        self.cached = cached

    def run(self):
        found = set()
        metadata = {}
        try:
            # The expensive PDF page-count operation is only performed for
            # new/changed files. Unchanged PDFs are never reopened.
            for p in ROOT.rglob("*"):
                if not p.is_file():
                    continue
                try:
                    p = p.resolve()
                except OSError:
                    continue
                # Search Repository is intentionally allowed even though it
                # lives inside the Digi installation directory. Only Digi's
                # internal Cache and the separate Incoming staging folder are
                # excluded from indexing.
                try:
                    if CACHE_DIR == p or CACHE_DIR in p.parents:
                        continue
                    if DEFAULT_INCOMING == p or DEFAULT_INCOMING in p.parents:
                        continue
                except Exception:
                    pass
                if p.suffix.lower() not in SUPPORTED:
                    continue

                path_str = str(p)
                found.add(path_str)
                try:
                    modified = p.stat().st_mtime
                except OSError:
                    continue

                old = self.cached.get(path_str)
                if old and old[0] == modified:
                    pages = old[1]
                else:
                    pages = None
                    if p.suffix.lower() == ".pdf" and fitz:
                        try:
                            with fitz.open(str(p)) as doc:
                                pages = len(doc)
                        except Exception:
                            pages = None

                metadata[path_str] = (p, modified, pages)

            self.finished_scan.emit(found, metadata)
        except Exception as exc:
            self.failed.emit(str(exc))



class ResultDelegate(QStyledItemDelegate):
    """Rounded, responsive search-result cards with expandable directory details."""
    def paint(self, painter, option, index):
        painter.save()
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        is_child = index.parent().isValid()

        if is_child:
            rect = option.rect.adjusted(12, 1, -12, -1)
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor("#383b40"))
            painter.drawRoundedRect(rect, 8, 8)

            folder = index.data(Qt.ItemDataRole.UserRole + 2) or ""
            meta = index.data(Qt.ItemDataRole.UserRole + 3) or ""
            font = QFont(option.font)
            font.setPointSize(max(8, option.font.pointSize() - 1))
            painter.setFont(font)
            colour = option.palette.color(QPalette.ColorRole.Text)
            colour.setAlpha(150)
            painter.setPen(colour)
            painter.drawText(rect.adjusted(14, 5, -14, -24),
                             Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                             folder)
            colour2 = option.palette.color(QPalette.ColorRole.Text)
            colour2.setAlpha(115)
            painter.setPen(colour2)
            painter.drawText(rect.adjusted(14, 25, -14, -3),
                             Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                             meta)
        else:
            rect = option.rect.adjusted(6, 4, -6, -4)
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(
                option.palette.highlight() if selected else QColor("#3f4247")
            )
            painter.drawRoundedRect(rect, 10, 10)

            name = index.data(Qt.ItemDataRole.UserRole + 1) or ""
            meta = index.data(Qt.ItemDataRole.UserRole + 3) or ""

            name_font = QFont(option.font)
            name_font.setBold(True)
            name_font.setPointSize(max(10, option.font.pointSize() + 1))
            painter.setFont(name_font)
            text_role = (
                QPalette.ColorRole.HighlightedText
                if selected else QPalette.ColorRole.Text
            )
            painter.setPen(option.palette.color(text_role))
            painter.drawText(rect.adjusted(30, 8, -14, -35),
                             Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                             name)

            meta_font = QFont(option.font)
            meta_font.setPointSize(max(8, option.font.pointSize() - 1))
            painter.setFont(meta_font)
            meta_colour = option.palette.color(text_role)
            if not selected:
                meta_colour.setAlpha(145)
            painter.setPen(meta_colour)
            painter.drawText(rect.adjusted(30, 38, -14, -7),
                             Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                             meta)

        painter.restore()

    def sizeHint(self, option, index):
        size = super().sizeHint(option, index)
        size.setHeight(78 if not index.parent().isValid() else 54)
        return size


class SplashScreen(QWidget):
    """Short branded startup screen with a subtle fade animation."""
    def __init__(self):
        super().__init__(
            None,
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.SplashScreen |
            Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedSize(760, 507)

        self.background = QLabel(self)
        self.background.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.background.setStyleSheet(
            "background:#05070a;border-radius:18px;"
        )

        splash_path = resource_path("digi_splash.png")
        if splash_path.exists():
            pixmap = QPixmap(str(splash_path))
            self.background.setPixmap(
                pixmap.scaled(
                    self.size(),
                    Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                    Qt.TransformationMode.SmoothTransformation
                )
            )

        self.background.setGeometry(self.rect())

        self.opacity_effect = QGraphicsOpacityEffect(self.background)
        self.background.setGraphicsEffect(self.opacity_effect)
        self.opacity_effect.setOpacity(0.0)

        self.fade_in = QPropertyAnimation(
            self.opacity_effect, b"opacity", self
        )
        self.fade_in.setDuration(650)
        self.fade_in.setStartValue(0.0)
        self.fade_in.setEndValue(1.0)
        self.fade_in.setEasingCurve(QEasingCurve.Type.OutCubic)

        self.fade_out = QPropertyAnimation(
            self.opacity_effect, b"opacity", self
        )
        self.fade_out.setDuration(500)
        self.fade_out.setStartValue(1.0)
        self.fade_out.setEndValue(0.0)
        self.fade_out.setEasingCurve(QEasingCurve.Type.InCubic)

        screen = QApplication.primaryScreen()
        if screen:
            area = screen.availableGeometry()
            self.move(
                area.center().x() - self.width() // 2,
                area.center().y() - self.height() // 2
            )

    def start(self, finished_callback):
        self.finished_callback = finished_callback
        self.show()
        self.raise_()
        self.fade_in.start()
        # Total startup presentation is about 3.5 seconds including fade-out.
        QTimer.singleShot(3000, self.finish)

    def finish(self):
        self.fade_out.finished.connect(self._finish_done)
        self.fade_out.start()

    def _finish_done(self):
        if hasattr(self, "finished_callback"):
            self.finished_callback()
        self.close()




class NoteCanvas(QWidget):
    """Stylus-first, touch-friendly infinite-ish canvas with zoom, pan and insert tools."""
    changed = Signal()

    def __init__(self):
        super().__init__()
        self.setMinimumSize(500, 400)
        self.setAttribute(Qt.WidgetAttribute.WA_StaticContents, True)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)
        self.grabGesture(Qt.GestureType.PinchGesture)

        self.image = QImage(1800, 1200, QImage.Format.Format_ARGB32_Premultiplied)
        self.image.fill(QColor("white"))
        self.zoom = 1.0
        self.pan = QPointF(0, 0)
        self.last_point = None
        self.last_screen = None
        self.panning = False
        self.tool = "pen"
        self.pen_width = 5
        self.pen_colour = QColor("#202124")
        self.marker_colour = QColor("#ffd84d")
        self.highlighter_colour = QColor("#66b3ff")
        self._last_touch_distance = None

    def set_tool(self, tool):
        self.tool = tool
        self.update()

    def set_colour(self, colour):
        self.pen_colour = QColor(colour)
        self.tool = "pen"
        self.update()

    def clear(self):
        self.image.fill(QColor("white"))
        self.pan = QPointF(0, 0)
        self.zoom = 1.0
        self.update()
        self.changed.emit()

    def load(self, path):
        pix = QImage(str(path))
        if not pix.isNull():
            self.image = pix.convertToFormat(QImage.Format.Format_ARGB32_Premultiplied)
            self.zoom = 1.0
            self.pan = QPointF(0, 0)
            self.update()

    def save(self, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image.save(str(path), "PNG")

    def _canvas_rect(self):
        w = self.image.width() * self.zoom
        h = self.image.height() * self.zoom
        x = (self.width() - w) / 2 + self.pan.x()
        y = (self.height() - h) / 2 + self.pan.y()
        return x, y, w, h

    def _image_point(self, pos):
        x, y, w, h = self._canvas_rect()
        if pos.x() < x or pos.y() < y or pos.x() >= x + w or pos.y() >= y + h:
            return None
        return (
            int((pos.x() - x) / self.zoom),
            int((pos.y() - y) / self.zoom)
        )

    def _expand_if_needed(self, point, margin=160):
        """Grow the backing image as the pen approaches any edge."""
        x, y = point
        left = top = right = bottom = 0
        if x < margin:
            left = max(600, margin * 2)
        if y < margin:
            top = max(500, margin * 2)
        if x > self.image.width() - margin:
            right = max(900, margin * 3)
        if y > self.image.height() - margin:
            bottom = max(700, margin * 3)
        if not any((left, top, right, bottom)):
            return point

        old = self.image
        new = QImage(
            old.width() + left + right,
            old.height() + top + bottom,
            QImage.Format.Format_ARGB32_Premultiplied
        )
        new.fill(QColor("white"))
        painter = QPainter(new)
        painter.drawImage(left, top, old)
        painter.end()
        self.image = new
        # Keep the visible old content anchored when growing upward/leftward.
        self.pan += QPointF(-left * self.zoom, -top * self.zoom)
        return x + left, y + top

    def _draw_segment(self, a, b, tool=None):
        tool = tool or self.tool
        if tool == "eraser":
            colour = QColor(255, 255, 255, 255)
            width = max(18, self.pen_width * 4)
            composition = QPainter.CompositionMode.CompositionMode_Source
        elif tool == "marker":
            colour = QColor(self.pen_colour)
            colour.setAlpha(235)
            width = max(8, self.pen_width * 2)
            composition = QPainter.CompositionMode.CompositionMode_SourceOver
        elif tool == "highlighter":
            colour = QColor(self.highlighter_colour)
            colour.setAlpha(80)
            width = max(18, self.pen_width * 5)
            composition = QPainter.CompositionMode.CompositionMode_SourceOver
        else:
            colour = QColor(self.pen_colour)
            width = self.pen_width
            composition = QPainter.CompositionMode.CompositionMode_SourceOver

        painter = QPainter(self.image)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setCompositionMode(composition)
        painter.setPen(QPen(
            colour, width, Qt.PenStyle.SolidLine,
            Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin
        ))
        painter.drawLine(a[0], a[1], b[0], b[1])
        painter.end()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.fillRect(self.rect(), QColor("#3f4247"))
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        x, y, w, h = self._canvas_rect()
        target = QRectF(x, y, w, h)
        painter.drawImage(target, self.image)
        painter.setPen(QPen(QColor("#777b82"), 1))
        painter.drawRect(target)
        painter.end()

    def _is_touch_mouse(self, event):
        try:
            return event.source() == Qt.MouseEventSource.MouseEventSynthesizedBySystem
        except Exception:
            return False

    def _begin_stroke(self, pos, eraser=False):
        point = self._image_point(pos)
        if point is None:
            return
        point = self._expand_if_needed(point)
        self.last_point = point
        if eraser:
            self.tool = "eraser"

    def mousePressEvent(self, event):
        if self._is_touch_mouse(event):
            return
        if event.button() == Qt.MouseButton.RightButton:
            self._begin_stroke(event.position().toPoint(), eraser=True)
            return
        if event.button() == Qt.MouseButton.LeftButton:
            self._begin_stroke(event.position().toPoint(), eraser=False)

    def mouseMoveEvent(self, event):
        if self._is_touch_mouse(event):
            return
        if self.last_point is None:
            return
        point = self._image_point(event.position().toPoint())
        if point is None:
            return
        point = self._expand_if_needed(point)
        self._draw_segment(self.last_point, point)
        self.last_point = point
        self.update()
        self.changed.emit()

    def mouseReleaseEvent(self, event):
        if event.button() in (Qt.MouseButton.LeftButton, Qt.MouseButton.RightButton):
            self.last_point = None

    # Windows pen/stylus devices can arrive as tablet events. A barrel/button
    # press is treated as an eraser, matching the requested stylus behaviour.
    def tabletPressEvent(self, event):
        buttons = event.buttons()
        self._begin_stroke(event.position().toPoint(),
                           eraser=bool(buttons & Qt.MouseButton.RightButton))
        event.accept()

    def tabletMoveEvent(self, event):
        if self.last_point is None:
            return
        point = self._image_point(event.position().toPoint())
        if point is None:
            return
        point = self._expand_if_needed(point)
        self._draw_segment(self.last_point, point)
        self.last_point = point
        self.update()
        self.changed.emit()
        event.accept()

    def tabletReleaseEvent(self, event):
        self.last_point = None
        event.accept()

    def event(self, event):
        if event.type() == QEvent.Type.Gesture:
            gesture_event = event
            pinch = gesture_event.gesture(Qt.GestureType.PinchGesture)
            if pinch:
                change = pinch.scaleFactor()
                self.zoom = max(0.25, min(5.0, self.zoom * change))
                self.update()
                return True
        if event.type() in {
            QEvent.Type.TouchBegin, QEvent.Type.TouchUpdate,
            QEvent.Type.TouchEnd, QEvent.Type.TouchCancel
        }:
            # Finger touches are navigation only; they never draw.
            return True
        return super().event(event)

    def wheelEvent(self, event):
        # Ctrl + wheel / trackpad wheel provides precise zoom.
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            factor = 1.12 if event.angleDelta().y() > 0 else 0.89
            self.zoom = max(0.25, min(5.0, self.zoom * factor))
            self.update()
            event.accept()
            return
        super().wheelEvent(event)

    def insert_image(self, path):
        img = QImage(str(path))
        if img.isNull():
            return
        max_w = int(self.image.width() * 0.55)
        max_h = int(self.image.height() * 0.55)
        if img.width() > max_w or img.height() > max_h:
            img = img.scaled(max_w, max_h, Qt.AspectRatioMode.KeepAspectRatio,
                             Qt.TransformationMode.SmoothTransformation)
        x = max(20, (self.image.width() - img.width()) // 2)
        y = max(20, (self.image.height() - img.height()) // 2)
        painter = QPainter(self.image)
        painter.drawImage(x, y, img)
        painter.end()
        self.update()
        self.changed.emit()

    def insert_text(self, text):
        if not text.strip():
            return
        painter = QPainter(self.image)
        font = QFont("Segoe UI", 34)
        painter.setFont(font)
        painter.setPen(QColor("#202124"))
        rect = QRectF(100, 100, self.image.width() - 200, 100)
        painter.drawText(rect, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter, text)
        painter.end()
        self.update()
        self.changed.emit()


class NotesDialog(QDialog):
    """Digi Notes with stylus tools, nested folders, backup-friendly pages and inserts."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Digi Notes")
        self.resize(1250, 780)
        self.setMinimumSize(900, 600)
        self.notes_dir = ROOT / "Digi Notes"
        self.notes_dir.mkdir(parents=True, exist_ok=True)
        self.current_file = None
        self.dirty = False

        root = QVBoxLayout(self)

        top = QHBoxLayout()
        top.addWidget(QLabel("Notebook / folder:"))
        self.path_label = QLabel("—")
        self.path_label.setStyleSheet("font-weight:bold;")
        top.addWidget(self.path_label)
        top.addStretch()

        for label, slot in [
            ("+ Notebook", self.create_notebook),
            ("+ Sub-page folder", self.create_subfolder),
            ("+ Page", self.new_page),
            ("Move up", lambda: self.move_page(-1)),
            ("Move down", lambda: self.move_page(1)),
            ("Insert image", self.insert_image),
            ("Insert text", self.insert_text),
        ]:
            b = QPushButton(label)
            b.clicked.connect(slot)
            top.addWidget(b)
        root.addLayout(top)

        split = QSplitter(Qt.Orientation.Horizontal)

        self.tree = QTreeWidget()
        self.tree.setHeaderHidden(True)
        self.tree.setMinimumWidth(260)
        self.tree.itemClicked.connect(self.tree_selected)
        self.tree.setDragDropMode(QTreeWidget.DragDropMode.InternalMove)
        split.addWidget(self.tree)

        right = QWidget()
        rv = QVBoxLayout(right)
        self.canvas = NoteCanvas()
        self.canvas.changed.connect(self.mark_dirty)
        rv.addWidget(self.canvas, 1)

        tools = QHBoxLayout()
        self.tool_buttons = {}
        for label, tool in [
            ("Pen", "pen"), ("Eraser", "eraser"),
            ("Marker", "marker"), ("Highlighter", "highlighter"),
        ]:
            b = QPushButton(label)
            b.setCheckable(True)
            b.clicked.connect(lambda checked, t=tool: self.select_tool(t))
            tools.addWidget(b)
            self.tool_buttons[tool] = b

        colour_btn = QPushButton("Colour")
        colour_btn.clicked.connect(self.choose_colour)
        tools.addWidget(colour_btn)

        tools.addWidget(QLabel("Size"))
        self.size_combo = QComboBox()
        self.size_combo.addItems(["2", "4", "6", "10", "16", "24", "32"])
        self.size_combo.setCurrentText("5" if "5" in [self.size_combo.itemText(i) for i in range(self.size_combo.count())] else "6")
        self.size_combo.currentTextChanged.connect(
            lambda v: setattr(self.canvas, "pen_width", int(v))
        )
        tools.addWidget(self.size_combo)

        zoom_out = QPushButton("−")
        zoom_out.clicked.connect(lambda: self.zoom_by(0.85))
        tools.addWidget(zoom_out)
        zoom_reset = QPushButton("100%")
        zoom_reset.clicked.connect(lambda: self.set_zoom(1.0))
        tools.addWidget(zoom_reset)
        zoom_in = QPushButton("+")
        zoom_in.clicked.connect(lambda: self.zoom_by(1.18))
        tools.addWidget(zoom_in)

        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self.clear_page)
        tools.addWidget(clear_btn)

        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_page)
        tools.addWidget(save_btn)
        rv.addLayout(tools)

        split.addWidget(right)
        split.setStretchFactor(0, 2)
        split.setStretchFactor(1, 8)
        root.addWidget(split, 1)

        self.populate_tree()
        self.select_tool("pen")

    def safe_name(self, name, fallback="Untitled"):
        safe = "".join(c for c in name.strip() if c not in '<>:"/\\|?*').strip()
        return safe or fallback

    def populate_tree(self):
        self.tree.clear()
        for notebook in sorted(
            [p for p in self.notes_dir.iterdir() if p.is_dir()],
            key=lambda p: p.name.casefold()
        ):
            root_item = QTreeWidgetItem([notebook.name])
            root_item.setData(0, Qt.ItemDataRole.UserRole, str(notebook))
            root_item.setData(0, Qt.ItemDataRole.UserRole + 1, "folder")
            self.tree.addTopLevelItem(root_item)
            self._add_note_children(root_item, notebook)

    def _add_note_children(self, item, folder):
        entries = sorted(
            [p for p in folder.iterdir() if p.is_dir() or p.suffix.lower() == ".png"],
            key=lambda p: (p.is_file(), p.name.casefold())
        )
        for p in entries:
            child = QTreeWidgetItem([p.stem if p.is_file() else p.name])
            child.setData(0, Qt.ItemDataRole.UserRole, str(p))
            child.setData(0, Qt.ItemDataRole.UserRole + 1, "page" if p.is_file() else "folder")
            item.addChild(child)
            if p.is_dir():
                self._add_note_children(child, p)

    def current_folder(self):
        item = self.tree.currentItem()
        if not item:
            return self.notes_dir
        path = Path(item.data(0, Qt.ItemDataRole.UserRole))
        return path if path.is_dir() else path.parent

    def tree_selected(self, item, column):
        if not item:
            return
        path = Path(item.data(0, Qt.ItemDataRole.UserRole))
        kind = item.data(0, Qt.ItemDataRole.UserRole + 1)
        if kind == "folder":
            self.path_label.setText(str(path.relative_to(self.notes_dir)) if path != self.notes_dir else "Digi Notes")
            return
        self.select_page_path(path)

    def select_page_path(self, path):
        if self.dirty and self.current_file:
            self.save_page()
        self.current_file = Path(path)
        self.canvas.load(self.current_file)
        rel = self.current_file.relative_to(self.notes_dir)
        self.path_label.setText(str(rel))
        self.dirty = False

    def create_notebook(self):
        name, ok = QInputDialog.getText(self, "New notebook", "Notebook name:")
        if not ok:
            return
        name = self.safe_name(name, "")
        if not name:
            return
        (self.notes_dir / name).mkdir(parents=True, exist_ok=True)
        self.populate_tree()

    def create_subfolder(self):
        parent = self.current_folder()
        name, ok = QInputDialog.getText(self, "New sub-page folder", "Folder name:")
        if not ok:
            return
        name = self.safe_name(name, "")
        if not name:
            return
        (parent / name).mkdir(parents=True, exist_ok=True)
        self.populate_tree()

    def new_page(self):
        folder = self.current_folder()
        nums = []
        for p in folder.glob("*.png"):
            m = re.search(r"(\d+)", p.stem)
            if m:
                nums.append(int(m.group(1)))
        n = max(nums, default=0) + 1
        path = folder / f"Page {n:03d}.png"
        self.canvas.clear()
        self.canvas.save(path)
        self.populate_tree()
        self._select_path_in_tree(path)

    def _select_path_in_tree(self, path):
        path = Path(path)
        def walk(item):
            for i in range(item.childCount()):
                child = item.child(i)
                p = Path(child.data(0, Qt.ItemDataRole.UserRole))
                if p == path:
                    self.tree.setCurrentItem(child)
                    self.tree_selected(child, 0)
                    return True
                if child.childCount() and walk(child):
                    child.setExpanded(True)
                    return True
            return False
        for i in range(self.tree.topLevelItemCount()):
            if walk(self.tree.topLevelItem(i)):
                return

    def move_page(self, delta):
        item = self.tree.currentItem()
        if not item or item.data(0, Qt.ItemDataRole.UserRole + 1) != "page":
            return
        current = Path(item.data(0, Qt.ItemDataRole.UserRole))
        siblings = sorted(current.parent.glob("*.png"), key=lambda p: p.name.casefold())
        try:
            idx = siblings.index(current)
        except ValueError:
            return
        target_idx = idx + delta
        if target_idx < 0 or target_idx >= len(siblings):
            return
        other = siblings[target_idx]
        temp = current.with_name(f".digi_swap_{os.getpid()}_{current.name}")
        try:
            current.rename(temp)
            other.rename(current)
            temp.rename(other)
        except OSError as exc:
            try:
                if temp.exists() and not current.exists():
                    temp.rename(current)
            except OSError:
                pass
            QMessageBox.warning(self, "Move failed", str(exc))
            return
        self.populate_tree()
        self._select_path_in_tree(other)

    def rename_page(self):
        item = self.tree.currentItem()
        if not item or item.data(0, Qt.ItemDataRole.UserRole + 1) != "page":
            return
        old = Path(item.data(0, Qt.ItemDataRole.UserRole))
        name, ok = QInputDialog.getText(self, "Rename page", "Page name:", text=old.stem)
        if not ok:
            return
        new = old.with_name(self.safe_name(name) + ".png")
        if new.exists() and new != old:
            QMessageBox.warning(self, "Already exists", "A page with that name already exists.")
            return
        old.rename(new)
        self.populate_tree()
        self._select_path_in_tree(new)

    def delete_page(self):
        item = self.tree.currentItem()
        if not item:
            return
        path = Path(item.data(0, Qt.ItemDataRole.UserRole))
        if item.data(0, Qt.ItemDataRole.UserRole + 1) == "folder":
            if QMessageBox.question(self, "Delete folder", f"Delete '{path.name}' and everything inside it?") != QMessageBox.StandardButton.Yes:
                return
            shutil.rmtree(path, ignore_errors=True)
        else:
            if QMessageBox.question(self, "Delete page", f"Delete '{path.stem}'?") != QMessageBox.StandardButton.Yes:
                return
            try:
                path.unlink()
            except OSError as exc:
                QMessageBox.warning(self, "Delete failed", str(exc))
        self.current_file = None
        self.dirty = False
        self.populate_tree()

    def select_tool(self, tool):
        self.canvas.set_tool(tool)
        for name, button in self.tool_buttons.items():
            button.setChecked(name == tool)

    def choose_colour(self):
        from PySide6.QtWidgets import QColorDialog
        colour = QColorDialog.getColor(self.canvas.pen_colour, self, "Pen colour")
        if colour.isValid():
            self.canvas.set_colour(colour.name())

    def zoom_by(self, factor):
        self.canvas.zoom = max(0.25, min(5.0, self.canvas.zoom * factor))
        self.canvas.update()

    def set_zoom(self, value):
        self.canvas.zoom = value
        self.canvas.update()

    def clear_page(self):
        if QMessageBox.question(self, "Clear page", "Clear the current page?") == QMessageBox.StandardButton.Yes:
            self.canvas.clear()

    def insert_image(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Insert image", str(ROOT),
            "Images (*.png *.jpg *.jpeg *.bmp *.webp)"
        )
        if path:
            self.canvas.insert_image(path)

    def insert_text(self):
        value, ok = QInputDialog.getMultiLineText(self, "Insert text", "Text:")
        if ok and value.strip():
            self.canvas.insert_text(value)

    def mark_dirty(self):
        self.dirty = True

    def save_page(self):
        if self.current_file:
            self.canvas.save(self.current_file)
            self.dirty = False

    def closeEvent(self, event):
        if self.dirty and self.current_file:
            self.save_page()
        event.accept()



class ConversionWorker(QThread):
    log = Signal(str)
    finished = Signal(bool, str, str)

    def __init__(self, source, target_kind, parent=None):
        super().__init__(parent)
        self.source = Path(source)
        self.target_kind = target_kind

    def run(self):
        source = self.source
        try:
            if not source.exists():
                raise FileNotFoundError(f"Source file does not exist: {source}")

            target_ext = ".pdf" if self.target_kind == "pdf" else ".docx"
            target = source.with_suffix(target_ext)

            self.log.emit(f">>> SOURCE: {source}")
            self.log.emit(f">>> TARGET: {target}")
            self.log.emit(f">>> MODE: {source.suffix.lower()} -> {target_ext}")

            if source.suffix.lower() == target_ext:
                raise ValueError(
                    f"This file is already a {target_ext.upper().lstrip('.') if target_ext != '.docx' else 'Word document'}."
                )

            if target.exists():
                self.log.emit(">>> Target already exists; replacing it after confirmation.")
                try:
                    target.unlink()
                except Exception as exc:
                    raise RuntimeError(f"Could not replace the existing target file: {exc}")

            if target_ext == ".docx":
                self.pdf_to_docx(source, target)
            else:
                self.docx_to_pdf(source, target)

            if not target.exists() or target.stat().st_size == 0:
                raise RuntimeError("The converter reported success, but no usable output file was created.")

            self.log.emit(f">>> COMPLETE: {target}")
            self.finished.emit(True, "Conversion completed successfully.", str(target))

        except Exception as exc:
            self.log.emit(f">>> FATAL ERROR: {type(exc).__name__}: {exc}")
            self.finished.emit(False, str(exc), "")

    def pdf_to_docx(self, source, target):
        """Convert each PDF page into a lossless PNG image inside a DOCX.
        The resulting Word document is intentionally image-based so its visual
        appearance matches the PDF pages rather than extracting/reflowing text.
        """
        self.log.emit(">>> Loading PyMuPDF...")
        if fitz is None:
            raise RuntimeError("PyMuPDF is not installed.")

        try:
            from docx import Document
            from docx.shared import Inches
            from docx.enum.text import WD_ALIGN_PARAGRAPH
            from docx.enum.section import WD_SECTION
        except ImportError:
            raise RuntimeError("python-docx is not installed. Run run.bat again to install it.")

        self.log.emit(">>> Creating image-based Word document...")
        doc = Document()
        pdf = fitz.open(str(source))
        page_records = []

        try:
            total = len(pdf)
            for number, page in enumerate(pdf, 1):
                self.log.emit(f">>> Rendering PDF page {number}/{total} as a lossless PNG...")

                # 200 DPI gives a good balance for exam papers while PNG remains
                # lossless (no JPEG-style quality reduction).
                dpi = 200
                scale = dpi / 72.0
                pix = page.get_pixmap(
                    matrix=fitz.Matrix(scale, scale),
                    alpha=False
                )
                png_bytes = pix.tobytes("png")

                page_width_pt = float(page.rect.width)
                page_height_pt = float(page.rect.height)
                page_records.append({
                    "page": number,
                    "width_pt": page_width_pt,
                    "height_pt": page_height_pt,
                    "png": png_bytes
                })
        finally:
            pdf.close()

        if not page_records:
            raise RuntimeError("The PDF contains no pages.")

        # Build one Word page per PDF page. Images are stored as PNGs without
        # lossy compression and Word is instructed not to recompress them.
        for idx, record in enumerate(page_records):
            if idx == 0:
                section = doc.sections[0]
            else:
                section = doc.add_section(WD_SECTION.NEW_PAGE)

            width_in = record["width_pt"] / 72.0
            height_in = record["height_pt"] / 72.0
            section.page_width = Inches(width_in)
            section.page_height = Inches(height_in)
            section.top_margin = Inches(0)
            section.bottom_margin = Inches(0)
            section.left_margin = Inches(0)
            section.right_margin = Inches(0)
            section.header_distance = Inches(0)
            section.footer_distance = Inches(0)

            paragraph = doc.add_paragraph()
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
            paragraph.paragraph_format.space_before = Inches(0)
            paragraph.paragraph_format.space_after = Inches(0)
            paragraph.paragraph_format.line_spacing = 1
            paragraph.add_run().add_picture(
                io.BytesIO(record["png"]),
                width=Inches(width_in),
                height=Inches(height_in)
            )

        self.log.emit(">>> Saving lossless page images into .docx...")
        doc.core_properties.comments = (
            "Digi Search Engine page-image PDF conversion. "
            "Each PDF page is stored as a lossless PNG image."
        )
        doc.save(str(target))

        # Add a private marker and page metadata so converting this DOCX back
        # to PDF can restore the PNG page images directly instead of sending
        # them through Word/LibreOffice and risking recompression.
        marker = {
            "format": "digi-page-image-docx-v1",
            "source_name": source.name,
            "dpi": 200,
            "pages": [
                {
                    "page": r["page"],
                    "width_pt": r["width_pt"],
                    "height_pt": r["height_pt"],
                    "media": f"word/media/image{i+1}.png"
                }
                for i, r in enumerate(page_records)
            ]
        }

        temp = target.with_suffix(".tmp.docx")
        with zipfile.ZipFile(target, "r") as zin, zipfile.ZipFile(
            temp, "w", compression=zipfile.ZIP_DEFLATED
        ) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                # Replace Word's settings with a version that explicitly
                # requests that pictures are not recompressed.
                if item.filename == "word/settings.xml":
                    try:
                        root = ET.fromstring(data)
                        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
                        if root.find("w:doNotCompressPictures", ns) is None:
                            root.append(ET.Element("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}doNotCompressPictures"))
                        data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
                    except Exception:
                        pass
                zout.writestr(item, data)

            zout.writestr(
                "word/digi_search_engine_page_images.json",
                json.dumps(marker, indent=2).encode("utf-8")
            )

        temp.replace(target)
        self.log.emit(">>> PNG images stored without lossy compression.")

    def docx_to_pdf(self, source, target):
        """Convert Word to PDF.
        Digi page-image DOCX files are restored directly from their embedded
        lossless PNGs. Other DOCX files use Microsoft Word/LibreOffice.
        """
        # First check whether this is a DOCX created by Digi's PDF->Word
        # image-preserving converter.
        try:
            with zipfile.ZipFile(source, "r") as zin:
                marker_name = "word/digi_search_engine_page_images.json"
                if marker_name in zin.namelist():
                    marker = json.loads(zin.read(marker_name).decode("utf-8"))
                    pages = marker.get("pages", [])
                    if not pages:
                        raise RuntimeError("The Digi page-image document contains no page images.")

                    self.log.emit(">>> Digi page-image document detected.")
                    self.log.emit(">>> Restoring original lossless PNG page images directly...")
                    pdf = fitz.open()
                    try:
                        for idx, record in enumerate(pages, 1):
                            media = record["media"]
                            png = zin.read(media)
                            width_pt = float(record["width_pt"])
                            height_pt = float(record["height_pt"])
                            self.log.emit(
                                f">>> Restoring page {idx}/{len(pages)} "
                                f"({width_pt:.1f} x {height_pt:.1f} pt)..."
                            )
                            page = pdf.new_page(width=width_pt, height=height_pt)
                            page.insert_image(
                                fitz.Rect(0, 0, width_pt, height_pt),
                                stream=png,
                                keep_proportion=False
                            )

                        pdf.save(
                            str(target),
                            deflate=True,
                            clean=True
                        )
                    finally:
                        pdf.close()

                    self.log.emit(">>> PDF rebuilt from PNG page images.")
                    self.log.emit(">>> No lossy JPEG recompression was used.")
                    return
        except zipfile.BadZipFile:
            pass
        except Exception as exc:
            self.log.emit(f">>> Page-image restoration unavailable: {exc}")
            self.log.emit(">>> Falling back to standard Word conversion...")

        self.log.emit(">>> Attempting Microsoft Word conversion...")
        try:
            import pythoncom
            import win32com.client
            pythoncom.CoInitialize()
            try:
                word = win32com.client.DispatchEx("Word.Application")
                word.Visible = False
                document = word.Documents.Open(str(source.resolve()))
                try:
                    document.ExportAsFixedFormat(
                        str(target.resolve()), 17,
                        OpenAfterExport=False,
                        OptimizeFor=0,
                        CreateBookmarks=0
                    )
                finally:
                    document.Close(False)
                    word.Quit()
            finally:
                pythoncom.CoUninitialize()
            self.log.emit(">>> Microsoft Word conversion completed.")
            return
        except Exception as word_error:
            self.log.emit(f">>> Microsoft Word unavailable/failed: {word_error}")
            self.log.emit(">>> Trying LibreOffice fallback...")

        libre = shutil.which("soffice") or shutil.which("libreoffice")
        if not libre:
            raise RuntimeError(
                "Word-to-PDF requires Microsoft Word or LibreOffice to be installed on this PC."
            )

        outdir = str(target.parent)
        proc = subprocess.run(
            [libre, "--headless", "--convert-to", "pdf", "--outdir", outdir, str(source)],
            capture_output=True, text=True, timeout=120
        )
        if proc.stdout.strip():
            self.log.emit(proc.stdout.strip())
        if proc.stderr.strip():
            self.log.emit(proc.stderr.strip())
        if proc.returncode != 0:
            raise RuntimeError(f"LibreOffice conversion failed with code {proc.returncode}.")
        generated = target.parent / (source.stem + ".pdf")
        if generated != target and generated.exists():
            shutil.move(str(generated), str(target))


class ConversionDialog(QDialog):
    def __init__(self, source, target_kind, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Digi Search Engine — Conversion")
        self.resize(720, 480)
        self.setModal(True)
        self.worker = ConversionWorker(source, target_kind, self)

        layout = QVBoxLayout(self)
        self.title = QLabel(
            f"Converting <b>{Path(source).name}</b> to "
            f"<b>{'PDF' if target_kind == 'pdf' else 'Word document'}</b>..."
        )
        self.title.setWordWrap(True)
        layout.addWidget(self.title)

        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setStyleSheet(
            "QTextEdit { background:#17191d; color:#b9c0ca; "
            "font-family:Consolas,monospace; font-size:11px; "
            "border:1px solid #30343b; border-radius:10px; padding:8px; }"
        )
        layout.addWidget(self.log_view, 1)

        self.conversion_ok = False
        self.output_path = ""

        self.result = QLabel("Working...")
        self.result.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.result.setStyleSheet("font-size:22px; padding:10px;")
        layout.addWidget(self.result)

        self.close_btn = QPushButton("Please wait…")
        self.close_btn.setEnabled(False)
        self.close_btn.clicked.connect(self.accept)
        layout.addWidget(self.close_btn)

        self.worker.log.connect(self.append_log)
        self.worker.finished.connect(self.complete)
        self.worker.start()

    def append_log(self, text):
        self.log_view.append(text)

    def complete(self, ok, message, output):
        self.conversion_ok = bool(ok)
        self.output_path = output or ""
        if ok:
            self.result.setText("☺  ✓  Conversion complete")
            self.result.setStyleSheet(
                "font-size:24px; font-weight:600; padding:10px;"
            )
            self.close_btn.setText("Done")
            self.close_btn.setEnabled(True)
        else:
            self.result.setText("☹  ✕  Conversion failed")
            self.result.setStyleSheet(
                "font-size:24px; font-weight:600; padding:10px;"
            )
            self.close_btn.setText("Close")
            self.close_btn.setEnabled(True)
            QMessageBox.critical(self, "Conversion failed", message)

class FolderBrowserDialog(QDialog):
    """Scalable folder picker for the Search Repository.

    A tree is used instead of cascading QMenus so an arbitrary number of
    folders/subfolders can be browsed without menus running off-screen.
    """

    def __init__(self, root, parent=None):
        super().__init__(parent)
        self.root = Path(root).resolve()
        self.selected_folder = None
        self.setWindowTitle("Folders — Search Repository")
        self.resize(720, 560)
        self.setMinimumSize(560, 420)

        layout = QVBoxLayout(self)

        title = QLabel("Search Repository")
        title.setStyleSheet("font-size:16px;font-weight:bold;")
        layout.addWidget(title)

        hint = QLabel(
            "Expand folders to browse subfolders. Right-click a folder to create or delete folders and documents."
        )
        hint.setStyleSheet("color:#777;")
        layout.addWidget(hint)

        self.tree = QTreeWidget()
        self.tree.setHeaderHidden(True)
        self.tree.setUniformRowHeights(True)
        self.tree.setAnimated(True)
        self.tree.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.tree.customContextMenuRequested.connect(self._show_context_menu)
        self.tree.itemSelectionChanged.connect(self._selection_changed)
        self.tree.itemDoubleClicked.connect(self._double_clicked)
        layout.addWidget(self.tree, 1)

        buttons = QHBoxLayout()
        self.show_files_btn = QPushButton("Show files inside this folder")
        self.show_files_btn.setEnabled(False)
        self.show_files_btn.clicked.connect(self._accept_selected)
        buttons.addWidget(self.show_files_btn)

        expand_btn = QPushButton("Expand all")
        expand_btn.clicked.connect(self.tree.expandAll)
        buttons.addWidget(expand_btn)

        collapse_btn = QPushButton("Collapse all")
        collapse_btn.clicked.connect(self.tree.collapseAll)
        buttons.addWidget(collapse_btn)

        close_btn = QPushButton("Close")
        close_btn.clicked.connect(self.reject)
        buttons.addWidget(close_btn)

        layout.addLayout(buttons)
        self._populate()

    def _context_folder(self, pos):
        """Return the folder under the context-menu position, or the repository root."""
        item = self.tree.itemAt(pos)
        if item:
            path = item.data(0, Qt.ItemDataRole.UserRole)
            if path:
                p = Path(path)
                if p.is_dir():
                    return p.resolve()
        return self.root

    def _show_context_menu(self, pos):
        folder = self._context_folder(pos)

        menu = QMenu(self)

        new_menu = menu.addMenu("New")
        new_folder_action = new_menu.addAction("Folder")
        new_menu.addSeparator()
        new_docx_action = new_menu.addAction("Word document (.docx)")
        new_doc_action = new_menu.addAction("Word document (.doc)")
        new_pdf_action = new_menu.addAction("PDF (.pdf)")

        delete_action = menu.addAction("Delete folder")
        delete_action.setEnabled(folder != self.root)

        chosen = menu.exec(self.tree.viewport().mapToGlobal(pos))
        if chosen == new_folder_action:
            self._create_folder(folder)
        elif chosen == new_docx_action:
            self._create_document(folder, "docx")
        elif chosen == new_doc_action:
            self._create_document(folder, "doc")
        elif chosen == new_pdf_action:
            self._create_document(folder, "pdf")
        elif chosen == delete_action:
            self._delete_folder(folder)

    def _ask_name(self, title, label, extension=None):
        name, ok = QInputDialog.getText(self, title, label)
        if not ok:
            return None
        name = name.strip()
        if not name:
            return None
        if extension and not name.lower().endswith(extension):
            name += extension
        return name

    def _create_folder(self, parent_folder):
        name = self._ask_name("New folder", "Folder name:")
        if not name:
            return

        target = parent_folder / name
        if target.exists():
            QMessageBox.warning(self, "Folder already exists",
                                f"'{name}' already exists in this folder.")
            return
        try:
            target.mkdir(parents=False)
        except OSError as exc:
            QMessageBox.critical(self, "Could not create folder",
                                 f"Could not create the folder:\n{exc}")
            return

        self._populate()
        self._select_folder_path(target)

    def _create_document(self, parent_folder, kind):
        labels = {
            "docx": ("New Word document", "Document name:", ".docx"),
            "doc": ("New Word document", "Document name:", ".doc"),
            "pdf": ("New PDF", "Document name:", ".pdf"),
        }
        title, label, extension = labels[kind]
        name = self._ask_name(title, label, extension)
        if not name:
            return

        target = parent_folder / name
        if target.exists():
            QMessageBox.warning(self, "File already exists",
                                f"'{name}' already exists in this folder.")
            return

        try:
            if kind == "docx":
                from docx import Document
                document = Document()
                document.save(str(target))
            elif kind == "pdf":
                if fitz is None:
                    raise RuntimeError("PyMuPDF is not installed, so PDF creation is unavailable.")
                document = fitz.open()
                document.new_page()
                document.save(str(target))
                document.close()
            else:
                # Legacy .doc creation requires Microsoft Word on Windows.
                try:
                    import win32com.client
                except ImportError as exc:
                    raise RuntimeError(
                        "Creating legacy .doc files requires pywin32 and Microsoft Word."
                    ) from exc

                word = None
                document = None
                try:
                    word = win32com.client.DispatchEx("Word.Application")
                    word.Visible = False
                    document = word.Documents.Add()
                    # wdFormatDocument = 0
                    document.SaveAs2(str(target), FileFormat=0)
                finally:
                    if document is not None:
                        document.Close(False)
                    if word is not None:
                        word.Quit()
        except Exception as exc:
            try:
                if target.exists():
                    target.unlink()
            except OSError:
                pass
            QMessageBox.critical(
                self,
                "Could not create document",
                f"Could not create the {kind.upper()} file:\n{exc}"
            )
            return

        # Keep the visible tree current. The main index is refreshed in the
        # background when the browser is closed.
        self._populate()
        self._select_folder_path(parent_folder)

        parent = self.parent()
        if parent is not None and hasattr(parent, "start_scan"):
            try:
                parent.start_scan()
            except Exception:
                pass

    def _delete_folder(self, folder):
        if folder == self.root:
            return
        if not folder.exists() or not folder.is_dir():
            return

        reply = QMessageBox.question(
            self,
            "Delete folder",
            f"Delete '{folder.name}' and everything inside it?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return

        try:
            shutil.rmtree(folder)
        except OSError as exc:
            QMessageBox.critical(self, "Could not delete folder",
                                 f"Could not delete the folder:\n{exc}")
            return

        self.selected_folder = None
        self.show_files_btn.setEnabled(False)
        self._populate()

        parent = self.parent()
        if parent is not None and hasattr(parent, "start_scan"):
            try:
                parent.start_scan()
            except Exception:
                pass

    def _select_folder_path(self, folder):
        folder = Path(folder).resolve()
        def walk(parent_item):
            for i in range(parent_item.childCount()):
                item = parent_item.child(i)
                path = item.data(0, Qt.ItemDataRole.UserRole)
                if path and Path(path).resolve() == folder:
                    self.tree.setCurrentItem(item)
                    self.tree.scrollToItem(item)
                    return True
                if walk(item):
                    item.setExpanded(True)
                    return True
            return False
        walk(self.tree.invisibleRootItem())

    def _populate(self):
        self.tree.clear()
        try:
            folders = sorted(
                [p for p in self.root.iterdir()
                 if p.is_dir() and p.name != "Digi Notes"],
                key=lambda p: p.name.casefold()
            )
        except OSError:
            folders = []

        for folder in folders:
            self._add_folder(self.tree.invisibleRootItem(), folder)

        if self.tree.topLevelItemCount() == 0:
            item = QTreeWidgetItem(["No folders available"])
            item.setDisabled(True)
            self.tree.addTopLevelItem(item)

    def _add_folder(self, parent_item, folder):
        item = QTreeWidgetItem([folder.name])
        item.setData(0, Qt.ItemDataRole.UserRole, str(folder))
        parent_item.addChild(item)

        try:
            children = sorted(
                [p for p in folder.iterdir()
                 if p.is_dir() and p.name != "Digi Notes"],
                key=lambda p: p.name.casefold()
            )
        except OSError:
            children = []

        for child in children:
            self._add_folder(item, child)

    def _selection_changed(self):
        item = self.tree.currentItem()
        path = item.data(0, Qt.ItemDataRole.UserRole) if item else None
        valid = bool(path and Path(path).is_dir())
        self.show_files_btn.setEnabled(valid)
        if valid:
            self.selected_folder = Path(path).resolve()
        else:
            self.selected_folder = None

    def _double_clicked(self, item, column):
        path = item.data(0, Qt.ItemDataRole.UserRole)
        if path and Path(path).is_dir():
            self.selected_folder = Path(path).resolve()
            self.accept()

    def _accept_selected(self):
        if self.selected_folder and self.selected_folder.is_dir():
            self.accept()


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Digi Search Engine")
        icon_path = resource_path("mbappe.ico")
        if icon_path.exists():
            self.setWindowIcon(QIcon(str(icon_path)))
        self.resize(1180, 720)
        self.setMinimumSize(900, 600)

        self.db = DB()
        # Keep one in-memory snapshot for fuzzy search. The previous implementation
        # queried every indexed row from SQLite on every keystroke, even for Normal
        # search, which made the GUI unnecessarily busy. This snapshot is refreshed
        # after background indexing completes.
        self.search_rows_cache = self.db.rows()
        # The library is a single user-selected folder. The folder containing
        # Digi itself is never searched unless the user explicitly selects it.
        global ROOT
        saved_library = self.db.setting("library_folder")
        if saved_library:
            candidate = Path(saved_library).expanduser()
            try:
                candidate = candidate.resolve()
                # A stale setting from an earlier installation must not make
                # Digi fall back to its application directory or internal data.
                if (
                    candidate.exists()
                    and candidate.is_dir()
                    and candidate != APP_DIR.resolve()
                    and candidate != CACHE_DIR.resolve()
                    and CACHE_DIR.resolve() not in candidate.parents
                ):
                    ROOT = candidate
            except Exception:
                pass
        self.library_root = ROOT
        # Persist the resolved default/selected library so the first launch
        # explicitly records Search Repository as the library.
        try:
            LIBRARY_CONFIG.write_text(str(self.library_root), encoding="utf-8")
            self.db.set_setting("library_folder", str(self.library_root))
        except OSError:
            pass
        self.current_path = None
        self.scanning = False
        self.scan_worker = None
        self.search_timer = QTimer(self)
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(180)
        self.search_timer.timeout.connect(self.refresh)
        self.incoming_alerted = set()
        # Temporary session memory for Incoming. The exact repository path is
        # authoritative; the Incoming filename is only a temporary handoff name.
        self.incoming_origin_map = {}
        self.incoming_origin_record = None
        self.incoming_debug_events = []
        self.folder_view_path = None
        self.duplicate_groups = []

        # Incoming is deliberately kept OUTSIDE the Search Repository.
        # It is a staging area for replacement files and is never searched/indexed.
        default_incoming = DEFAULT_INCOMING
        try:
            default_incoming.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

        saved_incoming = self.db.setting("incoming_folder")
        saved_incoming_path = Path(saved_incoming).expanduser() if saved_incoming else None
        self.incoming_folder = (
            saved_incoming_path if saved_incoming_path and saved_incoming_path.exists()
            else default_incoming
        )

        self.build_ui()
        self.update_duplicate_indicator()
        self.refresh()

        # Initial index is built in the background so the UI stays responsive.
        QTimer.singleShot(100, self.start_scan)

        # Much less frequent than the old 5-second full scan.
        self.index_timer = QTimer(self)
        self.index_timer.timeout.connect(self.start_scan)
        self.index_timer.start(300000)

        self.incoming_watcher = QFileSystemWatcher(self)
        self.ensure_incoming_folder()
        self.watch_incoming_folder()
        self.incoming_watcher.directoryChanged.connect(
            lambda _: QTimer.singleShot(500, self.check_incoming)
        )

    def build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        outer.setContentsMargins(16, 16, 16, 16)
        outer.setSpacing(10)

        # Header: the search box expands/contracts with the window instead
        # of leaving a large fixed empty area on wide/fullscreen windows.
        header = QHBoxLayout()
        header.setSpacing(8)

        title = QLabel("Digi Search Engine")
        title.setStyleSheet("font-size:25px;font-weight:bold;")
        title.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
        header.addWidget(title)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Search files...")
        self.search.setMinimumHeight(40)
        self.search.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.search.textChanged.connect(self.search_changed)
        self.search.returnPressed.connect(self.save_current_search)
        header.addWidget(self.search, 1)

        search_method_label = QLabel("Search:")
        self.search_method = QComboBox()
        self.search_method.addItems(["Normal", "Fuzzy"])
        self.search_method.setToolTip("Normal uses the standard search. Fuzzy allows approximate matches.")
        self.search_method.setMinimumWidth(105)
        self.search_method.currentTextChanged.connect(self.refresh)
        header.addWidget(search_method_label)
        header.addWidget(self.search_method)

        more_btn = QPushButton("More ▾")
        more_btn.setSizePolicy(
            QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed
        )
        more_menu = QMenu(more_btn)
        more_menu.addAction("Recent searches", self.show_recent)
        more_menu.addAction("Guide", self.show_guide)
        more_menu.addAction("Update log", self.show_update_log)
        more_menu.addAction("Notes", self.show_notes)
        more_menu.addAction("Incoming Geek Console", self.show_incoming_geek_console)
        more_menu.addSeparator()
        more_menu.addAction("Change library folder…", self.change_library_folder)
        more_menu.addAction("Refresh index", self.start_scan)
        more_btn.setMenu(more_menu)
        header.addWidget(more_btn)

        outer.addLayout(header)

        # Controls use a grid rather than a stretch between the filters and
        # action buttons. This keeps everything packed sensibly at fullscreen.
        controls = QGridLayout()
        controls.setHorizontalSpacing(8)
        controls.setVerticalSpacing(6)

        type_label = QLabel("Type:")
        self.type_filter = QComboBox()
        self.type_filter.addItems(["All types", "PDF", "Word"])
        self.type_filter.currentTextChanged.connect(self.refresh)

        status_label = QLabel("Status:")
        self.status_filter = QComboBox()
        self.status_filter.addItems([
            "All statuses", "Not started", "Currently working on",
            "Finished", "Due", "Due late"
        ])
        self.status_filter.currentTextChanged.connect(self.refresh)

        source_label = QLabel("Source:")
        self.source_filter = QComboBox()
        self.source_filter.addItems(["All sources", "ExamPro", "PMT"])
        self.source_filter.currentTextChanged.connect(self.refresh)

        folder_label = QLabel("Folders:")
        self.folder_browser_btn = QToolButton()
        self.folder_browser_btn.setText("Search Repository ▾")
        self.folder_browser_btn.setPopupMode(QToolButton.ToolButtonPopupMode.DelayedPopup)
        self.folder_browser_btn.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.folder_browser_btn.setToolTip("Browse folders in Search Repository")
        # A cascading QMenu was previously used here. With enough nested or
        # top-level folders, Qt's cascading menus can run out of screen space
        # and overlap earlier menus. Use a single scalable folder browser dialog.
        self.folder_browser_btn.clicked.connect(self.open_folder_browser)

        sort_label = QLabel("Sort:")
        self.sort = QComboBox()
        self.sort.addItems([
            "Relevance", "Name A-Z", "Name Z-A",
            "Newest modified", "Oldest modified",
            "Most pages", "Fewest pages"
        ])
        self.sort.currentTextChanged.connect(self.refresh)

        for combo in (self.type_filter, self.status_filter, self.sort):
            combo.setSizePolicy(
                QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
            )

        incoming_btn = QPushButton("Incoming")
        incoming_btn.clicked.connect(self.incoming_dialog)
        incoming_btn.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )

        self.incoming_status_btn = QPushButton("●")
        self.incoming_status_btn.setToolTip(
            "Green: no duplicate base names with different extensions. "
            "Red: duplicate files need attention."
        )
        self.incoming_status_btn.clicked.connect(self.show_duplicate_manager)
        self.incoming_status_btn.setMinimumWidth(48)
        self.incoming_status_btn.setMaximumWidth(60)

        controls.addWidget(type_label, 0, 0)
        controls.addWidget(self.type_filter, 0, 1)
        controls.addWidget(status_label, 0, 2)
        controls.addWidget(self.status_filter, 0, 3)
        controls.addWidget(source_label, 0, 4)
        controls.addWidget(self.source_filter, 0, 5)
        controls.addWidget(folder_label, 0, 6)
        controls.addWidget(self.folder_browser_btn, 0, 7)
        controls.addWidget(sort_label, 0, 8)
        controls.addWidget(self.sort, 0, 9)
        controls.addWidget(incoming_btn, 0, 10)
        controls.addWidget(self.incoming_status_btn, 0, 11)

        for col in (1, 3, 5, 7, 9, 10):
            controls.setColumnStretch(col, 1)

        outer.addLayout(controls)

        self.search_hint = QLabel("Type a search term to show files.")
        self.search_hint.setStyleSheet("color:#666;")
        outer.addWidget(self.search_hint)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setChildrenCollapsible(False)

        self.results = QTreeWidget()
        self.results.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self.results.setHeaderHidden(True)
        self.results.setRootIsDecorated(True)
        self.results.setIndentation(20)
        self.results.setUniformRowHeights(True)
        self.results.setExpandsOnDoubleClick(False)
        self.results.setAnimated(True)
        self.results.setStyleSheet("""
            QTreeWidget {
                font-size:14px;
                outline:none;
                border:none;
                background:#34373b;
                padding:4px;
            }
            QTreeWidget::item {
                border:none;
                margin:0px;
            }
            QTreeWidget::branch {
                background:transparent;
            }
        """)
        self.results.setItemDelegate(ResultDelegate(self.results))
        self.results.currentItemChanged.connect(self.selected)
        self.results.itemDoubleClicked.connect(self.open_selected)

        self.results_container = QWidget()
        self.results_stack = QStackedLayout(self.results_container)
        self.results_stack.setContentsMargins(0, 0, 0, 0)
        self.results_stack.addWidget(self.results)

        self.empty_state = QLabel()
        self.empty_state.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.empty_state.setStyleSheet("background:#3f4247; border:none;")
        self.empty_state.setScaledContents(True)
        nose_path = resource_path("nose_placeholder.png")
        if nose_path.exists():
            self.empty_state.setPixmap(QPixmap(str(nose_path)))
        self.results_stack.addWidget(self.empty_state)
        self.results_stack.setCurrentIndex(1)
        splitter.addWidget(self.results_container)

        self.detail = QGroupBox("Selected file")
        self.detail.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        d = QFormLayout(self.detail)
        d.setFieldGrowthPolicy(
            QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow
        )
        d.setLabelAlignment(
            Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop
        )

        self.detail_name = QLabel("No file selected")
        self.detail_name.setWordWrap(True)
        self.detail_name.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )
        d.addRow("File:", self.detail_name)

        self.status_edit = QComboBox()
        self.status_edit.addItems([
            "Not started", "Currently working on", "Finished"
        ])
        self.status_edit.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.status_edit.currentTextChanged.connect(self.save_status)
        d.addRow("Status:", self.status_edit)

        self.due_edit = QDateEdit()
        self.due_edit.setCalendarPopup(True)
        self.due_edit.setDisplayFormat("dd/MM/yyyy")
        self.due_edit.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.due_edit.dateChanged.connect(self.save_due)
        d.addRow("Due date:", self.due_edit)

        self.tags_label = QLabel("None")
        self.tags_label.setWordWrap(True)
        self.tags_label.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )
        d.addRow("Tags:", self.tags_label)

        tag_buttons = QHBoxLayout()
        add_tag = QPushButton("+ Add tag")
        add_tag.clicked.connect(self.add_tag)
        remove_tag = QPushButton("Remove tag")
        remove_tag.clicked.connect(self.remove_tag)
        tag_buttons.addWidget(add_tag)
        tag_buttons.addWidget(remove_tag)
        d.addRow(tag_buttons)

        conversion_row = QHBoxLayout()
        self.convert_pdf_btn = QPushButton("Convert to PDF")
        self.convert_pdf_btn.clicked.connect(self.convert_selected_to_pdf)
        self.convert_word_btn = QPushButton("Convert to Word document")
        self.convert_word_btn.clicked.connect(self.convert_selected_to_word)
        conversion_row.addWidget(self.convert_pdf_btn)
        conversion_row.addWidget(self.convert_word_btn)
        d.addRow(conversion_row)

        self.detail_open = QPushButton("Open file")
        self.detail_open.clicked.connect(self.open_selected)
        d.addRow(self.detail_open)

        self.detail_folder_btn = QPushButton("Open containing folder")
        self.detail_folder_btn.clicked.connect(self.open_containing_folder)
        d.addRow(self.detail_folder_btn)

        splitter.addWidget(self.detail)
        splitter.setStretchFactor(0, 7)
        splitter.setStretchFactor(1, 3)
        splitter.setSizes([800, 340])
        outer.addWidget(splitter, 1)

        bottom = QHBoxLayout()
        self.info = QLabel("0 results")
        bottom.addWidget(self.info)
        bottom.addStretch()

        self.open_btn = QPushButton("Open file")
        self.open_btn.clicked.connect(self.open_selected)
        bottom.addWidget(self.open_btn)

        self.open_folder_btn = QPushButton("Open containing folder")
        self.open_folder_btn.clicked.connect(self.open_containing_folder)
        bottom.addWidget(self.open_folder_btn)

        outer.addLayout(bottom)
        self.set_detail_enabled(False)

    def change_library_folder(self):
        global ROOT
        start = str(self.library_root if self.library_root.exists() else Path.home())
        folder = QFileDialog.getExistingDirectory(
            self,
            "Choose Digi Search Engine library folder",
            start
        )
        if not folder:
            return
        candidate = Path(folder).resolve()
        app_dir = APP_DIR.resolve()
        default_repo = DEFAULT_ROOT.resolve()

        # Search Repository is intentionally created beside the EXE, inside
        # Digi SE 1.14.3. It is therefore a valid library location even though
        # it is inside APP_DIR. Other application internals remain protected.
        try:
            if candidate == app_dir:
                QMessageBox.warning(
                    self, "Invalid library folder",
                    "Please choose Search Repository or a folder inside it."
                )
                return
            cache_dir = CACHE_DIR.resolve()
            if candidate == cache_dir or cache_dir in candidate.parents:
                QMessageBox.warning(
                    self, "Invalid library folder",
                    "The Cache folder cannot be used as the library."
                )
                return
            if app_dir in candidate.parents and not (
                candidate == default_repo or default_repo in candidate.parents
            ):
                QMessageBox.warning(
                    self, "Invalid library folder",
                    "Please choose Search Repository or a folder inside it."
                )
                return
        except Exception:
            pass

        ROOT = candidate
        self.library_root = candidate
        try:
            LIBRARY_CONFIG.write_text(str(candidate), encoding="utf-8")
        except OSError:
            pass
        self.db.set_setting("library_folder", str(candidate))

        # Incoming remains outside the selected library so it is never indexed.
        self.incoming_folder = DEFAULT_INCOMING
        self.db.set_setting("incoming_folder", str(self.incoming_folder))
        self.ensure_incoming_folder()
        self.watch_incoming_folder()
        self.current_path = None
        self.folder_view_path = None
        self.duplicate_groups = []
        self.set_detail_enabled(False)
        if hasattr(self, "folder_browser_btn"):
            self.folder_browser_btn.setText("Search Repository ▾")
        self.refresh()
        self.start_scan()

    def show_notes(self):
        dlg = NotesDialog(self)
        dlg.exec()

    def open_folder_browser(self):
        """Open a scalable folder browser without cascading-menu overflow."""
        if not hasattr(self, "library_root"):
            return

        root = Path(self.library_root).resolve()
        dlg = FolderBrowserDialog(root, self)
        if dlg.exec() == QDialog.DialogCode.Accepted and dlg.selected_folder:
            self.show_folder_files(dlg.selected_folder)

    def show_folder_files(self, folder):
        """Show all indexed files recursively under a selected folder."""
        self.folder_view_path = Path(folder).resolve()
        self.search.clear()
        self.results_stack.setCurrentIndex(0)
        rows = self.sort_rows(self.filtered_rows())
        self.render_rows(rows)
        self.search_hint.setText(
            f"Showing files in {self.folder_view_path.name}"
        )
        self.folder_browser_btn.setText(f"{self.folder_view_path.name} ▾")

    def toggle_directories(self):
        visible = not self.directory_group.isVisible()
        self.directory_group.setVisible(visible)
        self.dir_btn.setText("Hide directories" if visible else "Directories")
        if visible:
            self.populate_directories()

    def populate_directories(self):
        if not hasattr(self, "directory_tree"):
            return
        self.directory_tree.clear()
        root_item = QTreeWidgetItem([ROOT.name])
        root_item.setData(0, Qt.ItemDataRole.UserRole, str(ROOT))
        self.directory_tree.addTopLevelItem(root_item)
        self._populate_directory_children(root_item, ROOT)

    def _populate_directory_children(self, item, folder, depth=0):
        if depth >= 4:
            return
        try:
            dirs = [p for p in folder.iterdir() if p.is_dir() and p != APP_DIR and p.name != "Digi Notes"]
        except OSError:
            return
        for p in sorted(dirs, key=lambda x: x.name.lower()):
            child = QTreeWidgetItem([p.name])
            child.setData(0, Qt.ItemDataRole.UserRole, str(p))
            item.addChild(child)
            # Add a lightweight placeholder so the tree is expandable without
            # eagerly traversing the whole A-level collection.
            try:
                if any(x.is_dir() and x != APP_DIR for x in p.iterdir()):
                    child.addChild(QTreeWidgetItem([""]))
            except OSError:
                pass

    def directory_expanded(self, item):
        if item.childCount() == 1 and item.child(0).text(0) == "":
            item.takeChildren()
            path = Path(item.data(0, Qt.ItemDataRole.UserRole))
            self._populate_directory_children(item, path, item.parent().indexOfChild(item) + 1 if item.parent() else 1)

    def directory_selected(self, item, column):
        path = Path(item.data(0, Qt.ItemDataRole.UserRole))
        if path == ROOT:
            self.search.clear()
            return
        # Searching the folder name is intentionally simple and keeps the
        # directory navigator separate from the main filename search.
        self.search.setText(path.name)

    def show_guide(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Digi Search Engine — Guide")
        dlg.resize(900, 650)
        dlg.setMinimumSize(650, 450)

        layout = QVBoxLayout(dlg)
        browser = QTextBrowser()
        browser.setOpenExternalLinks(True)
        browser.setHtml("""
        <h1>Digi Search Engine Guide</h1>

        <h2>1. Searching</h2>
        <p>Type a word or phrase into the search bar. The app searches file
        names and folder paths.</p>
        <p><b>Nothing is shown when the search bar is empty.</b> This is
        intentional and keeps the app fast and uncluttered.</p>

        <h2>2. Search methods</h2>
         <p><b>Normal</b> uses the standard indexed search. <b>Fuzzy</b> allows approximate spelling and wording.</p>

        <h2>3. Sources</h2>
        <p><b>Source</b> automatically detects folders named <code>ExamPro</code> or <code>PMT</code> anywhere in a file's directory path. Use the Source filter to show only one.</p>

        <h2>4. Filters and sorting</h2>
        <ul>
          <li><b>Type</b> — show all files, PDFs, or Word documents.</li>
          <li><b>Status</b> — filter by Not started, Currently working on,
              Finished, Due, or Due late.</li>
          <li><b>Sort</b> — change the order of the results.</li>
        </ul>

        <h2>4. File details</h2>
        <p>Select a result to edit its study information.</p>
        <ul>
          <li><b>Status</b> — Not started, Currently working on, or Finished.</li>
          <li><b>Due date</b> — set the date you want to finish it by.</li>
          <li><b>Tags</b> — add labels such as Biology, Revision, or
              Year 13. Tags are stored against that individual file.</li>
        </ul>

        <h2>5. Updating a paper through Incoming</h2>
        <p>Use the <b>Incoming</b> folder as a middleman for modified files.</p>
        <ol>
          <li>Save your modified PDF/Word file into the Incoming folder.</li>
          <li>Keep the <b>same filename and extension</b> as the repository copy.</li>
          <li>Digi automatically finds the matching repository file and replaces
              the old version.</li>
          <li>If more than one exact matching destination exists, Digi shows a
              destination list so you can choose the correct folder.</li>
          <li>The Incoming copy is removed after a successful update.</li>
        </ol>

        <h2>6. Choosing the Incoming folder</h2>
        <p>The default <code>Incoming</code> folder is created beside the
        <code>Search Repository</code>, not inside it. Updated files placed
        there can be used by the same replacement workflow. You can change
        it from <b>Incoming / Replace → Change folder</b>.</p>

        <h2>7. Refreshing the index</h2>
        <p>The app maintains a local index so searching is fast. It updates
        automatically in the background. Use <b>Refresh index</b> if you have
        made a large number of changes and want an immediate update.</p>

        <h2>8. Opening files</h2>
        <p>Double-click a result to open it. You can also use
        <b>Open file</b> or <b>Open containing folder</b>.</p>

        <h2>9. Duplicate filename indicator</h2>
        <p>The green/red indicator beside <b>Incoming</b> reports same-folder
        files that share a base name but have different extensions, such as
        <code>2018.pdf</code> and <code>2018.docx</code>. Click the red indicator
        to manage those conflicts.</p>

        <h2>10. Performance / lag reduction</h2>
        <p>The app is designed to be friendly to slower PCs. Search results are
        only generated after you type a query, and typing is briefly debounced
        so the database is not queried on every keystroke. PDF page counts are
        only recalculated when a PDF is new or has changed. The background
        index refresh is infrequent, while the Incoming folder is watched
        separately for replacements.</p>
        <p>For very broad searches, the app displays the first 300 matching
        results rather than creating a huge list of widgets.</p>

        <h2>11. Digi Notes</h2>
        <p>Open <b>Notes</b> for the stylus notepad. The pen draws, the stylus barrel/right button acts as an eraser, and there are separate Pen, Eraser, Marker, Highlighter, Colour, size and zoom controls. Fingers do not draw; two-finger pinch can zoom. Pages grow automatically when you write near an edge. Create notebooks and nested sub-page folders, move pages up/down, rename/delete pages, insert images or text, and save. Each page is an individual PNG file under <code>Digi Notes</code>, so it can be backed up independently.</p>

        <h2>12. Expandable search results</h2>
        <p>Search results are displayed as individual rounded cards. Each file has an arrow beside it. Click the arrow to expand the result and reveal its directory and full path. Click it again to collapse it.</p>

        <h2>13. Library folder</h2>
        <p>When <code>build.bat</code> is run after extracting Digi, it creates
        <code>Search Repository</code> and <code>Incoming</code> beside the
        Digi application folder. Digi searches only <code>Search Repository</code>
        and everything inside it recursively. The <code>Incoming</code> folder
        stays outside the repository and is used only for the replacement workflow.</p>
        <pre>Digi Search Engine/
└── Digi Search Engine.exe

My Study Library/
├── Biology/
├── Chemistry/
├── Psychology/
└── Incoming/</pre>
        <p>Use <b>More ▾ → Change library folder…</b> to choose the folder.</p>

        <p><b>Tip:</b> You can leave the Incoming folder empty until you have
        an updated file to replace.</p>
        """)
        layout.addWidget(browser)

        close = QPushButton("Close")
        close.clicked.connect(dlg.accept)
        layout.addWidget(close)
        dlg.exec()

    def show_update_log(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Digi Search Engine — Update log")
        dlg.resize(900, 700)
        dlg.setMinimumSize(650, 450)

        layout = QVBoxLayout(dlg)
        browser = QTextBrowser()
        browser.setHtml("""
        <h1>Digi Search Engine — Update log</h1>

        <h2>Version 1.17.0.1 — Inspection / performance stability update</h2>
        <p><b>Inspection:</b> Normal, Fuzzy, indexing, folder browsing,
        document creation, deletion, Incoming replacement, and the existing
        conversion workflows were reviewed for responsiveness and regressions.
        No feature was removed.</p>
        <p><b>Fuzzy search:</b> The existing RapidFuzz path and scoring behavior
        were retained. It remains independent and does not
        load the legacy search component model.</p>
        <p><b>Indexing:</b> Scan completion no longer performs a SQLite SELECT
        for every indexed file. Existing metadata is already supplied by the
        background scanner, so updates are committed in a batch. Missing-file
        cleanup is also batched.</p>
        <p><b>Result:</b> This is an inspection/performance patch only. The
        application feature set remains unchanged.</p>

<h2>Version 1.17.6.5 — Search responsiveness and Fuzzy search bug fix</h2>
         <p><b>Bug fix:</b> Fixed unnecessary full-index and filesystem work being triggered by ordinary search-box and filter input. Normal search no longer fetches the entire database or walks the repository for every keystroke.</p>
         <p><b>Performance:</b> Fuzzy search now uses a maintained in-memory index snapshot, refreshed after background indexing, so approximate matching does not repeatedly hit SQLite or the filesystem while the user types. This removes a major source of GUI lag.</p>
         <p><b>Fuzzy search:</b> Reworked the fuzzy scoring so filenames receive the strongest match signal, while repository paths and folder names remain searchable. Approximate spelling, missing-character and word-order differences are handled more reliably.</p>
         <p><b>Functionality:</b> No search mode, filter, indexing, folder browsing, Incoming workflow, conversion feature, file management, or other existing feature was removed. The existing 3-second branded splash remains unchanged.</p>

<h2>Version 1.17.5.5 — Version-folder self-organisation bug fix</h2>
         <p><b>Bug fix:</b> Fixed an issue where moving the compiled Digi Search Engine.exe out of its version folder (for example, to the Desktop) left the executable outside the Digi folder structure instead of recreating its current version folder.</p>
         <p><b>Self-organisation:</b> If the executable is launched from outside <code>Digi SE 1.17.5.5</code>, Digi now creates the version folder beside the executable, creates <code>Search Repository</code>, <code>Incoming</code>, and <code>Cache</code> inside it, then moves and relaunches the executable from the correct location.</p>
         <p><b>Performance:</b> Normal launches from the correct version folder do not perform any relocation work. The existing 3-second branded splash delay and all other application functionality are retained.</p>

<h2>Version 1.17.4.5 — Startup performance bug fix</h2>
         <p><b>Bug fix:</b> Fixed excessive startup delay caused by the previous EXE self-relocation workflow. Digi is now built directly into its final version folder, so launching the application no longer requires moving the executable, waiting for the original process/file to disappear, and starting a second copy.</p>
         <p><b>Build cleanup:</b> Removed stale Sentence Transformers packaging from the Windows build configuration. Semantic search remains fully removed from Digi SE; the old dependency was only being bundled unnecessarily and could increase one-file executable size and extraction time.</p>
         <p><b>Startup behaviour:</b> The existing 3-second branded splash delay is intentionally retained. No user-facing Digi SE functionality was removed or redesigned.</p>

         <h2>Version 1.17.3.6 — Startup performance fix</h2>
        <p>Removed the pre-launch EXE self-relocation step. The finished build is now placed directly in its final version folder, so launching Digi no longer requires moving the EXE, waiting for the source file to disappear, and launching a second copy.</p>
        <p>Removed stale Sentence Transformers packaging from the Windows build configuration. Semantic search was already removed from the application; the build was still unnecessarily bundling its old machine-learning dependency tree, which made the single-file EXE substantially larger and slowed one-file extraction at startup.</p>
        <p>The 3-second branded splash delay is intentionally retained. No user-facing Digi SE functionality was removed.</p>
        <h2>Version 1.17.3.5 — Result filename cosmetic update</h2>
        <p><b>Microfeature:</b> Search result cards now display only the filename
        without the <code>.pdf</code>, <code>.doc</code>, or <code>.docx</code>
        extension. PDF filenames use a subtle light red tint and Word filenames
        use a subtle light blue tint.</p>
        <p><b>Scope:</b> Cosmetic rendering only. The underlying filename,
        extension, path, indexing, Normal Search, Fuzzy Search, sorting, filtering,
        opening, conversion, and Incoming mechanisms are unchanged.</p>

<h2>Version 1.17.3.4 — Incoming source identity and Geek Console</h2>
        <p><b>Problem:</b> The Incoming workflow still relied on the Incoming
        filename when no exact filename+extension match existed. This prevented
        a user from saving a modified copy under a different temporary name.</p>
        <p><b>Fix:</b> Digi now records the exact repository path, original
        filename, extension, and opening time when a repository file is opened.
        The Incoming filename is now treated as a temporary handoff name. A
        modified Incoming file is returned to the recorded directory and is
        installed under the original filename, even when the temporary name
        differs.</p>
        <p><b>Geek Console:</b> Added <b>More ▾ → Incoming Geek Console</b>.
        It displays the active source association and a live session event log,
        including file-open, Incoming detection, source resolution, identity
        restoration, installation, ambiguity, and failure events. The log can
        be saved as a text file for troubleshooting.</p>

<h2>Version 1.17.3.3 — Incoming destination memory fix</h2>
        <p><b>Problem:</b> Identical filename+extension files can exist in different
        repository folders. An Incoming copy by itself cannot tell which one was
        originally opened and modified.</p>
        <p><b>Fix:</b> When a repository file is opened, Digi temporarily remembers
        its exact path for the current session. A modified copy with the same
        filename <b>and</b> extension saved to Incoming is automatically returned
        to that exact original path and replaces the old version.</p>
        <p><b>Safety:</b> The remembered path is validated before use. If it is no
        longer valid, Digi falls back to exact filename+extension matching. If
        multiple destinations remain, Digi asks the user to choose instead of
        guessing.</p>

<h2>Version 1.17.3.2 — Search repair and automatic Incoming workflow</h2>
        <p><b>Problem:</b> Search could show no files when the background SQLite
        index had not yet populated or was temporarily stale. The previous
        Incoming workflow also required manual replacement and did not clearly
        expose same-folder duplicate filenames with different extensions.</p>
        <p><b>Fix:</b> Normal and Fuzzy search now fall back to the active
        Search Repository filesystem when the index has no usable candidates.
        Incoming is now an automatic middleman: save a modified file with the
        same filename and extension into Incoming and Digi automatically sends
        it to the matching repository file and replaces the old version.</p>
        <p><b>Ambiguous targets:</b> If more than one repository file has the
        exact same filename and extension, Digi presents the matching destinations
        so the correct folder can be selected rather than guessing.</p>
        <p><b>Duplicate indicator:</b> A green <b>●</b> means no same-folder
        duplicate base names with different extensions exist. A red
        <b>● (n)</b> shows the number of duplicate filename groups. Clicking it
        opens a manager where the affected files can be opened, deleted, or their
        containing folders opened.</p>

<h2>Version 1.17.2.2 — Search and selected-file controls fix</h2>
        <p><b>Problem:</b> Files displayed through the filesystem-first Folder
        Browser could be selected visually, but if they had not yet been added
        to the SQLite index, the Selected file panel remained disabled. This
        made Open, Convert, and related controls appear not to work.</p>
        <p><b>Fix:</b> Selected files now use indexed metadata when available
        and a filesystem metadata fallback when they are not indexed yet.
        This keeps the existing filesystem-first folder browsing behavior while
        making the selected-file controls immediately usable.</p>
        <p><b>Search stability:</b> Normal and Fuzzy search paths
        remain separate. Folder browsing no longer prevents a selected file
        from being acted on, and the search state is reset correctly when a
        search query is entered.</p>

        <h2>Version 1.17.1.2 — Conversion source-retention control</h2>
        <p><b>Feature:</b> Added a confirmation step when converting between
        PDF and Word. Digi now asks whether to <b>keep the original file</b>
        after the conversion.</p>
        <p><b>Behavior:</b> Choosing <b>Yes</b> keeps the original PDF/Word
        document alongside the converted version. Choosing <b>No</b> removes
        the original only after the conversion has completed successfully.
        If conversion fails, the original is always preserved.</p>

        <h2>Version 1.17.0 — Folder browser file management</h2>
        <p><b>Feature:</b> Added right-click file management directly inside the
        Folder Browser. Right-click a folder (or empty tree space for the
        repository root) to open a <b>New</b> menu for creating folders,
        Word <code>.docx</code> files, legacy Word <code>.doc</code> files, and
        PDF files. Selected folders can also be deleted recursively with a
        confirmation prompt.</p>
        <p><b>Implementation:</b> DOCX files are created with python-docx,
        PDFs with PyMuPDF, and legacy DOC files through Microsoft Word via
        pywin32. The folder tree refreshes immediately after changes and the
        main search index is refreshed in the background.</p>

        <h2>Version 1.16.9 — Folder browser filesystem fix</h2>
        <p><b>Problem:</b> The Folder Browser could correctly display and select a
        folder, but the results area could still show <code>0 results</code> even
        though the same files were found by normal search. The folder view was
        still relying on the SQLite index being fully synchronized with the
        selected folder, so filesystem files that were not represented by the
        current index snapshot were omitted.</p>
        <p><b>Fix:</b> Folder browsing is now <b>filesystem-first</b>. When a
        folder is selected, Digi recursively reads supported files from that
        folder on disk, uses indexed metadata when available, and creates
        lightweight result metadata for files that have not been indexed yet.
        This makes folder browsing immediately reflect the actual contents of
        <code>Search Repository</code> while leaving normal and fuzzy
        search behavior unchanged.</p>

        <h2>Version 1.16.8 — Folder browsing direct-file fix</h2>
        <p><b>Problem:</b> The new Folder Browser correctly displayed the repository tree, but selecting a folder returned no files when files were located directly inside that folder. Normal search still found those files because the database index was correct.</p>
        <p><b>Fix:</b> Corrected the folder-path filter so it includes both files directly inside the selected folder and files recursively contained in its subfolders.</p>

        <h2>Version 1.16.7 — Scalable folder browser</h2>
        <p><b>Problem:</b> The hierarchical folder dropdown used cascading
        submenus. With several folders or multiple levels of subfolders, the
        menus could run out of available screen space and overlap earlier
        menus, making some folders difficult or impossible to access.</p>
        <p><b>Fix:</b> Replaced the cascading folder menus with a single
        scrollable <b>Folder Browser</b> dialog containing an expandable
        folder tree. Folders can be expanded to any depth, and the selected
        folder can be opened with <b>Show files inside this folder</b>.
        This removes the horizontal submenu-space limitation while retaining
        nested-folder navigation.</p>

        <h2>Version 1.16.6 — Folder dropdown refresh fix</h2>
        <p><b>Problem:</b> Newly created folders inside <code>Search Repository</code>
        could still appear as <code>No folders available</code> in the dropdown.
        The folder browser button was also sharing an attribute name with the
        <b>Open containing folder</b> button, so later updates could target the
        wrong widget.</p>
        <p><b>Fix:</b> The two buttons now have separate references. The folder
        browser also keeps a single menu and rebuilds it immediately when the
        dropdown is about to open, reading the current library directory each
        time. Newly added folders and nested folders therefore appear without
        restarting Digi.</p>

        <h2>Version 1.16.5 — Folder menu and startup repair</h2>
        <p><b>Problem:</b> Version 1.16.3/1.16.4 did not reliably show the
        folders inside the active <code>Search Repository</code>. In addition,
        the 1.16.4 source package was missing the final application entry point,
        so <code>run.bat</code> could report that Digi closed normally without
        ever displaying the main window.</p>
        <p><b>Fix:</b> Restored the complete application startup/entry-point code,
        made the folder browser use the active library root, and rebuild the
        folder menu immediately before it opens. Newly created, nested, or
        newly selected-library folders are therefore reflected in the dropdown.</p>

        <h2>Version 1.16.4 — Launcher/startup diagnostics</h2>
        <p><b>Problem:</b> A startup failure could close the Command Prompt before
        the underlying Python error was visible.</p>
        <p><b>Fix:</b> The launcher was changed to keep the Command Prompt open,
        capture application output in <code>Cache\\launcher_output.txt</code>,
        and display the captured error when Python exits with a failure code.</p>
        <p><b>Follow-up problem discovered:</b> The packaged 1.16.4 source was
        missing the application's final startup block. This caused a clean
        Python exit with no GUI. Version 1.16.5 restores that block.</p>

        <h2>Version 1.16.3 — Folder browser fix</h2>
        <p><b>Problem:</b> Folders inside <code>Search Repository</code> could be
        missing from the <b>Folders</b> dropdown because the folder list was not
        reliably refreshed after repository changes.</p>
        <p><b>Fix:</b> The folder menu was changed to re-read the repository when
        opened and after an index refresh, while retaining hierarchical navigation
        for files and subfolders.</p>

        <h2>Version 1.16.2 — Startup and folder browser update</h2><h2>Version 1.16.0 — Search methods and update log</h2>
         <p><b>Problem:</b> Digi only had the standard search path and had no
         built-in release history for documenting changes and fixes.</p>
         <p><b>Fix:</b> Added <b>Normal</b> and <b>Fuzzy</b> search methods and
         the <b>Update log</b> entry in the <b>More ▾</b> menu.</p>


        <h2>Version 1.15.1</h2>
        <ul>
          <li>Added the <b>Subject</b> filter: Biology, Chemistry and Psychology.</li>
          <li>Kept automatic version-folder setup aligned with the release.</li>
        </ul>

        <h2>Version 1.14.3</h2>
        <ul>
          <li>Fixed repository indexing so files inside <b>Search Repository</b>
              are searchable.</li>
          <li>Internal Cache and Incoming folders remain excluded from search.</li>
        </ul>

        <h2>Version 1.14.2</h2>
        <ul>
          <li>Fixed self-organisation so duplicate application folders are not
              created beside the version folder.</li>
        </ul>

        <h2>Version 1.14.0</h2>
        <ul>
          <li>Established the current Digi SE application structure and indexing
              workflow used by later releases.</li>
        </ul>
        """)
        layout.addWidget(browser)

        close = QPushButton("Close")
        close.clicked.connect(dlg.accept)
        layout.addWidget(close)
        dlg.exec()

    def set_detail_enabled(self, enabled):
        for w in [
            self.status_edit, self.due_edit,
            self.convert_pdf_btn, self.convert_word_btn,
            self.detail_open, self.detail_folder_btn
        ]:
            w.setEnabled(enabled)

    # ---------------- Indexing ----------------

    def start_scan(self):
        if self.scanning:
            return
        if self.scan_worker and self.scan_worker.isRunning():
            return

        self.scanning = True
        self.search_hint.setText("Updating index in the background...")

        cached_rows = self.db.conn.execute(
            "SELECT path,modified,pages FROM files"
        ).fetchall()
        cached = {r[0]: (r[1], r[2]) for r in cached_rows}
        self.scan_worker = ScanWorker(cached)
        self.scan_worker.finished_scan.connect(self.finish_scan)
        self.scan_worker.failed.connect(self.scan_failed)
        self.scan_worker.finished.connect(self.scan_thread_finished)
        self.scan_worker.start()

    def finish_scan(self, found, metadata):
        try:
            values = []
            for path_str, (p, modified, pages) in metadata.items():
                values.append((
                    path_str,
                    p.name,
                    p.suffix.lower(),
                    modified,
                    pages
                ))

            if values:
                self.db.conn.executemany("""
                    INSERT INTO files(path,name,ext,modified,pages)
                    VALUES(?,?,?,?,?)
                    ON CONFLICT(path) DO UPDATE SET
                        name=excluded.name,
                        ext=excluded.ext,
                        modified=excluded.modified,
                        pages=excluded.pages
                """, values)

            # delete_missing still runs in one transaction; the expensive file
            # traversal itself remains in ScanWorker.
            self.db.delete_missing(found)
            self.db.commit()
            # Refresh the in-memory search snapshot once per completed scan,
            # rather than rebuilding it for every search-box/filter event.
            self.search_rows_cache = self.db.rows()
            self.update_duplicate_indicator(metadata)

            if self.search.text().strip():
                self.refresh()
            elif self.folder_view_path:
                # A newly created document/folder should become visible without
                # requiring a manual search.
                self.refresh()
            self.check_incoming()
        except Exception as exc:
            self.scan_failed(str(exc))

    def scan_failed(self, message):
        self.search_hint.setText(f"Index update failed: {message}")

    def scan_thread_finished(self):
        self.scanning = False
        if not self.search.text().strip():
            self.search_hint.setText(
                "Type a search term to show files."
            )

    # ---------------- Incoming replacement ----------------

    def ensure_incoming_folder(self):
        try:
            self.incoming_folder.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

    def watch_incoming_folder(self):
        try:
            watched = self.incoming_watcher.directories()
            if str(self.incoming_folder) not in watched:
                if watched:
                    self.incoming_watcher.removePaths(watched)
                if self.incoming_folder.exists():
                    self.incoming_watcher.addPath(str(self.incoming_folder))
        except Exception:
            pass

    def update_duplicate_indicator(self, metadata=None):
        """Find same-base-name files with different extensions in the same folder."""
        groups = {}
        try:
            if metadata is not None:
                paths = [value[0] for value in metadata.values()]
            else:
                paths = [Path(row[0]) for row in self.db.rows()]
            for p in paths:
                p = Path(p)
                if not p.is_file() or p.suffix.lower() not in SUPPORTED:
                    continue
                try:
                    folder_key = str(p.parent.resolve()).casefold()
                except OSError:
                    folder_key = str(p.parent).casefold()
                key = (folder_key, p.stem.casefold())
                groups.setdefault(key, []).append(p)
        except Exception:
            groups = {}

        duplicate_groups = []
        for paths in groups.values():
            extensions = {p.suffix.lower() for p in paths}
            if len(extensions) > 1:
                duplicate_groups.append(sorted(paths, key=lambda p: p.name.lower()))

        self.duplicate_groups = duplicate_groups

        if not hasattr(self, "incoming_status_btn"):
            return

        if duplicate_groups:
            self.incoming_status_btn.setText(f"● ({len(duplicate_groups)})")
            self.incoming_status_btn.setStyleSheet(
                "QPushButton { color:#ff4d4d; font-weight:bold; }"
            )
            self.incoming_status_btn.setToolTip(
                f"{len(duplicate_groups)} folder(s) contain files with the same "
                "base name but different extensions. Click to manage them."
            )
        else:
            self.incoming_status_btn.setText("●")
            self.incoming_status_btn.setStyleSheet(
                "QPushButton { color:#35c759; font-weight:bold; }"
            )
            self.incoming_status_btn.setToolTip(
                "No duplicate base names with different extensions in Search Repository."
            )

    def show_duplicate_manager(self):
        """Show all same-folder, same-base-name/different-extension conflicts."""
        self.update_duplicate_indicator()

        dlg = QDialog(self)
        dlg.setWindowTitle("Duplicate files — Search Repository")
        dlg.resize(900, 600)
        dlg.setMinimumSize(700, 450)

        layout = QVBoxLayout(dlg)
        intro = QLabel(
            "These folders contain files with the same base name but different "
            "extensions (for example 2018.pdf and 2018.docx). Select a file to "
            "open or delete it. You can also open the containing folder."
        )
        intro.setWordWrap(True)
        layout.addWidget(intro)

        tree = QTreeWidget()
        tree.setHeaderHidden(True)
        tree.setRootIsDecorated(True)
        layout.addWidget(tree, 1)

        def reload_tree():
            self.update_duplicate_indicator()
            tree.clear()
            for group in self.duplicate_groups:
                if not group:
                    continue
                parent = QTreeWidgetItem([str(group[0].parent)])
                parent.setData(0, Qt.ItemDataRole.UserRole, str(group[0].parent))
                parent.setExpanded(True)
                tree.addTopLevelItem(parent)
                for p in group:
                    child = QTreeWidgetItem([p.name])
                    child.setData(0, Qt.ItemDataRole.UserRole, str(p))
                    parent.addChild(child)

        reload_tree()

        buttons = QHBoxLayout()
        open_folder_btn = QPushButton("Open folder")
        open_file_btn = QPushButton("Open file")
        delete_btn = QPushButton("Delete selected")
        refresh_btn = QPushButton("Refresh")
        close_btn = QPushButton("Close")
        buttons.addWidget(open_folder_btn)
        buttons.addWidget(open_file_btn)
        buttons.addWidget(delete_btn)
        buttons.addWidget(refresh_btn)
        buttons.addStretch()
        buttons.addWidget(close_btn)
        layout.addLayout(buttons)

        def selected_path():
            item = tree.currentItem()
            if not item:
                return None
            raw = item.data(0, Qt.ItemDataRole.UserRole)
            return Path(raw) if raw else None

        def open_folder_action():
            p = selected_path()
            if not p:
                return
            folder = p if p.is_dir() else p.parent
            open_folder(folder)

        def open_file_action():
            p = selected_path()
            if p and p.is_file():
                if self._is_repository_file(p):
                    self.remember_incoming_origin(p)
                open_file(p)

        def delete_action():
            p = selected_path()
            if not p or not p.is_file():
                QMessageBox.information(
                    dlg, "Select a file", "Select one of the duplicate files first."
                )
                return
            answer = QMessageBox.question(
                dlg,
                "Delete file?",
                f"Delete this file permanently?\n\n{p}",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No,
            )
            if answer != QMessageBox.StandardButton.Yes:
                return
            try:
                p.unlink()
            except OSError as exc:
                QMessageBox.warning(dlg, "Delete failed", f"Could not delete:\n\n{exc}")
                return
            self.start_scan()
            QTimer.singleShot(300, reload_tree)

        open_folder_btn.clicked.connect(open_folder_action)
        open_file_btn.clicked.connect(open_file_action)
        delete_btn.clicked.connect(delete_action)
        refresh_btn.clicked.connect(reload_tree)
        close_btn.clicked.connect(dlg.accept)
        tree.itemDoubleClicked.connect(lambda *_: open_file_action())
        dlg.exec()

    def check_incoming(self):
        folder = self.incoming_folder
        if not folder:
            return
        try:
            folder.mkdir(parents=True, exist_ok=True)
        except OSError:
            return

        try:
            files = [
                p for p in folder.iterdir()
                if p.is_file() and p.suffix.lower() in SUPPORTED
            ]
        except OSError:
            return

        for source in files:
            try:
                stat = source.stat()
                key = f"{source.resolve()}|{stat.st_mtime_ns}|{stat.st_size}"
            except OSError:
                continue
            if key in self.incoming_alerted:
                continue
            self.incoming_alerted.add(key)

            self.log_incoming_event(
                "INCOMING FILE DETECTED",
                f"Incoming path: {source}\n"
                f"Incoming filename: {source.name}\n"
                f"Incoming extension: {source.suffix or '(none)'}"
            )

            # 1. Exact filename+extension association is retained for backwards
            # compatibility.
            origin_key = (source.name.casefold(), source.suffix.casefold())
            remembered = self.incoming_origin_map.get(origin_key)

            # 2. The active opened-file record is authoritative for the normal
            # workflow. The Incoming filename may be completely different.
            if not remembered and self.incoming_origin_record:
                remembered = self.incoming_origin_record.get("path")
                self.log_incoming_event(
                    "SOURCE ASSOCIATION",
                    "Incoming filename does not need to match the original.\n"
                    f"Using the exact file opened by the user:\n{remembered}"
                )

            if remembered:
                remembered = Path(remembered)
                try:
                    valid_origin = (
                        remembered.exists()
                        and remembered.is_file()
                        and self._is_repository_file(remembered)
                    )
                except OSError:
                    valid_origin = False

                if valid_origin:
                    original_name = remembered.name
                    original_suffix = remembered.suffix.casefold()
                    incoming_suffix = source.suffix.casefold()

                    self.log_incoming_event(
                        "SOURCE FOUND",
                        f"Original path: {remembered}\n"
                        f"Original filename: {original_name}\n"
                        f"Original extension: {remembered.suffix}\n"
                        f"Incoming filename: {source.name}\n"
                        f"Incoming extension: {source.suffix}"
                    )

                    if incoming_suffix != original_suffix:
                        answer = QMessageBox.question(
                            self,
                            "File type changed",
                            f"The modified file has a different extension.\n\n"
                            f"Original: {original_name}\n"
                            f"Incoming: {source.name}\n\n"
                            "Digi can still install the Incoming file under the "
                            "original filename, but the file type will be different.\n\n"
                            "Continue?",
                            QMessageBox.StandardButton.Yes
                            | QMessageBox.StandardButton.No,
                            QMessageBox.StandardButton.No,
                        )
                        if answer != QMessageBox.StandardButton.Yes:
                            self.log_incoming_event(
                                "WAITING",
                                "User declined replacement because the Incoming "
                                "file type differs from the original."
                            )
                            continue

                    self.log_incoming_event(
                        "RESTORE IDENTITY",
                        f"Temporary Incoming name: {source.name}\n"
                        f"Repository name: {original_name}\n"
                        f"Destination directory: {remembered.parent}"
                    )

                    if self.replace_file(source, remembered, self, automatic=True):
                        self.log_incoming_event(
                            "COMPLETE",
                            f"✓ Installed modified file as:\n{remembered}\n"
                            "✓ Original repository identity restored\n"
                            "✓ Incoming handoff completed"
                        )
                        self.incoming_origin_record = None
                        self.incoming_origin_map.pop(origin_key, None)
                    else:
                        self.log_incoming_event(
                            "FAILED",
                            "The replacement operation did not complete. "
                            "The Incoming file was preserved."
                        )
                    continue

                self.log_incoming_event(
                    "SOURCE INVALID",
                    f"The remembered source no longer exists or is not inside "
                    f"Search Repository:\n{remembered}"
                )

                if origin_key in self.incoming_origin_map:
                    self.incoming_origin_map.pop(origin_key, None)

                if self.incoming_origin_record and (
                    self.incoming_origin_record.get("path") == str(remembered)
                ):
                    self.incoming_origin_record = None

            # 3. Legacy fallback: exact filename AND exact extension. If there
            # are several, Digi refuses to guess.
            matches = self.find_matching_targets(source)
            self.log_incoming_event(
                "FALLBACK MATCH",
                f"Exact filename+extension matches found: {len(matches)}"
            )

            if not matches:
                QMessageBox.warning(
                    self,
                    "No matching file",
                    f"No existing file with the same filename AND file type was found:\n\n"
                    f"{source.name}\n\n"
                    "The file has been left in Incoming.\n\n"
                    "Open the original file through Digi first so its exact "
                    "directory and original filename can be remembered."
                )
                self.log_incoming_event(
                    "WAITING",
                    "No source association or exact filename+extension match. "
                    "Incoming file left untouched."
                )
                continue

            if len(matches) == 1:
                if self.replace_file(source, matches[0], self, automatic=True):
                    self.log_incoming_event(
                        "COMPLETE",
                        f"Fallback exact match replaced:\n{matches[0]}"
                    )
            else:
                self.log_incoming_event(
                    "AMBIGUOUS",
                    "Multiple exact filename+extension destinations exist; "
                    "showing destination chooser."
                )
                self.choose_replacement_target(source, matches, self)

    def log_incoming_event(self, event, details=""):
        """Record a human-readable Incoming event for Geek Console."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        block = f"[{timestamp}] {event}"
        if details:
            block += f"\n{details}"
        self.incoming_debug_events.append(block)
        # Keep the in-memory console bounded.
        if len(self.incoming_debug_events) > 300:
            self.incoming_debug_events = self.incoming_debug_events[-300:]

    def remember_incoming_origin(self, path):
        """Remember the exact repository file currently being worked on."""
        path = Path(path)
        if not self._is_repository_file(path):
            return
        resolved = str(path.resolve())
        self.incoming_origin_record = {
            "path": resolved,
            "name": path.name,
            "suffix": path.suffix,
            "opened_at": datetime.now().isoformat(timespec="seconds"),
        }
        self.incoming_origin_map[(path.name.casefold(), path.suffix.casefold())] = resolved
        self.log_incoming_event(
            "FILE OPENED",
            f"Source: {resolved}\n"
            f"Original filename: {path.name}\n"
            f"Original extension: {path.suffix or '(none)'}\n"
            f"Directory: {path.parent}\n"
            "Status: waiting for a modified file in Incoming"
        )

    def show_incoming_geek_console(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Digi SE — Incoming Geek Console")
        dlg.resize(980, 700)
        dlg.setMinimumSize(700, 480)

        layout = QVBoxLayout(dlg)

        title = QLabel("Incoming / Source Association")
        title.setStyleSheet("font-size:20px;font-weight:bold;")
        layout.addWidget(title)

        current = QTextBrowser()
        current.setOpenExternalLinks(False)
        layout.addWidget(current, 1)

        controls = QHBoxLayout()
        refresh = QPushButton("Refresh")
        save_btn = QPushButton("Save log…")
        clear_btn = QPushButton("Clear session log")
        close_btn = QPushButton("Close")
        controls.addWidget(refresh)
        controls.addWidget(save_btn)
        controls.addWidget(clear_btn)
        controls.addStretch()
        controls.addWidget(close_btn)
        layout.addLayout(controls)

        def render():
            origin = self.incoming_origin_record
            if origin:
                origin_text = (
                    "ACTIVE SOURCE ASSOCIATION\n"
                    "────────────────────────────────────────\n"
                    f"Original path : {origin['path']}\n"
                    f"Original name : {origin['name']}\n"
                    f"Extension     : {origin['suffix'] or '(none)'}\n"
                    f"Opened at     : {origin['opened_at']}\n"
                    "Status        : WAITING FOR INCOMING FILE\n"
                )
            else:
                origin_text = (
                    "ACTIVE SOURCE ASSOCIATION\n"
                    "────────────────────────────────────────\n"
                    "None\n"
                )

            events = "\n\n".join(self.incoming_debug_events)
            current.setPlainText(
                origin_text
                + "\nEVENT LOG\n"
                + "────────────────────────────────────────\n"
                + (events or "No Incoming events recorded this session.")
            )
            current.moveCursor(current.textCursor().MoveOperation.End)

        def save_log():
            default_name = (
                f"digi_incoming_debug_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            )
            path, _ = QFileDialog.getSaveFileName(
                dlg,
                "Save Incoming debug log",
                str(APP_DIR / default_name),
                "Text files (*.txt);;All files (*.*)",
            )
            if not path:
                return
            try:
                Path(path).write_text(current.toPlainText(), encoding="utf-8")
                QMessageBox.information(dlg, "Log saved", f"Debug log saved to:\n\n{path}")
            except OSError as exc:
                QMessageBox.warning(dlg, "Save failed", f"Could not save the log:\n\n{exc}")

        def clear_log():
            answer = QMessageBox.question(
                dlg,
                "Clear session log?",
                "Clear the Incoming Geek Console event history for this session?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No,
            )
            if answer == QMessageBox.StandardButton.Yes:
                self.incoming_debug_events.clear()
                render()

        refresh.clicked.connect(render)
        save_btn.clicked.connect(save_log)
        clear_btn.clicked.connect(clear_log)
        close_btn.clicked.connect(dlg.accept)
        render()
        dlg.exec()

    def _is_repository_file(self, path):
        """Return True only for a real file inside the active Search Repository."""
        try:
            path = Path(path).resolve()
            root = Path(self.library_root).resolve()
            path.relative_to(root)

            if self.incoming_folder:
                incoming = self.incoming_folder.resolve()
                if path == incoming or incoming in path.parents:
                    return False

            cache = CACHE_DIR.resolve()
            if path == cache or cache in path.parents:
                return False

            return path.is_file()
        except (OSError, ValueError):
            return False

    def find_matching_targets(self, source):
        """Find repository files with the exact same filename AND extension."""
        matches = []
        try:
            source_resolved = source.resolve()
        except OSError:
            source_resolved = source

        # Use the active library root, not a stale module-level path.
        root = Path(self.library_root).resolve()
        for target in root.rglob(source.name):
            try:
                target = target.resolve()
            except OSError:
                continue
            if target == source_resolved:
                continue
            # Exact match requires BOTH the complete filename AND extension.
            if target.is_file() and (
                target.name.casefold() == source.name.casefold()
                and target.suffix.casefold() == source.suffix.casefold()
                and self._is_repository_file(target)
            ):
                matches.append(target)

        return sorted(set(matches), key=lambda p: str(p).lower())

    def choose_replacement_target(self, source, matches, parent=None):
        dlg = QDialog(parent or self)
        dlg.setWindowTitle("Choose destination for Incoming file")
        dlg.resize(820, 500)
        layout = QVBoxLayout(dlg)

        label = QLabel(
            f"More than one repository file matches:\n{source.name}\n\n"
            "Choose the exact destination to update."
        )
        label.setWordWrap(True)
        layout.addWidget(label)

        choices = QListWidget()
        for target in matches:
            item = QListWidgetItem(str(target))
            item.setData(Qt.UserRole, str(target))
            choices.addItem(item)
        choices.setCurrentRow(0)
        layout.addWidget(choices)

        buttons = QHBoxLayout()
        choose_btn = QPushButton("Use selected destination")
        cancel_btn = QPushButton("Cancel")
        buttons.addStretch()
        buttons.addWidget(choose_btn)
        buttons.addWidget(cancel_btn)
        layout.addLayout(buttons)

        def do_replace():
            item = choices.currentItem()
            if not item:
                QMessageBox.warning(
                    dlg, "Select a file", "Select the destination file first."
                )
                return
            target = Path(item.data(Qt.UserRole))
            if self.replace_file(source, target, dlg, automatic=True):
                dlg.accept()

        choose_btn.clicked.connect(do_replace)
        cancel_btn.clicked.connect(dlg.reject)
        choices.itemDoubleClicked.connect(lambda _: do_replace())
        dlg.exec()

    def replace_file(self, source, target, parent=None, automatic=False):
        source = Path(source)
        target = Path(target)

        if not source.exists() or not target.exists():
            QMessageBox.warning(
                parent or self,
                "Automatic update failed",
                "The Incoming source or repository target no longer exists."
            )
            return False

        if source.resolve() == target.resolve():
            return False

        temp = target.with_name(
            f".{target.name}.digi-replacement-{os.getpid()}-{datetime.now().strftime('%f')}.tmp"
        )

        try:
            # Copy to a temporary file in the target folder first, then atomically
            # replace the old repository file. No .bak files are left behind.
            self.log_incoming_event(
                "INSTALL",
                f"Incoming source: {source}\n"
                f"Target path: {target}\n"
                f"Target name restored to: {target.name}"
            )
            shutil.copy2(source, temp)
            os.replace(temp, target)
            source.unlink()
        except Exception as exc:
            try:
                if temp.exists():
                    temp.unlink()
            except OSError:
                pass
            QMessageBox.critical(
                parent or self,
                "Automatic update failed",
                f"The updated file could not be installed.\n\n{exc}"
            )
            return False

        self.db.conn.execute("DELETE FROM files WHERE path=?", (str(source.resolve()),))
        self.db.conn.commit()
        self.start_scan()

        if not automatic:
            QMessageBox.information(
                parent or self,
                "Update complete",
                f"Updated file installed:\n\n{target}"
            )
        return True

    def incoming_dialog(self):
        """Show Incoming status/files; replacement itself is automatic."""
        dlg = QDialog(self)
        dlg.setWindowTitle("Incoming")
        dlg.resize(820, 520)
        layout = QVBoxLayout(dlg)

        folder_row = QHBoxLayout()
        folder_label = QLabel(str(self.incoming_folder))
        folder_label.setWordWrap(True)
        choose = QPushButton("Change folder")
        choose.clicked.connect(lambda: self.choose_incoming(folder_label))
        open_btn = QPushButton("Open folder")
        open_btn.clicked.connect(lambda: open_folder(self.incoming_folder))
        folder_row.addWidget(folder_label, 1)
        folder_row.addWidget(choose)
        folder_row.addWidget(open_btn)
        layout.addLayout(folder_row)

        info = QLabel(
            "Open the original file through Digi, modify it, then save the modified "
            "copy into Incoming under any temporary filename. Digi remembers the "
            "exact original directory and filename and automatically returns the "
            "modified file there. If no source association exists, Digi falls back "
            "to exact filename+extension matching rather than guessing."
        )
        info.setWordWrap(True)
        layout.addWidget(info)

        files = QListWidget()
        layout.addWidget(files, 1)

        buttons = QHBoxLayout()
        refresh = QPushButton("Refresh")
        close = QPushButton("Close")
        buttons.addWidget(refresh)
        buttons.addStretch()
        buttons.addWidget(close)
        layout.addLayout(buttons)

        def reload_files():
            files.clear()
            try:
                incoming_files = [
                    x for x in self.incoming_folder.iterdir()
                    if x.is_file() and x.suffix.lower() in SUPPORTED
                ]
            except OSError:
                incoming_files = []
            for f in sorted(incoming_files, key=lambda x: x.name.lower()):
                files.addItem(str(f))

        reload_files()
        refresh.clicked.connect(reload_files)
        close.clicked.connect(dlg.accept)
        dlg.exec()

    def choose_incoming(self, label):
        chosen = QFileDialog.getExistingDirectory(
            self,
            "Choose Incoming folder",
            str(self.incoming_folder)
        )
        if chosen:
            self.incoming_folder = Path(chosen)
            self.db.set_setting("incoming_folder", str(self.incoming_folder))
            label.setText(str(self.incoming_folder))
            self.watch_incoming_folder()

    # ---------------- Search / display ----------------

    def effective_status(self, row):
        status, due = row[5], row[6]
        if due and status != "Finished":
            today = date.today().isoformat()
            if due < today:
                return "Due late"
            if due == today:
                return "Due"
        return status

    def search_score(self, path, query):
        if not query:
            return 0
        target = str(path).lower()
        q = query.lower()
        if q in target:
            return 1000 - target.index(q)
        return fuzz.partial_ratio(q, target) if fuzz else 0

    def fuzzy_search_score(self, path, query):
        """Return a useful approximate-match score for a repository path."""
        if not query or fuzz is None:
            return 0

        q = query.casefold()
        p = Path(path)
        name = p.stem.casefold()
        target = str(p).casefold()

        # Filename gets the strongest signal. WRatio handles common typos,
        # missing characters and word-order differences much better than the
        # old single token-set comparison against the entire absolute path.
        name_score = fuzz.WRatio(q, name)
        path_score = fuzz.token_set_ratio(q, target)

        # Folder/source names can also be relevant (e.g. "bio" matching a
        # Biology folder), without allowing an unrelated long path to dominate.
        part_scores = [
            fuzz.WRatio(q, part.casefold())
            for part in p.parts
            if part
        ]
        folder_score = max(part_scores, default=0)

        return max(name_score, path_score, folder_score)

    def filesystem_search_fallback(self, query):
        """Return supported files directly from the active repository when the index is empty/stale."""
        q = query.strip().casefold()
        if not q:
            return []

        rows = []
        root = Path(self.library_root).resolve()
        try:
            iterator = root.rglob("*")
            for p in iterator:
                if not p.is_file() or p.suffix.lower() not in SUPPORTED:
                    continue
                try:
                    resolved = p.resolve()
                except OSError:
                    continue
                try:
                    if CACHE_DIR.resolve() in resolved.parents:
                        continue
                    if self.incoming_folder and self.incoming_folder.resolve() in resolved.parents:
                        continue
                except OSError:
                    pass

                if q not in resolved.name.casefold() and q not in str(resolved).casefold():
                    continue

                row = self.db.get_file(resolved)
                if row:
                    rows.append(row)
                else:
                    try:
                        modified = resolved.stat().st_mtime
                    except OSError:
                        continue
                    rows.append((
                        str(resolved),
                        resolved.name,
                        resolved.suffix.lower(),
                        modified,
                        None,
                        "Not started",
                        None,
                        "Normal",
                    ))
                if len(rows) >= 500:
                    break
        except OSError:
            pass
        return rows

    def filtered_rows(self):
        query = self.search.text().strip()
        if not query and not self.folder_view_path:
            return []

        typ = self.type_filter.currentText()
        status = self.status_filter.currentText()
        source_filter = self.source_filter.currentText()
        method = self.search_method.currentText()

        if self.folder_view_path:
            # Folder browsing is filesystem-first. The normal search index can
            # legitimately lag behind a newly added/moved file, so browsing a
            # folder must not depend on the SQLite index being perfectly current.
            # Use indexed metadata where available, and create a lightweight
            # result row for supported files that are present on disk but not
            # indexed yet.
            candidates = []
            indexed = {}
            for existing_row in self.search_rows_cache:
                try:
                    key = str(Path(existing_row[0]).resolve()).casefold()
                    indexed[key] = existing_row
                except OSError:
                    indexed[str(existing_row[0]).casefold()] = existing_row

            try:
                folder_root = self.folder_view_path.resolve()
                for candidate in folder_root.rglob("*"):
                    if not candidate.is_file():
                        continue
                    try:
                        resolved = candidate.resolve()
                    except OSError:
                        continue
                    if resolved.suffix.lower() not in SUPPORTED:
                        continue
                    try:
                        if CACHE_DIR.resolve() in resolved.parents:
                            continue
                        if DEFAULT_INCOMING.resolve() in resolved.parents:
                            continue
                    except OSError:
                        pass

                    key = str(resolved).casefold()
                    row = indexed.get(key)
                    if row is None:
                        try:
                            modified = resolved.stat().st_mtime
                        except OSError:
                            continue
                        row = (
                            str(resolved),
                            resolved.name,
                            resolved.suffix.lower(),
                            modified,
                            None,
                            "Not started",
                            None,
                            "Normal",
                        )
                    candidates.append(row)
            except OSError:
                candidates = []

        elif method == "Fuzzy":
            # Fuzzy search operates on the in-memory index snapshot. It no
            # longer performs a full filesystem traversal while the user types.
            # This keeps the GUI thread free from repeated disk I/O.
            candidates = self.search_rows_cache
        else:
            # Normal search stays on the SQLite search path. In particular, do
            # not fetch every indexed row or walk the repository for each
            # keystroke; the background scanner owns filesystem discovery.
            candidates = self.db.search_rows(query)

        rows = []
        for row in candidates:
            path = Path(row[0])
            if not path.exists():
                continue

            # Search Repository intentionally lives inside APP_DIR. Do NOT
            # exclude APP_DIR here, otherwise every repository result is
            # discarded. Only Digi's internal Cache and Incoming staging
            # directory are excluded from searchable results.
            try:
                resolved = path.resolve()
                cache_dir = CACHE_DIR.resolve()
                incoming_dir = DEFAULT_INCOMING.resolve()
                if resolved == cache_dir or cache_dir in resolved.parents:
                    continue
                if resolved == incoming_dir or incoming_dir in resolved.parents:
                    continue
            except OSError:
                pass

            if self.folder_view_path:
                try:
                    folder_root = self.folder_view_path.resolve()
                    resolved = path.resolve()
                    try:
                        resolved.relative_to(folder_root)
                    except ValueError:
                        # Windows paths can occasionally differ in case or
                        # normalization. Fall back to a case-insensitive
                        # common-path comparison.
                        common = os.path.commonpath(
                            [str(resolved).casefold(), str(folder_root).casefold()]
                        )
                        if common != str(folder_root).casefold():
                            continue
                except (OSError, ValueError):
                    continue

            parts = {part.casefold() for part in path.parts}
            if source_filter == "ExamPro" and "exampro" not in parts:
                continue
            if source_filter == "PMT" and "pmt" not in parts:
                continue

            if self.folder_view_path:
                score = 0
            elif method == "Fuzzy":
                score = self.fuzzy_search_score(path, query)
                if score < 45:
                    continue
            else:
                score = self.search_score(path, query.lower())
                if score < 45:
                    continue

            if typ == "PDF" and row[2] != ".pdf":
                continue
            if typ == "Word" and row[2] not in {".doc", ".docx"}:
                continue

            effective = self.effective_status(row)
            if status == "Due" and effective != "Due":
                continue
            if status == "Due late" and effective != "Due late":
                continue
            if status not in {
                "All statuses", "Due", "Due late"
            } and effective != status:
                continue

            rows.append((row, score, effective))

        return rows

    def sort_rows(self, rows):
        sort = self.sort.currentText()
        if sort == "Relevance":
            rows.sort(
                key=lambda x: (-x[1], x[0][1].lower())
            )
        elif sort == "Name A-Z":
            rows.sort(key=lambda x: x[0][1].lower())
        elif sort == "Name Z-A":
            rows.sort(
                key=lambda x: x[0][1].lower(), reverse=True
            )
        elif sort == "Newest modified":
            rows.sort(key=lambda x: x[0][3], reverse=True)
        elif sort == "Oldest modified":
            rows.sort(key=lambda x: x[0][3])
        elif sort == "Most pages":
            rows.sort(
                key=lambda x: x[0][4] or 0, reverse=True
            )
        elif sort == "Fewest pages":
            rows.sort(key=lambda x: x[0][4] or 0)
        return rows

    def refresh(self):
        if not hasattr(self, "results"):
            return

        query = self.search.text().strip()
        if self.folder_view_path and not query:
            self.results_stack.setCurrentIndex(0)
            rows = self.sort_rows(self.filtered_rows())
            self.render_rows(rows)
            return
        if not query:
            self.folder_view_path = None
            self.folder_browser_btn.setText("Search Repository ▾")
            self.results_stack.setCurrentIndex(1)
            self.results.clearSelection()
            self.results.clearFocus()
            self.current_path = None
            self.set_detail_enabled(False)
            self.detail_name.setText("No file selected")
            self.tags_label.setText("None")
            self.info.setText("0 results")
            self.search_hint.setText("Type a search term to show files.")
            return

        self.results_stack.setCurrentIndex(0)

        # Search work now uses the indexed database/in-memory snapshot only.
        # No repository-wide filesystem traversal is performed on each input.
        rows = self.sort_rows(self.filtered_rows())
        self.render_rows(rows)

        if self.scanning:
            self.search_hint.setText(
                "Updating index in the background..."
            )
        else:
            self.search_hint.setText("")


    def render_rows(self, rows):
        keep = (
            str(self.current_path.resolve())
            if self.current_path and self.current_path.exists()
            else None
        )

        self.results.blockSignals(True)
        self.results.clear()

        display_rows = rows[:300]
        for row, score, effective in display_rows:
            path = Path(row[0])
            try:
                relative = path.relative_to(ROOT)
                folder = (
                    str(relative.parent)
                    if str(relative.parent) != "."
                    else "Root"
                )
            except ValueError:
                folder = str(path.parent)

            ext = row[2].lower()
            meta = ext.upper().replace(".", "")
            if row[4] is not None:
                meta += f" • {row[4]} pages"
            meta += f" • Modified {datetime.fromtimestamp(row[3]).strftime('%d %b %Y')}"
            meta += f" • {effective}"

            # Cosmetic only: display the filename without its extension and
            # give PDF/Word filenames a subtle type-specific tint. The actual
            # path, extension, indexing and search data remain unchanged.
            display_name = path.stem

            item = QTreeWidgetItem()
            item.setData(0, Qt.ItemDataRole.UserRole, row[0])
            item.setData(0, Qt.ItemDataRole.UserRole + 1, path.name)
            item.setData(0, Qt.ItemDataRole.UserRole + 2, f"Directory: {folder}")
            item.setData(0, Qt.ItemDataRole.UserRole + 3, meta)
            item.setToolTip(0, row[0])
            item.setText(0, display_name)

            if ext == ".pdf":
                item.setForeground(0, QColor("#d98f8f"))
            elif ext in {".doc", ".docx"}:
                item.setForeground(0, QColor("#8eabd9"))

            child = QTreeWidgetItem()
            child.setData(0, Qt.ItemDataRole.UserRole, row[0])
            child.setData(0, Qt.ItemDataRole.UserRole + 2, f"Directory: {folder}")
            child.setData(0, Qt.ItemDataRole.UserRole + 3, str(path))
            child.setFlags(child.flags() & ~Qt.ItemFlag.ItemIsSelectable)
            item.addChild(child)
            item.setExpanded(False)
            self.results.addTopLevelItem(item)

        self.results.blockSignals(False)

        if len(rows) > len(display_rows):
            self.info.setText(
                f"{len(rows)} result(s) — showing first {len(display_rows)}"
            )
        else:
            self.info.setText(f"{len(rows)} result(s)")

        if keep:
            for i in range(self.results.topLevelItemCount()):
                item = self.results.topLevelItem(i)
                if item.data(0, Qt.ItemDataRole.UserRole) == keep:
                    self.results.setCurrentItem(item)
                    break

    def search_changed(self):
        # Typing a search query returns to normal search mode.
        if self.search.text().strip() and self.folder_view_path is not None:
            self.folder_view_path = None
            self.folder_browser_btn.setText("Search Repository ▾")
        self.search_timer.start()

    def save_current_search(self):
        q = self.search.text().strip()
        if q:
            self.db.add_recent(q)

    def show_recent(self):
        recents = self.db.recents()
        if not recents:
            QMessageBox.information(
                self, "Recent searches", "No recent searches yet."
            )
            return

        dlg = QDialog(self)
        dlg.setWindowTitle("Recent searches")
        layout = QVBoxLayout(dlg)

        listw = QListWidget()
        for (q,) in recents:
            listw.addItem(q)

        listw.itemDoubleClicked.connect(
            lambda item: (
                self.search.setText(item.text()),
                dlg.accept()
            )
        )

        layout.addWidget(listw)
        dlg.resize(400, 350)
        dlg.exec()

    # ---------------- Selected file metadata ----------------

    def _row_for_selected_path(self, path):
        """Return indexed metadata or a safe filesystem fallback for folder browsing."""
        row = self.db.get_file(path)
        if row:
            return row
        try:
            p = Path(path).resolve()
            st = p.stat()
            return (
                str(p),
                p.name,
                p.suffix.lower(),
                st.st_mtime,
                None,
                "Not started",
                None,
                "Normal",
            )
        except OSError:
            return None

    def selected(self, current, previous):
        if not current:
            self.current_path = None
            self.set_detail_enabled(False)
            self.detail_name.setText("No file selected")
            self.tags_label.setText("None")
            return

        self.current_path = Path(current.data(0, Qt.ItemDataRole.UserRole))
        row = self._row_for_selected_path(self.current_path)
        if not row:
            self.current_path = None
            self.set_detail_enabled(False)
            self.detail_name.setText("No file selected")
            self.tags_label.setText("None")
            return

        self.set_detail_enabled(True)
        self.detail_name.setText(row[1])

        self.status_edit.blockSignals(True)
        self.status_edit.setCurrentText(row[5])
        self.status_edit.blockSignals(False)

        self.due_edit.blockSignals(True)
        if row[6]:
            self.due_edit.setDate(
                QDate.fromString(row[6], "yyyy-MM-dd")
            )
        else:
            self.due_edit.setDate(QDate.currentDate())
        self.due_edit.blockSignals(False)

        self.update_tags()
        self.open_btn.setEnabled(True)
        self.open_folder_btn.setEnabled(True)

    def save_status(self, value):
        if self.current_path:
            self.db.update(
                self.current_path, "status", value
            )
            self.refresh()

    def save_due(self, value):
        if self.current_path:
            self.db.update(
                self.current_path,
                "due_date",
                value.toString("yyyy-MM-dd")
            )
            self.refresh()

    def update_tags(self):
        if not self.current_path:
            self.tags_label.setText("None")
            return
        tags = self.db.get_tags(self.current_path)
        self.tags_label.setText(
            ", ".join(tags) if tags else "None"
        )

    def add_tag(self):
        if not self.current_path:
            return

        tag, ok = QInputDialog.getText(
            self, "Add tag", "Tag name:"
        )
        if ok and tag.strip():
            self.db.add_tag(self.current_path, tag)
            self.update_tags()
            self.refresh()

    def remove_tag(self):
        if not self.current_path:
            return

        tags = self.db.get_tags(self.current_path)
        if not tags:
            return

        tag, ok = QInputDialog.getItem(
            self,
            "Remove tag",
            "Choose tag:",
            tags,
            0,
            False
        )
        if ok:
            self.db.remove_tag(self.current_path, tag)
            self.update_tags()
            self.refresh()

    def _convert_selected(self, target_kind):
        if not self.current_path:
            QMessageBox.information(self, "No file selected", "Select a file first.")
            return

        path = Path(self.current_path)
        if not path.exists():
            QMessageBox.warning(self, "File missing", "That file no longer exists.")
            return

        ext = path.suffix.lower()
        if target_kind == "pdf" and ext == ".pdf":
            QMessageBox.information(
                self, "Already a PDF",
                "This file is already a PDF; there is nothing to convert."
            )
            return

        if target_kind == "word" and ext not in {".doc", ".docx"}:
            # Only PDFs are expected to convert to Word in this tool.
            if ext == ".pdf":
                pass
            else:
                QMessageBox.warning(
                    self, "Unsupported conversion",
                    "Only PDF → Word and Word → PDF conversion is supported."
                )
                return

        if target_kind == "word" and ext == ".doc":
            QMessageBox.warning(
                self, "Word format limitation",
                "The Word converter outputs .docx. Legacy .doc files are not "
                "supported as an input for this conversion."
            )
            return

        if target_kind == "word":
            out = path.with_suffix(".docx")
        else:
            out = path.with_suffix(".pdf")

        if out.exists():
            answer = QMessageBox.question(
                self, "Output already exists",
                f"{out.name} already exists.\n\nReplace it?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )
            if answer != QMessageBox.StandardButton.Yes:
                return

        # Ask what to do with the source ("previous version") before conversion.
        # The source is only removed after a successful conversion, so a failed
        # conversion can never destroy the original file.
        source_label = "PDF" if ext == ".pdf" else "Word document"
        answer = QMessageBox.question(
            self,
            "Keep the original file?",
            f"Conversion will create {out.name}.\n\n"
            f"Keep the original {source_label} in the folder as well?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.Yes
        )
        retain_source = answer == QMessageBox.StandardButton.Yes

        dlg = ConversionDialog(path, target_kind, self)
        dlg.exec()

        if getattr(dlg, "conversion_ok", False) and not retain_source:
            try:
                if path.exists():
                    path.unlink()
            except OSError as exc:
                QMessageBox.warning(
                    self,
                    "Original file kept",
                    f"The conversion succeeded, but Digi could not remove the "
                    f"original {source_label.lower()}:\n{exc}"
                )

        self.start_scan()

    def convert_selected_to_pdf(self):
        if not self.current_path:
            QMessageBox.information(self, "No file selected", "Select a file first.")
            return
        if Path(self.current_path).suffix.lower() == ".pdf":
            QMessageBox.information(
                self, "Already a PDF",
                "This file is already a PDF; there is nothing to convert."
            )
            return
        self._convert_selected("pdf")

    def convert_selected_to_word(self):
        if not self.current_path:
            QMessageBox.information(self, "No file selected", "Select a file first.")
            return
        if Path(self.current_path).suffix.lower() == ".docx":
            QMessageBox.information(
                self, "Already a Word document",
                "This file is already a Word document; there is nothing to convert."
            )
            return
        if Path(self.current_path).suffix.lower() != ".pdf":
            QMessageBox.warning(
                self, "Unsupported conversion",
                "Only PDF files can be converted to Word documents."
            )
            return
        self._convert_selected("word")

    def open_selected(self, item=None, *args):
        # Buttons use the selected/current path; double-clicks may provide an item.
        if isinstance(item, QTreeWidgetItem):
            p = Path(item.data(0, Qt.ItemDataRole.UserRole))
        elif self.current_path:
            p = Path(self.current_path)
        else:
            current = self.results.currentItem()
            if not current:
                return
            p = Path(current.data(0, Qt.ItemDataRole.UserRole))

        if not p.exists():
            QMessageBox.warning(
                self, "File missing", "That file no longer exists."
            )
            self.start_scan()
            return

        # Remember the exact file the user opened. A later modified copy saved
        # to Incoming with the same filename+extension returns to this exact path.
        if self._is_repository_file(p):
            self.remember_incoming_origin(p)

        if not open_file(p):
            QMessageBox.warning(
                self, "Could not open file",
                f"Windows could not open this file:\n\n{p}"
            )

    def open_containing_folder(self, *args):
        if not self.current_path:
            current = self.results.currentItem()
            if current:
                self.current_path = Path(current.data(0, Qt.ItemDataRole.UserRole))
        if self.current_path and self.current_path.exists():
            if not open_folder(self.current_path):
                QMessageBox.warning(
                    self, "Could not open folder",
                    f"Windows could not open the containing folder:\n\n{self.current_path.parent}"
                )

    def closeEvent(self, event):
        if self.scan_worker and self.scan_worker.isRunning():
            self.scan_worker.quit()
            self.scan_worker.wait(1500)
        self.db.conn.close()
        event.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("Digi Search Engine")

    # Build the main window while the branded startup screen is visible.
    w = MainWindow()

    splash = SplashScreen()

    def show_main_window():
        w.show()
        w.raise_()
        w.activateWindow()

    splash.start(show_main_window)
    sys.exit(app.exec())
