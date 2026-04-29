# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
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
        
        self.assertEqual(res["code"], 201)
        self.assertEqual(res["data"]["name"], artist_name)
        self.assertTrue("id" in res["data"])

    def test_artist_create_missing_required(self):
        """Test missing required parameters (name): JsonValidator should return 400"""
        res = self.dispatch("CreateArtist", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

    def test_artist_create_type_mismatch(self):
        """Test parameter type mismatch (e.g., name as integer): Should return 400"""
        res = self.dispatch("CreateArtist", {"id": str(uuid.uuid4()), "name": 12345})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    # -----------
    # Get Test
    # -----------

    def test_artist_get_success(self):
        """Test successful retrieval of an existing Artist"""
        artist_id = str(uuid.uuid4())
        artist_name = "Get Artist Test"
        res_create = self.dispatch("CreateArtist", {"id": artist_id, "name": artist_name})
        self.assertEqual(res_create["code"], 201)

        real_id = res_create["data"]["id"]
        res_get = self.dispatch("GetArtist", {"id": real_id})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["name"], artist_name)

    def test_artist_get_invalid_uuid(self):
        """Test fetching Artist with invalid UUID format: Should trigger validation error (InvalidValue)"""
        res = self.dispatch("GetArtist", {"id": "not-a-valid-uuid-format"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    def test_artist_get_not_found(self):
        """Test fetching a non-existent Artist: Should return 404 (ArtistNotFound)"""
        res = self.dispatch("GetArtist", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "ArtistNotFound")

    # -----------
    # Update Test
    # -----------

    def test_artist_update_success(self):
        """Test successful update of an existing Artist"""
        artist_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateArtist", {"id": artist_id, "name": "Initial Name"})
        self.assertEqual(res_create["code"], 201)

        updated_name = "Updated Name"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateArtist", {"id": real_id, "name": updated_name})
        self.assertEqual(res_update["code"], 200)
        
        res_get = self.dispatch("GetArtist", {"id": real_id})
        self.assertEqual(res_get["data"]["name"], updated_name)

    def test_artist_update_no_fields(self):
        """Test Artist update with valid ID but no update fields: Should return 400"""
        artist_id = str(uuid.uuid4())
        res = self.dispatch("UpdateArtist", {"id": artist_id})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    def test_artist_update_not_exist_uuid(self):
        """Test an not-exist uuid"""
        updated_name = "Updated Name"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateArtist", {"id": unexist_id, "name": updated_name})
        self.assertEqual(res_update["code"], 500)
        self.assertTrue("error" in res_update)