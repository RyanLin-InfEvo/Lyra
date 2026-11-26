# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import math
import os
import struct
import subprocess
import uuid
import wave
from base_test_case import BaseLyraTestCase

class TestAlbumController(BaseLyraTestCase):

    # -----------
    # Create Test
    # -----------

    def test_album_create_success(self):
        """Test successful Album creation with valid ID and title"""
        album_title = "Automated Test Album"
        album_id = str(uuid.uuid4())
        res = self.dispatch("CreateAlbum", {"id": album_id, "title": album_title})
        
        self.assertResponseCode(res, 201)
        self.assertEqual(res["data"]["title"], album_title)
        self.assertTrue("id" in res["data"])

    def test_album_create_missing_required(self):
        """Test missing required parameters (title): JsonValidator should return 400"""
        res = self.dispatch("CreateAlbum", {"id": str(uuid.uuid4())})
        self.assertValidationError(res, expected_type="MissingParameter")

    def test_album_create_type_mismatch(self):
        """Test parameter type mismatch (e.g., title as integer): Should return 400"""
        res = self.dispatch("CreateAlbum", {"id": str(uuid.uuid4()), "title": 12345})
        self.assertValidationError(res, expected_type="InvalidValue")

    # -----------
    # Get Test
    # -----------

    def test_album_get_success(self):
        """Test successful retrieval of an existing Album"""
        album_id = str(uuid.uuid4())
        album_title = "Get Album Test"
        res_create = self.dispatch("CreateAlbum", {"id": album_id, "title": album_title})
        self.assertResponseCode(res_create, 201)

        real_id = res_create["data"]["id"]
        res_get = self.dispatch("GetAlbum", {"id": real_id})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["title"], album_title)

    def test_album_get_invalid_uuid(self):
        """Test fetching Album with invalid UUID format: Should trigger validation error (InvalidValue)"""
        res = self.dispatch("GetAlbum", {"id": "not-a-valid-uuid-format"})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_album_get_not_found(self):
        """Test fetching a non-existent Album: Should return 404 (AlbumNotFound)"""
        res = self.dispatch("GetAlbum", {"id": str(uuid.uuid4())})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AlbumNotFound")

    # -----------
    # Update Test
    # -----------

    def test_album_update_success(self):
        """Test successful update of an existing Album"""
        album_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateAlbum", {"id": album_id, "title": "Initial Title"})
        self.assertResponseCode(res_create, 201)

        updated_title = "Updated Title"
        updated_year = 2024
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateAlbum", {"id": real_id, "title": updated_title, "release_year": updated_year})
        self.assertResponseCode(res_update, 200)
        
        res_get = self.dispatch("GetAlbum", {"id": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)
        self.assertEqual(res_get["data"]["release_year"], updated_year)

    def test_album_update_no_fields(self):
        """Test Album update with valid ID but no update fields: Should return 400"""
        album_id = str(uuid.uuid4())
        res = self.dispatch("UpdateAlbum", {"id": album_id})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_album_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_title = "Updated Title"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateAlbum", {"id": unexist_id, "title": updated_title})
        self.assertResponseCode(res_update, 500)
        self.assertTrue("error" in res_update)

    def test_album_create_invalid_date(self):
        """Test album creation with invalid month or day (OutOfRange)"""
        # Invalid month 13
        res = self.dispatch("CreateAlbum", {
            "id": str(uuid.uuid4()),
            "title": "Invalid Month Album",
            "release_month": 13
        })
        self.assertValidationError(res, expected_type="OutOfRange")
        self.assertIn("out of reasonable month range", res["error"]["message"])

        # Invalid day 32
        res2 = self.dispatch("CreateAlbum", {
            "id": str(uuid.uuid4()),
            "title": "Invalid Day Album",
            "release_day": 32
        })
        self.assertValidationError(res2, expected_type="OutOfRange")
        self.assertIn("out of reasonable day range", res2["error"]["message"])

        # Negative month -1
        res3 = self.dispatch("CreateAlbum", {
            "id": str(uuid.uuid4()),
            "title": "Negative Month Album",
            "release_month": -1
        })
        self.assertValidationError(res3, expected_type="OutOfRange")

        # Invalid type for day (String)
        res4 = self.dispatch("CreateAlbum", {
            "id": str(uuid.uuid4()),
            "title": "String Day Album",
            "release_day": "15"
        })
        self.assertValidationError(res4, expected_type="InvalidValue")

    def _create_tagged_wav(self, filename, tags, freq=440.0):
        raw_path = os.path.join(self.test_db_dir, f"raw_{uuid.uuid4().hex[:8]}.wav")
        out_path = os.path.join(self.test_db_dir, filename)
        sample_rate = 44100
        num_frames = int(0.2 * sample_rate)
        with wave.open(raw_path, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            samples = [int(15000.0 * math.sin(2.0 * math.pi * freq * (i / sample_rate)))
                       for i in range(num_frames) for _ in range(2)]
            wf.writeframes(struct.pack("<" + "h" * len(samples), *samples))
        cmd = ["ffmpeg", "-y", "-v", "error", "-i", raw_path]
        for k, v in tags.items():
            cmd.extend(["-metadata", f"{k}={v}"])
        cmd.append(out_path)
        subprocess.run(cmd, check=True)
        os.remove(raw_path)
        return out_path

    def test_get_album_tracks_ordered_hydrated_and_errors(self):
        """Test GetAlbumTracks returns position-ordered hydrated tracks, empty list, and 400/404 errors."""
        # Import tracks in reverse track-number order plus one without track number (NULL position)
        w2 = self._create_tagged_wav("alb_t2.wav", {
            "title": "Second Song",
            "artist": "Album Artist",
            "album": "Ordered Album",
            "track": "2",
        }, freq=520.0)
        w1 = self._create_tagged_wav("alb_t1.wav", {
            "title": "First Song",
            "artist": "Album Artist",
            "album": "Ordered Album",
            "track": "1",
        }, freq=440.0)
        w_null = self._create_tagged_wav("alb_tnull.wav", {
            "title": "Bonus Null Pos",
            "artist": "Album Artist",
            "album": "Ordered Album",
        }, freq=660.0)

        r2 = self.dispatch("ImportTrack", {"source_path": w2})
        r1 = self.dispatch("ImportTrack", {"source_path": w1})
        rn = self.dispatch("ImportTrack", {"source_path": w_null})
        self.assertResponseCode(r2, 200)
        self.assertResponseCode(r1, 200)
        self.assertResponseCode(rn, 200)
        album_id = r1["data"]["album_id"]

        res_tracks = self.dispatch("GetAlbumTracks", {"album_id": album_id})
        self.assertResponseCode(res_tracks, 200)
        items = res_tracks["data"]
        self.assertEqual(len(items), 3)
        self.assertEqual(items[0]["id"], r1["data"]["track_id"])
        self.assertEqual(items[0]["track_number"], 1)
        self.assertEqual(items[0]["album_title"], "Ordered Album")
        self.assertEqual(items[0]["artist_name"], "Album Artist")
        self.assertEqual(items[0]["format"], "WAV")
        self.assertEqual(items[1]["id"], r2["data"]["track_id"])
        self.assertEqual(items[1]["track_number"], 2)
        self.assertEqual(items[2]["id"], rn["data"]["track_id"])
        self.assertIsNone(items[2]["track_number"])

        # Empty album -> 200 []
        res_empty_alb = self.dispatch("CreateAlbum", {"title": "Empty Album"})
        self.assertResponseCode(res_empty_alb, 201)
        res_empty = self.dispatch("GetAlbumTracks", {"album_id": res_empty_alb["data"]["id"]})
        self.assertResponseCode(res_empty, 200)
        self.assertEqual(res_empty["data"], [])

        # Non-existent album & wrong-entity-type UUID (Track UUID) -> 404 AlbumNotFound
        for bad_alb_id in (str(uuid.uuid4()), r1["data"]["track_id"]):
            res_404 = self.dispatch("GetAlbumTracks", {"album_id": bad_alb_id})
            self.assertResponseCode(res_404, 404)
            self.assertEqual(res_404["error"]["type"], "AlbumNotFound")

        # Validation errors
        self.assertValidationError(self.dispatch("GetAlbumTracks", {}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("GetAlbumTracks", {"album_id": "bad-uuid"}), expected_type="InvalidValue")
