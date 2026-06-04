# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
from base_test_case import BaseLyraTestCase

class TestAssetController(BaseLyraTestCase):

    def test_asset_create_success(self):
        """Test successful Asset creation"""
        file_hash = "sha256-abc123xyz"
        mime_type = "audio/flac"
        asset_type = "audio"
        file_size = 1048576
        res = self.dispatch("CreateAsset", {
            "file_hash": file_hash,
            "mime_type": mime_type,
            "asset_type": asset_type,
            "file_size": file_size
        })
        
        self.assertEqual(res["code"], 201)
        self.assertEqual(res["data"]["file_hash"], file_hash)

    def test_asset_create_missing_required(self):
        """Test missing required parameter file_hash"""
        res = self.dispatch("CreateAsset", {
            "mime_type": "audio/flac"
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

    def test_asset_get_success(self):
        """Test successful retrieval of an existing Asset"""
        file_hash = "sha256-get-test"
        res_create = self.dispatch("CreateAsset", {
            "file_hash": file_hash,
            "mime_type": "audio/mp3",
            "asset_type": "audio",
            "file_size": 2048
        })
        self.assertEqual(res_create["code"], 201)

        res_get = self.dispatch("GetAsset", {"file_hash": file_hash})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["mime_type"], "audio/mp3")
        self.assertEqual(res_get["data"]["file_size"], 2048)

    def test_asset_get_not_found(self):
        """Test fetching a non-existent Asset"""
        res = self.dispatch("GetAsset", {"file_hash": "non-existent-hash"})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "AssetNotFound")

    def test_asset_update_success(self):
        """Test successful update of an existing Asset"""
        file_hash = "sha256-update-test"
        res_create = self.dispatch("CreateAsset", {
            "file_hash": file_hash,
            "mime_type": "audio/wav",
            "asset_type": "audio",
            "file_size": 4096
        })
        self.assertEqual(res_create["code"], 201)

        res_update = self.dispatch("UpdateAsset", {
            "file_hash": file_hash,
            "mime_type": "audio/ogg",
            "file_size": 8192
        })
        self.assertEqual(res_update["code"], 200)

        res_get = self.dispatch("GetAsset", {"file_hash": file_hash})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["mime_type"], "audio/ogg")
        self.assertEqual(res_get["data"]["file_size"], 8192)

    def test_asset_list_success(self):
        """Test listing Assets with offset/limit"""
        self.dispatch("CreateAsset", {"file_hash": "list-1", "mime_type": "text/plain", "asset_type": "text", "file_size": 100})
        self.dispatch("CreateAsset", {"file_hash": "list-2", "mime_type": "image/png", "asset_type": "image", "file_size": 200})

        res_list = self.dispatch("ListAssets", {"offset": 0, "limit": 10})
        self.assertEqual(res_list["code"], 200)
        self.assertGreaterEqual(res_list["data"]["total"], 2)

    def test_asset_list_search_and_pagination(self):
        """Test search filter and pagination for listing Assets"""
        self.dispatch("CreateAsset", {"file_hash": "search-1", "mime_type": "audio/flac", "asset_type": "audio", "file_size": 300})
        self.dispatch("CreateAsset", {"file_hash": "search-2", "mime_type": "audio/mp3", "asset_type": "audio", "file_size": 400})
        self.dispatch("CreateAsset", {"file_hash": "search-3", "mime_type": "text/html", "asset_type": "document", "file_size": 500})

        # Test search by asset_type
        res = self.dispatch("ListAssets", {"offset": 0, "limit": 10, "search": "audio"})
        self.assertEqual(res["code"], 200)
        self.assertGreaterEqual(res["data"]["total"], 2)
        hashes = [item["file_hash"] for item in res["data"]["items"]]
        self.assertIn("search-1", hashes)
        self.assertIn("search-2", hashes)

        # Test search by mime_type
        res = self.dispatch("ListAssets", {"offset": 0, "limit": 10, "search": "html"})
        self.assertEqual(res["code"], 200)
        self.assertGreaterEqual(res["data"]["total"], 1)
        hashes = [item["file_hash"] for item in res["data"]["items"]]
        self.assertIn("search-3", hashes)

        # Test pagination
        res = self.dispatch("ListAssets", {"offset": 0, "limit": 1, "search": "html"})
        self.assertEqual(res["code"], 200)
        self.assertEqual(len(res["data"]["items"]), 1)
        self.assertEqual(res["data"]["items"][0]["file_hash"], "search-3")

    def test_asset_validation_errors(self):
        """Test Asset validation with incorrect parameter types"""
        # file_size should be Integer, passing String
        res = self.dispatch("CreateAsset", {
            "file_hash": "val-1",
            "file_size": "not-an-integer"
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    def test_asset_update_non_existent(self):
        """Test updating a non-existent Asset"""
        res = self.dispatch("UpdateAsset", {
            "file_hash": "non-existent-hash",
            "mime_type": "audio/wav"
        })
        self.assertEqual(res["code"], 500)
        self.assertEqual(res["error"]["type"], "DatabaseError")

    def test_asset_update_no_fields(self):
        """Test updating an Asset with no fields provided"""
        res = self.dispatch("UpdateAsset", {
            "file_hash": "some-hash"
        })
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")
