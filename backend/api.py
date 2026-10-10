import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path
import re
from PySide6.QtCore import QObject, Signal, Slot, QThread, QTimer
from PySide6.QtWidgets import QFileDialog
from .config import APP_VERSION, DEPENDENCIES_ROOT, LIBRARY_CONFIG, get_library_root, ensure_directories
from .database import Database
from .search import SearchService
from .files import FileService
from .conversion import ConversionWorker
from .notes import NotesService
from .version_manager import initialize_version_file, version_integrity, recalibrate_version
from .updater_download import download_package_to_path, verify_package_sha256


class ReleaseManifestWorker(QThread):
    resultReady = Signal(str)

    LATEST_URLS = (
        "https://api.github.com/repos/ananas123123/digiwebversionreleases/contents/latest.json?ref=main",
        "https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/latest.json",
    )
    RELEASES_RAW_ROOT = "https://raw.githubusercontent.com/ananas123123/digiwebversionreleases/main/releases"

    @staticmethod
    def _local_test_url():
        """Return an explicitly opted-in loopback-only test URL, otherwise None."""
        if os.environ.get("DIGI_UPDATER_TEST_MODE") != "1":
            return None
        candidate = os.environ.get("DIGI_UPDATER_TEST_MANIFEST_URL", "").strip()
        try:
            parsed = urllib.parse.urlparse(candidate)
            host = (parsed.hostname or "").lower()
            if (
                parsed.scheme != "http"
                or host not in {"127.0.0.1", "localhost", "::1"}
                or not parsed.port
                or parsed.username is not None
                or parsed.password is not None
            ):
                return None
            return candidate
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _read_json(url, github_api=False):
        separator = "&" if "?" in url else "?"
        request_url = url + separator + "_digi_check=" + str(int(time.time() * 1000))
        request = urllib.request.Request(request_url, headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "Digi-Update-Checker",
            "Cache-Control": "no-cache, no-store, max-age=0",
            "Pragma": "no-cache",
        })
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = response.read()
        if github_api:
            import base64
            envelope = json.loads(payload.decode("utf-8"))
            if envelope.get("encoding") != "base64" or not envelope.get("content"):
                raise ValueError("GitHub API did not return base64 file content.")
            payload = base64.b64decode(envelope["content"])
        value = json.loads(payload.decode("utf-8"))
        if not isinstance(value, dict):
            raise ValueError("Release metadata must be a JSON object.")
        return value

    @classmethod
    def _read_first_json(cls, urls):
        last_error = None
        for url, is_api in urls:
            try:
                return cls._read_json(url, github_api=is_api)
            except Exception as exc:
                last_error = exc
        raise ValueError("Could not read release metadata: " + (str(last_error) if last_error else "no metadata URLs configured"))

    @staticmethod
    def _safe_relative_path(value, label):
        if not isinstance(value, str) or not value.strip():
            raise ValueError(label + " is missing.")
        normalized = value.replace("\\", "/").strip()
        parsed = urllib.parse.urlparse(normalized)
        parts = normalized.split("/")
        if parsed.scheme or parsed.netloc or normalized.startswith("/") or any(part in {"", ".", ".."} for part in parts):
            raise ValueError(label + " must be a safe relative path.")
        return "/".join(urllib.parse.quote(part, safe="._- ") for part in parts).replace(" ", "%20")

    @classmethod
    def _resolve_latest_manifest(cls, latest):
        if latest.get("schema_version") != 1 or latest.get("product") != "Digi":
            raise ValueError("latest.json has an unsupported schema or product.")
        version = latest.get("latest_version")
        if not isinstance(version, str) or not version.strip() or not re.fullmatch(r"\d+(?:\.\d+)*", version.strip()):
            raise ValueError("latest.json does not contain a valid latest_version.")
        version = version.strip()
        status = latest.get("release_status")
        if status not in {"published", "unpublished"}:
            raise ValueError("latest.json has an invalid release_status.")
        if status == "unpublished":
            return {
                "schema_version": 1, "product": "Digi", "channel": latest.get("channel", "stable"),
                "latest_version": version, "release_status": status, "message": latest.get("message", ""),
                "release": {"version": version}
            }

        directory_index = cls._read_json(cls.RELEASES_RAW_ROOT + "/directory.json")
        if directory_index.get("schema_version") != 1 or directory_index.get("product") != "Digi":
            raise ValueError("releases/directory.json has an unsupported schema or product.")
        entries = directory_index.get("releases")
        entry = entries.get(version) if isinstance(entries, dict) else None
        if not isinstance(entry, dict):
            raise ValueError("directory.json does not contain latest version " + version + ".")

        folder = cls._safe_relative_path(entry.get("directory"), "Release directory")
        metadata_path = cls._safe_relative_path(entry.get("metadata_file"), "Release metadata_file")
        if "/" in folder or not metadata_path.startswith(folder + "/"):
            raise ValueError("directory.json points to a metadata file outside the selected release folder.")

        metadata_url = cls.RELEASES_RAW_ROOT + "/" + metadata_path
        release_metadata = cls._read_json(metadata_url)
        if (
            release_metadata.get("schema_version") != 1
            or release_metadata.get("product") != "Digi"
            or release_metadata.get("version") != version
            or release_metadata.get("directory") != folder
        ):
            raise ValueError("Version-specific release metadata does not match latest.json and directory.json.")

        package = release_metadata.get("package")
        if not isinstance(package, dict):
            raise ValueError("The selected release metadata has no package entry.")
        filename = package.get("file_name")
        relative_file = cls._safe_relative_path(package.get("path"), "Package path")
        if "/" in relative_file or not isinstance(filename, str) or not filename.strip() or filename != package.get("path"):
            raise ValueError("Package filename and relative path must identify one file inside the release folder.")
        if Path(filename).name != filename or Path(filename).suffix.lower() not in {".exe", ".txt"}:
            raise ValueError("The selected release package must be a .exe or .txt file.")
        size = package.get("size_bytes")
        checksum = package.get("sha256")
        if isinstance(size, bool) or not isinstance(size, int) or size <= 0:
            raise ValueError("Package size_bytes must be a positive integer.")
        if not isinstance(checksum, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", checksum):
            raise ValueError("Package SHA-256 checksum is invalid.")

        package_url = cls.RELEASES_RAW_ROOT + "/" + folder + "/" + relative_file
        return {
            "schema_version": 1,
            "product": "Digi",
            "channel": latest.get("channel", "stable"),
            "latest_version": version,
            "release_status": status,
            "message": latest.get("message", ""),
            "release": {
                "version": version,
                "url": "https://github.com/ananas123123/digiwebversionreleases/tree/main/releases/" + folder,
                "published_at": release_metadata.get("published_at"),
                "notes": release_metadata.get("release_notes", ""),
                "package": {
                    "url": package_url,
                    "file_name": filename,
                    "size_bytes": size,
                    "sha256": checksum.lower(),
                    "kind": package.get("kind", "installer")
                }
            }
        }

    def run(self):
        test_url = self._local_test_url()
        try:
            if test_url:
                manifest = self._read_json(test_url)
                result = {"ok": True, "manifest": manifest, "test_mode": True}
            else:
                latest = self._read_first_json(tuple((url, "api.github.com" in url) for url in self.LATEST_URLS))
                manifest = self._resolve_latest_manifest(latest)
                result = {"ok": True, "manifest": manifest}
        except Exception as exc:
            result = {"ok": False, "manifest": None, "error": str(exc)}
            if test_url:
                result["test_mode"] = True
        self.resultReady.emit(json.dumps(result))


class PackageDownloadWorker(QThread):
    resultReady = Signal(str)

    def __init__(self, manifest_json, parent=None):
        super().__init__(parent)
        self.manifest_json = manifest_json

    def run(self):
        try:
            manifest = json.loads(self.manifest_json)
            version = str(manifest.get("latest_version", "")).strip()
            safe_version = re.sub(r"[^0-9A-Za-z._-]", "_", version)
            if not safe_version or safe_version in {".", ".."}:
                raise ValueError("Release version cannot be used as a package folder name.")
            package = manifest.get("release", {}).get("package", {})
            filename = package.get("file_name", "Digi Search Engine.exe")
            if not isinstance(filename, str) or not filename.strip() or Path(filename).name != filename or filename in {".", ".."}:
                raise ValueError("Package filename is invalid.")
            if Path(filename).suffix.lower() not in {".exe", ".txt"}:
                raise ValueError("Only .exe and .txt update downloads are supported.")
            destination = DEPENDENCIES_ROOT / "update dependencies" / "package installer" / safe_version / filename
            path = download_package_to_path(manifest, destination)
            result = {
                "ok": True,
                "path": path,
                "version": manifest.get("latest_version", ""),
                "sha256": package.get("sha256", ""),
                "verified": True,
                "message": "File downloaded and verified. Saved to the package installer folder; no installation or replacement was performed."
            }
        except Exception as exc:
            result = {"ok": False, "verified": False, "message": str(exc) or "The update package could not be downloaded and verified."}
        self.resultReady.emit(json.dumps(result))

class DigiBridge(QObject):
    @Slot()
    def minimizeWindow(self):
        if self.parent():
            self.parent().showMinimized()

    @Slot()
    def toggleMaximizeWindow(self):
        window = self.parent()
        if window:
            window.showNormal() if window.isMaximized() else window.showMaximized()

    @Slot()
    def closeWindow(self):
        if self.parent():
            self.parent().close()

    indexUpdated = Signal()
    releaseManifestResult = Signal(str)
    packageDownloadResult = Signal(str)
    updateInstallResult = Signal(str)
    conversionProgress = Signal(str, int)
    conversionFinished = Signal(bool, str, str)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        initialize_version_file()
        self.version_ok, self.version_problem = version_integrity()
        self.db = None
        self.search_service = None
        self.notes = None
        self.worker = None
        self.release_worker = None
        self.package_download_worker = None
        if self.version_ok:
            try:
                ensure_directories()
                self._initialize_services()
            except Exception as exc:
                self.version_ok = False
                self.version_problem = f"initialization_failed: {exc}"
                self.error.emit(self.version_problem)

    def _initialize_services(self):
        """Create backend services once the runtime layout passes integrity checks."""
        self.db = Database()
        root = get_library_root()
        self.search_service = SearchService()
        self.search_service.configure(root)
        self.notes = NotesService(root)
        self.start_scan()

    @Slot()
    def checkReleaseManifest(self):
        if self.release_worker and self.release_worker.isRunning():
            return
        self.release_worker = ReleaseManifestWorker(self)
        self.release_worker.resultReady.connect(self.releaseManifestResult.emit)
        self.release_worker.start()

    @Slot(str)
    def downloadReleasePackage(self, manifest_json):
        if self.package_download_worker and self.package_download_worker.isRunning():
            self.packageDownloadResult.emit(json.dumps({"ok": False, "verified": False, "message": "An update download is already in progress."}))
            return
        self.package_download_worker = PackageDownloadWorker(manifest_json, self)
        self.package_download_worker.resultReady.connect(self.packageDownloadResult.emit)
        self.package_download_worker.start()

    @Slot(str, str)
    def installReleaseUpdate(self, manifest_json, downloaded_path):
        """Hand a verified update to the separate helper, only from the stable install."""
        try:
            manifest = json.loads(manifest_json)
            release = manifest.get("release")
            package = release.get("package") if isinstance(release, dict) else None
            version = manifest.get("latest_version")
            if (
                manifest.get("product") != "Digi"
                or manifest.get("schema_version") != 1
                or manifest.get("release_status") != "published"
                or not isinstance(version, str)
                or not isinstance(release, dict)
                or release.get("version") != version
                or not isinstance(package, dict)
            ):
                raise ValueError("Release metadata is invalid.")
            expected_hash = package.get("sha256")
            expected_size = package.get("size_bytes")
            if not isinstance(expected_hash, str) or not isinstance(expected_size, int) or isinstance(expected_size, bool):
                raise ValueError("Release package verification metadata is invalid.")

            local_app_data = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))).resolve()
            install_dir = (local_app_data / "Programs" / "Digi").resolve()
            target = Path(sys.executable).resolve()
            helper = install_dir / "DigiUpdater.exe"
            candidate = Path(downloaded_path).resolve()
            temp_root = Path(tempfile.gettempdir()).resolve()

            if target != (install_dir / "Digi Search Engine.exe").resolve():
                raise ValueError(
                    "Self-update is available only from Digi's stable installation at "
                    "%LOCALAPPDATA%\\Programs\\Digi. This copy was not changed."
                )
            if not helper.is_file():
                raise FileNotFoundError("DigiUpdater.exe is missing from the installation directory.")
            if candidate.parent != temp_root or not candidate.name.startswith("digi-update-") or candidate.suffix != ".download":
                raise ValueError("The downloaded update file is not in Digi's expected temporary location.")
            if not candidate.is_file() or candidate.stat().st_size != expected_size:
                raise ValueError("The downloaded update size does not match the release metadata.")
            verify_package_sha256(candidate, expected_hash)
            with candidate.open("rb") as executable:
                if executable.read(2) != b"MZ":
                    raise ValueError("The downloaded package is not a Windows executable.")
                executable.seek(0x3C)
                pe_offset_bytes = executable.read(4)
                if len(pe_offset_bytes) != 4:
                    raise ValueError("The downloaded executable header is invalid.")
                pe_offset = int.from_bytes(pe_offset_bytes, "little")
                if pe_offset < 64 or pe_offset > 16 * 1024 * 1024:
                    raise ValueError("The downloaded executable header is invalid.")
                executable.seek(pe_offset)
                if executable.read(4) != b"PE\x00\x00":
                    raise ValueError("The downloaded package is not a valid Windows executable.")

            subprocess.Popen([
                str(helper),
                "--parent-pid", str(os.getpid()),
                "--target-exe", str(target),
                "--candidate-exe", str(candidate),
                "--sha256", expected_hash,
                "--version", version,
            ], cwd=str(install_dir), close_fds=True)
            QTimer.singleShot(700, self.parent().close if self.parent() else lambda: None)
            self.updateInstallResult.emit(json.dumps({"ok": True, "message": "Digi is closing to install the verified update."}))
        except Exception as exc:
            self.updateInstallResult.emit(json.dumps({"ok": False, "message": str(exc) or "Could not start the update helper."}))

    @Slot(result=str)
    def state(self):
        return json.dumps({
            "library": str(self.search_service.root) if self.search_service else "",
            "version": APP_VERSION,
            "version_ok": self.version_ok,
            "version_problem": self.version_problem,
            "ready": bool(self.db and self.search_service and self.notes),
        })

    @Slot(result=bool)
    def recalibrateVersion(self):
        # Historical method name retained for frontend compatibility. This is
        # now a read-only recheck; it never repairs or rewrites user data.
        self.version_ok = recalibrate_version()
        if self.version_ok:
            self.version_problem = "ok"
            try:
                ensure_directories()
                self._initialize_services()
            except Exception as exc:
                self.version_ok = False
                self.version_problem = f"initialization_failed: {exc}"
                self.error.emit(self.version_problem)
        else:
            self.version_ok, self.version_problem = version_integrity()
        return self.version_ok

    @Slot(str, str, str, str, str, str, result=str)
    def search(self, q, typ, status, source, method, sort):
        if not self.search_service:
            return json.dumps([])
        return json.dumps(self.search_service.query(q, typ, status, source, method, sort))

    @Slot(str, result=str)
    def tags(self, path):
        return json.dumps(self.db.tags(path)) if self.db else "[]"

    @Slot(str, str, result=bool)
    def addTag(self, path, name):
        if not self.db:
            return False
        self.db.add_tag(path, name)
        return True

    @Slot(str, str, result=bool)
    def removeTag(self, path, name):
        if not self.db:
            return False
        self.db.remove_tag(path, name)
        return True

    @Slot(str, str, result=bool)
    def setStatus(self, path, value):
        if not self.db:
            return False
        self.db.update(path, "status", value)
        return True

    @Slot(str, str, result=bool)
    def setDueDate(self, path, value):
        if not self.db:
            return False
        self.db.update(path, "due_date", value)
        return True

    @Slot(str, result=str)
    def previewFile(self, path):
        """Return a safe, read-only preview payload for a selected PDF or Word file."""
        import base64
        from html import escape
        source = Path(path)
        try:
            if not source.is_file():
                return json.dumps({"kind": "error", "message": "This file is no longer available."})
            suffix = source.suffix.lower()
            if suffix == ".pdf":
                try:
                    import fitz
                except ImportError:
                    return json.dumps({"kind": "error", "message": "PDF preview is unavailable because the PDF renderer is not installed."})
                pages = []
                with fitz.open(str(source)) as document:
                    total = len(document)
                    for index, page in enumerate(document):
                        if index >= 20:
                            break
                        pixmap = page.get_pixmap(matrix=fitz.Matrix(1.15, 1.15), alpha=False)
                        encoded = base64.b64encode(pixmap.tobytes("png")).decode("ascii")
                        pages.append({"number": index + 1, "image": "data:image/png;base64," + encoded})
                return json.dumps({"kind": "pdf", "name": source.name, "pages": pages, "total": total, "truncated": total > len(pages)})
            if suffix in (".docx", ".docm"):
                # Read Office Open XML directly; this avoids python-docx package lookup
                # failures and also works in frozen PyInstaller builds.
                try:
                    import zipfile
                    import xml.etree.ElementTree as ET
                    if not zipfile.is_zipfile(str(source)):
                        raise ValueError("The file is not a valid DOCX/DOCM package; it may be a legacy .doc file renamed with a .docx extension.")
                    with zipfile.ZipFile(str(source), "r") as archive:
                        xml_data = archive.read("word/document.xml")
                    root = ET.fromstring(xml_data)
                    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
                    blocks = []
                    body_node = root.find("w:body", ns)
                    if body_node is not None:
                        for node in body_node:
                            tag = node.tag.rsplit("}", 1)[-1]
                            if tag == "p":
                                text = "".join(part.text or "" for part in node.findall(".//w:t", ns)).strip()
                                if text:
                                    blocks.append("<p>" + escape(text) + "</p>")
                            elif tag == "tbl":
                                rows = []
                                for row in node.findall("w:tr", ns):
                                    cells = []
                                    for cell in row.findall("w:tc", ns):
                                        text = "".join(part.text or "" for part in cell.findall(".//w:t", ns)).strip()
                                        cells.append("<td>" + escape(text) + "</td>")
                                    rows.append("<tr>" + "".join(cells) + "</tr>")
                                blocks.append("<table>" + "".join(rows) + "</table>")
                    body = "".join(blocks) or "<p>This Word document contains no extractable text. Use Open to view it in Word.</p>"
                    return json.dumps({"kind": "word", "name": source.name, "html": body})
                except Exception as exc:
                    return json.dumps({"kind": "error", "message": "Could not preview this Word document: " + str(exc) + ". Use Open to view it in Word."})
            if suffix == ".doc":
                return json.dumps({"kind": "error", "message": "Legacy .doc files are not Open XML documents. Open this file in Microsoft Word or save a copy as .docx to preview it here."})
            return json.dumps({"kind": "error", "message": "Preview is available for PDF and Word documents only."})
        except Exception as exc:
            return json.dumps({"kind": "error", "message": "Preview could not be loaded: " + str(exc)})

    @Slot(str, result=bool)
    def openFile(self, path):
        try:
            FileService.open_file(path)
            return True
        except Exception as exc:
            self.error.emit("Could not open the selected file: " + str(exc))
            return False

    @Slot(str, result=bool)
    def deleteFile(self, path):
        if not self.search_service:
            return False
        try:
            root = Path(self.search_service.root).resolve()
            target = Path(path).resolve()
            target.relative_to(root)
            if target == root or not target.is_file():
                return False
            target.unlink()
            self.start_scan()
            return True
        except (OSError, ValueError):
            return False

    @Slot(str, result=str)
    def listLibraryContents(self, folder):
        """List one directory inside the configured search repository."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        try:
            root = Path(self.search_service.root).resolve()
            supplied = str(folder or "").strip()
            candidate = Path(supplied).expanduser() if supplied else root
            if supplied and not candidate.is_absolute():
                # Browser paths are repository-relative, never machine-root paths.
                candidate = root / supplied.replace("/", os.sep).replace("\\", os.sep)
            current = candidate.resolve()
            current.relative_to(root)
            if not current.is_dir():
                raise NotADirectoryError("This folder no longer exists.")
            entries = []
            for item in sorted(current.iterdir(), key=lambda p: (not p.is_dir(), p.name.casefold())):
                try:
                    item.resolve().relative_to(root)
                except ValueError:
                    continue
                entries.append({"name": item.name, "path": str(item), "type": "folder" if item.is_dir() else "file"})
            return json.dumps({"ok": True, "root": str(root), "current": str(current), "parent": str(current.parent) if current != root else "", "entries": entries})
        except (OSError, ValueError) as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @Slot(result=str)
    def listSearchRepositoryFolders(self):
        """Return every accessible folder under the configured search repository."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready.", "folders": []})
        try:
            root = Path(self.search_service.root).resolve()
            folders = []
            for current, dirnames, _filenames in os.walk(root, topdown=True, onerror=lambda _error: None, followlinks=False):
                base = Path(current)
                safe_dirs = []
                for name in sorted(dirnames, key=str.casefold):
                    candidate = base / name
                    try:
                        resolved = candidate.resolve()
                        resolved.relative_to(root)
                        if candidate.is_dir() and not candidate.is_symlink():
                            safe_dirs.append(name)
                            folders.append(resolved.relative_to(root).as_posix())
                    except (OSError, ValueError):
                        continue
                dirnames[:] = safe_dirs
            folders.sort(key=lambda value: (value.casefold(), value))
            return json.dumps({"ok": True, "folders": folders})
        except (OSError, ValueError) as exc:
            return json.dumps({"ok": False, "error": str(exc), "folders": []})

    @Slot(str, str, result=str)
    def checkMoveDestination(self, source_path, destination_folder):
        """Check whether a file can safely be moved to a destination folder."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        import filecmp
        try:
            root = Path(self.search_service.root).resolve()
            source = Path(source_path).resolve()
            destination = Path(destination_folder).resolve() if destination_folder else root
            source.relative_to(root)
            destination.relative_to(root)
            if not source.is_file():
                return json.dumps({"ok": False, "error": "The selected file no longer exists."})
            if not destination.is_dir():
                return json.dumps({"ok": False, "error": "The destination folder no longer exists."})
            target = destination / source.name
            if target.exists():
                if target.is_file() and filecmp.cmp(source, target, shallow=False):
                    return json.dumps({"ok": True, "can_move": False, "conflict": True, "identical": True,
                                       "reason": "This file already exists here with identical contents."})
                return json.dumps({"ok": True, "can_move": False, "conflict": True, "identical": False,
                                   "reason": "A file with this name already exists. Choose Move here to rename your file."})
            return json.dumps({"ok": True, "can_move": True, "conflict": False, "identical": False, "reason": ""})
        except (OSError, ValueError) as exc:
            return json.dumps({"ok": False, "error": str(exc) or "Could not check this destination."})

    @Slot(str, str, str, result=str)
    def moveFile(self, source_path, destination_folder, new_name):
        """Move a file without overwriting existing data; optionally rename on collision."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        import shutil
        try:
            root = Path(self.search_service.root).resolve()
            source = Path(source_path).resolve()
            destination = Path(destination_folder).resolve() if destination_folder else root
            source.relative_to(root)
            destination.relative_to(root)
            if not source.is_file():
                raise FileNotFoundError("The selected file no longer exists.")
            if not destination.is_dir():
                raise NotADirectoryError("The destination folder no longer exists.")
            name = (new_name or "").strip() or source.name
            if name in (".", "..") or Path(name).name != name or "/" in name or "\\\\" in name:
                raise ValueError("Enter a valid filename without a folder path.")
            target = destination / name
            if target.exists():
                raise FileExistsError("Move failed — two files with the same name cannot be in one folder.")
            if source == target:
                raise FileExistsError("The file is already in this folder.")
            shutil.move(str(source), str(target))
            self.start_scan()
            return json.dumps({"ok": True, "path": str(target)})
        except (OSError, ValueError) as exc:
            return json.dumps({"ok": False, "error": str(exc) or "The file could not be moved."})

    @Slot(result=bool)
    def openSearchRepository(self):
        if not self.search_service:
            return False
        try:
            FileService.open_folder(str(self.search_service.root))
            return True
        except Exception as exc:
            self.error.emit("Could not open the search repository: " + str(exc))
            return False

    @Slot(str, result=bool)
    def openFolder(self, path):
        FileService.open_folder(path)
        return True

    @Slot(result=str)
    def chooseLibraryFolder(self):
        if not self.search_service:
            return ""
        return QFileDialog.getExistingDirectory(
            None, "Choose Digi Search Engine library folder", str(self.search_service.root)
        )

    @Slot(str, result=bool)
    def setLibraryFolder(self, path):
        if not all((self.search_service, self.db)):
            return False
        root = Path(path).resolve()
        self.search_service.configure(root)
        self.db.set_setting("library_folder", str(root))
        LIBRARY_CONFIG.write_text(str(root), encoding="utf-8")
        self.notes = NotesService(root)
        self.start_scan()
        return True

    @Slot(str, str, str, result=str)
    def createDocument(self, parent, name, kind):
        if not self.search_service:
            return ""
        destination = parent.strip() if parent and parent.strip() else str(self.search_service.root)
        try:
            result = FileService.create_document(destination, name, kind)
            self.start_scan()
            return json.dumps({"ok": True, "path": result})
        except Exception as exc:
            print("[Digi Create] Failed to create", kind, repr(exc), flush=True)
            return json.dumps({"ok": False, "error": str(exc) or type(exc).__name__})

    @Slot(str, str, result=str)
    def createFolder(self, parent, name):
        """Create a folder only inside the configured search repository."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        try:
            root = Path(self.search_service.root).resolve()
            destination = Path(parent).resolve() if parent else root
            destination.relative_to(root)
            if not destination.is_dir():
                raise NotADirectoryError("The selected destination folder no longer exists.")
            cleaned = (name or "").strip()
            if not cleaned or cleaned in (".", "..") or any(ch in cleaned for ch in '<>:"/\\\\|?*'):
                raise ValueError("Enter a valid folder name.")
            target = (destination / cleaned).resolve()
            target.relative_to(root)
            if target.exists():
                raise FileExistsError("A folder or file with that name already exists.")
            result = FileService.create_folder(str(destination), cleaned)
            self.start_scan()
            return json.dumps({"ok": True, "path": result})
        except (OSError, ValueError) as exc:
            return json.dumps({"ok": False, "error": str(exc) or "Could not create folder."})

    @Slot(str, str, result=str)
    def importFolder(self, source_path, destination_folder):
        """Copy a dropped local folder into the configured search repository."""
        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        try:
            import shutil
            source = Path(source_path).expanduser().resolve()
            root = Path(self.search_service.root).resolve()
            destination = Path(destination_folder).resolve() if destination_folder else root
            destination.relative_to(root)
            if not source.is_dir():
                raise NotADirectoryError("Drop a folder from your computer, not a file.")
            if not destination.is_dir():
                raise NotADirectoryError("The destination folder no longer exists.")
            target = (destination / source.name).resolve()
            target.relative_to(root)
            if target == root or target.exists():
                raise FileExistsError("A folder with that name already exists here.")
            # Avoid copying a directory into itself or one of its descendants.
            try:
                target.relative_to(source)
                raise ValueError("A folder cannot be copied into itself.")
            except ValueError as exc:
                if str(exc) == "A folder cannot be copied into itself.":
                    raise
            shutil.copytree(source, target)
            self.start_scan()
            return json.dumps({"ok": True, "path": str(target)})
        except Exception as exc:
            print("[Digi Import Folder] Failed:", repr(exc), flush=True)
            return json.dumps({"ok": False, "error": str(exc) or type(exc).__name__})

    @Slot(str, str, bool, result=str)
    def importDroppedItem(self, source_path, destination_folder, replace_existing=False):
        """Copy one local file or folder into the configured search repository."""

        if not self.search_service:
            return json.dumps({"ok": False, "error": "Search repository is not ready."})
        try:
            import shutil
            source = Path(source_path).expanduser().resolve()
            root = Path(self.search_service.root).resolve()
            destination = Path(destination_folder).resolve() if destination_folder else root
            destination.relative_to(root)
            if not source.exists() or not (source.is_file() or source.is_dir()):
                raise FileNotFoundError("The dropped file or folder no longer exists.")
            if not destination.is_dir():
                raise NotADirectoryError("The destination folder no longer exists.")
            target = (destination / source.name).resolve()
            target.relative_to(root)
            if target == root:
                raise ValueError("The repository root cannot be replaced.")
            if target.exists():
                if not replace_existing:
                    return json.dumps({"ok": False, "conflict": True, "name": source.name, "type": "folder" if target.is_dir() else "file"})
                # Replacement is only performed after explicit confirmation in Digi.
                if target.is_dir() and not target.is_symlink():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            if source.is_dir():
                try:
                    target.relative_to(source)
                    raise ValueError("A folder cannot be copied into itself.")
                except ValueError as exc:
                    if str(exc) == "A folder cannot be copied into itself.":
                        raise
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
            self.start_scan()
            return json.dumps({"ok": True, "path": str(target), "type": "folder" if source.is_dir() else "file"})
        except Exception as exc:
            print("[Digi Import Drop] Failed:", repr(exc), flush=True)
            return json.dumps({"ok": False, "error": str(exc) or type(exc).__name__})

    @Slot(str, result=bool)
    def deleteFolder(self, path):
        if not self.search_service:
            return False
        try:
            root = Path(self.search_service.root).resolve()
            target = Path(path).resolve()
            target.relative_to(root)
            if target == root or not target.is_dir():
                return False
            FileService.delete_folder(str(target))
            self.start_scan()
            return True
        except (OSError, ValueError):
            return False

    @Slot(str, str, result=bool)
    def convert(self, path, target):
        if self.worker and self.worker.isRunning():
            return False
        self.worker = ConversionWorker(path, target)
        self.worker.progress.connect(lambda value: self.conversionProgress.emit(str(path), value))
        self.worker.finished.connect(
            lambda ok, msg, out: (
                self.start_scan() if ok else None,
                self.conversionFinished.emit(ok, msg, str(path)),
            )
        )
        self.worker.start()
        return True

    @Slot(result=str)
    def notesTree(self):
        return json.dumps(self.notes.tree()) if self.notes else "[]"

    @Slot(str, str, result=str)
    def createNotebook(self, parent, name):
        return self.notes.create_notebook(name) if self.notes else ""

    @Slot(str, str, result=str)
    def createNoteFolder(self, parent, name):
        return self.notes.create_folder(name) if self.notes else ""

    @Slot(str, str, result=str)
    def createNotePage(self, parent, name):
        return self.notes.create_page(name) if self.notes else ""

    @Slot(str, str, result=str)
    def saveNote(self, path, data):
        return self.notes.save(path, data) if self.notes else ""

    @Slot(str, result=str)
    def loadNote(self, path):
        return self.notes.load(path) if self.notes else ""

    @Slot(str, result=bool)
    def deleteNote(self, path):
        if not self.notes:
            return False
        self.notes.delete(path)
        return True

    @Slot(str, str, result=str)
    def renameNote(self, path, name):
        return self.notes.rename(path, name) if self.notes else ""

    @Slot(result=str)
    def recentSearches(self):
        return json.dumps(self.db.recents()) if self.db else "[]"

    @Slot(str, result=bool)
    def rememberSearch(self, q):
        if not self.db:
            return False
        self.db.add_recent(q)
        return True

    @Slot(result=bool)
    def scan(self):
        if not self.search_service:
            return False
        self.start_scan()
        return True

    def start_scan(self):
        if self.search_service:
            self.search_service.scan(
                lambda: self.indexUpdated.emit(),
                lambda message: self.error.emit(message),
            )
