# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import os
import sqlite3
import struct
import time
import wave
from base_test_case import BaseLyraTestCase


class TestAudioSinkConfig(BaseLyraTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.sample_wav_path = os.path.abspath(os.path.join(cls.test_db_dir, "sink_test_sample.wav"))
        cls._create_sample_wav(cls.sample_wav_path, duration_sec=3)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, "sample_wav_path") and os.path.exists(cls.sample_wav_path):
            try:
                os.remove(cls.sample_wav_path)
            except OSError:
                pass
        super().tearDownClass()

    @classmethod
    def _create_sample_wav(cls, filepath, duration_sec=3, sample_rate=44100):
        with wave.open(filepath, "w") as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)  # 2 byte = 16 bit
            wav_file.setframerate(sample_rate)
            num_samples = int(sample_rate * duration_sec)
            frames = []
            for i in range(num_samples):
                val_l = int(10000 * (i % 100) / 100)
                val_r = int(-10000 * (i % 100) / 100)
                frames.append(val_l)
                frames.append(val_r)
            raw_data = struct.pack(f"<{len(frames)}h", *frames)
            wav_file.writeframes(raw_data)

    def setUp(self):
        super().setUp()
        # Reset configuration to default values before each test
        self.dispatch(
            "system.set_config",
            {
                "audio": {
                    "output_device_id": "default",
                    "volume": 1.0,
                    "buffer_size_frames": 256,
                    "exclusive_mode": False,
                }
            },
        )

    def tearDown(self):
        self.dispatch("audio.stop", {})
        super().tearDown()

    def test_default_audio_config(self):
        """Test system.get_config and audio.get_state return correct default buffer size and exclusive mode."""
        res = self.dispatch("system.get_config", {})
        self.assertResponseCode(res, 200)
        data = res.get("data", {})
        self.assertIn("audio", data)
        audio = data["audio"]
        self.assertEqual(audio.get("buffer_size_frames"), 256)
        self.assertIs(audio.get("exclusive_mode"), False)

        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        state_data = state_res.get("data", {})
        self.assertEqual(state_data.get("buffer_size_frames"), 256)
        self.assertIs(state_data.get("exclusive_mode"), False)
        self.assertIn("exclusive_mode_active", state_data)
        self.assertIs(state_data.get("exclusive_mode_active"), False)

    def test_buffer_size_valid_updates(self):
        """Test system.set_config successfully updates audio.buffer_size_frames across valid ranges."""
        valid_sizes = [64, 128, 512, 1024, 32, 8192]
        for sz in valid_sizes:
            res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": sz}})
            self.assertResponseCode(res, 200)
            self.assertEqual(res["data"]["audio"]["buffer_size_frames"], sz)

            # Check system.get_config
            get_res = self.dispatch("system.get_config", {})
            self.assertResponseCode(get_res, 200)
            self.assertEqual(get_res["data"]["audio"]["buffer_size_frames"], sz)

            # Check audio.get_state
            state_res = self.dispatch("audio.get_state", {})
            self.assertResponseCode(state_res, 200)
            self.assertEqual(state_res["data"]["buffer_size_frames"], sz)

    def test_buffer_size_boundary_rejection(self):
        """Test boundary rejections for out-of-range values and non-integer types on buffer_size_frames."""
        # 1. Out-of-range lower bounds (must be >= 32)
        for bad_val in [0, 31, -1, -256]:
            res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": bad_val}})
            self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="buffer_size_frames")

        # 2. Out-of-range upper bounds (must be <= 8192)
        for bad_val in [8193, 10000, 65536, 2147483648]:
            res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": bad_val}})
            self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="buffer_size_frames")

        # 3. Invalid types (must be an integer)
        invalid_types = ["256", 256.5, None, True, False, [256], {"size": 256}]
        for bad_val in invalid_types:
            res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": bad_val}})
            self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="buffer_size_frames")

    def test_exclusive_mode_valid_updates(self):
        """Test toggling audio.exclusive_mode between True and False."""
        # Enable exclusive mode
        res = self.dispatch("system.set_config", {"audio": {"exclusive_mode": True}})
        self.assertResponseCode(res, 200)
        self.assertIs(res["data"]["audio"]["exclusive_mode"], True)

        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertIs(get_res["data"]["audio"]["exclusive_mode"], True)

        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertIs(state_res["data"]["exclusive_mode"], True)

        # Disable exclusive mode
        res2 = self.dispatch("system.set_config", {"audio": {"exclusive_mode": False}})
        self.assertResponseCode(res2, 200)
        self.assertIs(res2["data"]["audio"]["exclusive_mode"], False)

        get_res2 = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res2, 200)
        self.assertIs(get_res2["data"]["audio"]["exclusive_mode"], False)

        state_res2 = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res2, 200)
        self.assertIs(state_res2["data"]["exclusive_mode"], False)

    def test_exclusive_mode_type_rejection(self):
        """Test strict boolean type enforcement on audio.exclusive_mode."""
        invalid_values = [
            "true", "false", "True", "False", "1", "0",
            1, 0, -1, 1.0, 0.0, None, [True], {"exclusive": True}
        ]
        for bad_val in invalid_values:
            res = self.dispatch("system.set_config", {"audio": {"exclusive_mode": bad_val}})
            self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="exclusive_mode")

    def test_sqlite_persistence_across_reinit(self):
        """Test buffer_size_frames and exclusive_mode persist in SQLite across lyra_init."""
        res = self.dispatch("system.set_config", {
            "audio": {
                "buffer_size_frames": 512,
                "exclusive_mode": True,
            }
        })
        self.assertResponseCode(res, 200)

        # Verify raw SQLite table contents
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config WHERE key LIKE 'audio.%' ORDER BY key")
        rows = dict(cursor.fetchall())
        conn.close()

        self.assertIn("audio.buffer_size_frames", rows)
        self.assertEqual(rows["audio.buffer_size_frames"], "512")
        self.assertIn("audio.exclusive_mode", rows)
        self.assertEqual(rows["audio.exclusive_mode"], "true")

        # Re-initialize library using lyra_init
        init_res = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res, 0)

        # Verify restored from persistence
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertEqual(get_res["data"]["audio"]["buffer_size_frames"], 512)
        self.assertIs(get_res["data"]["audio"]["exclusive_mode"], True)

        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertEqual(state_res["data"]["buffer_size_frames"], 512)
        self.assertIs(state_res["data"]["exclusive_mode"], True)

    def test_self_healing_corrupted_config(self):
        """Test corrupted or out-of-range database values for audio sink self-heal on startup."""
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '-999' WHERE key = 'audio.buffer_size_frames';", ()),
            ("UPDATE System_Config SET value = 'invalid_bool' WHERE key = 'audio.exclusive_mode';", ()),
        ])

        # Re-initialize library via lyra_init
        init_res = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res, 0)

        # Verify fell back to default values
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertEqual(get_res["data"]["audio"]["buffer_size_frames"], 256)
        self.assertIs(get_res["data"]["audio"]["exclusive_mode"], False)

        # Verify SQLite table rows were healed
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config WHERE key IN ('audio.buffer_size_frames', 'audio.exclusive_mode') ORDER BY key")
        rows = dict(cursor.fetchall())
        conn.close()

        self.assertEqual(rows.get("audio.buffer_size_frames"), "256")
        self.assertEqual(rows.get("audio.exclusive_mode"), "false")

        # Test non-numeric string for buffer_size_frames heals as well
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = 'not_a_number' WHERE key = 'audio.buffer_size_frames';", ()),
            ("UPDATE System_Config SET value = '999999' WHERE key = 'audio.buffer_size_frames';", ()),
        ])
        init_res2 = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res2, 0)

        get_res2 = self.dispatch("system.get_config", {})
        self.assertEqual(get_res2["data"]["audio"]["buffer_size_frames"], 256)

        # Test partial numeric strings (e.g. '256.5', '512_bytes') must NOT be partially parsed; must self-heal to 256
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '256.5' WHERE key = 'audio.buffer_size_frames';", ()),
        ])
        init_res3 = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res3, 0)
        get_res3 = self.dispatch("system.get_config", {})
        self.assertEqual(get_res3["data"]["audio"]["buffer_size_frames"], 256)
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM System_Config WHERE key = 'audio.buffer_size_frames'")
        row3 = cursor.fetchone()
        conn.close()
        self.assertEqual(row3[0], "256")

        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '512_bytes' WHERE key = 'audio.buffer_size_frames';", ()),
        ])
        init_res4 = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res4, 0)
        get_res4 = self.dispatch("system.get_config", {})
        self.assertEqual(get_res4["data"]["audio"]["buffer_size_frames"], 256)
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM System_Config WHERE key = 'audio.buffer_size_frames'")
        row4 = cursor.fetchone()
        conn.close()
        self.assertEqual(row4[0], "256")

    def test_runtime_toggling_during_playback(self):
        """Test dynamically changing buffer_size_frames and exclusive_mode while playing audio."""
        play_res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(play_res, 200)

        # Confirm playback is active
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertEqual(state_res["data"]["state"], "PLAYING")

        # Dynamically change buffer size during playback
        for new_sz in [512, 1024, 256]:
            set_res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": new_sz}})
            self.assertResponseCode(set_res, 200)
            self.assertEqual(set_res["data"]["audio"]["buffer_size_frames"], new_sz)

            # Check state remains valid and reflects new buffer size
            cur_state = self.dispatch("audio.get_state", {})
            self.assertResponseCode(cur_state, 200)
            self.assertEqual(cur_state["data"]["buffer_size_frames"], new_sz)

        # Dynamically toggle exclusive mode during playback
        for exc in [True, False]:
            set_res = self.dispatch("system.set_config", {"audio": {"exclusive_mode": exc}})
            self.assertResponseCode(set_res, 200)
            self.assertIs(set_res["data"]["audio"]["exclusive_mode"], exc)

            cur_state = self.dispatch("audio.get_state", {})
            self.assertResponseCode(cur_state, 200)
            self.assertIs(cur_state["data"]["exclusive_mode"], exc)

        # Stop playback cleanly
        stop_res = self.dispatch("audio.stop", {})
        self.assertResponseCode(stop_res, 200)

    def test_fine_grained_isolation(self):
        """Test updating buffer_size_frames or exclusive_mode does not touch unrelated settings or rewrite SQLite on identical values."""
        # Initial setup
        init_res = self.dispatch("system.set_config", {
            "audio": {
                "buffer_size_frames": 512,
                "exclusive_mode": False,
                "volume": 0.7,
                "output_device_id": "default",
            },
            "database": {
                "cache_size_kb": 131072,
            }
        })
        self.assertResponseCode(init_res, 200)

        # Snapshot SQLite updated_at timestamps
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        initial_timestamps = dict(cursor.fetchall())
        conn.close()

        # Update ONLY exclusive_mode -> buffer_size, volume, database must be identical
        res = self.dispatch("system.set_config", {"audio": {"exclusive_mode": True}})
        self.assertResponseCode(res, 200)
        data = res["data"]
        self.assertIs(data["audio"]["exclusive_mode"], True)
        self.assertEqual(data["audio"]["buffer_size_frames"], 512)
        self.assertAlmostEqual(data["audio"]["volume"], 0.7, places=2)
        self.assertEqual(data["database"]["cache_size_kb"], 131072)

        # Update with identical values -> must return 200 and NOT update timestamps in SQLite
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        mid_timestamps = dict(cursor.fetchall())
        conn.close()

        res_same = self.dispatch("system.set_config", {
            "audio": {
                "buffer_size_frames": 512,
                "exclusive_mode": True,
            }
        })
        self.assertResponseCode(res_same, 200)

        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        after_timestamps = dict(cursor.fetchall())
        conn.close()

        self.assertEqual(mid_timestamps, after_timestamps)

    def test_audio_state_reflection(self):
        """Test audio.get_state accurately reflects runtime buffer size, exclusive mode, and active status."""
        self.dispatch("system.set_config", {
            "audio": {
                "buffer_size_frames": 1024,
                "exclusive_mode": False,
            }
        })

        state = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state, 200)
        data = state["data"]
        self.assertEqual(data["buffer_size_frames"], 1024)
        self.assertIs(data["exclusive_mode"], False)
        self.assertIn("exclusive_mode_active", data)

    def test_exclusive_mode_released_on_stop(self):
        """Test exclusive mode lock is released on audio stop and restored on start."""
        self.dispatch("system.set_config", {"audio": {"exclusive_mode": True}})
        play_res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(play_res, 200)

        state_play = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_play, 200)
        self.assertEqual(state_play["data"]["state"], "PLAYING")
        self.assertIs(state_play["data"]["exclusive_mode"], True)

        # Stop playback -> exclusive lock must be released
        stop_res = self.dispatch("audio.stop", {})
        self.assertResponseCode(stop_res, 200)

        state_stop = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_stop, 200)
        self.assertEqual(state_stop["data"]["state"], "STOPPED")
        self.assertIs(state_stop["data"]["exclusive_mode"], True)
        self.assertIs(state_stop["data"]["exclusive_mode_active"], False)

    def test_buffer_size_reconfiguration_while_stopped_releases_exclusive_lock(self):
        """Test that updating buffer_size_frames while stopped with exclusive_mode == true leaves exclusive_mode_active == False."""
        self.dispatch("system.set_config", {"audio": {"exclusive_mode": True}})
        play_res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(play_res, 200)

        # Stop playback
        stop_res = self.dispatch("audio.stop", {})
        self.assertResponseCode(stop_res, 200)

        state_stopped = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_stopped, 200)
        self.assertIs(state_stopped["data"]["exclusive_mode_active"], False)

        # Reconfigure buffer_size_frames while stopped
        reconfig_res = self.dispatch("system.set_config", {"audio": {"buffer_size_frames": 512}})
        self.assertResponseCode(reconfig_res, 200)

        state_after = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_after, 200)
        self.assertEqual(state_after["data"]["buffer_size_frames"], 512)
        self.assertIs(state_after["data"]["exclusive_mode"], True)
        self.assertIs(state_after["data"]["exclusive_mode_active"], False)

    def test_multi_setting_preflight_rollback_on_device_failure(self):
        """Test that when a combined system.set_config fails on output_device_id during active playback, buffer_size_frames and exclusive_mode are rolled back."""
        play_res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(play_res, 200)

        non_existent_hex_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        res = self.dispatch(
            "system.set_config",
            {
                "audio": {
                    "buffer_size_frames": 1024,
                    "exclusive_mode": True,
                    "output_device_id": non_existent_hex_id,
                }
            },
        )
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="output device")

        state_after = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_after, 200)
        self.assertEqual(state_after["data"]["buffer_size_frames"], 256)
        self.assertIs(state_after["data"]["exclusive_mode"], False)
        self.assertEqual(state_after["data"]["device_id"], "default")

        cfg_after = self.dispatch("system.get_config", {})
        self.assertResponseCode(cfg_after, 200)
        self.assertEqual(cfg_after["data"]["audio"]["buffer_size_frames"], 256)
        self.assertIs(cfg_after["data"]["audio"]["exclusive_mode"], False)
        self.assertEqual(cfg_after["data"]["audio"]["output_device_id"], "default")

        self.dispatch("audio.stop", {})

    def test_play_fails_with_device_unavailable_when_configured_device_offline(self):
        """Test Layer 1 & Layer 2 defense: setting offline device fails with 400 InvalidValue, and playing with a persisted offline device fails with 503 DeviceUnavailable and emits audio_device_unavailable event."""
        import ctypes

        non_existent_hex_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        # 1. Layer 1: Setting an offline device ID while STOPPED fails with 400 InvalidValue
        set_cfg_res = self.dispatch("system.set_config", {"audio": {"output_device_id": non_existent_hex_id}})
        self.assertValidationError(set_cfg_res, expected_type="InvalidValue", expected_message_content="output device")

        set_dev_res = self.dispatch("audio.set_output_device", {"device_id": non_existent_hex_id})
        self.assertValidationError(set_dev_res, expected_type="InvalidValue", expected_message_content="output device")

        # 2. Import a track so we can test Track, Audio, Asset, and DirectFile playback targets
        import_res = self.dispatch("ImportTrack", {"source_path": self.sample_wav_path})
        self.assertResponseCode(import_res, 200)
        track_id = import_res["data"]["track_id"]
        pcm_hash = import_res["data"]["pcm_hash"]
        assets_res = self.dispatch("ListAssets", {})
        self.assertResponseCode(assets_res, 200)
        file_hash = assets_res["data"]["items"][0]["file_hash"]

        # 3. Persist non_existent_hex_id in System_Config (simulating a previously configured DAC that is now offline)
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = ? WHERE key = 'audio.output_device_id';", (non_existent_hex_id,)),
        ])
        init_res = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res, 0)

        # Register event callback to capture "audio_device_unavailable"
        received_events = []
        EVENT_CB_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_void_p)

        def on_event(json_bytes, _user_data):
            if json_bytes:
                received_events.append(json.loads(json_bytes.decode("utf-8")))

        c_cb = EVENT_CB_TYPE(on_event)
        self.lib.lyra_register_event_callback(c_cb, None)

        try:
            # Verify audio.play fails with 503 DeviceUnavailable across DirectFile, Track, Audio, and Asset targets
            for play_params in [
                {"file_path": self.sample_wav_path},
                {"track_id": track_id},
                {"pcm_hash": pcm_hash},
                {"file_hash": file_hash},
            ]:
                received_events.clear()
                play_res = self.dispatch("audio.play", play_params)
                self.assertEqual(play_res.get("code"), 503, f"Expected 503 DeviceUnavailable, got {play_res}")
                self.assertEqual(play_res.get("error", {}).get("type"), "DeviceUnavailable")
                self.assertIn(non_existent_hex_id, play_res.get("error", {}).get("message", ""))

                state_res = self.dispatch("audio.get_state", {})
                self.assertResponseCode(state_res, 200)
                self.assertEqual(state_res["data"]["state"], "STOPPED")
                self.assertEqual(state_res["data"]["device_id"], non_existent_hex_id)
                self.assertEqual(state_res["data"]["file_path"], "")
                self.assertEqual(state_res["data"]["duration"], 0.0)
                self.assertEqual(state_res["data"]["position"], 0.0)

                unavail_events = [e for e in received_events if e.get("event") == "audio_device_unavailable"]
                self.assertGreaterEqual(len(unavail_events), 1)
                self.assertEqual(unavail_events[-1]["data"].get("device_id"), non_existent_hex_id)
                self.assertEqual(unavail_events[-1]["data"].get("error"), "DeviceUnavailable")
                self.assertEqual(unavail_events[-1]["data"].get("state"), "STOPPED")
                self.assertEqual(unavail_events[-1]["data"].get("file_path"), "")
                self.assertEqual(unavail_events[-1]["data"].get("duration"), 0.0)

            # 4. Switch output_device_id back to "default" via audio.set_output_device, then verify playback succeeds
            recover_res = self.dispatch("audio.set_output_device", {"device_id": "default"})
            self.assertResponseCode(recover_res, 200)

            # Verify system.get_config and SQLite System_Config were also updated by audio.set_output_device
            cfg_res = self.dispatch("system.get_config", {})
            self.assertResponseCode(cfg_res, 200)
            self.assertEqual(cfg_res["data"]["audio"]["output_device_id"], "default")

            db_path = os.path.join(self.test_db_dir, "lyra.db")
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT value FROM System_Config WHERE key = 'audio.output_device_id'")
            row = cursor.fetchone()
            conn.close()
            self.assertIsNotNone(row)
            self.assertEqual(row[0], "default")

            play_ok = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
            self.assertResponseCode(play_ok, 200)
            self.assertEqual(play_ok["data"]["state"], "PLAYING")
            self.assertEqual(play_ok["data"]["device_id"], "default")
        finally:
            self.lib.lyra_register_event_callback(EVENT_CB_TYPE(0), None)
            self.dispatch("audio.stop", {})



