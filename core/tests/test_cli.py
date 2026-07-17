# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
import subprocess
import json
import os
import shutil

class TestLyraCLI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.test_db_dir = "./test_run_cli"
        if os.path.exists(cls.test_db_dir):
            shutil.rmtree(cls.test_db_dir)
        os.makedirs(cls.test_db_dir)
        
        # Absolute path to workspace root
        cls.workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        cls.cli_path = os.path.join(cls.workspace_root, "core/build/lyra-cli")
        if not os.path.exists(cls.cli_path):
            raise FileNotFoundError(f"CLI binary not found at {cls.cli_path}")

    @classmethod
    def tearDownClass(cls):
        if os.path.exists(cls.test_db_dir):
            shutil.rmtree(cls.test_db_dir)

    def run_cli(self, args, stdin_data=None):
        cmd = [self.cli_path, "-d", self.test_db_dir] + args
        env = os.environ.copy()
        # Add the build directory to LD_LIBRARY_PATH in case the shared library cannot be located
        build_dir = os.path.dirname(self.cli_path)
        if "LD_LIBRARY_PATH" in env:
            env["LD_LIBRARY_PATH"] = f"{build_dir}:{env['LD_LIBRARY_PATH']}"
        else:
            env["LD_LIBRARY_PATH"] = build_dir

        result = subprocess.run(
            cmd,
            input=stdin_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env
        )
        return result

    def test_cli_help(self):
        res = self.run_cli(["-h"])
        self.assertEqual(res.returncode, 0)
        self.assertIn("Usage: lyra-cli", res.stdout)

    def test_artist_lifecycle(self):
        # 1. Create Artist
        res = self.run_cli(["artist", "create", "--name", "Claude Debussy"])
        self.assertEqual(res.returncode, 0)
        
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 201)
        artist_id = data["data"]["id"]
        self.assertTrue(artist_id)
        
        # 2. Get Artist
        res_get = self.run_cli(["artist", "get", artist_id])
        self.assertEqual(res_get.returncode, 0)
        data_get = json.loads(res_get.stdout)
        self.assertEqual(data_get["code"], 200)
        self.assertEqual(data_get["data"]["name"], "Claude Debussy")

        # 3. Update Artist
        res_up = self.run_cli(["artist", "update", artist_id, "--name", "Debussy"])
        self.assertEqual(res_up.returncode, 0)
        
        res_get2 = self.run_cli(["artist", "get", artist_id])
        data_get2 = json.loads(res_get2.stdout)
        self.assertEqual(data_get2["data"]["name"], "Debussy")

    def test_track_lifecycle(self):
        res = self.run_cli(["track", "create", "--pcm-hash", "debussy_pcm", "--title", "La Mer", "--duration", "480"])
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 201)
        track_id = data["data"]["id"]
        
        # Get track
        res_get = self.run_cli(["track", "get", track_id])
        data_get = json.loads(res_get.stdout)
        self.assertEqual(data_get["code"], 200)
        self.assertEqual(data_get["data"]["title"], "La Mer")
        self.assertEqual(data_get["data"]["duration"], 480)

    def test_dispatch_direct(self):
        req = {
            "command": "CreateArtist",
            "params": {
                "name": "Maurice Ravel"
            }
        }
        res = self.run_cli(["dispatch", json.dumps(req)])
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 201)
        self.assertEqual(data["data"]["name"], "Maurice Ravel")

    def test_dispatch_stdin(self):
        req = {
            "command": "CreateArtist",
            "params": {
                "name": "Erik Satie"
            }
        }
        res = self.run_cli(["dispatch", "-"], stdin_data=json.dumps(req))
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 201)
        self.assertEqual(data["data"]["name"], "Erik Satie")

    def test_cli_missing_positional_id(self):
        res = self.run_cli(["artist", "update", "--name", "Wrong ID"])
        self.assertEqual(res.returncode, 1)
        self.assertIn("requires an <id> positional argument, but found flag", res.stderr)

    def test_cli_invalid_integer_format(self):
        res = self.run_cli(["track", "create", "--pcm-hash", "hash", "--duration", "not-a-number"])
        self.assertEqual(res.returncode, 1)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 400)
        self.assertEqual(data["error"]["type"], "InvalidValue")
        self.assertIn("Value of key 'duration' is not a expected type", data["error"]["message"])

    def test_cli_flag_consumed_as_value_prevention(self):
        res = self.run_cli(["artist", "create", "--name", "--spotify-id"])
        self.assertEqual(res.returncode, 1)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 400)
        self.assertEqual(data["error"]["type"], "MissingParameter")
        self.assertIn("Missing required field: 'name'", data["error"]["message"])

    def test_cli_no_args_exit_code(self):
        # When called without TTY and no args, it should exit with 1
        res = self.run_cli([])
        self.assertEqual(res.returncode, 1)

    def test_cli_underscore_hyphen_conversion(self):
        # Test that using underscores in option flags instead of hyphens works correctly
        # and that --name is mapped to --title
        res = self.run_cli(["track", "create", "--pcm_hash", "debussy_pcm_2", "--name", "La Mer 2"])
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 201)
        self.assertEqual(data["data"]["pcm_hash"], "debussy_pcm_2")
        self.assertEqual(data["data"]["title"], "La Mer 2")

    def test_cli_track_import(self):
        # Create a dummy WAV file
        import wave
        import struct
        wav_path = os.path.join(self.test_db_dir, "cli_import_test.wav")
        with wave.open(wav_path, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(44100)
            data = struct.pack('<h', 0)
            wav_file.writeframes(data)
            
        res = self.run_cli(["track", "import", wav_path])
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["code"], 200)
        self.assertEqual(data["data"]["title"], "cli_import_test")



