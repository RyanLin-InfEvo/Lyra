# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
import unittest
from base_test_case import BaseLyraTestCase

class TestPlaybackService(BaseLyraTestCase):

    def test_playback_service_cpp(self):
        """
        Verify the C++ PlaybackService implementation.
        """
        executable = "./core/build/playback_service_test"

        # Ensure executable exists
        self.assertTrue(os.path.exists(executable), f"Executable not found at {executable}. Make sure the project is built.")

        # Run the C++ test binary, passing our temporary test directory for temporary file tests
        res = subprocess.run([executable, self.test_db_dir], capture_output=True, text=True)

        # We expect the return code to be 0 (ALL_PLAYBACK_SERVICE_TESTS_PASSED)
        self.assertEqual(res.returncode, 0, f"Expected exit code 0, got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
        self.assertIn("ALL_PLAYBACK_SERVICE_TESTS_PASSED", res.stdout)

if __name__ == "__main__":
    unittest.main()
