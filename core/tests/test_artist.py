# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import math
import os
import struct
import subprocess
import uuid
import wave
import json
import ctypes
from base_test_case import BaseLyraTestCase

class TestArtistController(BaseLyraTestCase):

    # -----------
    # Create Test
    # -----------

    def test_artist_create_success(self):
        """Test successful Artist creation with valid ID and name"""
        artist_name = "Automated Test Artist"
        artist_id = str(uuid.uuid4())
        res = self.dispatch("CreateArtist", {"id": artist_id, "name": artist_name})
        
        self.assertResponseCode(res, 201)
        self.assertEqual(res["data"]["name"], artist_name)
        self.assertTrue("id" in res["data"])

    def test_artist_create_missing_required(self):
        """Test missing required parameters (name): JsonValidator should return 400"""
        res = self.dispatch("CreateArtist", {"id": str(uuid.uuid4())})
        self.assertValidationError(res, expected_type="MissingParameter")

    def test_artist_create_type_mismatch(self):
        """Test parameter type mismatch (e.g., name as integer): Should return 400"""
        res = self.dispatch("CreateArtist", {"id": str(uuid.uuid4()), "name": 12345})
        self.assertValidationError(res, expected_type="InvalidValue")

    # -----------
    # Get Test
    # -----------

    def test_artist_get_success(self):
        """Test successful retrieval of an existing Artist"""
        artist_id = str(uuid.uuid4())
        artist_name = "Get Artist Test"
        res_create = self.dispatch("CreateArtist", {"id": artist_id, "name": artist_name})
        self.assertResponseCode(res_create, 201)

        real_id = res_create["data"]["id"]
        res_get = self.dispatch("GetArtist", {"id": real_id})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["name"], artist_name)

    def test_artist_get_invalid_uuid(self):
        """Test fetching Artist with invalid UUID format: Should trigger validation error (InvalidValue)"""
        res = self.dispatch("GetArtist", {"id": "not-a-valid-uuid-format"})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_artist_get_not_found(self):
        """Test fetching a non-existent Artist: Should return 404 (ArtistNotFound)"""
        res = self.dispatch("GetArtist", {"id": str(uuid.uuid4())})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "ArtistNotFound")

    # -----------
    # Update Test
    # -----------

    def test_artist_update_success(self):
        """Test successful update of an existing Artist"""
        artist_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateArtist", {"id": artist_id, "name": "Initial Name"})
        self.assertResponseCode(res_create, 201)

        updated_name = "Updated Name"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateArtist", {"id": real_id, "name": updated_name})
        self.assertResponseCode(res_update, 200)
        
        res_get = self.dispatch("GetArtist", {"id": real_id})
        self.assertEqual(res_get["data"]["name"], updated_name)

    def test_artist_update_no_fields(self):
        """Test Artist update with valid ID but no update fields: Should return 400"""
        artist_id = str(uuid.uuid4())
        res = self.dispatch("UpdateArtist", {"id": artist_id})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_artist_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_name = "Updated Name"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateArtist", {"id": unexist_id, "name": updated_name})
        self.assertResponseCode(res_update, 500)
        self.assertTrue("error" in res_update)

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

    def test_get_artist_tracks_and_albums(self):
        """Test GetArtistTracks and GetArtistAlbums deduplication, hydration, and error handling."""
        w1 = self._create_tagged_wav("art_a1_t1.wav", {
            "title": "Beta Track",
            "artist": "Solo Artist",
            "album": "Album Older",
            "date": "2018",
            "track": "1",
        }, freq=440.0)
        w2 = self._create_tagged_wav("art_a1_t2.wav", {
            "title": "Alpha Track",
            "artist": "Solo Artist",
            "album": "Album Older",
            "date": "2018",
            "track": "2",
        }, freq=520.0)
        w3 = self._create_tagged_wav("art_a2_t1.wav", {
            "title": "Gamma Track",
            "artist": "Solo Artist",
            "album": "Album Newer",
            "date": "2024",
            "track": "1",
        }, freq=660.0)

        r1 = self.dispatch("ImportTrack", {"source_path": w1})
        r2 = self.dispatch("ImportTrack", {"source_path": w2})
        r3 = self.dispatch("ImportTrack", {"source_path": w3})
        self.assertResponseCode(r1, 200)
        self.assertResponseCode(r2, 200)
        self.assertResponseCode(r3, 200)

        artist_id = r1["data"]["artist_id"]
        alb_older_id = r1["data"]["album_id"]
        alb_newer_id = r3["data"]["album_id"]

        # Update album release_year to verify release_year DESC ordering on GetArtistAlbums
        self.assertResponseCode(self.dispatch("UpdateAlbum", {"id": alb_older_id, "release_year": 2018}), 200)
        self.assertResponseCode(self.dispatch("UpdateAlbum", {"id": alb_newer_id, "release_year": 2024}), 200)

        res_tracks = self.dispatch("GetArtistTracks", {"artist_id": artist_id})
        self.assertResponseCode(res_tracks, 200)
        tracks = res_tracks["data"]
        self.assertEqual(len(tracks), 3)
        self.assertEqual([t["title"] for t in tracks], ["Alpha Track", "Beta Track", "Gamma Track"])
        self.assertEqual(tracks[0]["artist_name"], "Solo Artist")
        self.assertEqual(tracks[0]["album_title"], "Album Older")
        self.assertEqual(tracks[0]["format"], "WAV")

        # Import an album with NULL release_year to verify NULL release_year sorts LAST
        w4 = self._create_tagged_wav("art_a3_t1.wav", {
            "title": "Delta Track",
            "artist": "Solo Artist",
            "album": "Album Undated",
            "track": "1",
        }, freq=770.0)
        r4 = self.dispatch("ImportTrack", {"source_path": w4})
        self.assertResponseCode(r4, 200)
        alb_undated_id = r4["data"]["album_id"]

        res_albums = self.dispatch("GetArtistAlbums", {"artist_id": artist_id})
        self.assertResponseCode(res_albums, 200)
        albums = res_albums["data"]
        # Album Older had 2 tracks -> must appear once (deduplicated), after 2024 Album Newer, before NULL year album
        self.assertEqual([a["id"] for a in albums], [alb_newer_id, alb_older_id, alb_undated_id])

        # Empty artist -> 200 []
        res_empty_art = self.dispatch("CreateArtist", {"name": "New Empty Artist"})
        self.assertResponseCode(res_empty_art, 201)
        empty_id = res_empty_art["data"]["id"]
        self.assertEqual(self.dispatch("GetArtistTracks", {"artist_id": empty_id})["data"], [])
        self.assertEqual(self.dispatch("GetArtistAlbums", {"artist_id": empty_id})["data"], [])

        # 404 ArtistNotFound (including wrong-entity-type Track UUID) and 400 validation errors
        missing_id = str(uuid.uuid4())
        for cmd in ("GetArtistTracks", "GetArtistAlbums"):
            for bad_art_id in (missing_id, r1["data"]["track_id"]):
                res_404 = self.dispatch(cmd, {"artist_id": bad_art_id})
                self.assertResponseCode(res_404, 404)
                self.assertEqual(res_404["error"]["type"], "ArtistNotFound")
            self.assertValidationError(self.dispatch(cmd, {}), expected_type="MissingParameter")
            self.assertValidationError(self.dispatch(cmd, {"artist_id": "invalid"}), expected_type="InvalidValue")