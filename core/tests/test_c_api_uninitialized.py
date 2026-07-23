# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
import json
import os
import subprocess
import sys

class TestCApiUninitialized(unittest.TestCase):

    def test_c_api_dispatch_uninitialized(self):
        """
        Verify that calling lyra_dispatch before initialization returns 400 with a clear error.
        We run this test in a clean python subprocess to ensure the liblyra_core.so shared library
        is loaded completely uninitialized and not affected by other test classes in the discover runner.
        """
        so_file_path = './core/build/liblyra_core.so'
        self.assertTrue(os.path.exists(so_file_path), f"Shared library not found at {so_file_path}. Please build the project first.")

        # Clean subprocess load python script
        python_code = """
import ctypes
import json
import sys

lib = ctypes.CDLL('./core/build/liblyra_core.so')

lib.lyra_dispatch.argtypes = [ctypes.c_char_p]
lib.lyra_dispatch.restype = ctypes.c_void_p

lib.lyra_free_string.argtypes = [ctypes.c_void_p]
lib.lyra_free_string.restype = None

request = {
    "command": "GetAlbum",
    "params": {"id": "00000000-0000-0000-0000-000000000000"}
}

req_str = json.dumps(request).encode('utf-8')
res_ptr = lib.lyra_dispatch(req_str)

if res_ptr:
    res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
    lib.lyra_free_string(res_ptr)
    print(res_str)
else:
    print("NULL")
"""
        res = subprocess.run([sys.executable, "-c", python_code], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Subprocess failed with stderr:\n{res.stderr}")

        output_str = res.stdout.strip()
        self.assertNotEqual(output_str, "NULL", "C++ returned a null pointer.")

        response = json.loads(output_str)

        # Assert response code is 400
        self.assertEqual(response.get("code"), 400)
        self.assertIn("error", response)
        self.assertIn("Lyra not initialized. Call lyra_init first.", response["error"].get("message", ""))

if __name__ == "__main__":
    unittest.main()
