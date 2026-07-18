# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
from base_test_case import BaseLyraTestCase

class TesttrackController(BaseLyraTestCase):

    # -----------
    # Create Test
    # -----------
    def test_track_create_success(self):
        """Test successful Track creation"""
        pcm_hash = "fake_pcm_hash_123"
        title = "Automated Test Track"
        res = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": title, "duration": 180})
        
        self.assertResponseCode(res, 201)
        self.assertEqual(res["data"]["pcm_hash"], pcm_hash)
        self.assertEqual(res["data"]["title"], title)

    def test_track_create_missing_required(self):
        """Test missing required Track fields (pcm_hash): Should return 400 (MissingParameter)"""
        res = self.dispatch("CreateTrack", {"title": "Missing Hash Track"})
        self.assertValidationError(res, expected_type="MissingParameter")

    def test_track_create_type_mismatch(self):
        """Test Track creation with invalid parameter types (e.g., duration as string): Should return 400"""
        res = self.dispatch("CreateTrack", {"pcm_hash": "hash_456", "duration": "invalid_type_str"})
        self.assertValidationError(res, expected_type="InvalidValue")

    # --------
    # Get Test
    # --------

    def test_track_get_success(self):
        """Test successful retrieval of an existing Track"""
        pcm_hash = "fake_pcm_hash_get"
        res_create = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": "Get Target Track"})
        self.assertResponseCode(res_create, 201)

        res_get = self.dispatch("GetTrack", {"id": res_create["data"]["id"]})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["id"], res_create["data"]["id"])
        self.assertEqual(res_get["data"]["pcm_hash"], pcm_hash)

    def test_track_get_invalid_uuid(self):
        """Test fetching Track with invalid UUID format: Should trigger validation error"""
        res = self.dispatch("GetTrack", {"id": "invalid-uuid"})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_track_get_not_found(self):
        """Test fetching a non-existent Track: Should return 404 (TrackNotFound)"""
        res = self.dispatch("GetTrack", {"id": str(uuid.uuid4())})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

    # -----------
    # Update Test
    # -----------

    def test_track_update_success(self):
        """Test successful update of an existing track"""
        res_create = self.dispatch("CreateTrack", {"pcm_hash": "PCM Hash Update", "title": "Track Title"})
        self.assertResponseCode(res_create, 201)

        updated_title = "Updated Track Name"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateTrack", {"id": real_id, "title": updated_title})
        self.assertResponseCode(res_update, 200)
        
        res_get = self.dispatch("GetTrack", {"id": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)

    def test_track_update_no_fields(self):
        """Test track update with valid ID but no update fields: Should return 400"""
        real_id = str(uuid.uuid4())
        res = self.dispatch("UpdateTrack", {"id": real_id, "invalid_field": "A value"})
        self.assertValidationError(res, expected_type="InvalidValue")

    def test_track_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_title = "Updated Title"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateTrack", {"id": unexist_id, "title": updated_title})
        self.assertResponseCode(res_update, 500)
        self.assertTrue("error" in res_update)

    # ------------------
    # Track-Artist Tests
    # ------------------
    
    def test_add_track_artist_success(self):
        """Test successful addition of a track-artist relation"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 1", "title": "Track TA 1"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 1"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        res_add = self.dispatch("AddTrackArtist", {
            "track_id": track_id, 
            "artist_id": artist_id,
            "role": "main",
            "position": 1
        })
        self.assertResponseCode(res_add, 201)
        self.assertEqual(res_add["data"]["track_id"], track_id)
        self.assertEqual(res_add["data"]["artist_id"], artist_id)
        self.assertEqual(res_add["data"]["role"], "main")
        self.assertEqual(res_add["data"]["position"], 1)

    def test_remove_track_artist_success(self):
        """Test successful removal of a track-artist relation"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 2", "title": "Track TA 2"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 2"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        self.dispatch("AddTrackArtist", {
            "track_id": track_id, 
            "artist_id": artist_id,
            "role": "featured"
        })
        
        res_remove = self.dispatch("RemoveTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id
        })
        self.assertResponseCode(res_remove, 200)

    def test_update_track_artist_success(self):
        """Test successful update of a track-artist relation"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 3", "title": "Track TA 3"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 3"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        self.dispatch("AddTrackArtist", {
            "track_id": track_id, 
            "artist_id": artist_id,
            "role": "performer",
            "position": 5
        })
        
        res_update = self.dispatch("UpdateTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id,
            "role": "producer"
        })
        self.assertResponseCode(res_update, 200)
        self.assertEqual(res_update["data"]["role"], "producer")

    def test_add_track_artist_invalid_role(self):
        """Test adding track artist with invalid role (e.g. vocalist): Should return 400 InvalidValue"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 4", "title": "Track TA 4"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 4"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]

        res_add = self.dispatch("AddTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id,
            "role": "vocalist",
            "position": 1
        })
        self.assertValidationError(res_add, expected_type="InvalidValue")

    def test_update_track_artist_invalid_role(self):
        """Test updating track artist with invalid role (e.g. vocalist): Should return 400 InvalidValue"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 5", "title": "Track TA 5"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 5"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]

        self.dispatch("AddTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id,
            "role": "main",
            "position": 1
        })

        res_update = self.dispatch("UpdateTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id,
            "role": "vocalist"
        })
        self.assertValidationError(res_update, expected_type="InvalidValue")

    def test_add_track_artist_track_not_found(self):
        """Test AddTrackArtist with non-existent track ID: Should return 404 (TrackNotFound)"""
        res_artist = self.dispatch("CreateArtist", {"name": "Artist For Track NF"})
        artist_id = res_artist["data"]["id"]
        non_existent_track_id = str(uuid.uuid4())
        
        res = self.dispatch("AddTrackArtist", {
            "track_id": non_existent_track_id,
            "artist_id": artist_id,
            "role": "main"
        })
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

    def test_add_track_artist_artist_not_found(self):
        """Test AddTrackArtist with non-existent artist ID: Should return 404 (ArtistNotFound)"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA NF 1", "title": "Track For Artist NF"})
        track_id = res_track["data"]["id"]
        non_existent_artist_id = str(uuid.uuid4())
        
        res = self.dispatch("AddTrackArtist", {
            "track_id": track_id,
            "artist_id": non_existent_artist_id,
            "role": "main"
        })
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "ArtistNotFound")

    def test_update_track_artist_relation_not_found(self):
        """Test UpdateTrackArtist with non-existent relation: Should return 404 (RelationNotFound)"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA NF 2", "title": "Track For Relation NF"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist For Relation NF"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        res = self.dispatch("UpdateTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id,
            "role": "producer"
        })
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "RelationNotFound")
        self.assertEqual(res["error"]["message"], "Relation between Track and Artist not found.")

    def test_remove_track_artist_relation_not_found(self):
        """Test RemoveTrackArtist with non-existent relation: Should return 404 (RelationNotFound)"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA NF 3", "title": "Track For Relation NF 2"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist For Relation NF 2"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        res = self.dispatch("RemoveTrackArtist", {
            "track_id": track_id,
            "artist_id": artist_id
        })
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "RelationNotFound")
        self.assertEqual(res["error"]["message"], "Relation between Track and Artist not found.")

    def test_track_create_invalid_date(self):
        """Test track creation with invalid recording month or day (OutOfRange)"""
        # Invalid month 13
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "track_invalid_month",
            "title": "Invalid Month Track",
            "recording_month": 13
        })
        self.assertValidationError(res, expected_type="OutOfRange")
        self.assertIn("out of reasonable month range", res["error"]["message"])

        # Invalid day 32
        res2 = self.dispatch("CreateTrack", {
            "pcm_hash": "track_invalid_day",
            "title": "Invalid Day Track",
            "recording_day": 32
        })
        self.assertValidationError(res2, expected_type="OutOfRange")
        self.assertIn("out of reasonable day range", res2["error"]["message"])

        # Negative month -1
        res3 = self.dispatch("CreateTrack", {
            "pcm_hash": "track_negative_month",
            "title": "Negative Month Track",
            "recording_month": -1
        })
        self.assertValidationError(res3, expected_type="OutOfRange")

        # Invalid type for day (String)
        res4 = self.dispatch("CreateTrack", {
            "pcm_hash": "track_string_day",
            "title": "String Day Track",
            "recording_day": "15"
        })
        self.assertValidationError(res4, expected_type="InvalidValue")
