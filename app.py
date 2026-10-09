from pathlib import Path
import sys
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtWebChannel import QWebChannel
from PySide6.QtWebEngineWidgets import QWebEngineView
from backend.api import DigiBridge
from backend.version_manager import repair_after_close

BASE_DIR = Path(__file__).resolve().parent

class DigiWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Digi Search Engine")
        self.resize(1180, 720)
        self.setMinimumSize(900, 600)
        self.view = QWebEngineView(self)
        self.setCentralWidget(self.view)
        self.bridge = DigiBridge(self)
        self.channel = QWebChannel(self.view.page())
        self.channel.registerObject("backend", self.bridge)
        self.view.page().setWebChannel(self.channel)
        self.view.load(QUrl.fromLocalFile(str(BASE_DIR / "frontend" / "index.html")))

def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Digi Search Engine")
    window = DigiWindow()
    window.show()
    app.aboutToQuit.connect(repair_after_close)
    sys.exit(app.exec())
