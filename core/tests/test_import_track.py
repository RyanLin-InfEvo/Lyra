# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import sqlite3
import wave
import struct
import subprocess
from base_test_case import BaseLyraTestCase

class TestImportTrack(BaseLyraTestCase):

    def write_dummy_wav(self, filepath, duration=1.0, sample_rate=44100, channels=2):
        with wave.open(filepath, 'wb') as wav_file:
            wav_file.setnchannels(channels)
            wav_file.setsampwidth(2) # 16-bit
            wav_file.setframerate(sample_rate)
            num_frames = int(duration * sample_rate)
            data = struct.pack('<' + 'h' * num_frames * channels, *([0] * num_frames * channels))
            wav_file.writeframes(data)

    def create_tagged_wav(self, filepath, tags: dict, duration=1.0):
        # First write a temp untagged wav
        temp_wav = filepath + ".temp.wav"
        self.write_dummy_wav(temp_wav, duration=duration)
        
        # Build ffmpeg command
        cmd = ["ffmpeg", "-y", "-i", temp_wav]
        for k, v in tags.items():
            cmd.extend(["-metadata", f"{k}={v}"])
        cmd.append(filepath)
        
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode != 0:
            raise RuntimeError(f"ffmpeg failed to write tags: {res.stderr.decode('utf-8')}")
        
        # Clean up temp file
        if os.path.exists(temp_wav):
            os.remove(temp_wav)

    def test_import_track_success(self):
        """Creates a small dummy WAV file with tags, calls dispatch('ImportTrack', {'source_path': ...}),
        and asserts that track, artist, and album records are created and correctly linked."""
        wav_path = os.path.join(self.test_db_dir, "test_success.wav")
        tags = {
            "title": "Success Track",
            "artist": "Success Artist",
            "album": "Success Album",
            "date": "2026-07-14",
            "track": "3/12"
        }
        self.create_tagged_wav(wav_path, tags, duration=1.5)
        self.assertTrue(os.path.exists(wav_path))

        res = self.dispatch("ImportTrack", {"source_path": wav_path})
        self.assertResponseCode(res, 200)

        track_id = res["data"]["track_id"]
        pcm_hash = res["data"]["pcm_hash"]
        artist_id = res["data"]["artist_id"]
        album_id = res["data"]["album_id"]

        self.assertTrue(len(track_id) > 0)
        self.assertTrue(len(pcm_hash) > 0)
        self.assertTrue(len(artist_id) > 0)
        self.assertTrue(len(album_id) > 0)

        # Check values in SQLite database directly
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check Track
        cursor.execute("SELECT pcm_hash, title, recording_year, recording_month, recording_day, duration FROM Track WHERE id = ?", (track_id,))
        track_row = cursor.fetchone()
        self.assertIsNotNone(track_row)
        self.assertEqual(track_row[0], pcm_hash)
        self.assertEqual(track_row[1], "Success Track")
        self.assertEqual(track_row[2], 2026)
        self.assertEqual(track_row[3], 7)
        self.assertEqual(track_row[4], 14)
        # Duration should be around 1500ms (1.5 seconds)
        self.assertAlmostEqual(track_row[5], 1500, delta=100)

        # Check Artist
        cursor.execute("SELECT name FROM Artist WHERE id = ?", (artist_id,))
        artist_row = cursor.fetchone()
        self.assertIsNotNone(artist_row)
        self.assertEqual(artist_row[0], "Success Artist")

        # Check Album
        cursor.execute("SELECT title FROM Album WHERE id = ?", (album_id,))
        album_row = cursor.fetchone()
        self.assertIsNotNone(album_row)
        self.assertEqual(album_row[0], "Success Album")

        # Check Track-Artist link
        cursor.execute("SELECT artist_id, role, position FROM Track_Artist WHERE track_id = ?", (track_id,))
        ta_rows = cursor.fetchall()
        self.assertEqual(len(ta_rows), 1)
        self.assertEqual(ta_rows[0][0], artist_id)
        self.assertEqual(ta_rows[0][1], "main")
        self.assertEqual(ta_rows[0][2], 1)

        # Check Track-Album link
        cursor.execute("SELECT album_id, position FROM Track_Album WHERE track_id = ?", (track_id,))
        tal_rows = cursor.fetchall()
        self.assertEqual(len(tal_rows), 1)
        self.assertEqual(tal_rows[0][0], album_id)
        self.assertEqual(tal_rows[0][1], 3)

        conn.close()

    def test_import_track_deduplication(self):
        """Imports the same file twice, verifying that duplicate files are not stored in CAS
        and the same Artist and Album entries are reused."""
        wav_path = os.path.join(self.test_db_dir, "test_dedup.wav")
        tags = {
            "title": "Dedup Track",
            "artist": "Shared Artist",
            "album": "Shared Album",
            "date": "2026",
            "track": "5"
        }
        self.create_tagged_wav(wav_path, tags, duration=1.0)

        # First import
        res1 = self.dispatch("ImportTrack", {"source_path": wav_path})
        self.assertResponseCode(res1, 200)
        track_id1 = res1["data"]["track_id"]
        artist_id1 = res1["data"]["artist_id"]
        album_id1 = res1["data"]["album_id"]

        # Create a second wav file with the same tags and content
        res2 = self.dispatch("ImportTrack", {"source_path": wav_path})
        self.assertResponseCode(res2, 200)
        track_id2 = res2["data"]["track_id"]
        artist_id2 = res2["data"]["artist_id"]
        album_id2 = res2["data"]["album_id"]

        # Track IDs should be different (creating new Track instance)
        self.assertNotEqual(track_id1, track_id2)
        self.assertEqual(artist_id1, artist_id2)
        self.assertEqual(album_id1, album_id2)

        # Verify database only has one Artist and one Album with those names
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM Artist WHERE name = ?", ("Shared Artist",))
        self.assertEqual(cursor.fetchone()[0], 1)

        cursor.execute("SELECT COUNT(*) FROM Album WHERE title = ?", ("Shared Album",))
        self.assertEqual(cursor.fetchone()[0], 1)

        conn.close()

    def test_import_track_no_tags(self):
        """Imports a file with no tags, verifying it falls back to using the filename as the track title."""
        wav_path = os.path.join(self.test_db_dir, "no_tags_test_filename.wav")
        self.write_dummy_wav(wav_path, duration=1.0)
        self.assertTrue(os.path.exists(wav_path))

        res = self.dispatch("ImportTrack", {"source_path": wav_path})
        self.assertResponseCode(res, 200)

        track_id = res["data"]["track_id"]
        title = res["data"]["title"]

        self.assertTrue(len(track_id) > 0)
        self.assertEqual(title, "no_tags_test_filename")

        # Let's verify it created no Artist or Album link
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM Track_Artist WHERE track_id = ?", (track_id,))
        self.assertEqual(cursor.fetchone()[0], 0)

        cursor.execute("SELECT COUNT(*) FROM Track_Album WHERE track_id = ?", (track_id,))
        self.assertEqual(cursor.fetchone()[0], 0)

        conn.close()
