# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
import unittest
from base_test_case import BaseLyraTestCase


class TestWaveformServiceCpp(BaseLyraTestCase):

    def test_waveform_service_cpp_suite(self):
        """
        Execute the C++ unit test binary for WaveformService.
        Covers:
        1. Synthetic sine wave extraction
        2. Silence & DC offset
        3. Stereo channel peak preservation
        4. Downsampling peak preservation
        5. Cache save & binary LWAV format validation
        6. Cache hit read consistency
        7. Corrupted cache self-healing (magic, trunc, NaN)
        8. Multi-threaded concurrency
        """
        executable = "./core/build/waveform_service_test"

        self.assertTrue(
            os.path.exists(executable),
            f"Executable not found at {executable}. Make sure the project is built.",
        )

        res = subprocess.run(
            [executable, self.test_db_dir], capture_output=True, text=True
        )

        self.assertEqual(
            res.returncode,
            0,
            f"Expected exit code 0, got {res.returncode}.\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}",
        )
        self.assertIn("ALL_WAVEFORM_TESTS_PASSED", res.stdout)


if __name__ == "__main__":
    unittest.main()
