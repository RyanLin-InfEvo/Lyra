# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
import unittest
from base_test_case import BaseLyraTestCase


class TestAudioDeviceInfo(BaseLyraTestCase):

    def test_audio_device_info_json_validation(self):
        """
        Verify that AudioDeviceInfo JSON deserialization enforces strict fail-fast validation
        against non-object payloads, null fields, and mismatched types.
        """
        executable = "./core/build/audio_device_info_test"

        self.assertTrue(
            os.path.exists(executable),
            f"Executable not found at {executable}. Make sure the project is built."
        )

        res = subprocess.run([executable], capture_output=True, text=True)
        self.assertEqual(
            res.returncode,
            0,
            f"Expected exit code 0, got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}"
        )
        self.assertIn("ALL_TESTS_PASSED", res.stdout)


if __name__ == "__main__":
    unittest.main()
