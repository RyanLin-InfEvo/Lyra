# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import ctypes
import json
import os
import unittest
import uuid
import shutil

class TestLyraCore(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Path to shared library
        so_file_path = './core/build/liblyra_core.so'
        if not os.path.exists(so_file_path):
            raise FileNotFoundError(f"Shared library not found at {so_file_path}. Please build the project first.")
        
        cls.lib = ctypes.CDLL(so_file_path)
        
        # Setup argument and return types
        cls.lib.lyra_init.argtypes = [ctypes.c_char_p]
        cls.lib.lyra_init.restype = ctypes.c_int
        
        cls.lib.lyra_dispatch.argtypes = [ctypes.c_char_p]
        cls.lib.lyra_dispatch.restype = ctypes.c_void_p
        
        cls.lib.lyra_free_string.argtypes = [ctypes.c_void_p]
        cls.lib.lyra_free_string.restype = None

        # Use a temporary database for testing
        cls.test_db_dir = "./test_run"
        if os.path.exists(cls.test_db_dir):
            shutil.rmtree(cls.test_db_dir)
        os.makedirs(cls.test_db_dir)
        
        init_result = cls.lib.lyra_init(cls.test_db_dir.encode('utf-8'))
        if init_result != 0:
            raise RuntimeError("Failed to initialize database")

    def dispatch(self, command, params):
        request = {
            "command": command,
            "params": params
        }
        req_str = json.dumps(request).encode('utf-8')
        res_ptr = self.lib.lyra_dispatch(req_str)
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        response = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)
        return response

    # ==========================================
    # 1. Router and Command Validation Tests
    # Checks basic validation before request enters controllers
    # ==========================================

    def test_router_missing_command(self):
        """Test missing 'command' field: Should return 400 (Router level)"""
        request = {"params": {"some_param": 1}}
        req_str = json.dumps(request).encode('utf-8')
        res_ptr = self.lib.lyra_dispatch(req_str)
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        res = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["message"], "Missing or invalid 'command' field")

    def test_router_invalid_command_type(self):
        """Test invalid 'command' type (e.g., integer): Should return 400"""
        request = {"command": 123, "params": {}}
        req_str = json.dumps(request).encode('utf-8')
        res_ptr = self.lib.lyra_dispatch(req_str)
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        res = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["message"], "Missing or invalid 'command' field")

    def test_router_unknown_command(self):
        """Test calling an unknown command: Router should return 404 Not Found"""
        res = self.dispatch("InvalidCommand123", {"some_param": 1})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["message"], "Unknown command: InvalidCommand123")

    # ==========================================
    # 2. Artist Controller Validation and Operation Tests
    # Tests for Artist CRUD behavior and parameter validation
    # ==========================================

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

    def test_artist_get_success(self):
        """Test successful retrieval of an existing Artist"""
        artist_id = str(uuid.uuid4())
        artist_name = "Get Artist Test"
        res_create = self.dispatch("CreateArtist", {"id": artist_id, "name": artist_name})
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
        res_update = self.dispatch("UpdateArtist", {"id": '4da4efaf-391a-4c43-a596-000000000000', "name": updated_name})
        self.assertEqual(res_update["code"], 500)
        self.assertTrue("error" in res_update)

    # ==========================================
    # 3. Track Controller Validation and Operation Tests
    # Tests for Track creation and retrieval behaviors
    # ==========================================

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

    def test_track_get_success(self):
        """Test successful retrieval of an existing Track"""
        pcm_hash = "fake_pcm_hash_get"
        res_create = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": "Get Target Track"})
        self.assertEqual(res_create["code"], 201)

        res_get = self.dispatch("GetTrack", {"id": res_create["data"]["id"]})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["id"], res_create["data"]["id"])
        self.assertEqual(res_get["data"]["pcm_hash"], pcm_hash)

    def test_track_get_invalid_uuid(self):
        """Test fetching Track with invalid UUID format: Should trigger validation error"""
        res = self.dispatch("GetTrack", {"id": "invalid-uuid"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "InvalidValue")

    def test_track_get_not_found(self):
        """Test fetching a non-existent Track: Should return 404 (TrackNotFound)"""
        res = self.dispatch("GetTrack", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")



if __name__ == "__main__":
    unittest.main()
