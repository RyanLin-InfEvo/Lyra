# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import sqlite3
import subprocess
from base_test_case import BaseLyraTestCase

class TestCoverArtIngest(BaseLyraTestCase):

    def create_audio_with_cover_art(self, output_mp3_path, title="Cover Art Track", artist="Cover Art Artist", album="Cover Art Album", freq=1000, color="red"):
        # 1. Create a temporary image using ffmpeg
        cover_jpg_path = os.path.join(self.test_db_dir, f"temp_cover_{freq}_{color}.jpg")
        cmd_img = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", f"color=c={color}:s=100x100",
            "-vframes", "1", cover_jpg_path
        ]
        subprocess.run(cmd_img, check=True)

        # 2. Create a temporary audio using ffmpeg
        audio_wav_path = os.path.join(self.test_db_dir, f"temp_audio_{freq}_{color}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", f"sine=frequency={freq}:duration=1.0",
            audio_wav_path
        ]
        subprocess.run(cmd_wav, check=True)

        # 3. Combine audio and cover art into an MP3 file with attached picture metadata
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

    def test_import_track_with_cover_art(self):
        mp3_path = os.path.join(self.test_db_dir, "test_track_with_cover.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Cover Track Test", artist="Cover Artist Test", album="Cover Album Test", freq=880, color="blue")

        self.assertTrue(os.path.exists(mp3_path))

        # 1. Import track via Router
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)

        data = res_import.get("data", {})
        self.assertIn("track_id", data)
        self.assertIn("album_id", data)
        self.assertIn("artist_id", data)
        self.assertIn("cover_image_hash", data)

        track_id = data["track_id"]
        album_id = data["album_id"]
        artist_id = data["artist_id"]
        cover_hash = data["cover_image_hash"]

        self.assertTrue(len(cover_hash) > 0)

        # 2. Verify cover art file exists in CAS storage: objects/xx/yy/[hash].jpg (or .png)
        xx = cover_hash[0:2]
        yy = cover_hash[2:4]
        cas_dir = os.path.join(self.test_db_dir, "objects", xx, yy)
        self.assertTrue(os.path.exists(cas_dir), f"CAS directory {cas_dir} does not exist")

        cas_files = os.listdir(cas_dir)
        matching_files = [f for f in cas_files if f.startswith(cover_hash)]
        self.assertTrue(len(matching_files) > 0, f"No CAS file starting with {cover_hash} found in {cas_dir}")

        # 3. Query database to verify Image record and Entity_Images links
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        cursor = conn.cursor()

        # Verify Image record
        cursor.execute("SELECT image_hash, file_hash FROM Image WHERE image_hash = ?", (cover_hash,))
        img_row = cursor.fetchone()
        self.assertIsNotNone(img_row, f"Image record for hash {cover_hash} not found in database")
        self.assertEqual(img_row[0], cover_hash)

        # Verify Entity_Images link for Track
        cursor.execute("SELECT entity_id, image_hash, role FROM Entity_Images WHERE entity_id = ? AND image_hash = ?", (track_id, cover_hash))
        track_img_row = cursor.fetchone()
        self.assertIsNotNone(track_img_row, f"Entity_Images link for Track {track_id} not found")
        self.assertEqual(track_img_row[2], "front")

        # Verify Entity_Images link for Album
        cursor.execute("SELECT entity_id, image_hash, role FROM Entity_Images WHERE entity_id = ? AND image_hash = ?", (album_id, cover_hash))
        album_img_row = cursor.fetchone()
        self.assertIsNotNone(album_img_row, f"Entity_Images link for Album {album_id} not found")
        self.assertEqual(album_img_row[2], "front")

        # Verify Artist does NOT have artist_avatar (or any cover image link) automatically set
        cursor.execute("SELECT entity_id, image_hash, role FROM Entity_Images WHERE entity_id = ?", (artist_id,))
        artist_img_row = cursor.fetchone()
        self.assertIsNone(artist_img_row, f"Entity_Images link for Artist {artist_id} should not be automatically set from cover art")

        conn.close()

    def test_import_second_track_same_album_preserves_first_album_cover(self):
        mp3_path1 = os.path.join(self.test_db_dir, "test_track_album1.mp3")
        mp3_path2 = os.path.join(self.test_db_dir, "test_track_album2.mp3")
        self.create_audio_with_cover_art(mp3_path1, title="Track 1", artist="Artist Multi", album="Album Multi", freq=440, color="red")
        self.create_audio_with_cover_art(mp3_path2, title="Track 2", artist="Artist Multi", album="Album Multi", freq=550, color="green")

        res1 = self.dispatch("ImportTrack", {"source_path": mp3_path1})
        self.assertResponseCode(res1, 200)
        album_id1 = res1["data"]["album_id"]
        cover_hash1 = res1["data"]["cover_image_hash"]
        track_id1 = res1["data"]["track_id"]

        res2 = self.dispatch("ImportTrack", {"source_path": mp3_path2})
        self.assertResponseCode(res2, 200)
        cover_hash2 = res2["data"]["cover_image_hash"]
        track_id2 = res2["data"]["track_id"]

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        cursor = conn.cursor()

        # Album should only have 1 cover art linked (cover_hash1 with role 'front')
        cursor.execute("SELECT image_hash, role FROM Entity_Images WHERE entity_id = ?", (album_id1,))
        album_images = cursor.fetchall()
        self.assertEqual(len(album_images), 1)
        self.assertEqual(album_images[0][0], cover_hash1)
        self.assertEqual(album_images[0][1], "front")

        # Track 1 should have cover_hash1 linked
        cursor.execute("SELECT image_hash, role FROM Entity_Images WHERE entity_id = ?", (track_id1,))
        track1_images = cursor.fetchall()
        self.assertEqual(len(track1_images), 1)
        self.assertEqual(track1_images[0][0], cover_hash1)
        self.assertEqual(track1_images[0][1], "front")

        # Track 2 should have cover_hash2 linked
        cursor.execute("SELECT image_hash, role FROM Entity_Images WHERE entity_id = ?", (track_id2,))
        track2_images = cursor.fetchall()
        self.assertEqual(len(track2_images), 1)
        self.assertEqual(track2_images[0][0], cover_hash2)
        self.assertEqual(track2_images[0][1], "front")

        conn.close()

    def test_ingest_asset_with_cover_art(self):
        mp3_path = os.path.join(self.test_db_dir, "test_asset_with_cover.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Asset Ingest Title", artist="Asset Artist", album="Asset Album", freq=660, color="yellow")

        res_ingest = self.dispatch("IngestAsset", {"source_path": mp3_path})
        self.assertResponseCode(res_ingest, 200)

        data = res_ingest.get("data", {})
        self.assertIn("asset", data)
        self.assertIn("audio", data)
        self.assertIn("cover_image_hash", data)
        self.assertIn("cover_file_hash", data)

        cover_hash = data["cover_image_hash"]
        self.assertEqual(cover_hash, data["cover_file_hash"])

        # Verify Image record in database
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT image_hash FROM Image WHERE image_hash = ?", (cover_hash,))
        self.assertIsNotNone(cursor.fetchone())

        conn.close()
