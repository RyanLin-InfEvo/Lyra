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
            },
        })

    def test_get_config_defaults(self):
        """Test system.get_config returns the expected default dictionary without phantom settings."""
        res = self.dispatch("system.get_config", {})
        self.assertResponseCode(res, 200)

        data = res.get("data", {})
        self.assertIn("storage", data)
        self.assertIn("database", data)
        self.assertIn("audio", data)

        # Storage subsystem
        self.assertEqual(
            os.path.normpath(data["storage"].get("storage_root")),
            os.path.normpath(self.test_db_dir),
        )

        # Database subsystem
        self.assertEqual(data["database"].get("cache_size_kb"), 131072)
        self.assertEqual(data["database"].get("mmap_size_bytes"), 536870912)
        self.assertEqual(data["database"].get("busy_timeout_ms"), 30000)
        self.assertEqual(data["database"].get("wal_autocheckpoint"), 1000)

        # Audio subsystem
        self.assertEqual(data["audio"].get("output_device_id"), "default")
        self.assertAlmostEqual(data["audio"].get("volume"), 1.0, places=2)

        # Anti-Phantom / YAGNI assertions: Ensure no un-implemented subsystems exist
        self.assertNotIn("dsd_mode", data)
        self.assertNotIn("resampler_quality", data)
        self.assertNotIn("volume_mode", data)
        self.assertNotIn("ingestion", data)
        self.assertNotIn("dsd_mode", data.get("audio", {}))
        self.assertNotIn("resampler_quality", data.get("audio", {}))
        self.assertNotIn("volume_mode", data.get("audio", {}))

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
        # 1. cache_size_kb >= 1024
        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 1023}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": -1}})
        self.assertValidationError(res, expected_type="OutOfRange", expected_message_content="cache_size_kb")

        res = self.dispatch("system.set_config", {"database": {"cache_size_kb": 1024}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["database"]["cache_size_kb"], 1024)

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
            ("UPDATE System_Config SET value = 'bogus_device_xyz' WHERE key = 'audio.output_device_id';", ()),
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
        """Test valid 64-hex device ID is accepted and retained across re-init even if device is offline."""
        valid_hex_device_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        # a) system.set_config accepts valid 64-hex device ID
        res = self.dispatch("system.set_config", {"audio": {"output_device_id": valid_hex_device_id}})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["audio"]["output_device_id"], valid_hex_device_id)

        # Verify get_config reflects it
        get_res = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res, 200)
        self.assertEqual(get_res["data"]["audio"]["output_device_id"], valid_hex_device_id)

        # b) Re-opening / reinitializing the database preserves this valid device ID and does NOT self-heal to default
        init_res = self.lib.lyra_init(self.test_db_dir.encode('utf-8'))
        self.assertEqual(init_res, 0)

        get_res2 = self.dispatch("system.get_config", {})
        self.assertResponseCode(get_res2, 200)
        self.assertEqual(get_res2["data"]["audio"]["output_device_id"], valid_hex_device_id)

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

        # Invalid values in DB are still self-healed to "default" on re-init
        self.execute_raw_sqls([
            ("UPDATE System_Config SET value = 'bogus_device_xyz' WHERE key = 'audio.output_device_id';", ()),
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
        init_res = self.dispatch("system.set_config", {
            "audio": {
                "output_device_id": valid_dev,
                "volume": 0.45,
            }
        })
        self.assertResponseCode(init_res, 200)
        self.assertEqual(init_res["data"]["audio"]["output_device_id"], valid_dev)
        self.assertAlmostEqual(init_res["data"]["audio"]["volume"], 0.45, places=2)

        # Update ONLY volume - output_device_id must remain valid_dev
        vol_res = self.dispatch("system.set_config", {"audio": {"volume": 0.85}})
        self.assertResponseCode(vol_res, 200)
        self.assertAlmostEqual(vol_res["data"]["audio"]["volume"], 0.85, places=2)
        self.assertEqual(vol_res["data"]["audio"]["output_device_id"], valid_dev)

        # Verify live AudioEngine state
        state_res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(state_res, 200)
        self.assertAlmostEqual(state_res["data"]["volume"], 0.85, places=2)

        # Update ONLY output_device_id - volume must remain 0.85
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


