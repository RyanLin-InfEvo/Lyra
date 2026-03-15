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
        
        self.assertEqual(res["code"], 201)
        self.assertEqual(res["data"]["pcm_hash"], pcm_hash)
        self.assertEqual(res["data"]["title"], title)

    def test_track_create_missing_required(self):
        """Test missing required Track fields (pcm_hash): Should return 400 (MissingParameter)"""
        res = self.dispatch("CreateTrack", {"title": "Missing Hash Track"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

    def test_track_create_type_mismatch(self):
        """Test Track creation with invalid parameter types (e.g., duration as string): Should return 400"""
        res = self.dispatch("CreateTrack", {"pcm_hash": "hash_456", "duration": "invalid_type_str"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    # --------
    # Get Test
    # --------

    def test_track_get_success(self):
        """Test successful retrieval of an existing Track"""
        pcm_hash = "fake_pcm_hash_get"
        res_create = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": "Get Target Track"})
        self.assertEqual(res_create["code"], 201)

        res_get = self.dispatch("GetTrack", {"uuid": res_create["data"]["id"]})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["id"], res_create["data"]["id"])
        self.assertEqual(res_get["data"]["pcm_hash"], pcm_hash)

    def test_track_get_invalid_uuid(self):
        """Test fetching Track with invalid UUID format: Should trigger validation error"""
        res = self.dispatch("GetTrack", {"uuid": "invalid-uuid"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    def test_track_get_not_found(self):
        """Test fetching a non-existent Track: Should return 404 (TrackNotFound)"""
        res = self.dispatch("GetTrack", {"uuid": str(uuid.uuid4())})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

    # -----------
    # Update Test
    # -----------

    def test_track_update_success(self):
        """Test successful update of an existing track"""
        res_create = self.dispatch("CreateTrack", {"pcm_hash": "PCM Hash Update", "title": "Track Title"})
        self.assertEqual(res_create["code"], 201)

        updated_title = "Updated Track Name"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateTrack", {"id": real_id, "title": updated_title})
        self.assertEqual(res_update["code"], 200)
        
        res_get = self.dispatch("GetTrack", {"uuid": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)

    def test_track_update_no_fields(self):
        """Test track update with valid ID but no update fields: Should return 400"""
        real_id = str(uuid.uuid4())
        res = self.dispatch("UpdateTrack", {"id": real_id, "invalid_field": "A value"})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    def test_track_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_title = "Updated Title"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateTrack", {"id": unexist_id, "title": updated_title})
        self.assertEqual(res_update["code"], 500)
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
            "track_uuid": track_id, 
            "artist_uuid": artist_id,
            "role": "main",
            "position": 1
        })
        self.assertEqual(res_add["code"], 201)
        self.assertEqual(res_add["data"]["track_uuid"], track_id)
        self.assertEqual(res_add["data"]["artist_uuid"], artist_id)
        self.assertEqual(res_add["data"]["role"], "main")
        self.assertEqual(res_add["data"]["position"], 1)

    def test_remove_track_artist_success(self):
        """Test successful removal of a track-artist relation"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 2", "title": "Track TA 2"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 2"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        self.dispatch("AddTrackArtist", {
            "track_uuid": track_id, 
            "artist_uuid": artist_id,
            "role": "featured"
        })
        
        res_remove = self.dispatch("RemoveTrackArtist", {
            "track_uuid": track_id,
            "artist_uuid": artist_id
        })
        self.assertEqual(res_remove["code"], 200)

    def test_update_track_artist_success(self):
        """Test successful update of a track-artist relation"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash TA 3", "title": "Track TA 3"})
        res_artist = self.dispatch("CreateArtist", {"name": "Artist 3"})
        track_id = res_track["data"]["id"]
        artist_id = res_artist["data"]["id"]
        
        self.dispatch("AddTrackArtist", {
            "track_uuid": track_id, 
            "artist_uuid": artist_id,
            "role": "performer",
            "position": 5
        })
        
        res_update = self.dispatch("UpdateTrackArtist", {
            "track_uuid": track_id,
            "artist_uuid": artist_id,
            "role": "producer"
        })
        self.assertEqual(res_update["code"], 200)
        self.assertEqual(res_update["data"]["role"], "producer")