"""Safe temporary package downloader for Digi's updater.

This module only downloads and validates the metadata needed to start a download.
It never installs, launches, or replaces application files.
"""
import hashlib
import os
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path


CHUNK_SIZE = 1024 * 1024
DOWNLOAD_TIMEOUT_SECONDS = 20
MAX_PACKAGE_SIZE_BYTES = 2 * 1024 * 1024 * 1024


class _HttpsOnlyRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Prevent HTTPS downloads from redirecting to an insecure scheme."""

    def redirect_request(self, request, response, code, message, headers, new_url):
        parsed = urllib.parse.urlparse(new_url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("Package download redirected to an unsafe URL.")
        return super().redirect_request(request, response, code, message, headers, new_url)


def _validate_manifest(manifest):
    if not isinstance(manifest, dict):
        raise ValueError("Release metadata is invalid.")
    if manifest.get("product") != "Digi" or manifest.get("schema_version") != 1:
        raise ValueError("Release metadata is not supported.")
    if manifest.get("release_status") != "published":
        raise ValueError("This release is not published.")

    latest = manifest.get("latest_version")
    release = manifest.get("release")
    if not isinstance(latest, str) or not latest.strip() or not isinstance(release, dict):
        raise ValueError("Release version information is missing.")
    if release.get("version") != latest:
        raise ValueError("Release version does not match the announced version.")

    package = release.get("package")
    if not isinstance(package, dict):
        raise ValueError("No downloadable package is published.")
    url = package.get("url")
    if not isinstance(url, str):
        raise ValueError("Package download URL is missing.")
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.fragment:
        raise ValueError("Package download URL must be a valid HTTPS URL.")

    size = package.get("size_bytes")
    if isinstance(size, bool) or not isinstance(size, int) or not 0 < size <= MAX_PACKAGE_SIZE_BYTES:
        raise ValueError("Package size is invalid or exceeds the 2 GiB safety limit.")
    checksum = package.get("sha256")
    if not isinstance(checksum, str) or len(checksum) != 64 or any(ch not in "0123456789abcdefABCDEF" for ch in checksum):
        raise ValueError("Package SHA-256 checksum is invalid.")

    return url, size, checksum.lower()


def verify_package_sha256(path, expected_sha256):
    """Verify a completed package against its published SHA-256 checksum."""
    if not isinstance(expected_sha256, str) or len(expected_sha256) != 64 or any(
        ch not in "0123456789abcdefABCDEF" for ch in expected_sha256
    ):
        raise ValueError("Package SHA-256 checksum is invalid.")
    digest = hashlib.sha256()
    with open(path, "rb") as package_file:
        while True:
            chunk = package_file.read(CHUNK_SIZE)
            if not chunk:
                break
            digest.update(chunk)
    if digest.hexdigest().lower() != expected_sha256.lower():
        raise ValueError("Downloaded package SHA-256 does not match the published checksum.")
    return digest.hexdigest()


def download_package_to_temp(manifest, temp_dir=None, opener=None, progress_callback=None):
    """Download a package to a new temporary file and return its path.

    The file is returned only after both published size and SHA-256 are verified.
    Any failed or interrupted download is removed. No existing file is overwritten.
    """
    url, expected_size, expected_sha256 = _validate_manifest(manifest)
    directory = Path(temp_dir) if temp_dir is not None else None
    if directory is not None:
        directory.mkdir(parents=True, exist_ok=True)

    http_opener = opener or urllib.request.build_opener(_HttpsOnlyRedirectHandler())
    request = urllib.request.Request(url, headers={
        "User-Agent": "Digi-Updater",
        "Accept": "application/octet-stream",
        "Cache-Control": "no-cache",
    })

    fd, temp_path = tempfile.mkstemp(prefix="digi-update-", suffix=".download", dir=str(directory) if directory else None)
    os.close(fd)
    downloaded = 0
    try:
        with http_opener.open(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
            final_url = response.geturl()
            final_parsed = urllib.parse.urlparse(final_url)
            if final_parsed.scheme != "https" or not final_parsed.hostname:
                raise ValueError("Package download ended at an unsafe URL.")
            with open(temp_path, "wb") as output:
                while True:
                    chunk = response.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    downloaded += len(chunk)
                    if downloaded > expected_size or downloaded > MAX_PACKAGE_SIZE_BYTES:
                        raise ValueError("Downloaded package is larger than the published size.")
                    output.write(chunk)
                    if progress_callback is not None:
                        try:
                            progress_callback(downloaded, expected_size)
                        except Exception:
                            pass

        if downloaded != expected_size:
            raise ValueError("Downloaded package size does not match the published size.")
        verify_package_sha256(temp_path, expected_sha256)
        return temp_path
    except Exception:
        try:
            os.remove(temp_path)
        except OSError:
            pass
        raise


def download_package_to_path(manifest, destination_path, opener=None, progress_callback=None):
    """Download and verify a package, then save it at a caller-selected .exe or .txt path.

    The destination is only replaced after the complete download passes size and
    SHA-256 verification. Failed downloads leave any existing destination intact.
    This function downloads only; it never launches or installs the package.
    """
    destination = Path(destination_path)
    if destination.suffix.lower() not in {".exe", ".txt"}:
        raise ValueError("Update download destination must have a .exe or .txt extension.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp_path = download_package_to_temp(
        manifest, temp_dir=destination.parent, opener=opener,
        progress_callback=progress_callback
    )
    try:
        os.replace(temp_path, destination)
    except Exception:
        try:
            os.remove(temp_path)
        except OSError:
            pass
        raise
    return str(destination)
