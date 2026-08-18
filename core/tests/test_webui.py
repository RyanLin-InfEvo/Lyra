# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

# Add repository root to sys.path so webui package can be imported
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from base_test_case import BaseLyraTestCase
from webui.lyra_client import LyraClient
from webui.server import create_server


class TestWebUI(BaseLyraTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        os.environ["LYRA_WEBUI_QUIET"] = "1"

        # Initialize LyraClient with the test database directory
        cls.client = LyraClient(
            storage_root=cls.test_db_dir,
            so_path="./core/build/liblyra_core.so",
        )

        # Create server on ephemeral port (port 0 lets OS assign free port)
        cls.server = create_server(
            host="127.0.0.1",
            port=0,
            lyra_client=cls.client,
        )
        cls.server_port = cls.server.server_address[1]
        cls.base_url = f"http://127.0.0.1:{cls.server_port}"

        # Start server in background daemon thread
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.05)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        super().tearDownClass()

    def create_dummy_audio_file(self, filename="test_audio.mp3", with_cover=True):
        """Helper to create dummy audio file with optional embedded album art."""
        output_path = os.path.join(self.test_db_dir, filename)

        wav_path = os.path.join(self.test_db_dir, f"temp_wav_{uuid.uuid4().hex[:6]}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1.0",
            wav_path,
        ]
        subprocess.run(cmd_wav, check=True)

        if with_cover:
            cover_path = os.path.join(self.test_db_dir, f"temp_cov_{uuid.uuid4().hex[:6]}.jpg")
            cmd_img = [
                "ffmpeg", "-y", "-v", "error",
                "-f", "lavfi", "-i", "color=c=blue:s=64x64",
                "-vframes", "1", cover_path,
            ]
            subprocess.run(cmd_img, check=True)

            cmd_combine = [
                "ffmpeg", "-y", "-v", "error",
                "-i", wav_path,
                "-i", cover_path,
                "-map", "0:0", "-map", "1:0",
                "-c:a", "mp3", "-c:v", "copy",
                "-metadata", "title=WebUI Test Track",
                "-metadata", "artist=WebUI Test Artist",
                "-metadata", "album=WebUI Test Album",
                "-disposition:v", "attached_pic",
                output_path,
            ]
            subprocess.run(cmd_combine, check=True)
        else:
            cmd_combine = [
                "ffmpeg", "-y", "-v", "error",
                "-i", wav_path,
                "-c:a", "mp3",
                "-metadata", "title=Plain Test Track",
                output_path,
            ]
            subprocess.run(cmd_combine, check=True)

        return output_path

    # =========================================================================
    # LyraClient Unit Tests
    # =========================================================================

    def test_lyra_client_dispatch_and_error(self):
        """Test LyraClient basic dispatching and error handling."""
        # 1. Valid dispatch
        res = self.client.dispatch("ListTracks", {})
        self.assertEqual(res["code"], 200)
        self.assertIn("data", res)

        # 2. Command with params
        pcm_hash = f"client_hash_{uuid.uuid4().hex[:6]}"
        res_create = self.client.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": "Client Created Track"})
        self.assertEqual(res_create["code"], 201)

        # 3. Invalid command
        res_err = self.client.dispatch("NonExistentCommand", {})
        self.assertEqual(res_err["code"], 404)
        self.assertEqual(res_err["error"]["type"], "UnknownCommand")

    def test_lyra_client_invalid_so_path(self):
        """Test LyraClient raises FileNotFoundError when given non-existent .so path."""
        with self.assertRaises(FileNotFoundError):
            LyraClient(so_path="/path/that/does/not/exist/liblyra_core.so")

    def test_lyra_client_event_callback(self):
        """Test event callback registration on LyraClient."""
        events = []
        def handler(event):
            events.append(event)

        self.client.register_event_callback(handler)
        self.assertIsNotNone(self.client._c_callback)
        self.client.unregister_event_callback()
        self.assertIsNone(self.client._c_callback)

    # =========================================================================
    # HTTP Server API Endpoints Tests
    # =========================================================================

    def test_http_health_endpoint(self):
        """Test GET /api/health."""
        req = urllib.request.Request(f"{self.base_url}/api/health")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data["status"], "ok")
            self.assertEqual(data["service"], "lyra-webui")

    def test_http_dispatch_endpoint(self):
        """Test POST /api/dispatch with JSON RPC body."""
        payload = json.dumps({"command": "ListTracks", "params": {"limit": 5}}).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base_url}/api/dispatch",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data["code"], 200)
            self.assertIn("items", data["data"])

    def test_http_dispatch_invalid_json(self):
        """Test POST /api/dispatch with malformed JSON body."""
        req = urllib.request.Request(
            f"{self.base_url}/api/dispatch",
            data=b"NOT_JSON",
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req)
        self.assertEqual(ctx.exception.code, 400)

    def test_http_audio_streaming_and_range_requests(self):
        """Test GET /api/audio/<track_id> with full download and Range headers."""
        # 1. Import dummy audio file
        audio_file = self.create_dummy_audio_file("stream_test.mp3", with_cover=True)
        import_res = self.client.dispatch("ImportTrack", {"source_path": audio_file})
        self.assertEqual(import_res["code"], 200)
        track_id = import_res["data"]["track_id"]

        # 2. Full Audio Stream (No Range header) -> HTTP 200
        req = urllib.request.Request(f"{self.base_url}/api/audio/{track_id}")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers.get("Accept-Ranges"), "bytes")
            total_len = int(resp.headers.get("Content-Length"))
            full_body = resp.read()
            self.assertEqual(len(full_body), total_len)

        # 3. Partial Content Range: bytes=0-49 -> HTTP 206
        req_range = urllib.request.Request(
            f"{self.base_url}/api/audio/{track_id}",
            headers={"Range": "bytes=0-49"},
        )
        with urllib.request.urlopen(req_range) as resp:
            self.assertEqual(resp.status, 206)
            self.assertEqual(resp.headers.get("Content-Range"), f"bytes 0-49/{total_len}")
            self.assertEqual(resp.headers.get("Content-Length"), "50")
            chunk = resp.read()
            self.assertEqual(len(chunk), 50)
            self.assertEqual(chunk, full_body[:50])

        # 4. Partial Content Range: bytes=50- -> HTTP 206
        req_range_open = urllib.request.Request(
            f"{self.base_url}/api/audio/{track_id}",
            headers={"Range": "bytes=50-"},
        )
        with urllib.request.urlopen(req_range_open) as resp:
            self.assertEqual(resp.status, 206)
            expected_len = total_len - 50
            self.assertEqual(resp.headers.get("Content-Range"), f"bytes 50-{total_len - 1}/{total_len}")
            self.assertEqual(resp.headers.get("Content-Length"), str(expected_len))
            chunk = resp.read()
            self.assertEqual(len(chunk), expected_len)
            self.assertEqual(chunk, full_body[50:])

        # 5. Suffix Range: bytes=-30 -> HTTP 206
        req_range_suffix = urllib.request.Request(
            f"{self.base_url}/api/audio/{track_id}",
            headers={"Range": "bytes=-30"},
        )
        with urllib.request.urlopen(req_range_suffix) as resp:
            self.assertEqual(resp.status, 206)
            self.assertEqual(resp.headers.get("Content-Length"), "30")
            chunk = resp.read()
            self.assertEqual(len(chunk), 30)
            self.assertEqual(chunk, full_body[-30:])

        # 6. Out of Range -> HTTP 416
        req_invalid_range = urllib.request.Request(
            f"{self.base_url}/api/audio/{track_id}",
            headers={"Range": f"bytes={total_len + 500}-{total_len + 600}"},
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req_invalid_range)
        self.assertEqual(ctx.exception.code, 416)

        # 7. Non-existent Track Audio -> HTTP 404
        req_404 = urllib.request.Request(f"{self.base_url}/api/audio/{str(uuid.uuid4())}")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req_404)
        self.assertEqual(ctx.exception.code, 404)

    def test_http_cover_image_endpoint(self):
        """Test GET /api/cover/<track_id> for tracks with and without cover art."""
        # 1. Track with cover art -> returns image binary
        audio_with_cov = self.create_dummy_audio_file("cover_track.mp3", with_cover=True)
        res_import = self.client.dispatch("ImportTrack", {"source_path": audio_with_cov})
        self.assertEqual(res_import["code"], 200)
        track_id = res_import["data"]["track_id"]

        req = urllib.request.Request(f"{self.base_url}/api/cover/{track_id}")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            content_type = resp.headers.get("Content-Type", "")
            self.assertTrue(content_type.startswith("image/"))
            body = resp.read()
            self.assertGreater(len(body), 0)

        # 2. Track without cover art -> returns SVG fallback with 200 OK
        req_fallback = urllib.request.Request(f"{self.base_url}/api/cover/{str(uuid.uuid4())}")
        with urllib.request.urlopen(req_fallback) as resp:
            self.assertEqual(resp.status, 200)
            content_type = resp.headers.get("Content-Type", "")
            self.assertIn("image/svg+xml", content_type)
            body = resp.read().decode("utf-8")
            self.assertIn("<svg", body)

    def test_http_static_files(self):
        """Test serving static files (index.html, styles.css, app.js)."""
        # 1. Root / -> index.html
        with urllib.request.urlopen(f"{self.base_url}/") as resp:
            self.assertEqual(resp.status, 200)
            self.assertIn("text/html", resp.headers.get("Content-Type"))
            html_content = resp.read().decode("utf-8")
            self.assertIn("LYRA", html_content)

        # 2. /styles.css
        with urllib.request.urlopen(f"{self.base_url}/styles.css") as resp:
            self.assertEqual(resp.status, 200)
            self.assertIn("text/css", resp.headers.get("Content-Type"))
            css_content = resp.read().decode("utf-8")
            self.assertIn("--bg-base", css_content)

        # 3. /app.js
        with urllib.request.urlopen(f"{self.base_url}/app.js") as resp:
            self.assertEqual(resp.status, 200)
            self.assertIn("javascript", resp.headers.get("Content-Type"))
            js_content = resp.read().decode("utf-8")
            self.assertIn("class LyraApp", js_content)

    def test_http_album_cover_endpoint(self):
        """Test GET /api/cover/<album_id> fallback retrieval."""
        audio_with_cov = self.create_dummy_audio_file("album_cov_test.mp3", with_cover=True)
        res_import = self.client.dispatch("ImportTrack", {"source_path": audio_with_cov})
        self.assertEqual(res_import["code"], 200)

        # Get the album
        albums_res = self.client.dispatch("ListAlbums", {})
        self.assertGreater(len(albums_res["data"]["items"]), 0)
        album_id = albums_res["data"]["items"][0]["id"]

        req = urllib.request.Request(f"{self.base_url}/api/cover/{album_id}")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            content_type = resp.headers.get("Content-Type", "")
            self.assertTrue(content_type.startswith("image/"))

    def test_http_head_requests(self):
        """Test HEAD requests for endpoints."""
        req_health = urllib.request.Request(f"{self.base_url}/api/health", method="HEAD")
        with urllib.request.urlopen(req_health) as resp:
            self.assertEqual(resp.status, 200)
            body = resp.read()
            self.assertEqual(len(body), 0)

        req_static = urllib.request.Request(f"{self.base_url}/styles.css", method="HEAD")
        with urllib.request.urlopen(req_static) as resp:
            self.assertEqual(resp.status, 200)
            self.assertIn("text/css", resp.headers.get("Content-Type"))
            body = resp.read()
            self.assertEqual(len(body), 0)

    def test_http_static_path_traversal(self):
        """Test directory traversal attack is denied."""
        req = urllib.request.Request(f"{self.base_url}/static/../../../../etc/passwd")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req)
        self.assertIn(ctx.exception.code, (400, 403, 404))

    def test_http_unknown_post_endpoint(self):
        """Test POST on unknown API path returns 404."""
        req = urllib.request.Request(
            f"{self.base_url}/api/unknown_route",
            data=b"{}",
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req)
        self.assertEqual(ctx.exception.code, 404)
