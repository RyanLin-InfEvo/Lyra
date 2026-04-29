# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
import unittest
from base_test_case import BaseLyraTestCase

class TestJsonValidator(BaseLyraTestCase):

    def test_missing_required_field(self):
        """Test missing required field: Should return 400 with MissingParameter"""
        # ArtistController::create requires 'name'
        res = self.dispatch("CreateArtist", {})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")
        self.assertTrue("Missing required field" in res["error"]["message"])

    def test_type_mismatch_string(self):
        """Test type mismatch for String field"""
        # ArtistController::create requires 'name' (String)
        res = self.dispatch("CreateArtist", {"name": 1234})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"].get("type"), "InvalidValue", f"Unexpected response: {res}")
        self.assertTrue("is not a expected type" in res["error"]["message"])

    def test_type_mismatch_number(self):
        """Test type mismatch for Number field"""
        # TrackController::create optional 'duration' (Number)
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_123",
            "title": "Title",
            "duration": "180" # String instead of Number
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"].get("type"), "InvalidValue", f"Unexpected response: {res}")
        self.assertTrue("is not a expected type" in res["error"]["message"])

    def test_string_format_uuid(self):
        """Test invalid UUID format"""
        # ArtistController::get requires 'id' (StringFormat::UUID)
        res = self.dispatch("GetArtist", {"id": "invalid-uuid-format"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"].get("type"), "InvalidValue", f"Unexpected response: {res}")
        # 'vaild' is a typo in the original C++ error message
        self.assertTrue("not a vaild UUID" in res["error"]["message"])

    def test_string_empty(self):
        """Test empty string validation"""
        # TrackController::create requires 'pcm_hash' not to be empty
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "",
            "title": "Title" # title is optional but we test required string
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"].get("type"), "InvalidValue", f"Unexpected response: {res}")
        self.assertTrue("should not be empty" in res["error"]["message"])

    def test_valid_json_payload(self):
        """Test valid payload passes JsonValidator completely"""
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_abc",
            "duration": 180
        })
        self.assertEqual(res["code"], 201)

if __name__ == "__main__":
    unittest.main()
