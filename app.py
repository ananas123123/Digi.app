from pathlib import Path
import sys

from PySide6.QtCore import QEvent, QUrl, Qt
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import (
    QApplication,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QPushButton,
    QVBoxLayout,
    QWidget,
)
from PySide6.QtWebChannel import QWebChannel
from PySide6.QtWebEngineWidgets import QWebEngineView

from backend.api import DigiBridge
from backend.version_manager import repair_after_close

BASE_DIR = Path(__file__).resolve().parent

TITLEBAR_HEIGHT = 42
RESIZE_MARGIN = 8
ACCENT = "#c5f36b"
WINDOW_BG = "#10110f"
TITLEBAR_BG = "#171916"
TITLEBAR_BORDER = "#30352c"


class DigiTitleBar(QWidget):
    """Custom Digi title bar with native window move and window controls."""

    def __init__(self, window):
        super().__init__(window)
        self.window = window
        self.setObjectName("DigiTitleBar")
        self.setFixedHeight(TITLEBAR_HEIGHT)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 0, 0, 0)
        layout.setSpacing(0)

        mark = QLabel("D")
        mark.setObjectName("DigiTitleMark")
        mark.setAlignment(Qt.AlignmentFlag.AlignCenter)
        mark.setFixedSize(23, 23)

        title = QLabel("Digi")
        title.setObjectName("DigiTitleText")

        subtitle = QLabel("SEARCH ENGINE")
        subtitle.setObjectName("DigiTitleSubtitle")

        brand = QHBoxLayout()
        brand.setContentsMargins(0, 0, 0, 0)
        brand.setSpacing(9)
        brand.addWidget(mark)
        brand.addWidget(title)
        brand.addWidget(subtitle)
        brand.addStretch(1)

        brand_widget = QWidget()
        brand_widget.setLayout(brand)
        brand_widget.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        layout.addWidget(brand_widget, 1)

        self.min_button = self._button("—", "Minimise Digi", "DigiMinButton")
        self.max_button = self._button("□", "Maximise Digi", "DigiMaxButton")
        self.close_button = self._button("×", "Close Digi", "DigiCloseButton")
        self.min_button.clicked.connect(self.window.showMinimized)
        self.max_button.clicked.connect(self.toggle_maximized)
        self.close_button.clicked.connect(self.window.close)
        layout.addWidget(self.min_button)
        layout.addWidget(self.max_button)
        layout.addWidget(self.close_button)

    def _button(self, text, tooltip, name):
        button = QPushButton(text)
        button.setObjectName(name)
        button.setToolTip(tooltip)
        button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        button.setFixedSize(46, TITLEBAR_HEIGHT)
        return button

    def toggle_maximized(self):
        if self.window.isMaximized():
            self.window.showNormal()
        else:
            self.window.showMaximized()

    def sync_maximize_button(self):
        maximized = self.window.isMaximized()
        self.max_button.setText("❐" if maximized else "□")
        self.max_button.setToolTip("Restore Digi" if maximized else "Maximise Digi")

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.toggle_maximized()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self.window.isMaximized():
            handle = self.window.windowHandle()
            if handle and handle.startSystemMove():
                event.accept()
                return
        elif event.button() == Qt.MouseButton.LeftButton and self.window.isMaximized():
            # Native move allows dragging a maximised window down to restore it
            # on platforms that support startSystemMove.
            handle = self.window.windowHandle()
            if handle and handle.startSystemMove():
                event.accept()
                return
        super().mousePressEvent(event)


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
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)

        root = QWidget(self)
        root.setObjectName("DigiWindowRoot")
        root.setStyleSheet(
            f"""
            QWidget#DigiWindowRoot {{
                background: {WINDOW_BG};
                border: 1px solid {TITLEBAR_BORDER};
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
        self.title_bar = DigiTitleBar(self)
        layout.addWidget(self.title_bar)

        self.view = QWebEngineView(root)
        self.view.setObjectName("DigiWebView")
        self.view.setStyleSheet("border: none; background: #10110f;")
        layout.addWidget(self.view, 1)
        self.setCentralWidget(root)

        self.bridge = DigiBridge(self)
        self.channel = QWebChannel(self.view.page())
        self.channel.registerObject("backend", self.bridge)
        self.view.page().setWebChannel(self.channel)
        self.view.load(QUrl.fromLocalFile(str(BASE_DIR / "frontend" / "index.html")))

        app = QApplication.instance()
        if app:
            app.installEventFilter(self)

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QEvent.Type.WindowStateChange and hasattr(self, "title_bar"):
            self.title_bar.sync_maximize_button()

    def eventFilter(self, watched, event):
        # FramelessWindowHint removes Windows' native resize frame. Restore
        # native resizing by handing edge drags to the operating system.
        if event.type() == QEvent.Type.MouseButtonPress:
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
        return super().eventFilter(watched, event)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Digi Search Engine")
    app.setStyle("Fusion")
    window = DigiWindow()
    window.show()
    app.aboutToQuit.connect(repair_after_close)
    sys.exit(app.exec())
