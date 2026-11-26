# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import concurrent.futures
import json
import os
import sqlite3
import struct
import time
import wave
from base_test_case import BaseLyraTestCase


class TestSystemConfig(BaseLyraTestCase):
    def setUp(self):
        super().setUp()
        # Reset configuration to default values before each test
        self.dispatch("system.set_config", {
            "database": {
                "cache_size_kb": 131072,
                "mmap_size_bytes": 536870912,
                "busy_timeout_ms": 30000,
                "wal_autocheckpoint": 1000,
            },
            "audio": {
                "output_device_id": "default",
                "volume": 1.0,
                "buffer_size_frames": 256,
                "exclusive_mode": False,
                "volume_mode": "fixed",
                "resampler_quality": "soxr_hq",
                "dsd_mode": "dop",
            },
            "ingestion": {
                "parallel_threads": 0,
                "mode": "full",
            },
        })

    def test_get_config_defaults(self):
        """Test system.get_config returns the expected default dictionary aligned with EngineConfig."""
        res = self.dispatch("system.get_config", {})
        self.assertResponseCode(res, 200)

        data = res.get("data", {})
        self.assertIn("storage", data)
        self.assertIn("database", data)
        self.assertIn("audio", data)
        self.assertIn("ingestion", data)

        # Storage subsystem
        self.assertEqual(
            os.path.normpath(data["storage"].get("storage_root")),
            os.path.normpath(self.test_db_dir),
        )
        self.assertEqual(
            os.path.normpath(data["storage"].get("database_path")),
            os.path.normpath(os.path.join(self.test_db_dir, "lyra.db")),
        )
        self.assertEqual(
            os.path.normpath(data["storage"].get("cas_objects_dir")),
            os.path.normpath(os.path.join(self.test_db_dir, "objects")),
        )

        # Database subsystem
        self.assertEqual(data["database"].get("cache_size_kb"), 131072)
        self.assertEqual(data["database"].get("mmap_size_bytes"), 536870912)
        self.assertEqual(data["database"].get("busy_timeout_ms"), 30000)
        self.assertEqual(data["database"].get("wal_autocheckpoint"), 1000)

        # Audio subsystem
        self.assertEqual(data["audio"].get("output_device_id"), "default")
        self.assertAlmostEqual(data["audio"].get("volume"), 1.0, places=2)
        self.assertEqual(data["audio"].get("volume_mode"), "fixed")
        self.assertEqual(data["audio"].get("resampler_quality"), "soxr_hq")
        self.assertEqual(data["audio"].get("dsd_mode"), "dop")

        # Ingestion subsystem
        self.assertEqual(data["ingestion"].get("parallel_threads"), 0)
        detected_cores = data["ingestion"].get("detected_cpu_cores")
        self.assertIsInstance(detected_cores, int)
        self.assertNotIsInstance(detected_cores, bool)
        self.assertGreaterEqual(detected_cores, 1)
        self.assertEqual(data["ingestion"].get("mode"), "full")

        # Anti-Phantom assertions: Ensure top-level phantom keys do not exist
        self.assertNotIn("dsd_mode", data)
        self.assertNotIn("resampler_quality", data)
        self.assertNotIn("volume_mode", data)

        # Ensure no restart_required flag
        self.assertNotIn("restart_required", data)
        self.assertNotIn("restart_required", res)

    def test_set_config_partial_updates(self):
        """Test system.set_config supports partial updates across subsystems."""
        # 1. Update only audio volume
        res = self.dispatch("system.set_config", {"audio": {"volume": 0.8}})
        self.assertResponseCode(res, 200)
        data = res.get("data", {})
        self.assertAlmostEqual(data["audio"]["volume"], 0.8, places=2)
        # Database settings must remain untouched
        self.assertEqual(data["database"]["cache_size_kb"], 131072)
        self.assertEqual(data["database"]["mmap_size_bytes"], 536870912)

        # 2. Update only database cache_size_kb
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 262144}})
        self.assertResponseCode(res, 200)
        data = res.get("data", {})
        self.assertEqual(data["database"]["cache_size_kb"], 262144)
        # Audio settings must remain preserved
        self.assertAlmostEqual(data["audio"]["volume"], 0.8, places=2)

        # 3. Update multiple parameters across database and audio
        update_payload = {
            "database": {
                "mmap_size_bytes": 1073741824,
                "busy_timeout_ms": 60000,
                "wal_autocheckpoint": 2000,
            },
            "audio": {
                "volume": 0.5,
                "output_device_id": "default",
            },
        }
        res = self.dispatch("system.set_config", update_payload)
        self.assertResponseCode(res, 200)
        data = res.get("data", {})
        self.assertEqual(data["database"]["cache_size_kb"], 262144)
        self.assertEqual(data["database"]["mmap_size_bytes"], 1073741824)
        self.assertEqual(data["database"]["busy_timeout_ms"], 60000)
        self.assertEqual(data["database"]["wal_autocheckpoint"], 2000)
        self.assertAlmostEqual(data["audio"]["volume"], 0.5, places=2)
        self.assertEqual(data["audio"]["output_device_id"], "default")

        # 4. Verify system.get_config reflects all modified values
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        get_data = get_res.get("data", {})
        self.assertEqual(get_data["database"]["cache_size_kb"], 262144)
        self.assertEqual(get_data["database"]["mmap_size_bytes"], 1073741824)
        self.assertEqual(get_data["database"]["busy_timeout_ms"], 60000)
        self.assertEqual(get_data["database"]["wal_autocheckpoint"], 2000)
        self.assertAlmostEqual(get_data["audio"]["volume"], 0.5, places=2)

    def test_persistence_across_reinit(self):
        """Test configuration persists across database re-initialization (lyra_init)."""
        # Set custom configuration
        res = self.dispatch("system.set_config", {
            "database": {
                "cache_size_kb": 524288,
                "busy_timeout_ms": 45000,
            },
            "audio": {
                "volume": 0.65,
            },
        })
        self.assertResponseCode(res, 200)

        # Verify raw SQLite table contents
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config ORDER BY key")
        rows = dict(cursor.fetchall())
        conn.close()

        self.assertIn("database.cache_size_kb", rows)
        self.assertEqual(rows["database.cache_size_kb"], "524288")
        self.assertEqual(rows["database.busy_timeout_ms"], "45000")
        self.assertAlmostEqual(float(rows["audio.volume"]), 0.65, places=2)

        # Re-initialize library using lyra_init on the same directory
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        # Fetch config again and assert values were restored from persistence
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        data = get_res.get("data", {})
        self.assertEqual(data["database"]["cache_size_kb"], 524288)
        self.assertEqual(data["database"]["busy_timeout_ms"], 45000)
        self.assertAlmostEqual(data["audio"]["volume"], 0.65, places=2)

    def test_boundary_validation_numeric_ranges(self):
        """Test boundary limits strictly reject out-of-range values and accept edge values."""
        # 1. cache_size_kb: 1024 <= cache_size_kb <= 4194304 (4 GiB)
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 1023}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": -1}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 4194305}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 1024}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["cache_size_kb"], 1024)

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 4194304}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["cache_size_kb"], 4194304)

        # 6. ingestion.parallel_threads: 0 <= parallel_threads <= 1024
        res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": -1}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="parallel_threads")

        res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": 1025}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="parallel_threads")

        res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": 2147483648}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="parallel_threads")

        for wraparound_val in (2**63, 2**64 - 1):
            res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": wraparound_val}})
            self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="parallel_threads")

        for valid_threads in (0, 1, 1024):
            res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": valid_threads}})
            self.assertResponseCode(res, 200)
            self.assertEqual(res["data"]["ingestion"]["parallel_threads"], valid_threads)

        # 2. mmap_size_bytes >= 0
        res = self.dispatch("system.set_config", {"database": {"mmap_size_bytes": -1}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="mmap_size_bytes")

        res = self.dispatch("system.set_config", {"database": {"mmap_size_bytes": 0}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["mmap_size_bytes"], 0)

        # 3. busy_timeout_ms >= 1000
        res = self.dispatch("system.set_config", {"database": {"busy_timeout_ms": 999}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="busy_timeout_ms")

        res = self.dispatch("system.set_config", {"database": {"busy_timeout_ms": 1000}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["busy_timeout_ms"], 1000)

        # 4. wal_autocheckpoint >= 10
        res = self.dispatch("system.set_config", {"database": {"wal_autocheckpoint": 9}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="wal_autocheckpoint")

        res = self.dispatch("system.set_config", {"database": {"wal_autocheckpoint": 10}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["wal_autocheckpoint"], 10)

        # 5. volume: 0.0 <= volume <= 1.0
        res = self.dispatch("system.set_config", {"audio": {"volume": -0.01}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="volume")

        res = self.dispatch("system.set_config", {"audio": {"volume": 1.01}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="volume")

        res = self.dispatch("system.set_config", {"audio": {"volume": 0.0}})
        self.assertResponseCode(res, 200)
        self.assertAlmostEqual(res["data"]["audio"]["volume"], 0.0, places=2)

        res = self.dispatch("system.set_config", {"audio": {"volume": 1.0}})
        self.assertResponseCode(res, 200)
        self.assertAlmostEqual(res["data"]["audio"]["volume"], 1.0, places=2)

    def test_boundary_validation_types_and_formats(self):
        """Test strict type validation and structural boundary defense."""
        # Non-object params
        res = self.raw_dispatch({"command": "system.set_config", "params": "invalid_string"})
        self.assertValidationError(res, expected_type="InvalidCommandFormat")

        res = self.raw_dispatch({"command": "system.set_config", "params": [1, 2, 3]})
        self.assertValidationError(res, expected_type="InvalidCommandFormat")

        # Empty params object
        res = self.raw_dispatch({"command": "system.set_config", "params": {}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Empty category object
        res = self.raw_dispatch({"command": "system.set_config", "params": {"database": {}}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Non-integer for cache_size_kb
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": "invalid"}})
        self.assertValidationError(res, expected_type="InvalidValue")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 12.34}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Non-number for volume
        res = self.dispatch("system.set_config", {"audio": {"volume": "loud"}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Non-string for output_device_id
        res = self.dispatch("system.set_config", {"audio": {"output_device_id": 12345}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Empty string for output_device_id
        res = self.dispatch("system.set_config", {"audio": {"output_device_id": ""}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Explicit null values fail fast
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": None}})
        self.assertValidationError(res, expected_type="InvalidValue")

        res = self.dispatch("system.set_config", {"audio": {"volume": None}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Upper bound checks for integer parameters (> INT_MAX)
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 2147483648}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"busy_timeout_ms": 2147483648}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="busy_timeout_ms")

        res = self.dispatch("system.set_config", {"database": {"wal_autocheckpoint": 2147483648}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="wal_autocheckpoint")

        # Upper bound check for mmap_size_bytes (> 100 GB)
        res = self.dispatch("system.set_config", {"database": {"mmap_size_bytes": 10**15}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="mmap_size_bytes")

        # Bogus output device ID rejection
        res = self.dispatch("system.set_config", {"audio": {"output_device_id": "bogus_device_xyz"}})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="output_device_id")

    def test_anti_phantom_and_read_only_protection(self):
        """Test anti-phantom defense rejecting non-existent subsystems and guarding read-only fields."""
        # Top-level phantom category
        res = self.dispatch("system.set_config", {"dsd_mode": "native"})
        self.assertValidationError(res, expected_type="InvalidValue")

        res = self.dispatch("system.set_config", {"ingestion": {"auto_scan": True}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Nested phantom key
        res = self.dispatch("system.set_config", {"database": {"resampler_quality": "vhq"}})
        self.assertValidationError(res, expected_type="InvalidValue")

        res = self.dispatch("system.set_config", {"audio": {"volume_mode": "replaygain"}})
        self.assertValidationError(res, expected_type="InvalidValue")

        # Attempting to change read-only storage_root
        res = self.dispatch("system.set_config", {"storage": {"storage_root": "/malicious/override"}})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="storage_root")

        # Passing identical storage_root alongside other changes is accepted or ignored
        res = self.dispatch("system.set_config", {
            "storage": {"storage_root": os.path.abspath(self.test_db_dir)},
            "audio": {"volume": 0.9}
        })
        self.assertResponseCode(res, 200)
        self.assertAlmostEqual(res["data"]["audio"]["volume"], 0.9, places=2)

    def test_audio_engine_state_synchronization(self):
        """Test system.get_config synchronizes live state from AudioEngine."""
        # 1. Update volume via audio.set_volume
        res = self.dispatch("audio.set_volume", {"volume": 0.4})
        self.assertResponseCode(res, 200)

        # 2. Check system.get_config reflects the new volume
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertAlmostEqual(get_res["data"]["audio"]["volume"], 0.4, places=2)

        # 3. Update volume via system.set_config
        set_res = self.dispatch("system.set_config", {"audio": {"volume": 0.75}})
        self.assertResponseCode(set_res, 200)

        # 4. Check audio.get_state reflects the new volume
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertAlmostEqual(state_res["data"]["volume"], 0.75, places=2)

    def test_database_corruption_self_healing_on_init(self):
        """Test corrupted or out-of-range database values self-heal on startup."""
        # Directly inject corrupted/out-of-range values into System_Config table
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '-999' WHERE key = 'database.cache_size_kb';", ()),
            ("UPDATE System_Config SET value = '-1' WHERE key = 'database.mmap_size_bytes';", ()),
            ("UPDATE System_Config SET value = '99' WHERE key = 'database.busy_timeout_ms';", ()),
            ("UPDATE System_Config SET value = '1' WHERE key = 'database.wal_autocheckpoint';", ()),
            ("UPDATE System_Config SET value = 'NaN' WHERE key = 'audio.volume';", ()),
            ("UPDATE System_Config SET value = '' WHERE key = 'audio.output_device_id';", ()),
        ])

        # Re-initialize library via lyra_init
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        # Verify system.get_config fell back to default values
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        data = get_res.get("data", {})
        self.assertEqual(data["database"]["cache_size_kb"], 131072)
        self.assertEqual(data["database"]["mmap_size_bytes"], 536870912)
        self.assertEqual(data["database"]["busy_timeout_ms"], 30000)
        self.assertEqual(data["database"]["wal_autocheckpoint"], 1000)
        self.assertAlmostEqual(data["audio"]["volume"], 1.0, places=2)
        self.assertEqual(data["audio"]["output_device_id"], "default")

        # Verify raw SQLite table contents were self-healed
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config ORDER BY key")
        rows = dict(cursor.fetchall())
        conn.close()

        self.assertEqual(rows["database.cache_size_kb"], "131072")
        self.assertEqual(rows["database.mmap_size_bytes"], "536870912")
        self.assertEqual(rows["database.busy_timeout_ms"], "30000")
        self.assertEqual(rows["database.wal_autocheckpoint"], "1000")
        self.assertAlmostEqual(float(rows["audio.volume"]), 1.0, places=2)
        self.assertEqual(rows["audio.output_device_id"], "default")

    def test_output_device_id_validation_and_offline_persistence(self):
        """Test offline 64-hex device ID is rejected at set time (Layer 1) but retained across re-init if previously persisted."""
        valid_hex_device_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        # a) Layer 1: system.set_config and audio.set_output_device reject offline 64-hex device ID even when STOPPED
        res = self.dispatch("system.set_config", {"audio": {"output_device_id": valid_hex_device_id}})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="output device")

        dev_res = self.dispatch("audio.set_output_device", {"device_id": valid_hex_device_id})
        self.assertValidationError(dev_res, expected_type="InvalidValue", expected_message_content="output device")

        # Verify get_config remains "default"
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertEqual(get_res["data"]["audio"]["output_device_id"], "default")

        # b) When a valid 64-hex device ID was previously persisted in System_Config (e.g. DAC saved when online, now unplugged),
        # reinitializing the database retains the user's saved device preference in get_config and audio.get_state
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = ? WHERE key = 'audio.output_device_id';", (valid_hex_device_id,)),
        ])
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        get_res2 = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res2, 200)
        self.assertEqual(get_res2["data"]["audio"]["output_device_id"], valid_hex_device_id)

        state_res2 = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res2, 200)
        self.assertEqual(state_res2["data"]["device_id"], valid_hex_device_id)

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM System_Config WHERE key = 'audio.output_device_id'")
        row = cursor.fetchone()
        conn.close()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], valid_hex_device_id)

        # Ensure bogus device is still rejected with InvalidValue (code 400)
        bad_res = self.dispatch("system.set_config", {"audio": {"output_device_id": "bogus_device_xyz"}})
        self.assertValidationError(bad_res, expected_type="InvalidValue", expected_message_content="output_device_id")

        # Empty/corrupted empty values in DB are still self-healed to "default" on re-init
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '' WHERE key = 'audio.output_device_id';", ()),
        ])
        init_res2 = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res2, 0)

        get_res3 = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res3, 200)
        self.assertEqual(get_res3["data"]["audio"]["output_device_id"], "default")

        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM System_Config WHERE key = 'audio.output_device_id'")
        row = cursor.fetchone()
        conn.close()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "default")

    def test_granular_subsystem_settings_application(self):
        """Test granular settings application updates only the target subsystem without side effects."""
        # 1. Update only audio volume
        res = self.dispatch("system.set_config", {"audio": {"volume": 0.42}})
        self.assertResponseCode(res, 200)
        self.assertAlmostEqual(res["data"]["audio"]["volume"], 0.42, places=2)

        # Verify AudioEngine live state changed
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertAlmostEqual(state_res["data"]["volume"], 0.42, places=2)

        # Verify database settings remained untouched
        self.assertEqual(res["data"]["database"]["cache_size_kb"], 131072)
        self.assertEqual(res["data"]["database"]["busy_timeout_ms"], 30000)

        # 2. Update only database cache_size_kb
        res2 = self.dispatch("system.set_config", {"database": {"cache_size_kb": 65536}})
        self.assertResponseCode(res2, 200)
        self.assertEqual(res2["data"]["database"]["cache_size_kb"], 65536)

        # Audio settings must remain preserved
        self.assertAlmostEqual(res2["data"]["audio"]["volume"], 0.42, places=2)
        state_res2 = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res2, 200)
        self.assertAlmostEqual(state_res2["data"]["volume"], 0.42, places=2)

    def test_idempotent_no_net_change_and_same_values(self):
        """Test re-setting identical values returns HTTP 200 without writing to SQLite."""
        # Initial config state
        init_res = self.dispatch("system.set_config", {
            "database": {
                "cache_size_kb": 262144,
                "busy_timeout_ms": 15000,
            },
            "audio": {
                "volume": 0.6,
            }
        })
        self.assertResponseCode(init_res, 200)

        # Snapshot current row timestamps in System_Config
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        initial_timestamps = dict(cursor.fetchall())
        conn.close()

        # Re-set exact same values (partial database + audio)
        res_same = self.dispatch("system.set_config", {
            "database": {
                "cache_size_kb": 262144,
                "busy_timeout_ms": 15000,
            },
            "audio": {
                "volume": 0.6,
            }
        })
        self.assertResponseCode(res_same, 200)
        self.assertEqual(res_same["data"]["database"]["cache_size_kb"], 262144)
        self.assertEqual(res_same["data"]["database"]["busy_timeout_ms"], 15000)
        self.assertAlmostEqual(res_same["data"]["audio"]["volume"], 0.6, places=2)

        # Timestamps must NOT have changed because no DB write should occur on identical values
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        after_timestamps = dict(cursor.fetchall())
        conn.close()
        self.assertEqual(initial_timestamps, after_timestamps)

        # Re-set valid identical storage_root alone returns 200 with full config
        res_storage = self.dispatch("system.set_config", {
            "storage": {
                "storage_root": os.path.abspath(self.test_db_dir),
            }
        })
        self.assertResponseCode(res_storage, 200)
        self.assertEqual(
            os.path.normpath(res_storage["data"]["storage"]["storage_root"]),
            os.path.normpath(self.test_db_dir),
        )
        self.assertEqual(res_storage["data"]["database"]["cache_size_kb"], 262144)
        self.assertAlmostEqual(res_storage["data"]["audio"]["volume"], 0.6, places=2)

    def test_fine_grained_per_key_isolation(self):
        """Test fine-grained isolation: setting only audio.volume doesn't affect output_device_id and vice-versa."""
        valid_dev = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = ? WHERE key = 'audio.output_device_id';", (valid_dev,)),
            ("UPDATE System_Config SET value = '0.45' WHERE key = 'audio.volume';", ()),
        ])
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        get_init = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_init, 200)
        self.assertEqual(get_init["data"]["audio"]["output_device_id"], valid_dev)
        self.assertAlmostEqual(get_init["data"]["audio"]["volume"], 0.45, places=2)

        # Update ONLY volume - output_device_id must remain valid_dev
        vol_res = self.dispatch("system.set_config", {"audio": {"volume": 0.85}})
        self.assertResponseCode(vol_res, 200)
        self.assertAlmostEqual(vol_res["data"]["audio"]["volume"], 0.85, places=2)
        self.assertEqual(vol_res["data"]["audio"]["output_device_id"], valid_dev)

        # Verify live AudioEngine state
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertAlmostEqual(state_res["data"]["volume"], 0.85, places=2)
        self.assertEqual(state_res["data"]["device_id"], valid_dev)

        # Update ONLY output_device_id to "default" - volume must remain 0.85
        dev_res = self.dispatch("system.set_config", {"audio": {"output_device_id": "default"}})
        self.assertResponseCode(dev_res, 200)
        self.assertEqual(dev_res["data"]["audio"]["output_device_id"], "default")
        self.assertAlmostEqual(dev_res["data"]["audio"]["volume"], 0.85, places=2)

        # Database settings were never touched throughout
        self.assertEqual(dev_res["data"]["database"]["cache_size_kb"], 131072)
        self.assertEqual(dev_res["data"]["database"]["mmap_size_bytes"], 536870912)

    def test_database_missing_row_self_healing_on_init(self):
        """Test completely missing rows in System_Config are restored with default values upon lyra_init."""
        # Directly delete keys from System_Config
        self.execute_raw_sqls([
            ("DELETE FROM System_Config WHERE key = 'database.cache_size_kb';", ()),
            ("DELETE FROM System_Config WHERE key = 'audio.volume';", ()),
        ])

        # Verify raw SQLite table no longer contains those keys
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key FROM System_Config WHERE key IN ('database.cache_size_kb', 'audio.volume')")
        self.assertEqual(len(cursor.fetchall()), 0)
        conn.close()

        # Re-initialize library via lyra_init
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        # Verify system.get_config returns default values
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        data = get_res.get("data", {})
        self.assertEqual(data["database"]["cache_size_kb"], 131072)
        self.assertAlmostEqual(data["audio"]["volume"], 1.0, places=2)

        # Verify rows were re-inserted into System_Config table
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config WHERE key IN ('database.cache_size_kb', 'audio.volume')")
        rows = dict(cursor.fetchall())
        conn.close()

        self.assertIn("database.cache_size_kb", rows)
        self.assertEqual(rows["database.cache_size_kb"], "131072")
        self.assertIn("audio.volume", rows)
        self.assertAlmostEqual(float(rows["audio.volume"]), 1.0, places=2)

    def test_concurrent_multithreaded_set_config(self):
        """Test concurrent/multithreaded calls to system.set_config without race conditions or DB desync."""
        errors = []
        volumes = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        cache_sizes = [131072, 262144, 524288, 65536, 1048576]
        busy_timeouts = [10000, 20000, 30000, 40000, 50000]

        def worker(thread_idx):
            for i in range(15):
                vol = volumes[(thread_idx + i) % len(volumes)]
                cache = cache_sizes[(thread_idx + i) % len(cache_sizes)]
                timeout = busy_timeouts[(thread_idx + i) % len(busy_timeouts)]
                payload = {
                    "database": {
                        "cache_size_kb": cache,
                        "busy_timeout_ms": timeout,
                    },
                    "audio": {
                        "volume": vol,
                    }
                }
                res = self.dispatch("system.set_config", payload)
                if res.get("code") != 200:
                    errors.append(f"Thread {thread_idx} iter {i} failed: {res}")

        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(worker, idx) for idx in range(8)]
            concurrent.futures.wait(futures)

        self.assertEqual(len(errors), 0, f"Concurrent updates failed: {errors}")

        # Check final state consistency: DB values must match get_config values
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        data = get_res.get("data", {})

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config")
        db_rows = dict(cursor.fetchall())
        conn.close()

        self.assertEqual(int(db_rows["database.cache_size_kb"]), data["database"]["cache_size_kb"])
        self.assertEqual(int(db_rows["database.busy_timeout_ms"]), data["database"]["busy_timeout_ms"])
        self.assertAlmostEqual(float(db_rows["audio.volume"]), data["audio"]["volume"], places=2)

    def test_storage_root_type_validation_error(self):
        """Test non-string storage_root is rejected by generic type validator."""
        res = self.dispatch("system.set_config", {"storage": {"storage_root": 12345}})
        self.assertValidationError(res, expected_type="InvalidValue")

        res2 = self.dispatch("system.set_config", {"storage": {"storage_root": ["/path"]}})
        self.assertValidationError(res2, expected_type="InvalidValue")

    def test_multi_setting_table_driven_preflight_lifo_rollback_on_hardware_failure(self):
        """Test that when multi-setting configuration fails during preflight, previously executed preflights are rolled back in LIFO order."""
        non_existent_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        payload = {
            "audio": {
                "buffer_size_frames": 512,
                "exclusive_mode": True,
                "output_device_id": non_existent_hex,
            }
        }
        res = self.dispatch("system.set_config", payload)
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="output device")

        # Verify state in AudioEngine (hardware) remains default/rolled-back
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertEqual(state_res["data"]["buffer_size_frames"], 256)
        self.assertIs(state_res["data"]["exclusive_mode"], False)
        self.assertEqual(state_res["data"]["device_id"], "default")

        # Verify ConfigurationService memory state
        cfg_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(cfg_res, 200)
        self.assertEqual(cfg_res["data"]["audio"]["buffer_size_frames"], 256)
        self.assertIs(cfg_res["data"]["audio"]["exclusive_mode"], False)
        self.assertEqual(cfg_res["data"]["audio"]["output_device_id"], "default")

        # Verify SQLite DB System_Config
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM System_Config WHERE key LIKE 'audio.%'")
        rows = dict(cursor.fetchall())
        conn.close()
        self.assertEqual(rows.get("audio.buffer_size_frames", "256"), "256")
        self.assertEqual(rows.get("audio.exclusive_mode", "false"), "false")
        self.assertEqual(rows.get("audio.output_device_id", "default"), "default")

    def test_table_driven_preflight_lifo_rollback_on_database_failure(self):
        """Test that when preflight succeeds on hardware but SQLite commit fails, all preflights are rolled back in LIFO order."""
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        # Create triggers to force SQLite transaction failure upon System_Config insert or update
        cursor.execute("CREATE TRIGGER fail_system_config_insert BEFORE INSERT ON System_Config BEGIN SELECT RAISE(ABORT, 'Simulated DB failure'); END;")
        cursor.execute("CREATE TRIGGER fail_system_config_update BEFORE UPDATE ON System_Config BEGIN SELECT RAISE(ABORT, 'Simulated DB failure'); END;")
        conn.commit()
        conn.close()

        try:
            payload = {
                "audio": {
                    "buffer_size_frames": 512,
                    "exclusive_mode": True,
                }
            }
            res = self.dispatch("system.set_config", payload)
            # Response should indicate error due to DB transaction failure
            self.assertResponseCode(res, 500)
            self.assertEqual(res["error"]["type"], "DatabaseError")

            # Assert hardware state was cleanly rolled back via rollback_stack in LIFO order
            state_res = self.dispatch("audio.get_state", {})
            self.assertResponseCode(state_res, 200)
            self.assertEqual(state_res["data"]["buffer_size_frames"], 256)
            self.assertIs(state_res["data"]["exclusive_mode"], False)

            # Assert memory state remains 256 and False
            cfg_res = self.dispatch("system.get_config", {})
            self.assertResponseCode(cfg_res, 200)
            self.assertEqual(cfg_res["data"]["audio"]["buffer_size_frames"], 256)
            self.assertIs(cfg_res["data"]["audio"]["exclusive_mode"], False)

        finally:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("DROP TRIGGER IF EXISTS fail_system_config_insert;")
            cursor.execute("DROP TRIGGER IF EXISTS fail_system_config_update;")
            conn.commit()
            conn.close()

    def test_lyra_deinit_and_reinit_lifecycle(self):
        """Test lyra_deinit cleans up state, returns typed 400 error on dispatch, is idempotent, and reinit succeeds."""
        # 1. lyra_deinit returns 0
        deinit_res = self.lib.lyra_deinit()
        self.assertEqual(deinit_res, 0)

        # 2. Dispatching while deinitialized returns code == 400 with error.type present
        res = self.dispatch("system.get_config", {})
        self.assertResponseCode(res, 400)
        self.assertIn("error", res)
        self.assertIn("type", res["error"])
        self.assertEqual(res["error"]["type"], "InvalidCommandFormat")

        # 3. Calling lyra_deinit a second time is idempotent and returns 0
        deinit_res2 = self.lib.lyra_deinit()
        self.assertEqual(deinit_res2, 0)

        # 4. Re-initialize library to restore environment for subsequent tests
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        # Verify router is restored
        cfg_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(cfg_res, 200)

    def _generate_wav_file(self, filename, duration_sec=0.5, sample_rate=44100, amplitude=12000):
        import math
        path = os.path.join(self.test_db_dir, filename)
        num_frames = int(sample_rate * duration_sec)
        with wave.open(path, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            samples = []
            freq = 220.0 + (amplitude % 500)
            for i in range(num_frames):
                val = int(amplitude * math.sin(2.0 * math.pi * freq * i / sample_rate))
                samples.append(val)
                samples.append(val)
            wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        return path

    def test_ui_engine_config_save_payload_contract(self):
        """Test system.set_config accepts the full EngineConfig.toSavePayload() structure and persists across reinit."""
        # Pre-set a custom volume to ensure toSavePayload() (which omits audio.volume) preserves it
        vol_res = self.dispatch("system.set_config", {"audio": {"volume": 0.42}})
        self.assertResponseCode(vol_res, 200)

        save_payload = {
            "database": {
                "cache_size_kb": 262144,
                "mmap_size_bytes": 1073741824,
                "busy_timeout_ms": 45000,
                "wal_autocheckpoint": 2000,
            },
            "audio": {
                "output_device_id": "default",
                "buffer_size_frames": 512,
                "exclusive_mode": True,
                "volume_mode": "log",
                "resampler_quality": "sinc_medium",
                "dsd_mode": "pcm_transcode",
            },
            "ingestion": {
                "parallel_threads": 12,
                "mode": "fast",
            },
        }
        res = self.dispatch("system.set_config", save_payload)
        self.assertResponseCode(res, 200)
        data = res.get("data", {})

        # Verify read-only fields remain present in response
        self.assertEqual(
            os.path.normpath(data["storage"]["database_path"]),
            os.path.normpath(os.path.join(self.test_db_dir, "lyra.db")),
        )
        self.assertEqual(
            os.path.normpath(data["storage"]["cas_objects_dir"]),
            os.path.normpath(os.path.join(self.test_db_dir, "objects")),
        )
        self.assertGreaterEqual(data["ingestion"]["detected_cpu_cores"], 1)

        # Verify updated values & preserved volume
        self.assertEqual(data["database"]["cache_size_kb"], 262144)
        self.assertEqual(data["database"]["mmap_size_bytes"], 1073741824)
        self.assertEqual(data["database"]["busy_timeout_ms"], 45000)
        self.assertEqual(data["database"]["wal_autocheckpoint"], 2000)
        self.assertAlmostEqual(data["audio"]["volume"], 0.42, places=2)
        self.assertEqual(data["audio"]["buffer_size_frames"], 512)
        self.assertIs(data["audio"]["exclusive_mode"], True)
        self.assertEqual(data["audio"]["volume_mode"], "log")
        self.assertEqual(data["audio"]["resampler_quality"], "sinc_medium")
        self.assertEqual(data["audio"]["dsd_mode"], "pcm_transcode")
        self.assertEqual(data["ingestion"]["parallel_threads"], 12)
        self.assertEqual(data["ingestion"]["mode"], "fast")

        # Verify persistence in SQLite and across lyra_init
        init_res = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res, 0)

        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        restored = get_res.get("data", {})
        self.assertAlmostEqual(restored["audio"]["volume"], 0.42, places=2)
        self.assertEqual(restored["audio"]["volume_mode"], "log")
        self.assertEqual(restored["audio"]["resampler_quality"], "sinc_medium")
        self.assertEqual(restored["audio"]["dsd_mode"], "pcm_transcode")
        self.assertEqual(restored["ingestion"]["parallel_threads"], 12)
        self.assertEqual(restored["ingestion"]["mode"], "fast")

    def test_audio_and_ingestion_enum_validation(self):
        """Test valid enum transitions and strict rejection of invalid enum values and types."""
        enum_cases = [
            ("audio", "volume_mode", ["linear", "log", "fixed"],
             ["", "LINEAR", "bit_perfect_lock_0db", "logarithmic_db", "bitperfect_lock_0db", "replaygain", 1, True, None, ["linear"]]),
            ("audio", "resampler_quality", ["native", "sinc_medium", "soxr_hq"],
             ["", "NATIVE", "vhq", "soxr_vhq", 2, False, None, {"q": "native"}]),
            ("audio", "dsd_mode", ["dop", "pcm_transcode"],
             ["", "DOP", "native", "dsd_native", 0, True, None, ["dop"]]),
            ("ingestion", "mode", ["fast", "full"],
             ["", "FAST", "FULL", "partial", 1, False, None, []]),
        ]

        for section, key, valid_values, invalid_values in enum_cases:
            for val in valid_values:
                res = self.dispatch("system.set_config", {section: {key: val}})
                self.assertResponseCode(res, 200)
                self.assertEqual(res["data"][section][key], val)

                get_res = self.dispatch("system.get_config", {})
                self.assertResponseCode(get_res, 200)
                self.assertEqual(get_res["data"][section][key], val)

            last_valid = valid_values[-1]
            for bad in invalid_values:
                err_res = self.dispatch("system.set_config", {section: {key: bad}})
                self.assertValidationError(err_res, expected_type="InvalidValue", expected_message_content=key)
                # Ensure state did not mutate on failure
                after_res = self.dispatch("system.get_config", {})
                self.assertEqual(after_res["data"][section][key], last_valid)

    def test_parallel_threads_type_validation(self):
        """Test strict integer type validation for ingestion.parallel_threads."""
        for bad_val in ["4", 2.5, True, False, None, [4], {"threads": 4}]:
            res = self.dispatch("system.set_config", {"ingestion": {"parallel_threads": bad_val}})
            self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="parallel_threads")

    def test_read_only_keys_strict_rejection(self):
        """Test storage.database_path, storage.cas_objects_dir, and ingestion.detected_cpu_cores strictly reject any write."""
        cfg = self.dispatch("system.get_config", {})
        self.assertResponseCode(cfg, 200)
        cur_db_path = cfg["data"]["storage"]["database_path"]
        cur_cas_dir = cfg["data"]["storage"]["cas_objects_dir"]
        cur_cores = cfg["data"]["ingestion"]["detected_cpu_cores"]

        read_only_cases = [
            ("storage", "database_path", "/tmp/evil.db", cur_db_path, 123),
            ("storage", "cas_objects_dir", "/tmp/evil_objects", cur_cas_dir, False),
            ("ingestion", "detected_cpu_cores", cur_cores + 1, cur_cores, "16"),
        ]

        for section, key, diff_val, same_val, wrong_type_val in read_only_cases:
            for candidate in (diff_val, same_val, wrong_type_val):
                res = self.dispatch("system.set_config", {section: {key: candidate}})
                self.assertValidationError(res, expected_type="InvalidValue", expected_message_content=key)

            # Mixed payload with a valid mutable key must reject atomically without mutating the valid key
            mixed_res = self.dispatch("system.set_config", {
                section: {key: same_val},
                "audio": {"volume": 0.33},
            })
            self.assertValidationError(mixed_res, expected_type="InvalidValue", expected_message_content=key)
            check_res = self.dispatch("system.get_config", {})
            self.assertAlmostEqual(check_res["data"]["audio"]["volume"], 1.0, places=2)

    def test_new_config_keys_db_self_healing_and_idempotency(self):
        """Test corrupted/missing DB rows for new keys self-heal on init and idempotent updates skip DB writes."""
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '4194305' WHERE key = 'database.cache_size_kb';", ()),
            ("UPDATE System_Config SET value = 'invalid_vol_mode' WHERE key = 'audio.volume_mode';", ()),
            ("UPDATE System_Config SET value = 'bad_resampler' WHERE key = 'audio.resampler_quality';", ()),
            ("UPDATE System_Config SET value = 'bad_dsd' WHERE key = 'audio.dsd_mode';", ()),
            ("UPDATE System_Config SET value = '1025' WHERE key = 'ingestion.parallel_threads';", ()),
            ("DELETE FROM System_Config WHERE key = 'ingestion.mode';", ()),
        ])

        init_res = self.lib.lyra_init(self.test_db_dir.encode("utf-8"))
        self.assertEqual(init_res, 0)

        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        data = get_res["data"]
        self.assertEqual(data["database"]["cache_size_kb"], 131072)
        self.assertEqual(data["audio"]["volume_mode"], "fixed")
        self.assertEqual(data["audio"]["resampler_quality"], "soxr_hq")
        self.assertEqual(data["audio"]["dsd_mode"], "dop")
        self.assertEqual(data["ingestion"]["parallel_threads"], 0)
        self.assertEqual(data["ingestion"]["mode"], "full")

        # Also test negative parallel_threads self-heals
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = '-1' WHERE key = 'ingestion.parallel_threads';", ()),
        ])
        self.assertEqual(self.lib.lyra_init(self.test_db_dir.encode("utf-8")), 0)
        self.assertEqual(
            self.dispatch("system.get_config", {})["data"]["ingestion"]["parallel_threads"],
            0,
        )

        # Verify idempotency on new keys (timestamps in System_Config must not change)
        res_set = self.dispatch("system.set_config", {
            "audio": {
                "volume_mode": "linear",
                "resampler_quality": "native",
                "dsd_mode": "pcm_transcode",
            },
            "ingestion": {
                "parallel_threads": 8,
                "mode": "fast",
            },
        })
        self.assertResponseCode(res_set, 200)

        # Backdate updated_at so 1-second SQLite datetime('now') aliasing cannot mask an unwanted write
        self.execute_raw_sqls([
            ("UPDATE System_Config SET updated_at = '2000-01-01 00:00:00';", ()),
        ])

        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        before_ts = dict(cursor.fetchall())
        conn.close()

        res_same = self.dispatch("system.set_config", {
            "audio": {
                "volume_mode": "linear",
                "resampler_quality": "native",
                "dsd_mode": "pcm_transcode",
            },
            "ingestion": {
                "parallel_threads": 8,
                "mode": "fast",
            },
        })
        self.assertResponseCode(res_same, 200)

        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT key, updated_at FROM System_Config ORDER BY key")
        after_ts = dict(cursor.fetchall())
        conn.close()
        self.assertEqual(before_ts, after_ts)

    def test_ingestion_mode_waveform_precomputation(self):
        """Test ingestion.mode ('fast' vs 'full') controls post-ingestion waveform precomputation for IngestAsset and ImportTrack."""
        import shutil
        created_files = []
        created_dirs = []
        try:
            # 1. Fast mode: IngestAsset and ImportTrack skip waveform precomputation
            res_fast = self.dispatch("system.set_config", {"ingestion": {"mode": "fast"}})
            self.assertResponseCode(res_fast, 200)

            wav_fast_asset = self._generate_wav_file("wf_fast_asset.wav", duration_sec=0.5, amplitude=10100)
            wav_fast_track = self._generate_wav_file("wf_fast_track.wav", duration_sec=0.5, amplitude=10200)
            wav_fast_reimport = self._generate_wav_file("wf_fast_reimport.wav", duration_sec=0.5, amplitude=10500)
            wav_nonfatal_dir = self._generate_wav_file("wf_nonfatal_dir.wav", duration_sec=0.5, amplitude=10600)
            created_files.extend([wav_fast_asset, wav_fast_track, wav_fast_reimport, wav_nonfatal_dir])

            ingest_fast = self.dispatch("IngestAsset", {"source_path": wav_fast_asset})
            self.assertResponseCode(ingest_fast, 200)
            pcm_fast_asset = ingest_fast["data"]["audio"]["pcm_hash"]
            cache_fast_asset = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_fast_asset}.bin")
            self.assertFalse(os.path.exists(cache_fast_asset))

            import_fast = self.dispatch("ImportTrack", {"source_path": wav_fast_track})
            self.assertResponseCode(import_fast, 200)
            pcm_fast_track = import_fast["data"]["pcm_hash"]
            cache_fast_track = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_fast_track}.bin")
            self.assertFalse(os.path.exists(cache_fast_track))

            ingest_reimport_prep = self.dispatch("IngestAsset", {"source_path": wav_fast_reimport})
            self.assertResponseCode(ingest_reimport_prep, 200)
            pcm_fast_reimport = ingest_reimport_prep["data"]["audio"]["pcm_hash"]
            cache_fast_reimport = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_fast_reimport}.bin")
            self.assertFalse(os.path.exists(cache_fast_reimport))

            ingest_nonfatal_prep = self.dispatch("IngestAsset", {"source_path": wav_nonfatal_dir})
            self.assertResponseCode(ingest_nonfatal_prep, 200)
            pcm_nonfatal = ingest_nonfatal_prep["data"]["audio"]["pcm_hash"]
            cache_nonfatal_dir = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_nonfatal}.bin")
            self.assertFalse(os.path.exists(cache_nonfatal_dir))

            # On-demand audio.get_waveform still lazily computes and caches the waveform
            wf_lazy = self.dispatch("audio.get_waveform", {"pcm_hash": pcm_fast_track})
            self.assertResponseCode(wf_lazy, 200)
            self.assertTrue(os.path.exists(cache_fast_track))
            self.assertEqual(os.path.getsize(cache_fast_track), 12016)

            # 2. Full mode: IngestAsset and ImportTrack precompute waveform caches automatically
            res_full = self.dispatch("system.set_config", {"ingestion": {"mode": "full"}})
            self.assertResponseCode(res_full, 200)

            wav_full_asset = self._generate_wav_file("wf_full_asset.wav", duration_sec=0.5, amplitude=10300)
            wav_full_track = self._generate_wav_file("wf_full_track.wav", duration_sec=0.5, amplitude=10400)
            created_files.extend([wav_full_asset, wav_full_track])

            ingest_full = self.dispatch("IngestAsset", {"source_path": wav_full_asset})
            self.assertResponseCode(ingest_full, 200)
            pcm_full_asset = ingest_full["data"]["audio"]["pcm_hash"]
            cache_full_asset = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_full_asset}.bin")
            self.assertTrue(os.path.exists(cache_full_asset))
            self.assertEqual(os.path.getsize(cache_full_asset), 12016)
            with open(cache_full_asset, "rb") as f:
                self.assertEqual(f.read(4), b"LWAV")

            import_full = self.dispatch("ImportTrack", {"source_path": wav_full_track})
            self.assertResponseCode(import_full, 200)
            pcm_full_track = import_full["data"]["pcm_hash"]
            cache_full_track = os.path.join(self.test_db_dir, ".cache", "waveforms", f"{pcm_full_track}.bin")
            self.assertTrue(os.path.exists(cache_full_track))
            self.assertEqual(os.path.getsize(cache_full_track), 12016)
            with open(cache_full_track, "rb") as f:
                self.assertEqual(f.read(4), b"LWAV")

            # 3. Re-ingesting the deduplicated fast-mode asset under full mode fills in its missing waveform cache
            self.assertFalse(os.path.exists(cache_fast_asset))
            reingest = self.dispatch("IngestAsset", {"source_path": wav_fast_asset})
            self.assertResponseCode(reingest, 200)
            self.assertTrue(os.path.exists(cache_fast_asset))
            self.assertEqual(os.path.getsize(cache_fast_asset), 12016)

            # 4. ImportTrack on an existing fast-mode asset under full mode fills in its missing waveform cache
            self.assertFalse(os.path.exists(cache_fast_reimport))
            reimport = self.dispatch("ImportTrack", {"source_path": wav_fast_reimport})
            self.assertResponseCode(reimport, 200)
            self.assertTrue(os.path.exists(cache_fast_reimport))
            self.assertEqual(os.path.getsize(cache_fast_reimport), 12016)

            # 5. Corrupted waveform cache self-heals when re-ingesting in full mode
            with open(cache_full_asset, "wb") as f:
                f.write(b"CORRUPT")
            self.assertEqual(os.path.getsize(cache_full_asset), 7)
            heal_res = self.dispatch("IngestAsset", {"source_path": wav_full_asset})
            self.assertResponseCode(heal_res, 200)
            self.assertEqual(os.path.getsize(cache_full_asset), 12016)
            with open(cache_full_asset, "rb") as f:
                self.assertEqual(f.read(4), b"LWAV")

            # 6. Waveform cache write failure (non-empty directory blocking target path) is non-fatal for ingestion
            os.makedirs(cache_nonfatal_dir, exist_ok=True)
            created_dirs.append(cache_nonfatal_dir)
            blocker_file = os.path.join(cache_nonfatal_dir, "blocker")
            with open(blocker_file, "wb") as f:
                f.write(b"block")
            nonfatal_res = self.dispatch("IngestAsset", {"source_path": wav_nonfatal_dir})
            self.assertResponseCode(nonfatal_res, 200)
            self.assertTrue(os.path.isdir(cache_nonfatal_dir))
            self.assertTrue(os.path.exists(blocker_file))
        finally:
            for d in created_dirs:
                if os.path.isdir(d):
                    shutil.rmtree(d, ignore_errors=True)
            for p in created_files:
                if os.path.exists(p):
                    try:
                        os.remove(p)
                    except OSError:
                        pass



