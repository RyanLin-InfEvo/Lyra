# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
from base_test_case import BaseLyraTestCase

class TestAudioController(BaseLyraTestCase):

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
