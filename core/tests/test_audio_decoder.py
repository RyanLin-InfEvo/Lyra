# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
import unittest
from base_test_case import BaseLyraTestCase


class TestAudioDecoder(BaseLyraTestCase):

    def test_audio_decoder_suite(self):
        """
        Verify universal audio decoding across multiple formats (Opus, Vorbis, AAC, FLAC, MP3, WAV).
        """
        executable = "./core/build/audio_decoder_test"

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
        self.assertIn("ALL_DECODER_TESTS_PASSED", res.stdout)


if __name__ == "__main__":
    unittest.main()
