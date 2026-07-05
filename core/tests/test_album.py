# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
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
