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
        track_id = str(uuid.uuid4())
        res_create = self.dispatch("Createtrack", {"pcm_hash": "PCM Hash", "title": "Track Title"})
        self.assertEqual(res_create["code"], 200)

        updated_name = "Updated Track Name"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("Updatetrack", {"name": updated_name})
        self.assertEqual(res_update["code"], 200)
        
        res_get = self.dispatch("Gettrack", {"uuid": real_id})
        self.assertEqual(res_get["data"]["name"], updated_name)

    def test_track_update_no_fields(self):
        """Test track update with valid ID but no update fields: Should return 400"""
        res = self.dispatch("Updatetrack", {"invalide_field": "A value"})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    def test_track_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_name = "Updated Name"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("Updatetrack", {"id": unexist_id, "name": updated_name})
        self.assertEqual(res_update["code"], 500)
        self.assertTrue("error" in res_update)