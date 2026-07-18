# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
from base_test_case import BaseLyraTestCase

class TestSqliteHelper(BaseLyraTestCase):

    def test_sqlite_helper_utility(self):
        """
        Verify the C++ SqliteHelper escape_like implementation.
        """
        import subprocess
        import os
        
        executable = "./core/build/sqlite_helper_test"
        
        # Ensure executable exists
        self.assertTrue(os.path.exists(executable), f"Executable not found at {executable}. Make sure the project is built.")
        
        # Run the C++ test binary
        res = subprocess.run([executable], capture_output=True, text=True)
        
        # We expect the return code to be 0 (ALL_TESTS_PASSED)
        self.assertEqual(res.returncode, 0, f"Expected exit code 0, got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
        self.assertIn("ALL_TESTS_PASSED", res.stdout)

if __name__ == "__main__":
    unittest.main()
