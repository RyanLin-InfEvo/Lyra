# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import ctypes
import json
import os
import unittest
import shutil

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