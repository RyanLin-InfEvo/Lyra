# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import uuid
import wave
import struct
from base_test_case import BaseLyraTestCase

class TestAssetIngestion(BaseLyraTestCase):

    def write_dummy_wav(self, filepath, duration=1.0, sample_rate=44100, channels=2):
        with wave.open(filepath, 'wb') as wav_file:
            wav_file.setnchannels(channels)
            wav_file.setsampwidth(2) # 16-bit
            wav_file.setframerate(sample_rate)
            # Generate dummy silence (zeros)
            num_frames = int(duration * sample_rate)
            data = struct.pack('<' + 'h' * num_frames * channels, *([0] * num_frames * channels))
            wav_file.writeframes(data)

    def test_asset_ingestion_pipeline(self):
        # 1. Create a dummy WAV file
        wav_path = os.path.join(self.test_db_dir, "dummy_test.wav")
        self.write_dummy_wav(wav_path, duration=1.5, sample_rate=44100, channels=2)
        
        # Ensure dummy file exists
        self.assertTrue(os.path.exists(wav_path))

        # 2. Ingest the file using IngestAsset command
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)

        # Verify response contains asset and audio info
        self.assertIn("asset", res_ingest["data"])
        self.assertIn("audio", res_ingest["data"])

        file_hash = res_ingest["data"]["asset"]["file_hash"]
        pcm_hash = res_ingest["data"]["audio"]["pcm_hash"]

        self.assertTrue(len(file_hash) > 0)
        self.assertTrue(len(pcm_hash) > 0)

        # 3. Verify that the file exists in the CAS folder structure: test_db_dir/objects/xx/yy/hash.wav
        xx = file_hash[0:2]
        yy = file_hash[2:4]
        cas_file_path = os.path.join(self.test_db_dir, "objects", xx, yy, f"{file_hash}.wav")
        self.assertTrue(os.path.exists(cas_file_path))

        # 4. Ingest again and verify deduplication works
        res_ingest_dup = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest_dup, 200)

        # The returned hashes should match
        self.assertEqual(res_ingest_dup["data"]["asset"]["file_hash"], file_hash)
        self.assertEqual(res_ingest_dup["data"]["audio"]["pcm_hash"], pcm_hash)

        # 5. Create a Track with the ingested pcm_hash
        track_title = "Ingested Asset Track"
        res_track = self.dispatch("CreateTrack", {
            "title": track_title,
            "pcm_hash": pcm_hash
        })
        self.assertResponseCode(res_track, 201)
        track_id = res_track["data"]["id"]

        # 6. Retrieve the resource path using GetResourcePath (via track_id)
        res_path = self.dispatch("GetResourcePath", {"track_id": track_id})
        self.assertResponseCode(res_path, 200)
        self.assertEqual(os.path.normpath(res_path["data"]["path"]), os.path.normpath(cas_file_path))
        self.assertEqual(res_path["data"]["mime_type"], "audio/wav")

        # 7. Retrieve the resource path using GetResourcePath (via pcm_hash)
        res_path_pcm = self.dispatch("GetResourcePath", {"pcm_hash": pcm_hash})
        self.assertResponseCode(res_path_pcm, 200)
        self.assertEqual(os.path.normpath(res_path_pcm["data"]["path"]), os.path.normpath(cas_file_path))
        self.assertEqual(res_path_pcm["data"]["mime_type"], "audio/wav")

        # 8. Retrieve the resource path using GetResourcePath (via file_hash)
        res_path_file = self.dispatch("GetResourcePath", {"file_hash": file_hash})
        self.assertResponseCode(res_path_file, 200)
        self.assertEqual(os.path.normpath(res_path_file["data"]["path"]), os.path.normpath(cas_file_path))
        self.assertEqual(res_path_file["data"]["mime_type"], "audio/wav")

        # 9. Expect error if no parameter is provided
        res_path_fail = self.dispatch("GetResourcePath", {})
        self.assertResponseCode(res_path_fail, 400)

        # 10. Expect error if all parameters are explicitly null/None
        res_path_all_null = self.dispatch("GetResourcePath", {"track_id": None, "pcm_hash": None, "file_hash": None})
        self.assertResponseCode(res_path_all_null, 400)

        # 11. Success when one param is valid and others are explicitly null/None
        res_path_file_nulls = self.dispatch("GetResourcePath", {"track_id": None, "pcm_hash": None, "file_hash": file_hash})
        self.assertResponseCode(res_path_file_nulls, 200)

        res_path_pcm_nulls = self.dispatch("GetResourcePath", {"track_id": None, "pcm_hash": pcm_hash, "file_hash": None})
        self.assertResponseCode(res_path_pcm_nulls, 200)

        res_path_track_nulls = self.dispatch("GetResourcePath", {"track_id": track_id, "pcm_hash": None, "file_hash": None})
        self.assertResponseCode(res_path_track_nulls, 200)

    def test_asset_ingestion_non_existent_file(self):
        # Ingest a non-existent file path
        res = self.dispatch("IngestAsset", {"source_path": "/nonexistent/path/to/file.wav"})
        self.assertValidationError(res, "InvalidValue", "does not exist or is not a regular file")

    def test_asset_ingestion_invalid_metadata(self):
        # Ingest a file with invalid metadata (e.g. duration <= 0)
        # Create a dummy WAV file with duration = 0.0
        invalid_wav_path = os.path.join(self.test_db_dir, "invalid_meta.wav")
        self.write_dummy_wav(invalid_wav_path, duration=0.0, sample_rate=44100, channels=2)
            
        res = self.dispatch("IngestAsset", {"source_path": invalid_wav_path})
        self.assertValidationError(res, "InvalidValue", "Invalid audio metadata")

    def test_asset_ingestion_path_traversal_prevention(self):
        # Path traversal prevention: attempt to get resource path with malformed file_hash containing path traversal sequences or non-hex chars
        # 1. Create an asset directly in database with a path traversal string as hash
        traversal_hash = "../../../etc/passwd"
        res_create = self.dispatch("CreateAsset", {
            "file_hash": traversal_hash,
            "mime_type": "audio/wav",
            "asset_type": "audio",
            "file_size": 1024
        })
        self.assertResponseCode(res_create, 201)

        # 2. Get resource path for this traversal hash - it should fail the validation in resolve_file_path
        res_path = self.dispatch("GetResourcePath", {"file_hash": traversal_hash})
        self.assertResponseCode(res_path, 404)
        self.assertEqual(res_path["error"]["type"], "AssetNotFound")
        self.assertIn("Invalid file hash format", res_path["error"]["message"])

    def test_ingest_database_rollback_removes_cas_file(self):
        """Test that CAS file is deleted when database insert fails during ingestion"""
        import sqlite3
        import hashlib
        
        # 1. Create a dummy WAV file
        wav_path = os.path.join(self.test_db_dir, "rollback_test.wav")
        self.write_dummy_wav(wav_path, duration=1.0, sample_rate=44100, channels=2)
        
        # Calculate expected file_hash
        h = hashlib.sha256()
        with open(wav_path, 'rb') as f:
            h.update(f.read())
        file_hash = h.hexdigest()
        
        xx = file_hash[0:2]
        yy = file_hash[2:4]
        cas_file_path = os.path.join(self.test_db_dir, "objects", xx, yy, f"{file_hash}.wav")
        
        # 2. Inject a trigger to force DB insert failure
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TRIGGER fail_insert BEFORE INSERT ON Asset
            BEGIN
                SELECT RAISE(ABORT, 'Simulated database insert failure');
            END;
        """)
        conn.commit()
        conn.close()
        
        try:
            # 3. Call IngestAsset - expect database failure
            res = self.dispatch("IngestAsset", {"source_path": wav_path})
            
            # Expecting validation / api error (e.g. InvalidValue or DatabaseError)
            self.assertResponseCode(res, 400)
            self.assertIn("error", res)
            self.assertIn("Failed to insert asset and audio", res["error"].get("message", ""))
            
            # 4. Verify CAS file does NOT exist
            self.assertFalse(os.path.exists(cas_file_path), f"CAS file {cas_file_path} should have been cleaned up")
            
        finally:
            # 5. Clean up the trigger
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("DROP TRIGGER IF EXISTS fail_insert;")
            conn.commit()
            conn.close()

    def test_get_resource_path_boundary_errors(self):
        """Test GetResourcePath with boundary errors and missing physical files"""
        # 1. No associated Asset test (pcm_hash doesn't exist)
        res1 = self.dispatch("GetResourcePath", {"pcm_hash": str(uuid.uuid4())})
        self.assertResponseCode(res1, 404)
        self.assertEqual(res1["error"]["type"], "AssetNotFound")

        # 2. Invalid Track test (track_id doesn't exist)
        res2 = self.dispatch("GetResourcePath", {"track_id": str(uuid.uuid4())})
        self.assertResponseCode(res2, 404)
        self.assertEqual(res2["error"]["type"], "TrackNotFound")

        # 3. Track exists but no Asset associated test
        # Create a track with a dummy pcm_hash (which has no Asset in DB)
        fake_pcm_hash = "fake_pcm_no_asset_" + str(uuid.uuid4())
        res_create_track = self.dispatch("CreateTrack", {
            "title": "Track Without Asset",
            "pcm_hash": fake_pcm_hash
        })
        self.assertResponseCode(res_create_track, 201)
        track_id = res_create_track["data"]["id"]

        # Call GetResourcePath using this track_id -> should fail with AssetNotFound
        res3 = self.dispatch("GetResourcePath", {"track_id": track_id})
        self.assertResponseCode(res3, 404)
        self.assertEqual(res3["error"]["type"], "AssetNotFound")

        # 4. Database has records but physical file is missing test
        # Ingest a valid file to create DB records and physical file
        wav_path = os.path.join(self.test_db_dir, "missing_phys.wav")
        self.write_dummy_wav(wav_path, duration=0.5, sample_rate=44100, channels=2)
        
        res_ingest = self.dispatch("IngestAsset", {"source_path": wav_path})
        self.assertResponseCode(res_ingest, 200)
        file_hash = res_ingest["data"]["asset"]["file_hash"]
        
        # Get path of the physical file in CAS structure
        xx = file_hash[0:2]
        yy = file_hash[2:4]
        cas_file_path = os.path.join(self.test_db_dir, "objects", xx, yy, f"{file_hash}.wav")
        self.assertTrue(os.path.exists(cas_file_path))

        # Directly delete the physical file
        os.remove(cas_file_path)
        self.assertFalse(os.path.exists(cas_file_path))

        # Call GetResourcePath -> should return 404 with AssetNotFound
        # and message containing "Asset file not found in storage"
        res4 = self.dispatch("GetResourcePath", {"file_hash": file_hash})
        self.assertResponseCode(res4, 404)
        self.assertEqual(res4["error"]["type"], "AssetNotFound")
        self.assertIn("Asset file not found in storage", res4["error"].get("message", ""))


