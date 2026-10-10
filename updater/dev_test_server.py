"""Local-only release metadata server for exercising Digi's real updater path.

Run from the repository root:
    python updater/dev_test_server.py --version 99.0.0.0

This server binds only to loopback and never serves application packages.
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0] != "/latest.json":
            self.send_error(404)
            return
        manifest = {
            "schema_version": 1,
            "product": "Digi",
            "channel": "development-test",
            "latest_version": self.server.test_version,
            "release_status": "published",
            "message": "LOCAL TEST FEED ONLY — no update package is downloaded or installed.",
            "release": {
                "version": self.server.test_version,
                "url": "http://127.0.0.1:8765/",
                "published_at": None,
                "notes": "Controlled local runtime test. Not a real Digi release."
            }
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
    args = parser.parse_args()
    parts = args.version.split(".")
    if not args.version or any(not part.isdigit() for part in parts):
        parser.error("--version must contain numeric dot-separated components")
    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    server.test_version = args.version
    print("Digi local updater test feed: http://127.0.0.1:8765/latest.json", flush=True)
    print("Fake latest version: " + args.version, flush=True)
    print("Loopback only. No package, download, or install endpoint exists. Press Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local updater test feed.", flush=True)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
