# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
import unittest
from base_test_case import BaseLyraTestCase

class TestImageRepository(BaseLyraTestCase):

    def test_image_repository_cxx(self):
        """
        Verify the C++ SqliteImageRepository implementation via standalone unit test binary.
        """
        executable = "./core/build/image_repository_test"

        # Ensure executable exists
        self.assertTrue(os.path.exists(executable), f"Executable not found at {executable}. Make sure the project is built.")

        # Run the C++ test binary
        res = subprocess.run([executable], capture_output=True, text=True)

        # Expect exit code 0 and ALL_IMAGE_REPOSITORY_TESTS_PASSED in stdout
        self.assertEqual(res.returncode, 0, f"Expected exit code 0, got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
        self.assertIn("ALL_IMAGE_REPOSITORY_TESTS_PASSED", res.stdout)

if __name__ == "__main__":
    unittest.main()
