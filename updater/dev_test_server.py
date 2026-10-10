"""Local-only release metadata server for exercising Digi's real updater path.

Run from the repository root:
    python updater/dev_test_server.py --version 99.0.0.0
    python updater/dev_test_server.py --version 99.0.0.0 --with-package-metadata

The server binds only to loopback and never serves application packages.
Package URL, size, and SHA-256 can be overridden to test a harmless HTTPS fixture.
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0] != "/latest.json":
            self.send_error(404)
            return
        release = {
            "version": self.server.test_version,
            "url": "http://127.0.0.1:8765/",
            "published_at": None,
            "notes": "Controlled local test. Not a real Digi release."
        }
        if self.server.with_package_metadata:
            release["package"] = {
                "url": self.server.package_url,
                "size_bytes": self.server.package_size,
                "sha256": self.server.package_sha256
            }
        manifest = {
            "schema_version": 1,
            "product": "Digi",
            "channel": "development-test",
            "latest_version": self.server.test_version,
            "release_status": "published",
            "message": "LOCAL TEST FEED ONLY — no real package is available.",
            "release": release
        }
        payload = json.dumps(manifest).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format_string, *args):
        print("[local updater test] " + (format_string % args), flush=True)


def main():
    parser = argparse.ArgumentParser(description="Serve controlled Digi updater metadata on loopback only.")
    parser.add_argument("--version", default="99.0.0.0", help="fake latest version shown to the app (default: 99.0.0.0)")
    parser.add_argument(
        "--with-package-metadata",
        action="store_true",
        help="include package metadata; defaults to a deliberately invalid test URL"
    )
    parser.add_argument("--package-url", default="https://digi-updater-test-package.invalid/Digi-test.exe", help="HTTPS URL for test package")
    parser.add_argument("--package-size", type=int, default=1, help="expected package size in bytes")
    parser.add_argument("--package-sha256", default="0" * 64, help="expected package SHA-256")
    args = parser.parse_args()
    parts = args.version.split(".")
    if not args.version or any(not part.isdigit() for part in parts):
        parser.error("--version must contain numeric dot-separated components")
    if args.package_size <= 0:
        parser.error("--package-size must be positive")
    if len(args.package_sha256) != 64 or any(ch not in "0123456789abcdefABCDEF" for ch in args.package_sha256):
        parser.error("--package-sha256 must contain exactly 64 hexadecimal characters")
    if not args.package_url.lower().startswith("https://"):
        parser.error("--package-url must use HTTPS")
    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    server.test_version = args.version
    server.with_package_metadata = args.with_package_metadata
    server.package_url = args.package_url
    server.package_size = args.package_size
    server.package_sha256 = args.package_sha256.lower()
    print("Digi local updater test feed: http://127.0.0.1:8765/latest.json", flush=True)
    print("Fake latest version: " + args.version, flush=True)
    print("Package metadata enabled: " + str(args.with_package_metadata), flush=True)
    print("Package URL: " + args.package_url, flush=True)
    print("Loopback only. No package is served or installed. Press Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local updater test feed.", flush=True)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
