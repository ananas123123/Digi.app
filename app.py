from pathlib import Path
import sys

from PySide6.QtCore import QEvent, QUrl, Qt, Signal
from PySide6.QtGui import QPainterPath, QRegion
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QVBoxLayout,
    QWidget,
)
from PySide6.QtWebChannel import QWebChannel
from PySide6.QtWebEngineWidgets import QWebEngineView

from backend.api import DigiBridge
from backend.version_manager import repair_after_close

BASE_DIR = Path(__file__).resolve().parent

RESIZE_MARGIN = 8
ACCENT = "#c5f36b"
WINDOW_BG = "#10110f"
TITLEBAR_BG = "#171916"
TITLEBAR_BORDER = "#30352c"


class DigiWebView(QWebEngineView):
    localFoldersDropped = Signal("QStringList", int, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event):
        mime = event.mimeData()
        if mime.hasUrls() and any(url.isLocalFile() and Path(url.toLocalFile()).is_dir() for url in mime.urls()):
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            return
        event.ignore()

    def dragMoveEvent(self, event):
        mime = event.mimeData()
        if mime.hasUrls() and any(url.isLocalFile() and Path(url.toLocalFile()).is_dir() for url in mime.urls()):
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            return
        event.ignore()

    def dropEvent(self, event):
        mime = event.mimeData()
        folders = []
        if mime.hasUrls():
            for url in mime.urls():
                if not url.isLocalFile():
                    continue
                path = Path(url.toLocalFile())
                if path.is_dir():
                    folders.append(str(path.resolve()))
        if folders:
            self.localFoldersDropped.emit(folders, event.position().toPoint().x(), event.position().toPoint().y())
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
        else:
            event.ignore()


class DigiWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Digi Search Engine")
        self.setWindowFlags(
            Qt.WindowType.Window
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowSystemMenuHint
            | Qt.WindowType.WindowMinMaxButtonsHint
        )
        self.resize(1180, 720)
        self.setMinimumSize(900, 600)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)

        root = QWidget(self)
        root.setObjectName("DigiWindowRoot")
        root.setStyleSheet(
            f"""
            QWidget#DigiWindowRoot {{
                background: {WINDOW_BG};
                border: 1px solid {TITLEBAR_BORDER};
                border-radius: 18px;
            }}
            QWidget#DigiTitleBar {{
                background: {TITLEBAR_BG};
                border-bottom: 1px solid {TITLEBAR_BORDER};
            }}
            QLabel#DigiTitleMark {{
                background: {ACCENT};
                color: #1b2410;
                border-radius: 7px;
                font-size: 14px;
                font-weight: 900;
            }}
            QLabel#DigiTitleText {{
                color: #f3f5ed;
                font-size: 13px;
                font-weight: 750;
            }}
            QLabel#DigiTitleSubtitle {{
                color: #8f9884;
                font-size: 9px;
                font-weight: 700;
                letter-spacing: 1px;
                padding-left: 2px;
            }}
            QPushButton#DigiMinButton, QPushButton#DigiMaxButton,
            QPushButton#DigiCloseButton {{
                background: transparent;
                color: #c5cbbd;
                border: none;
                border-radius: 0;
                font-size: 15px;
                font-weight: 500;
                padding: 0;
            }}
            QPushButton#DigiMinButton:hover, QPushButton#DigiMaxButton:hover {{
                background: #2a2e25;
                color: #ffffff;
            }}
            QPushButton#DigiCloseButton:hover {{
                background: #d83b43;
                color: #ffffff;
            }}
            """
        )

        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self.view = DigiWebView(root)
        self.view.setObjectName("DigiWebView")
        self.view.setStyleSheet("border: none; background: #10110f;")
        self.view.localFoldersDropped.connect(self._handle_local_folders_dropped)
        layout.addWidget(self.view, 1)
        self.setCentralWidget(root)
        self._apply_window_shape()

        self.bridge = DigiBridge(self)
        self.channel = QWebChannel(self.view.page())
        self.channel.registerObject("backend", self.bridge)
        self.view.page().setWebChannel(self.channel)
        self.view.load(QUrl.fromLocalFile(str(BASE_DIR / "frontend" / "index.html")))

        app = QApplication.instance()
        if app:
            app.installEventFilter(self)

    def _handle_local_folders_dropped(self, folders, x, y):
        # Pass actual native filesystem paths to the page; Chromium's HTML5
        # DataTransfer intentionally does not expose reliable folder paths.
        import json
        payload = json.dumps(list(folders))
        self.view.page().runJavaScript(
            "if (window.handleNativeFolderDrop) window.handleNativeFolderDrop("
            + json.dumps(payload) + ", " + str(int(x)) + ", " + str(int(y)) + ");"
        )

    def _apply_window_shape(self):
        # Apply the shape to the native frameless window, not only the HTML.
        # Maximized/full-screen mode must fill the screen with square corners.
        if self.isMaximized() or self.isFullScreen():
            self.clearMask()
            return
        path = QPainterPath()
        path.addRoundedRect(0, 0, self.width(), self.height(), 18, 18)
        self.setMask(QRegion(path.toFillPolygon().toPolygon()))

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._apply_window_shape()

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QEvent.Type.WindowStateChange:
            self._apply_window_shape()

    def eventFilter(self, watched, event):
        # FramelessWindowHint removes Windows' native resize frame. Restore
        # native resizing by handing edge drags to the operating system.
        belongs_to_window = watched is self or (
            isinstance(watched, QWidget) and self.isAncestorOf(watched)
        )
        if belongs_to_window and event.type() == QEvent.Type.MouseButtonPress:
            if event.button() == Qt.MouseButton.LeftButton and self.isVisible():
                global_pos = event.globalPosition().toPoint()
                local = self.mapFromGlobal(global_pos)
                x, y = local.x(), local.y()
                width, height = self.width(), self.height()
                edges = Qt.Edge(0)
                if x < RESIZE_MARGIN:
                    edges |= Qt.Edge.LeftEdge
                elif x >= width - RESIZE_MARGIN:
                    edges |= Qt.Edge.RightEdge
                if y < RESIZE_MARGIN:
                    edges |= Qt.Edge.TopEdge
                elif y >= height - RESIZE_MARGIN:
                    edges |= Qt.Edge.BottomEdge
                if edges and not self.isMaximized():
                    handle = self.windowHandle()
                    if handle and handle.startSystemResize(edges):
                        return True
        # Forward drags from the embedded page's header to the native window.
        # Interactive controls are excluded so their clicks continue to work.
        if event.type() == QEvent.Type.MouseButtonPress and event.button() == Qt.MouseButton.LeftButton:
            if watched is self.view or (isinstance(watched, QWidget) and self.view.isAncestorOf(watched)):
                global_pos = event.globalPosition().toPoint()
                local = self.view.mapFromGlobal(global_pos)
                js = """
                    (() => {
                      const el = document.elementFromPoint(%d, %d);
                      if (!el) return false;
                      const header = el.closest('.header');
                      if (!header) return false;
                      return !el.closest('button, input, select, textarea, a, .search-wrap, .window-controls');
                    })()
                """ % (local.x(), local.y())
                def begin_move(result):
                    if result and not self.isMaximized():
                        handle = self.windowHandle()
                        if handle:
                            handle.startSystemMove()
                self.view.page().runJavaScript(js, begin_move)
        return super().eventFilter(watched, event)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Digi Search Engine")
    app.setStyle("Fusion")
    window = DigiWindow()
    window.show()
    app.aboutToQuit.connect(repair_after_close)
    sys.exit(app.exec())
