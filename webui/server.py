# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""
Lyra Web UI HTTP Server
Zero-dependency lightweight HTTP server built on Python standard library http.server.
Provides static asset delivery, JSON RPC dispatching, HTTP 206 audio streaming, and cover retrieval.
"""

import argparse
import json
import mimetypes
import os
import re
import sys
import urllib.parse
import webbrowser
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler
from typing import Optional, Tuple

from .lyra_client import LyraClient

DEFAULT_STATIC_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "static"))

# Fallback SVG Cover Art
FALLBACK_COVER_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" width="300" height="300">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e293b" />
      <stop offset="100%" stop-color="#0f172a" />
    </linearGradient>
    <linearGradient id="icon" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8" />
      <stop offset="100%" stop-color="#6366f1" />
    </linearGradient>
  </defs>
  <rect width="300" height="300" rx="16" fill="url(#bg)" />
  <circle cx="150" cy="150" r="70" fill="none" stroke="#334155" stroke-width="6" opacity="0.6"/>
  <circle cx="150" cy="150" r="28" fill="none" stroke="#334155" stroke-width="4" opacity="0.6"/>
  <path d="M140 115 v70 a20 20 0 1 1 -15 -19 v-40 l45 -10 v50 a20 20 0 1 1 -15 -19 v-32 z" fill="url(#icon)"/>
</svg>""".encode("utf-8")


class LyraHTTPRequestHandler(BaseHTTPRequestHandler):
    """Custom request handler for Lyra Web UI."""

    client: LyraClient
    static_dir: str

    server_version = "LyraWebUI/0.1"

    def do_HEAD(self) -> None:
        self._handle_route(send_body=False)

    def do_GET(self) -> None:
        self._handle_route(send_body=True)

    def do_POST(self) -> None:
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path.rstrip("/")

        if path == "/api/dispatch":
            self._handle_dispatch()
        else:
            self._send_json({"error": "Endpoint not found", "code": 404}, status=404)

    def _handle_route(self, send_body: bool = True) -> None:
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/api/health":
            self._send_json({"status": "ok", "service": "lyra-webui"}, send_body=send_body)
            return

        if path.startswith("/api/audio/"):
            track_id = path[len("/api/audio/") :].strip("/")
            self._handle_audio_stream(track_id, send_body=send_body)
            return

        if path.startswith("/api/cover/"):
            entity_id = path[len("/api/cover/") :].strip("/")
            self._handle_cover_image(entity_id, send_body=send_body)
            return

        # Serve static assets
        self._handle_static_file(path, send_body=send_body)

    def _handle_dispatch(self) -> None:
        content_length = self.headers.get("Content-Length")
        if not content_length:
            self._send_json(
                {"error": {"type": "InvalidRequest", "message": "Missing Content-Length"}},
                status=400,
            )
            return

        try:
            body_bytes = self.rfile.read(int(content_length))
            req_json = json.loads(body_bytes.decode("utf-8"))
        except Exception as e:
            self._send_json(
                {"error": {"type": "InvalidJSON", "message": f"Malformed request body: {e}"}},
                status=400,
            )
            return

        try:
            res_dict = self.client.raw_dispatch(req_json)
            http_status = 200
            # If C++ response indicates error code (e.g. 404 or 400), we can still return 200 or matching status
            self._send_json(res_dict, status=http_status)
        except Exception as e:
            self._send_json(
                {"error": {"type": "InternalServerError", "message": str(e)}},
                status=500,
            )

    def _handle_audio_stream(self, track_id: str, send_body: bool = True) -> None:
        if not track_id:
            self._send_json({"error": "Missing track ID"}, status=400, send_body=send_body)
            return

        # Call C++ core to get physical asset path
        try:
            res = self.client.dispatch("GetResourcePath", {"track_id": track_id})
            if res.get("code") != 200 or not res.get("data") or "path" not in res["data"]:
                self._send_json(
                    {"error": f"Audio track not found: {track_id}"},
                    status=404,
                    send_body=send_body,
                )
                return

            file_path = res["data"]["path"]
            mime_type = res["data"].get("mime_type")
        except Exception as e:
            self._send_json({"error": str(e)}, status=500, send_body=send_body)
            return

        if not os.path.exists(file_path) or not os.path.isfile(file_path):
            self._send_json(
                {"error": f"Audio file does not exist on disk: {file_path}"},
                status=404,
                send_body=send_body,
            )
            return

        if not mime_type:
            mime_type, _ = mimetypes.guess_type(file_path)
        if not mime_type:
            mime_type = "audio/mpeg"

        file_size = os.path.getsize(file_path)
        range_header = self.headers.get("Range")

        if range_header:
            range_match = re.match(r"^bytes=(\d*)-(\d*)$", range_header.strip())
            if not range_match:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{file_size}")
                self.end_headers()
                return

            start_str, end_str = range_match.groups()
            if start_str and end_str:
                start = int(start_str)
                end = min(int(end_str), file_size - 1)
            elif start_str:
                start = int(start_str)
                end = file_size - 1
            elif end_str:
                suffix = int(end_str)
                start = max(0, file_size - suffix)
                end = file_size - 1
            else:
                start = 0
                end = file_size - 1

            if start > end or start >= file_size:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{file_size}")
                self.end_headers()
                return

            content_length = end - start + 1
            self.send_response(206)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
            self.send_header("Content-Length", str(content_length))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()

            if send_body:
                self._stream_file_range(file_path, start, content_length)
        else:
            self.send_response(200)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(file_size))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()

            if send_body:
                self._stream_file_range(file_path, 0, file_size)

    def _stream_file_range(self, file_path: str, start: int, length: int) -> None:
        chunk_size = 64 * 1024  # 64KB chunks
        bytes_remaining = length
        try:
            with open(file_path, "rb") as f:
                if start > 0:
                    f.seek(start)
                while bytes_remaining > 0:
                    to_read = min(chunk_size, bytes_remaining)
                    chunk = f.read(to_read)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    bytes_remaining -= len(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _handle_cover_image(self, entity_id: str, send_body: bool = True) -> None:
        if not entity_id:
            self._send_fallback_cover(send_body)
            return

        cover_path = None
        mime_type = "image/jpeg"

        # 1. Try track cover
        try:
            res = self.client.dispatch("GetTrackCover", {"track_id": entity_id})
            if res.get("code") == 200 and res.get("data") and "path" in res["data"]:
                cover_path = res["data"]["path"]
                mime_type = res["data"].get("mime_type", "image/jpeg")
        except Exception:
            pass

        # 2. Try album cover if track cover not found
        if not cover_path or not os.path.exists(cover_path):
            try:
                res = self.client.dispatch("GetAlbumCover", {"album_id": entity_id})
                if res.get("code") == 200 and res.get("data") and "path" in res["data"]:
                    cover_path = res["data"]["path"]
                    mime_type = res["data"].get("mime_type", "image/jpeg")
            except Exception:
                pass

        # 3. Serve file or fallback SVG
        if cover_path and os.path.exists(cover_path) and os.path.isfile(cover_path):
            try:
                file_size = os.path.getsize(cover_path)
                self.send_response(200)
                self.send_header("Content-Type", mime_type)
                self.send_header("Content-Length", str(file_size))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                if send_body:
                    with open(cover_path, "rb") as img_file:
                        while chunk := img_file.read(64 * 1024):
                            self.wfile.write(chunk)
                return
            except Exception:
                pass

        self._send_fallback_cover(send_body)

    def _send_fallback_cover(self, send_body: bool = True) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "image/svg+xml; charset=utf-8")
        self.send_header("Content-Length", str(len(FALLBACK_COVER_SVG)))
        self.send_header("Cache-Control", "public, max-age=86400")
        self.end_headers()
        if send_body:
            self.wfile.write(FALLBACK_COVER_SVG)

    def _handle_static_file(self, req_path: str, send_body: bool = True) -> None:
        clean_path = req_path.lstrip("/")
        if clean_path.startswith("static/"):
            clean_path = clean_path[len("static/") :]

        if not clean_path or clean_path == "":
            clean_path = "index.html"

        # Prevent directory traversal attacks
        full_path = os.path.abspath(os.path.join(self.static_dir, clean_path))
        if not full_path.startswith(self.static_dir):
            self._send_json({"error": "Access Denied"}, status=403, send_body=send_body)
            return

        if not os.path.exists(full_path) or os.path.isdir(full_path):
            # Fallback to index.html for SPA routing if available
            fallback_index = os.path.join(self.static_dir, "index.html")
            if os.path.exists(fallback_index):
                full_path = fallback_index
            else:
                self._send_json({"error": "File Not Found"}, status=404, send_body=send_body)
                return

        if full_path.endswith(".js"):
            mime_type = "text/javascript"
        elif full_path.endswith(".css"):
            mime_type = "text/css"
        elif full_path.endswith(".html"):
            mime_type = "text/html"
        elif full_path.endswith(".svg"):
            mime_type = "image/svg+xml"
        else:
            mime_type, _ = mimetypes.guess_type(full_path)
            if not mime_type:
                mime_type = "application/octet-stream"

        if "text/" in mime_type or mime_type in ("application/javascript", "application/json"):
            mime_type += "; charset=utf-8"

        file_size = os.path.getsize(full_path)
        self.send_response(200)
        self.send_header("Content-Type", mime_type)
        self.send_header("Content-Length", str(file_size))
        self.end_headers()

        if send_body:
            with open(full_path, "rb") as f:
                while chunk := f.read(64 * 1024):
                    self.wfile.write(chunk)

    def _send_json(self, data: dict, status: int = 200, send_body: bool = True) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if send_body:
            self.wfile.write(body)

    def log_message(self, format: str, *args) -> None:
        # Override to provide concise logging or silence in tests
        if os.environ.get("LYRA_WEBUI_QUIET") == "1":
            return
        sys.stderr.write(f"[LyraWebUI] {self.address_string()} - {format % args}\n")


def create_server(
    host: str = "127.0.0.1",
    port: int = 8080,
    lyra_client: Optional[LyraClient] = None,
    static_dir: Optional[str] = None,
) -> ThreadingHTTPServer:
    """Factory creating a configured ThreadingHTTPServer for Lyra Web UI."""
    if lyra_client is None:
        raise ValueError("A valid LyraClient instance is required.")

    resolved_static_dir = os.path.abspath(static_dir or DEFAULT_STATIC_DIR)
    os.makedirs(resolved_static_dir, exist_ok=True)

    class CustomHandler(LyraHTTPRequestHandler):
        pass

    CustomHandler.client = lyra_client
    CustomHandler.static_dir = resolved_static_dir

    server = ThreadingHTTPServer((host, port), CustomHandler)
    server.daemon_threads = True
    return server


def main() -> None:
    """CLI entry point for running the Lyra Web UI server."""
    parser = argparse.ArgumentParser(description="Lyra Web UI Server")
    parser.add_argument("-H", "--host", default="127.0.0.1", help="Host address to bind to (default: 127.0.0.1)")
    parser.add_argument("-p", "--port", type=int, default=8080, help="Port to listen on (default: 8080)")
    parser.add_argument("-s", "--storage-root", default="./lyra_storage", help="Lyra storage directory path (default: ./lyra_storage)")
    parser.add_argument("--so-path", default=None, help="Custom path to liblyra_core.so")
    parser.add_argument("--static-dir", default=None, help="Custom static files directory")
    parser.add_argument("--open-browser", action="store_true", help="Automatically open default web browser upon start")

    args = parser.parse_args()

    print("=" * 60)
    print(" 🎵  Lyra Music Management - Web UI Server")
    print("=" * 60)
    print(f" Storage Directory : {os.path.abspath(args.storage_root)}")

    try:
        client = LyraClient(storage_root=args.storage_root, so_path=args.so_path)
    except Exception as err:
        print(f"\n❌ Error initializing Lyra Core: {err}", file=sys.stderr)
        sys.exit(1)

    server = create_server(
        host=args.host,
        port=args.port,
        lyra_client=client,
        static_dir=args.static_dir,
    )

    url = f"http://{args.host}:{args.port}"
    print(f" Server URL        : {url}")
    print(" Status            : Ready for connections (Press Ctrl+C to stop)")
    print("=" * 60)

    if args.open_browser:
        try:
            webbrowser.open(url)
        except Exception:
            pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Shutting down Lyra Web UI Server...")
    finally:
        server.server_close()
        print("✅ Server stopped.")


if __name__ == "__main__":
    main()
