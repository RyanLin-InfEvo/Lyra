# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import uuid
import subprocess
from base_test_case import BaseLyraTestCase

class TestCoverArtApi(BaseLyraTestCase):

    def create_audio_with_cover_art(self, output_mp3_path, title="Cover Art Track", artist="Cover Art Artist", album="Cover Art Album"):
        cover_jpg_path = os.path.join(self.test_db_dir, f"temp_cover_{uuid.uuid4().hex[:8]}.jpg")
        cmd_img = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "color=c=blue:s=128x128",
            "-vframes", "1", cover_jpg_path
        ]
        subprocess.run(cmd_img, check=True)

        audio_wav_path = os.path.join(self.test_db_dir, f"temp_audio_{uuid.uuid4().hex[:8]}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1.0",
            audio_wav_path
        ]
        subprocess.run(cmd_wav, check=True)

        cmd_combine = [
            "ffmpeg", "-y", "-v", "error",
            "-i", audio_wav_path,
            "-i", cover_jpg_path,
            "-map", "0:0", "-map", "1:0",
            "-c:a", "mp3", "-c:v", "copy",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
            "-metadata", f"album={album}",
            "-disposition:v", "attached_pic",
            output_mp3_path
        ]
        subprocess.run(cmd_combine, check=True)

    def create_audio_without_cover_art(self, output_mp3_path, title="No Cover Track", artist="No Cover Artist", album="No Cover Album"):
        audio_wav_path = os.path.join(self.test_db_dir, f"temp_audio_{uuid.uuid4().hex[:8]}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "sine=frequency=880:duration=1.0",
            audio_wav_path
        ]
        subprocess.run(cmd_wav, check=True)

        cmd_combine = [
            "ffmpeg", "-y", "-v", "error",
            "-i", audio_wav_path,
            "-c:a", "mp3",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
            "-metadata", f"album={album}",
            output_mp3_path
        ]
        subprocess.run(cmd_combine, check=True)

    def test_get_album_cover(self):
        mp3_path = os.path.join(self.test_db_dir, "album_cover_test.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Album Track", artist="Album Artist", album="Test Album API")

        # Import track
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        data_import = res_import.get("data", {})
        album_id = data_import["album_id"]
        cover_hash = data_import["cover_image_hash"]

        # Call GetAlbumCover
        res_cover = self.dispatch("GetAlbumCover", {"album_id": album_id})
        self.assertResponseCode(res_cover, 200)

        data = res_cover.get("data", {})
        self.assertEqual(data["image_hash"], cover_hash)
        self.assertTrue(len(data["file_hash"]) > 0)
        self.assertTrue(os.path.exists(data["path"]), f"Cover file path does not exist: {data['path']}")
        self.assertIn("image/", data["mime_type"])

    def test_get_track_cover_direct(self):
        mp3_path = os.path.join(self.test_db_dir, "track_cover_direct.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Direct Track", artist="Direct Artist", album="Direct Album")

        # Import track
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        data_import = res_import.get("data", {})
        track_id = data_import["track_id"]
        cover_hash = data_import["cover_image_hash"]

        # Call GetTrackCover
        res_cover = self.dispatch("GetTrackCover", {"track_id": track_id})
        self.assertResponseCode(res_cover, 200)

        data = res_cover.get("data", {})
        self.assertEqual(data["image_hash"], cover_hash)
        self.assertTrue(os.path.exists(data["path"]), f"Track cover path does not exist: {data['path']}")
        self.assertIn("image/", data["mime_type"])

    def test_get_track_cover_fallback_to_album(self):
        # 1. Import Track 1 WITH cover art into "Shared Fallback Album"
        mp3_with_cover = os.path.join(self.test_db_dir, "track_with_cover.mp3")
        self.create_audio_with_cover_art(mp3_with_cover, title="Track With Cover", artist="Fallback Artist", album="Shared Fallback Album")

        res1 = self.dispatch("ImportTrack", {"source_path": mp3_with_cover})
        self.assertResponseCode(res1, 200)
        album_id = res1["data"]["album_id"]
        album_cover_hash = res1["data"]["cover_image_hash"]

        # 2. Import Track 2 WITHOUT cover art into the same "Shared Fallback Album"
        mp3_no_cover = os.path.join(self.test_db_dir, "track_no_cover.mp3")
        self.create_audio_without_cover_art(mp3_no_cover, title="Track No Cover", artist="Fallback Artist", album="Shared Fallback Album")

        res2 = self.dispatch("ImportTrack", {"source_path": mp3_no_cover})
        self.assertResponseCode(res2, 200)
        track_id_no_cover = res2["data"]["track_id"]
        self.assertEqual(res2["data"]["album_id"], album_id)
        self.assertNotIn("cover_image_hash", res2["data"])

        # 3. Call GetTrackCover for Track 2 (which has no direct cover) -> should fallback to album's cover
        res_fallback = self.dispatch("GetTrackCover", {"track_id": track_id_no_cover})
        self.assertResponseCode(res_fallback, 200)

        data = res_fallback.get("data", {})
        self.assertEqual(data["image_hash"], album_cover_hash)
        self.assertTrue(os.path.exists(data["path"]))

    def test_get_cover_not_found(self):
        # Non-existent album
        res_album_err = self.dispatch("GetAlbumCover", {"album_id": str(uuid.uuid4())})
        self.assertResponseCode(res_album_err, 404)

        # Track with no cover and no album cover
        mp3_no_cover = os.path.join(self.test_db_dir, "orphan_no_cover.mp3")
        self.create_audio_without_cover_art(mp3_no_cover, title="Orphan Track", artist="Orphan Artist", album="Orphan Album No Cover")
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_no_cover})
        self.assertResponseCode(res_import, 200)
        orphan_track_id = res_import["data"]["track_id"]

        res_track_err = self.dispatch("GetTrackCover", {"track_id": orphan_track_id})
        self.assertResponseCode(res_track_err, 404)
