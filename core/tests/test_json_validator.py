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
        self.assertValidationError(res, expected_type="MissingParameter", expected_message_content="Missing required field")

    def test_type_mismatch_string(self):
        """Test type mismatch for String field"""
        # ArtistController::create requires 'name' (String)
        res = self.dispatch("CreateArtist", {"name": 1234})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="is not a expected type")

    def test_type_mismatch_number(self):
        """Test type mismatch for Number field"""
        # TrackController::create optional 'duration' (Number)
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_123",
            "title": "Title",
            "duration": "180" # String instead of Number
        })
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="is not a expected type")

    def test_string_format_uuid(self):
        """Test invalid UUID format"""
        # ArtistController::get requires 'id' (StringFormat::UUID)
        res = self.dispatch("GetArtist", {"id": "invalid-uuid-format"})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="not a vaild UUID")

    def test_string_empty(self):
        """Test empty string validation"""
        # TrackController::create requires 'pcm_hash' not to be empty
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "",
            "title": "Title" # title is optional but we test required string
        })
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="should not be empty")

    def test_valid_json_payload(self):
        """Test valid payload passes JsonValidator completely"""
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_abc",
            "duration": 180
        })
        self.assertResponseCode(res, 201)

    def assert_structured_error(self, res, msg_context):
        """Helper: verify the response is a proper structured 400 error, not a catch-all leak."""
        self.assertResponseCode(res, 400, f"[{msg_context}] Expected 400, got: {res}")
        self.assertIn("error", res, f"[{msg_context}] Missing 'error' key: {res}")
        self.assertIn("type", res["error"], f"[{msg_context}] Missing error.type (catch-all leak): {res}")
        self.assertEqual(
            res["error"]["type"], "InvalidCommandFormat",
            f"[{msg_context}] Expected InvalidCommandFormat, got: {res['error']}"
        )
        # Must NOT contain raw C++ exception leak
        self.assertNotIn(
            "json.exception", res["error"].get("message", ""),
            f"[{msg_context}] Raw nlohmann exception leaked: {res['error']['message']}"
        )

    def test_params_null(self):
        """params: null → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": None})
        self.assert_structured_error(res, "params=null")

    def test_params_array(self):
        """params: [] → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": []})
        self.assert_structured_error(res, "params=array")

    def test_params_number(self):
        """params: 42 → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": 42})
        self.assert_structured_error(res, "params=number")

    def test_params_string(self):
        """params: 'hello' → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": "hello"})
        self.assert_structured_error(res, "params=string")

    def test_artist_name_empty(self):
        """Test empty artist name validation"""
        res = self.dispatch("CreateArtist", {"name": ""})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="should not be empty")


if __name__ == "__main__":
    unittest.main()
