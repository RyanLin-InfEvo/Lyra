# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import ctypes
import json
import unittest
from base_test_case import BaseLyraTestCase

class TestSecurityDoS(BaseLyraTestCase):

    def test_deeply_nested_json(self):
        """Test deeply nested JSON to ensure it is caught by depth limits instead of crashing"""
        depth = 1000  # 1,000 is enough to exceed the 64 limit
        
        # Manually construct to avoid Python's json.dumps recursion limit
        prefix = '{"a":' * depth
        suffix = '}' * depth
        payload_content = '{"command":"GetArtist","params":{"id":"00000000-0000-0000-0000-000000000000"}}'
        payload_str = prefix + payload_content + suffix

        res_ptr = self.lib.lyra_dispatch(payload_str.encode('utf-8'))
        self.assertIsNotNone(res_ptr, "C++ returned NULL (Possible crash!)")
        
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        response = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertEqual(response.get("code"), 400)
        self.assertIn("exceeds maximum nesting depth", response["error"].get("message"))

    def test_extremely_large_json(self):
        """Test extremely large JSON string (100MB) to ensure length limit works"""
        # We construct a large raw string instead of a dict to avoid memory overhead in Python
        large_val = "x" * (100 * 1024 * 1024)
        payload_str = '{"command":"CreateArtist","params":{"name":"' + large_val + '"}}'
        
        res_ptr = self.lib.lyra_dispatch(payload_str.encode('utf-8'))
        self.assertIsNotNone(res_ptr, "C++ returned NULL (Possible crash!)")

        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        response = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertEqual(response.get("code"), 400)
        self.assertIn("exceeds maximum length", response["error"].get("message"))

    def test_null_json_input(self):
        """Test passing a NULL pointer to lyra_dispatch"""
        res_ptr = self.lib.lyra_dispatch(None)
        self.assertIsNotNone(res_ptr, "C++ returned NULL")

        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        response = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertEqual(response.get("code"), 400)
        self.assertIn("JSON request is null", response["error"].get("message"))

if __name__ == "__main__":
    unittest.main()
