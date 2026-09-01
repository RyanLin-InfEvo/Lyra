# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import ctypes
import json
import os
import shutil
import sqlite3
import unittest

class BaseLyraTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Poka-Yoke: Ensure .so path exits
        so_file_path = './core/build/liblyra_core.so'
        if not os.path.exists(so_file_path):
            raise FileNotFoundError(f"Shared library not found at {so_file_path}. Please build the project first.")
        
        cls.lib = ctypes.CDLL(so_file_path)
        
        # Setup FFI argument and return types
        cls.lib.lyra_init.argtypes = [ctypes.c_char_p]
        cls.lib.lyra_init.restype = ctypes.c_int
        
        cls.lib.lyra_dispatch.argtypes = [ctypes.c_char_p]
        cls.lib.lyra_dispatch.restype = ctypes.c_void_p
        
        cls.lib.lyra_free_string.argtypes = [ctypes.c_void_p]
        cls.lib.lyra_free_string.restype = None

        # Use indivisual temporary database for each testing class
        cls.test_db_dir = f"./test_run_{cls.__name__}"
        if os.path.exists(cls.test_db_dir):
            shutil.rmtree(cls.test_db_dir)
        os.makedirs(cls.test_db_dir)
        
        init_result = cls.lib.lyra_init(cls.test_db_dir.encode('utf-8'))
        if init_result != 0:
            raise RuntimeError(f"Failed to initialize database in {cls.test_db_dir}")

    @classmethod
    def tearDownClass(cls):
        # Clean up after test is done
        if os.path.exists(cls.test_db_dir):
            shutil.rmtree(cls.test_db_dir)

    def dispatch(self, command, params):
        return self.raw_dispatch({
            "command": command,
            "params": params
        })

    def raw_dispatch(self, raw_request_dict: dict) -> dict:
        # For testing 'Router Layer' edge condition, sending Malformed JSON
        res_ptr = None
        try:
            req_str = json.dumps(raw_request_dict).encode('utf-8')
            res_ptr = self.lib.lyra_dispatch(req_str)
            
            if not res_ptr:
                raise ValueError("C++ returned a null pointer.")
            
            res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
            return json.loads(res_str)
            
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Failed to parse JSON response from C++: {e}")
        finally:
            # Poka-Yoke: Free memory even if C++ returns invalid JSON or an exception occurs
            if res_ptr:
                self.lib.lyra_free_string(res_ptr)

    def assertResponseCode(self, response: dict, expected_code: int, msg: str = None):
        """Assert that the response dict contains the expected code."""
        code = response.get("code")
        self.assertEqual(
            code, expected_code,
            msg or f"Expected response code {expected_code}, but got {code}. Response: {response}"
        )

    def assertValidationError(self, response: dict, expected_type: str = "InvalidValue", expected_message_content: str = None):
        """Assert that the response indicates a validation error (400) with proper structured info."""
        self.assertResponseCode(response, 400)
        self.assertIn("error", response, "Response is missing 'error' key.")
        
        error_type = response["error"].get("type")
        self.assertEqual(
            error_type, expected_type,
            f"Expected error type '{expected_type}', but got '{error_type}'. Response: {response}"
        )
        
        if expected_message_content:
            error_msg = response["error"].get("message", "")
            self.assertIn(
                expected_message_content, error_msg,
                f"Expected '{expected_message_content}' in error message, but got: '{error_msg}'"
            )

    def execute_raw_sql(self, sql: str, params=()):
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA journal_mode=WAL;")
        cursor = conn.cursor()
        cursor.execute(sql, params)
        conn.commit()
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        conn.close()

    def execute_raw_sqls(self, operations):
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA journal_mode=WAL;")
        cursor = conn.cursor()
        for sql, params in operations:
            cursor.execute(sql, params)
        conn.commit()
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        conn.close()