# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import sqlite3
import subprocess
import time
import unittest
from base_test_case import BaseLyraTestCase

class TestAudioController(BaseLyraTestCase):

    def test_audio_get_without_assets(self):
        """Test GetAudio returns empty assets array when no assets are linked"""
        pcm_hash = "pcm-no-assets"
        res_create = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 90,
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 60.0
        })
        self.assertResponseCode(res_create, 201)

        res_get = self.dispatch("GetAudio", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["assets"], [])

    def test_audio_get_with_single_asset(self):
        """Test GetAudio returns single linked asset with matching fields"""
        pcm_hash = "pcm-single-asset"
        file_hash = "file-hash-single"
        mime_type = "audio/flac"
        asset_type = "audio"
        file_size = 1048576

        res_audio = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 95,
            "bit_depth": 24,
            "sample_rate": 48000,
            "channels": 2,
            "duration": 180.0
        })
        self.assertResponseCode(res_audio, 201)

        res_asset = self.dispatch("CreateAsset", {
            "file_hash": file_hash,
            "mime_type": mime_type,
            "asset_type": asset_type,
            "file_size": file_size
        })
        self.assertResponseCode(res_asset, 201)

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (pcm_hash, file_hash))
        conn.commit()
        conn.close()

        res_get = self.dispatch("GetAudio", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_get, 200)
        assets = res_get["data"]["assets"]
        self.assertEqual(len(assets), 1)
        self.assertEqual(assets[0]["file_hash"], file_hash)
        self.assertEqual(assets[0]["mime_type"], mime_type)
        self.assertEqual(assets[0]["asset_type"], asset_type)
        self.assertEqual(assets[0]["file_size"], file_size)

    def test_audio_get_with_multiple_assets(self):
        """Test GetAudio returns multiple linked assets with matching file hashes"""
        pcm_hash = "pcm-multi-assets"
        file_hash_1 = "file-hash-multi-1"
        file_hash_2 = "file-hash-multi-2"

        res_audio = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 88,
            "sample_rate": 44100
        })
        self.assertResponseCode(res_audio, 201)

        res_asset_1 = self.dispatch("CreateAsset", {
            "file_hash": file_hash_1,
            "mime_type": "audio/flac",
            "asset_type": "audio",
            "file_size": 204800
        })
        self.assertResponseCode(res_asset_1, 201)

        res_asset_2 = self.dispatch("CreateAsset", {
            "file_hash": file_hash_2,
            "mime_type": "audio/mp3",
            "asset_type": "audio",
            "file_size": 51200
        })
        self.assertResponseCode(res_asset_2, 201)

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (pcm_hash, file_hash_1))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (pcm_hash, file_hash_2))
        conn.commit()
        conn.close()

        res_get = self.dispatch("GetAudio", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_get, 200)
        assets = res_get["data"]["assets"]
        self.assertEqual(len(assets), 2)
        asset_hashes = [a["file_hash"] for a in assets]
        self.assertIn(file_hash_1, asset_hashes)
        self.assertIn(file_hash_2, asset_hashes)

    def test_audio_create_success(self):
        """Test successful Audio creation"""
        pcm_hash = "pcm-abc123xyz"
        res = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 95,
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 180.5,
            "integrated_loudness": -14.2,
            "true_peak": -1.0
        })
        
        self.assertResponseCode(res, 201)
        self.assertEqual(res["data"]["pcm_hash"], pcm_hash)

    def test_audio_create_missing_required(self):
        """Test missing required parameter pcm_hash"""
        res = self.dispatch("CreateAudio", {
            "quality_score": 90
        })
        self.assertValidationError(res, expected_type="MissingParameter")

    def test_audio_get_success(self):
        """Test successful retrieval of an existing Audio"""
        pcm_hash = "pcm-get-test"
        res_create = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 80,
            "bit_depth": 24,
            "sample_rate": 96000,
            "channels": 6,
            "duration": 320.0,
            "integrated_loudness": -18.0,
            "true_peak": -2.5
        })
        self.assertResponseCode(res_create, 201)

        res_get = self.dispatch("GetAudio", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["sample_rate"], 96000)
        self.assertEqual(res_get["data"]["duration"], 320.0)

    def test_audio_get_not_found(self):
        """Test fetching a non-existent Audio"""
        res = self.dispatch("GetAudio", {"pcm_hash": "non-existent-pcm"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AudioNotFound")

    def test_audio_update_success(self):
        """Test successful update of an existing Audio"""
        pcm_hash = "pcm-update-test"
        res_create = self.dispatch("CreateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 75,
            "bit_depth": 16,
            "sample_rate": 48000,
            "channels": 2,
            "duration": 120.0
        })
        self.assertResponseCode(res_create, 201)

        res_update = self.dispatch("UpdateAudio", {
            "pcm_hash": pcm_hash,
            "quality_score": 85,
            "duration": 125.5
        })
        self.assertResponseCode(res_update, 200)

        res_get = self.dispatch("GetAudio", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["quality_score"], 85)
        self.assertEqual(res_get["data"]["duration"], 125.5)

    def test_audio_list_success(self):
        """Test listing Audio with offset/limit"""
        self.dispatch("CreateAudio", {"pcm_hash": "pcm-list-1", "sample_rate": 44100})
        self.dispatch("CreateAudio", {"pcm_hash": "pcm-list-2", "sample_rate": 48000})

        res_list = self.dispatch("ListAudio", {"offset": 0, "limit": 10})
        self.assertResponseCode(res_list, 200)
        self.assertGreaterEqual(res_list["data"]["total"], 2)

    def test_audio_list_search_and_pagination(self):
        """Test search filter and pagination for listing Audio"""
        # Create parent audio
        self.dispatch("CreateAudio", {"pcm_hash": "parent-audio", "sample_rate": 44100})
        # Create child audios
        self.dispatch("CreateAudio", {"pcm_hash": "child-1", "parent_hash": "parent-audio", "sample_rate": 44100})
        self.dispatch("CreateAudio", {"pcm_hash": "child-2", "parent_hash": "parent-audio", "sample_rate": 48000})
        self.dispatch("CreateAudio", {"pcm_hash": "other-audio", "sample_rate": 96000})

        # Test search by parent_hash
        res = self.dispatch("ListAudio", {"offset": 0, "limit": 10, "search": "parent-audio"})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["total"], 2)
        self.assertEqual(res["data"]["items"][0]["pcm_hash"], "child-1")
        self.assertEqual(res["data"]["items"][1]["pcm_hash"], "child-2")

        # Test pagination
        res = self.dispatch("ListAudio", {"offset": 1, "limit": 1, "search": "parent-audio"})
        self.assertResponseCode(res, 200)
        self.assertEqual(len(res["data"]["items"]), 1)
        self.assertEqual(res["data"]["items"][0]["pcm_hash"], "child-2")

    def test_audio_foreign_key_violation(self):
        """Test foreign key constraint fails when parent_hash does not exist"""
        res = self.dispatch("CreateAudio", {
            "pcm_hash": "child-orphan",
            "parent_hash": "non-existent-parent"
        })
        self.assertResponseCode(res, 500)
        self.assertEqual(res["error"]["type"], "DatabaseError")

    def test_audio_validation_errors(self):
        """Test Audio validation with incorrect parameter types"""
        # duration should be number, passing string
        res = self.dispatch("CreateAudio", {
            "pcm_hash": "val-audio-1",
            "duration": "not-a-number"
        })
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_audio_update_non_existent(self):
        """Test updating a non-existent Audio"""
        res = self.dispatch("UpdateAudio", {
            "pcm_hash": "non-existent-pcm",
            "quality_score": 90
        })
        self.assertResponseCode(res, 500)
        self.assertEqual(res["error"]["type"], "DatabaseError")

    def test_audio_update_no_fields(self):
        """Test updating an Audio with no fields provided"""
        res = self.dispatch("UpdateAudio", {
            "pcm_hash": "some-pcm"
        })
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_compare_versions_with_pcm_hashes(self):
        """Test Case 1: Hi-Res FLAC (24bit/96kHz, stereo, lossless, size=52428800) and MP3 (16bit/44.1kHz, stereo, duration=180s, size=7200000 -> 320kbps)"""
        # Create Audio 1: Lossless Hi-Res FLAC 24-bit 96kHz
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-flac-24-96",
            "bit_depth": 24,
            "sample_rate": 96000,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-flac",
            "mime_type": "audio/flac",
            "asset_type": "audio",
            "file_size": 52428800
        })

        # Create Audio 2: High quality MP3 16-bit 44.1kHz (320kbps)
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-mp3-320",
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-mp3-320",
            "mime_type": "audio/mpeg",
            "asset_type": "audio",
            "file_size": 7200000  # 7,200,000 * 8 / 180 = 320,000 bps
        })

        # Create Audio 3: Medium quality MP3 16-bit 44.1kHz (128kbps)
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-mp3-128",
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-mp3-128",
            "mime_type": "audio/mp3",
            "asset_type": "audio",
            "file_size": 2880000  # 2,880,000 * 8 / 180 = 128,000 bps
        })

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-flac-24-96", "file-flac"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-mp3-320", "file-mp3-320"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-mp3-128", "file-mp3-128"))
        conn.commit()
        conn.close()

        res = self.dispatch("audio.compare_versions", {
            "pcm_hashes": ["pcm-mp3-128", "pcm-flac-24-96", "pcm-mp3-320"]
        })
        self.assertResponseCode(res, 200)
        data = res["data"]
        self.assertEqual(data["recommended_master"], "pcm-flac-24-96")
        versions = data["versions"]
        self.assertEqual(len(versions), 3)

        # 1st: FLAC
        self.assertEqual(versions[0]["pcm_hash"], "pcm-flac-24-96")
        self.assertEqual(versions[0]["format"], "FLAC 24-bit / 96kHz")
        self.assertEqual(versions[0]["quality_score"], 97)
        self.assertTrue(versions[0]["is_lossless"])
        self.assertEqual(versions[0]["file_size"], 52428800)
        self.assertTrue(versions[0]["is_master"])

        # 2nd: MP3 320k
        self.assertEqual(versions[1]["pcm_hash"], "pcm-mp3-320")
        self.assertEqual(versions[1]["format"], "MP3 16-bit / 44.1kHz")
        self.assertEqual(versions[1]["quality_score"], 68)
        self.assertFalse(versions[1]["is_lossless"])
        self.assertEqual(versions[1]["file_size"], 7200000)
        self.assertFalse(versions[1]["is_master"])

        # 3rd: MP3 128k
        self.assertEqual(versions[2]["pcm_hash"], "pcm-mp3-128")
        self.assertEqual(versions[2]["format"], "MP3 16-bit / 44.1kHz")
        self.assertEqual(versions[2]["quality_score"], 48)
        self.assertFalse(versions[2]["is_lossless"])
        self.assertEqual(versions[2]["file_size"], 2880000)
        self.assertFalse(versions[2]["is_master"])

    def test_compare_versions_with_track_id(self):
        """Test Case 2: Comparison via track_id (parent-child relationship in Audio table)"""
        root_pcm = "pcm-track-root"
        child_pcm = "pcm-track-child"

        # Create root audio and child audio
        self.dispatch("CreateAudio", {
            "pcm_hash": root_pcm,
            "bit_depth": 24,
            "sample_rate": 192000,
            "channels": 2,
            "duration": 240.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-root-wav",
            "mime_type": "audio/x-wav",
            "asset_type": "audio",
            "file_size": 90000000
        })

        self.dispatch("CreateAudio", {
            "pcm_hash": child_pcm,
            "parent_hash": root_pcm,
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 240.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-child-aac",
            "mime_type": "audio/aac",
            "asset_type": "audio",
            "file_size": 7680000  # 256kbps
        })

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (root_pcm, "file-root-wav"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (child_pcm, "file-child-aac"))
        conn.commit()
        conn.close()

        # Create Track linking to child audio
        res_track = self.dispatch("CreateTrack", {
            "title": "Masterpiece",
            "pcm_hash": child_pcm
        })
        self.assertResponseCode(res_track, 201)
        track_id = res_track["data"]["id"]

        # Call compare_versions using track_id
        res = self.dispatch("audio.compare_versions", {
            "track_id": track_id
        })
        self.assertResponseCode(res, 200)
        data = res["data"]
        self.assertEqual(data["recommended_master"], root_pcm)
        self.assertEqual(len(data["versions"]), 2)
        self.assertEqual(data["versions"][0]["pcm_hash"], root_pcm)
        self.assertEqual(data["versions"][0]["format"], "WAV 24-bit / 192kHz")
        self.assertTrue(data["versions"][0]["is_master"])
        self.assertEqual(data["versions"][1]["pcm_hash"], child_pcm)
        self.assertEqual(data["versions"][1]["format"], "AAC 16-bit / 44.1kHz")
        self.assertFalse(data["versions"][1]["is_master"])

    def test_compare_versions_with_dangling_parent_auto_healing(self):
        """Test audio.compare_versions with dangling parent_hash triggers auto-healing"""
        dangling_pcm = "pcm-track-dangling"
        self.dispatch("CreateAsset", {
            "file_hash": "file-dangling-wav",
            "mime_type": "audio/x-wav",
            "asset_type": "audio",
            "file_size": 20000000
        })

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("PRAGMA foreign_keys = OFF;")
        cursor.execute(
            "INSERT INTO Audio (pcm_hash, parent_hash, sample_rate, bit_depth, channels, duration) VALUES (?, ?, ?, ?, ?, ?)",
            (dangling_pcm, "non-existent-master-hash", 44100, 16, 2, 120.0),
        )
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", (dangling_pcm, "file-dangling-wav"))
        conn.commit()
        conn.close()

        res_track = self.dispatch("CreateTrack", {
            "title": "Dangling Track",
            "pcm_hash": dangling_pcm
        })
        self.assertResponseCode(res_track, 201)
        track_id = res_track["data"]["id"]

        res = self.dispatch("audio.compare_versions", {
            "track_id": track_id
        })
        self.assertResponseCode(res, 200)
        data = res["data"]
        self.assertEqual(data["recommended_master"], dangling_pcm)
        self.assertEqual(len(data["versions"]), 1)
        self.assertEqual(data["versions"][0]["pcm_hash"], dangling_pcm)

        # Check that parent_hash in database is now NULL
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT parent_hash FROM Audio WHERE pcm_hash = ?", (dangling_pcm,))
        row = cursor.fetchone()
        conn.close()
        self.assertIsNone(row[0])

    def test_compare_versions_sorting_tie_breaking(self):
        """Test Case 5: Tie breaking (equal score -> lossless wins; equal score & both lossy/lossless -> larger file size wins)"""
        # Part A: Equal score where lossless wins (Score 71: lossless 8-bit mono FLAC vs lossy 24-bit stereo MP3 256k)
        # Lossless: bit_depth=8 (8) + sample_rate=48k (16) + lossless (45) + channels=1 (2) = 71
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossless-71",
            "bit_depth": 8,
            "sample_rate": 48000,
            "channels": 1,
            "duration": 100.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossless-71",
            "mime_type": "audio/flac",
            "file_size": 5000000
        })

        # Lossy: bit_depth=24 (25) + sample_rate=48k (16) + 256kbps (25) + channels=2 (5) = 71
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossy-71",
            "bit_depth": 24,
            "sample_rate": 48000,
            "channels": 2,
            "duration": 100.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossy-71",
            "mime_type": "audio/mp3",
            "file_size": 3200000  # 3,200,000 * 8 / 100 = 256,000 bps
        })

        # Part B: Equal score & both lossy -> larger file size wins (MP3 320k 7.5MB vs 7.2MB, Score 68)
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossy-small",
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossy-small",
            "mime_type": "audio/mpeg",
            "file_size": 7200000
        })

        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossy-large",
            "bit_depth": 16,
            "sample_rate": 44100,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossy-large",
            "mime_type": "audio/mpeg",
            "file_size": 7500000
        })

        # Part C: Equal score & both lossless -> larger file size wins (FLAC 97 score, 50MB vs 52.4MB)
        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossless-small",
            "bit_depth": 24,
            "sample_rate": 96000,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossless-small",
            "mime_type": "audio/flac",
            "file_size": 50000000
        })

        self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-tie-lossless-large",
            "bit_depth": 24,
            "sample_rate": 96000,
            "channels": 2,
            "duration": 180.0
        })
        self.dispatch("CreateAsset", {
            "file_hash": "file-tie-lossless-large",
            "mime_type": "audio/flac",
            "file_size": 52428800
        })

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossless-71", "file-tie-lossless-71"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossy-71", "file-tie-lossy-71"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossy-small", "file-tie-lossy-small"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossy-large", "file-tie-lossy-large"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossless-small", "file-tie-lossless-small"))
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-tie-lossless-large", "file-tie-lossless-large"))
        conn.commit()
        conn.close()

        # Test A: Equal score (71) -> Lossless wins over Lossy
        res_a = self.dispatch("audio.compare_versions", {
            "pcm_hashes": ["pcm-tie-lossy-71", "pcm-tie-lossless-71"]
        })
        self.assertResponseCode(res_a, 200)
        v_a = res_a["data"]["versions"]
        self.assertEqual(v_a[0]["quality_score"], 71)
        self.assertEqual(v_a[1]["quality_score"], 71)
        self.assertEqual(v_a[0]["pcm_hash"], "pcm-tie-lossless-71")
        self.assertTrue(v_a[0]["is_lossless"])
        self.assertEqual(v_a[1]["pcm_hash"], "pcm-tie-lossy-71")
        self.assertFalse(v_a[1]["is_lossless"])

        # Test B: Equal score & both lossy -> Larger file size wins
        res_b = self.dispatch("audio.compare_versions", {
            "pcm_hashes": ["pcm-tie-lossy-small", "pcm-tie-lossy-large"]
        })
        self.assertResponseCode(res_b, 200)
        v_b = res_b["data"]["versions"]
        self.assertEqual(v_b[0]["pcm_hash"], "pcm-tie-lossy-large")
        self.assertEqual(v_b[1]["pcm_hash"], "pcm-tie-lossy-small")

        # Test C: Equal score & both lossless -> Larger file size wins
        res_c = self.dispatch("audio.compare_versions", {
            "pcm_hashes": ["pcm-tie-lossless-small", "pcm-tie-lossless-large"]
        })
        self.assertResponseCode(res_c, 200)
        v_c = res_c["data"]["versions"]
        self.assertEqual(v_c[0]["pcm_hash"], "pcm-tie-lossless-large")
        self.assertEqual(v_c[1]["pcm_hash"], "pcm-tie-lossless-small")

    def test_compare_versions_errors(self):
        """Test all error cases for audio.compare_versions"""
        # 1. Missing parameter
        res = self.dispatch("audio.compare_versions", {})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 2. Empty track_id
        res = self.dispatch("audio.compare_versions", {"track_id": ""})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 3. Invalid track_id type
        res = self.dispatch("audio.compare_versions", {"track_id": 12345})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # 4. Non-existent track_id
        res = self.dispatch("audio.compare_versions", {"track_id": "00000000-0000-0000-0000-000000000000"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

        # 5. Track has no associated audio
        no_audio_track_id = "22222222-3333-4444-5555-666666666666"
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Track (id, title, pcm_hash) VALUES (?, ?, ?)", (no_audio_track_id, "No Audio Track", ""))
        conn.commit()
        conn.close()

        res = self.dispatch("audio.compare_versions", {"track_id": no_audio_track_id})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AudioNotFound")

        # 6. Empty pcm_hashes list
        res = self.dispatch("audio.compare_versions", {"pcm_hashes": []})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 7. Invalid pcm_hashes type
        res = self.dispatch("audio.compare_versions", {"pcm_hashes": "not-a-list"})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # 8. Non-string in pcm_hashes
        res = self.dispatch("audio.compare_versions", {"pcm_hashes": ["valid", 123]})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # 9. Non-existent pcm_hash
        res = self.dispatch("audio.compare_versions", {"pcm_hashes": ["non-existent-hash"]})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AudioNotFound")

    def _generate_wav_file(self, filename="sample.wav", duration=1.0):
        filepath = os.path.abspath(os.path.join(self.test_db_dir, filename))
        subprocess.run([
            "ffmpeg", "-y", "-v", "error", "-f", "lavfi",
            "-i", f"sine=frequency=440:duration={duration}",
            "-c:a", "pcm_s16le", filepath
        ], check=True)
        return filepath

    def test_get_waveform_via_track_id(self):
        """Test audio.get_waveform using track_id with default points (300)"""
        wav_path = self._generate_wav_file("track_waveform.wav", 1.5)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        res_track = self.dispatch("CreateTrack", {
            "title": "Track with Waveform",
            "pcm_hash": pcm_hash
        })
        self.assertResponseCode(res_track, 201)
        track_id = res_track["data"]["id"]

        res_wf = self.dispatch("audio.get_waveform", {"track_id": track_id})
        self.assertResponseCode(res_wf, 200)
        data = res_wf["data"]
        self.assertEqual(data["pcm_hash"], pcm_hash)
        self.assertEqual(data["points"], 300)
        self.assertEqual(len(data["peaks"]), 300)
        self.assertEqual(len(data["rms"]), 300)

        for min_val, max_val in data["peaks"]:
            self.assertLessEqual(min_val, 0.0)
            self.assertGreaterEqual(max_val, 0.0)
            self.assertGreaterEqual(min_val, -1.0)
            self.assertLessEqual(max_val, 1.0)

        for rms_val in data["rms"]:
            self.assertGreaterEqual(rms_val, 0.0)
            self.assertLessEqual(rms_val, 1.0)

    def test_get_waveform_via_pcm_hash_custom_points(self):
        """Test audio.get_waveform using pcm_hash and custom points (500)"""
        wav_path = self._generate_wav_file("hash_waveform.wav", 1.0)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        res_wf = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash, "points": 500})
        self.assertResponseCode(res_wf, 200)
        data = res_wf["data"]
        self.assertEqual(data["pcm_hash"], pcm_hash)
        self.assertEqual(data["points"], 500)
        self.assertEqual(len(data["peaks"]), 500)
        self.assertEqual(len(data["rms"]), 500)

    def test_get_waveform_points_boundary_values(self):
        """Test audio.get_waveform boundary values for points (50, 1000)"""
        wav_path = self._generate_wav_file("boundary_waveform.wav", 1.0)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        # Lower boundary (50)
        res_min = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash, "points": 50})
        self.assertResponseCode(res_min, 200)
        self.assertEqual(res_min["data"]["points"], 50)
        self.assertEqual(len(res_min["data"]["peaks"]), 50)
        self.assertEqual(len(res_min["data"]["rms"]), 50)

        # Upper boundary (1000)
        res_max = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash, "points": 1000})
        self.assertResponseCode(res_max, 200)
        self.assertEqual(res_max["data"]["points"], 1000)
        self.assertEqual(len(res_max["data"]["peaks"]), 1000)
        self.assertEqual(len(res_max["data"]["rms"]), 1000)

    def test_get_waveform_cache_acceleration(self):
        """Test waveform cache creation and cache hit performance acceleration"""
        wav_path = self._generate_wav_file("cached_waveform.wav", 2.0)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        cache_file = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_hash}.bin")
        self.assertFalse(os.path.exists(cache_file))

        # First call: computes and creates binary cache
        res_1 = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_1, 200)

        self.assertTrue(os.path.exists(cache_file))
        # 16 bytes header + 1000 points * 12 bytes = 12016 bytes
        self.assertEqual(os.path.getsize(cache_file), 12016)

        # Second call: cache hit
        res_2 = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_2, 200)

        self.assertEqual(res_1["data"]["peaks"], res_2["data"]["peaks"])
        self.assertEqual(res_1["data"]["rms"], res_2["data"]["rms"])

    def test_get_waveform_cache_corruption_self_healing(self):
        """Test that corrupted cache file is detected, removed, and self-healed"""
        wav_path = self._generate_wav_file("corrupt_heal_waveform.wav", 1.0)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        cache_dir = os.path.join(self.test_db_dir, ".cache", "waveforms")
        os.makedirs(cache_dir, exist_ok=True)
        cache_file = os.path.join(cache_dir, f"{pcm_hash}.bin")

        # Write corrupted garbage bytes
        with open(cache_file, "wb") as f:
            f.write(b"INVALID_HEADER_GARBAGE_DATA_12345678")

        # API call should detect corrupt cache, remove it, recompute from audio file, and restore cache
        res = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["pcm_hash"], pcm_hash)
        self.assertEqual(res["data"]["points"], 300)

        # Verify cache file was self-healed and has valid size
        self.assertTrue(os.path.exists(cache_file))
        self.assertEqual(os.path.getsize(cache_file), 12016)

        # Verify header is now valid LWAV
        with open(cache_file, "rb") as f:
            magic = f.read(4)
            self.assertEqual(magic, b"LWAV")

    def test_get_waveform_errors(self):
        """Test all error cases for audio.get_waveform"""
        # 1. Missing parameter
        res = self.dispatch("audio.get_waveform", {})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 2. Empty track_id
        res = self.dispatch("audio.get_waveform", {"track_id": ""})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 3. Invalid track_id type
        res = self.dispatch("audio.get_waveform", {"track_id": 12345})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # 4. Non-existent track_id
        res = self.dispatch("audio.get_waveform", {"track_id": "00000000-0000-0000-0000-000000000000"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

        # 5. Track has no associated audio
        no_audio_track_id = "33333333-4444-5555-6666-777777777777"
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Track (id, title, pcm_hash) VALUES (?, ?, ?)", (no_audio_track_id, "Track No Audio", ""))
        conn.commit()
        conn.close()

        res = self.dispatch("audio.get_waveform", {"track_id": no_audio_track_id})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AudioNotFound")

        # 6. Empty pcm_hash
        res = self.dispatch("audio.get_waveform", {"pcm_hash": ""})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

        # 7. Invalid pcm_hash type
        res = self.dispatch("audio.get_waveform", {"pcm_hash": True})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # 8. Non-existent pcm_hash
        res = self.dispatch("audio.get_waveform", {"pcm_hash": "non-existent-pcm-hash"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AudioNotFound")

        # 9. Audio exists but has no linked assets
        res_audio = self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-audio-no-assets",
            "quality_score": 80,
            "sample_rate": 44100
        })
        self.assertResponseCode(res_audio, 201)

        res = self.dispatch("audio.get_waveform", {"pcm_hash": "pcm-audio-no-assets"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AssetNotFound")

        # 10. Audio and Asset exist in DB, but file is missing on disk
        res_audio_2 = self.dispatch("CreateAudio", {
            "pcm_hash": "pcm-audio-missing-file",
            "quality_score": 80,
            "sample_rate": 44100
        })
        self.assertResponseCode(res_audio_2, 201)
        res_asset_2 = self.dispatch("CreateAsset", {
            "file_hash": "file-missing-on-disk",
            "mime_type": "audio/flac",
            "asset_type": "audio",
            "file_size": 1000
        })
        self.assertResponseCode(res_asset_2, 201)
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Audio_Asset (pcm_hash, file_hash) VALUES (?, ?)", ("pcm-audio-missing-file", "file-missing-on-disk"))
        conn.commit()
        conn.close()

        res = self.dispatch("audio.get_waveform", {"pcm_hash": "pcm-audio-missing-file"})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "AssetNotFound")

        # 11. Valid audio ingested, but invalid points type / range
        wav_path = self._generate_wav_file("valid_for_err.wav", 1.0)
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        valid_pcm = res_ingest["data"]["audio"]["pcm_hash"]

        # Invalid points type (string)
        res = self.dispatch("audio.get_waveform", {"pcm_hash": valid_pcm, "points": "three_hundred"})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # Invalid points type (float)
        res = self.dispatch("audio.get_waveform", {"pcm_hash": valid_pcm, "points": 300.5})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

        # Out of range (points < 50)
        res = self.dispatch("audio.get_waveform", {"pcm_hash": valid_pcm, "points": 49})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

        # Out of range (points > 1000)
        res = self.dispatch("audio.get_waveform", {"pcm_hash": valid_pcm, "points": 1001})
        self.assertResponseCode(res, 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")


