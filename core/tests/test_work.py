# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
import json
from base_test_case import BaseLyraTestCase

class TestWorkController(BaseLyraTestCase):

    # -----------
    # Create Test
    # -----------

    def test_work_create_success(self):
        """Test successful Work creation with valid ID and title"""
        work_title = "Symphony No. 5"
        work_id = str(uuid.uuid4())
        res = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": work_title,
            "composition_start_year": 1804,
            "composition_end_year": 1808,
            "iswc": "T-123.456.789-Z"
        })
        
        self.assertEqual(res["code"], 201)
        self.assertEqual(res["data"]["title"], work_title)
        self.assertEqual(res["data"]["composition_start_year"], 1804)
        self.assertEqual(res["data"]["composition_end_year"], 1808)
        self.assertEqual(res["data"]["iswc"], "T-123.456.789-Z")
        self.assertTrue("id" in res["data"])

    def test_work_create_missing_required(self):
        """Test missing required parameters (title): JsonValidator should return 400"""
        res = self.dispatch("CreateWork", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

    def test_work_create_type_mismatch(self):
        """Test parameter type mismatch (e.g., title as integer): Should return 400"""
        res = self.dispatch("CreateWork", {"id": str(uuid.uuid4()), "title": 12345})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    def test_work_create_unreasonable_composition_year(self):
        """Test composition year out of range: Should return 400"""
        work_title = "Symphony No. 5"
        work_id = str(uuid.uuid4())
        res = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": work_title,
            "composition_start_year": 0,
            "composition_end_year": 6000
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

    def test_work_create_composition_year_end_earlier_than_start(self):
        """Test composition year end earlier than start: Should return 400"""
        work_title = "Symphony No. 5"
        work_id = str(uuid.uuid4())
        res = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": work_title,
            "composition_start_year": 1900,
            "composition_end_year": 1800
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

    def test_work_create_composition_year_out_of_range(self):
        """Test composition year out of range: Should return 400"""
        work_title = "Symphony No. 5"
        work_id = str(uuid.uuid4())
        res = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": work_title,
            "composition_start_year": -1,
            "composition_end_year": 65536
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

    # -----------
    # Get Test
    # -----------

    def test_work_get_success(self):
        """Test successful retrieval of an existing Work"""
        work_id = str(uuid.uuid4())
        work_title = "Get Work Test"
        res_create = self.dispatch("CreateWork", {"id": work_id, "title": work_title})
        self.assertEqual(res_create["code"], 201)

        real_id = res_create["data"]["id"]
        res_get = self.dispatch("GetWork", {"id": real_id})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["title"], work_title)

    def test_work_get_invalid_uuid(self):
        """Test fetching Work with invalid UUID format: Should trigger validation error"""
        res = self.dispatch("GetWork", {"id": "not-a-valid-uuid-format"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    def test_work_get_not_found(self):
        """Test fetching a non-existent Work: Should return 404"""
        res = self.dispatch("GetWork", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "WorkNotFound")

    # -----------
    # Update Test
    # -----------

    def test_work_update_success(self):
        """Test successful update of an existing Work"""
        work_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateWork", {"id": work_id, "title": "Initial Title"})
        self.assertEqual(res_create["code"], 201)

        updated_title = "Updated Title"
        updated_year = 2026
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateWork", {
            "id": real_id, 
            "title": updated_title,
            "composition_start_year": updated_year
        })
        self.assertEqual(res_update["code"], 200)
        
        res_get = self.dispatch("GetWork", {"id": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)
        self.assertEqual(res_get["data"]["composition_start_year"], updated_year)

    def test_work_update_no_fields(self):
        """Test Work update with valid ID but no update fields: Should return 400"""
        work_id = str(uuid.uuid4())
        res = self.dispatch("UpdateWork", {"id": work_id})
        self.assertEqual(res["code"], 400)
        self.assertTrue("error" in res)

    def test_work_update_not_exist_uuid(self):
        """Test updating a non-existent Work"""
        updated_title = "Updated Title"
        unexist_id = str(uuid.uuid4())
        res_update = self.dispatch("UpdateWork", {"id": unexist_id, "title": updated_title})
        self.assertEqual(res_update["code"], 500)
        self.assertTrue("error" in res_update)

    def test_work_update_same_values(self):
        """Test updating a Work with the same values: Should still return 200 (matched rows)"""
        work_id = str(uuid.uuid4())
        title = "Same Value Test"
        res_create = self.dispatch("CreateWork", {"id": work_id, "title": title})
        self.assertEqual(res_create["code"], 201)

        real_id = res_create["data"]["id"]
        # Update with identical title
        res_update = self.dispatch("UpdateWork", {"id": real_id, "title": title})
        
        # In SQLite, matched rows are returned even if values don't change.
        # This test verifies that DatabaseManager doesn't return 0 (and thus doesn't return error).
        self.assertEqual(res_update["code"], 200)

    def test_work_create_duplicate_iswc(self):
        """Test creating a work with a duplicate ISWC: Should return 409 Conflict"""
        iswc = "T-999.999.999-A"
        res_create1 = self.dispatch("CreateWork", {
            "id": str(uuid.uuid4()),
            "title": "Work 1",
            "iswc": iswc
        })
        self.assertEqual(res_create1["code"], 201)

        res_create2 = self.dispatch("CreateWork", {
            "id": str(uuid.uuid4()),
            "title": "Work 2",
            "iswc": iswc
        })
        self.assertEqual(res_create2["code"], 409)
        self.assertEqual(res_create2["error"]["type"], "Conflict")

    def test_work_update_duplicate_iswc(self):
        """Test updating a work to an ISWC that is already used by another work: Should return 409 Conflict"""
        iswc1 = "T-999.999.999-B"
        iswc2 = "T-999.999.999-C"
        
        res_create1 = self.dispatch("CreateWork", {
            "id": str(uuid.uuid4()),
            "title": "Work A",
            "iswc": iswc1
        })
        self.assertEqual(res_create1["code"], 201)

        res_create2 = self.dispatch("CreateWork", {
            "id": str(uuid.uuid4()),
            "title": "Work B",
            "iswc": iswc2
        })
        self.assertEqual(res_create2["code"], 201)

        real_id_2 = res_create2["data"]["id"]
        # Update work B to use work A's ISWC (iswc1)
        res_update = self.dispatch("UpdateWork", {
            "id": real_id_2,
            "iswc": iswc1
        })
        self.assertEqual(res_update["code"], 409)
        self.assertEqual(res_update["error"]["type"], "Conflict")

    def test_work_update_start_greater_than_existing_end(self):
        """Test updating start year to be greater than the existing end year: Should return 400 OutOfRange"""
        work_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": "Symphony No. 5",
            "composition_start_year": 1804,
            "composition_end_year": 1808
        })
        self.assertEqual(res_create["code"], 201)

        # Update only start year to 1809 (which is > 1808)
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateWork", {
            "id": real_id, 
            "composition_start_year": 1809
        })
        self.assertEqual(res_update["code"], 400)
        self.assertEqual(res_update["error"]["type"], "OutOfRange")

    def test_work_update_end_less_than_existing_start(self):
        """Test updating end year to be less than the existing start year: Should return 400 OutOfRange"""
        work_id = str(uuid.uuid4())
        res_create = self.dispatch("CreateWork", {
            "id": work_id, 
            "title": "Symphony No. 5",
            "composition_start_year": 1804,
            "composition_end_year": 1808
        })
        self.assertEqual(res_create["code"], 201)

        # Update only end year to 1803 (which is < 1804)
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdateWork", {
            "id": real_id, 
            "composition_end_year": 1803
        })
        self.assertEqual(res_update["code"], 400)
        self.assertEqual(res_update["error"]["type"], "OutOfRange")
