# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
from base_test_case import BaseLyraTestCase

class TestTransactionBug(BaseLyraTestCase):

    def test_transaction_nesting_bug(self):
        """
        Verify that multiple SqliteDatabaseContext instances on the same thread
        incorrectly share transaction depth due to function-static thread_local.
        """
        import subprocess
        import os
        
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        executable = "./core/build/database_context_test"
        
        # Ensure executable exists
        self.assertTrue(os.path.exists(executable), f"Executable not found at {executable}. Make sure the project is built.")
        
        # Run the C++ test binary
        res = subprocess.run([executable, db_path], capture_output=True, text=True)
        
        # Now that the bug is fixed, we expect the return code to be 0 (BUG_FIXED)
        self.assertEqual(res.returncode, 0, f"Expected exit code 0 (BUG_FIXED), got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
        self.assertIn("BUG_FIXED", res.stdout)

if __name__ == "__main__":
    unittest.main()
