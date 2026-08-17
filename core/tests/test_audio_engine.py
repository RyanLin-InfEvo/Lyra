# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import concurrent.futures
import ctypes
import json
import os
import random
import struct
import threading
import time
import wave
from base_test_case import BaseLyraTestCase

EVENT_CALLBACK_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_void_p)

class TestAudioEngine(BaseLyraTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.lib.lyra_register_event_callback.argtypes = [EVENT_CALLBACK_TYPE, ctypes.c_void_p]
        cls.lib.lyra_register_event_callback.restype = None

        cls.sample_wav_path = os.path.abspath(os.path.join(cls.test_db_dir, "sample.wav"))
        cls._create_sample_wav(cls.sample_wav_path, duration_sec=3)

        cls.short_wav_path = os.path.abspath(os.path.join(cls.test_db_dir, "short_sample.wav"))
        cls._create_sample_wav(cls.short_wav_path, duration_sec=0.2)

    @classmethod
    def _create_sample_wav(cls, filepath, duration_sec=3, sample_rate=44100):
        with wave.open(filepath, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)
            num_samples = int(sample_rate * duration_sec)
            raw_data = bytearray()
            for i in range(num_samples):
                value = int(10000 * (i % 100) / 100)
                raw_data.extend(struct.pack('<h', value))
            wav_file.writeframes(raw_data)

    def test_audio_engine_commands(self):
        # 1. Get initial state
        res = self.dispatch("audio.get_state", {})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "STOPPED")

        # 2. Play audio file
        res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "PLAYING")

        # 3. Set volume
        res = self.dispatch("audio.set_volume", {"volume": 0.6})
        self.assertResponseCode(res, 200)
        self.assertAlmostEqual(res["data"]["volume"], 0.6, places=2)

        # 4. Pause audio
        res = self.dispatch("audio.pause", {})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "PAUSED")

        # 5. Resume audio
        res = self.dispatch("audio.resume", {})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "PLAYING")

        # 6. Seek audio
        res = self.dispatch("audio.seek", {"position": 1.5})
        self.assertResponseCode(res, 200)
        self.assertGreaterEqual(res["data"]["position"], 1.4)

        # 7. Stop audio
        res = self.dispatch("audio.stop", {})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "STOPPED")

    def test_audio_event_callback(self):
        events_received = []

        def py_callback(json_event_ptr, user_data_ptr):
            if json_event_ptr:
                event_str = json_event_ptr.decode('utf-8')
                try:
                    events_received.append(json.loads(event_str))
                except Exception:
                    pass

        self._c_callback = EVENT_CALLBACK_TYPE(py_callback)
        self.lib.lyra_register_event_callback(self._c_callback, None)

        try:
            res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
            self.assertResponseCode(res, 200)
            time.sleep(0.1)

            res = self.dispatch("audio.stop", {})
            self.assertResponseCode(res, 200)

            self.assertGreater(len(events_received), 0, "Should receive audio events via C callback")
        finally:
            self.lib.lyra_register_event_callback(EVENT_CALLBACK_TYPE(), None)
            self._c_callback = None

    def test_replay_after_eof(self):
        """
        Verify playing a short audio stream to EOF, verifying transition to STOPPED,
        and replaying immediately without thread crashes or std::terminate.
        """
        res = self.dispatch("audio.play", {"file_path": self.short_wav_path})
        self.assertResponseCode(res, 200)
        self.assertEqual(res["data"]["state"], "PLAYING")

        # Wait until EOF is reached (max 2 seconds)
        start_time = time.time()
        is_stopped = False
        while time.time() - start_time < 2.0:
            state_res = self.dispatch("audio.get_state", {})
            if state_res["data"]["state"] == "STOPPED":
                is_stopped = True
                break
            time.sleep(0.02)

        self.assertTrue(is_stopped, "Audio should have reached EOF and transitioned to STOPPED")

        # Immediately replay after EOF
        replay_res = self.dispatch("audio.play", {"file_path": self.short_wav_path})
        self.assertResponseCode(replay_res, 200)
        self.assertEqual(replay_res["data"]["state"], "PLAYING")

        # Stop audio cleanly
        stop_res = self.dispatch("audio.stop", {})
        self.assertResponseCode(stop_res, 200)
        self.assertEqual(stop_res["data"]["state"], "STOPPED")

    def test_concurrent_event_callback_swapping(self):
        """
        Test registering / unregistering / swapping event callbacks concurrently
        while audio playback commands are active.
        """
        events_a = []
        events_b = []

        def cb_a(json_ptr, user_ptr):
            if json_ptr:
                events_a.append(1)

        def cb_b(json_ptr, user_ptr):
            if json_ptr:
                events_b.append(1)

        c_cb_a = EVENT_CALLBACK_TYPE(cb_a)
        c_cb_b = EVENT_CALLBACK_TYPE(cb_b)

        stop_threads = threading.Event()

        def swapper():
            toggle = False
            while not stop_threads.is_set():
                if toggle:
                    self.lib.lyra_register_event_callback(c_cb_a, None)
                else:
                    self.lib.lyra_register_event_callback(c_cb_b, None)
                toggle = not toggle
                time.sleep(0.005)

        res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(res, 200)

        swap_thread = threading.Thread(target=swapper)
        swap_thread.start()

        try:
            # Emit multiple events via volume & seek operations
            for i in range(10):
                self.dispatch("audio.set_volume", {"volume": 0.1 * (i % 10)})
                self.dispatch("audio.seek", {"position": 0.1 * (i % 5)})
                time.sleep(0.01)
        finally:
            stop_threads.set()
            swap_thread.join()
            self.dispatch("audio.stop", {})
            self.lib.lyra_register_event_callback(EVENT_CALLBACK_TYPE(), None)

    def test_concurrent_seek_and_control(self):
        """
        Test rapid concurrent seek and get_state operations while audio is playing.
        """
        res = self.dispatch("audio.play", {"file_path": self.sample_wav_path})
        self.assertResponseCode(res, 200)

        errors = []

        def worker_seek(tid):
            try:
                for _ in range(15):
                    target = round(random.uniform(0.1, 2.5), 2)
                    r = self.dispatch("audio.seek", {"position": target})
                    if r.get("code") != 200:
                        errors.append(f"Seek failed: {r}")
                    time.sleep(0.005)
            except Exception as e:
                errors.append(str(e))

        def worker_query(tid):
            try:
                for _ in range(25):
                    r = self.dispatch("audio.get_state", {})
                    if r.get("code") != 200:
                        errors.append(f"GetState failed: {r}")
                    time.sleep(0.003)
            except Exception as e:
                errors.append(str(e))

        threads = []
        for i in range(3):
            threads.append(threading.Thread(target=worker_seek, args=(i,)))
            threads.append(threading.Thread(target=worker_query, args=(i,)))

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertEqual(len(errors), 0, f"Concurrent audio operations had errors: {errors}")
        self.dispatch("audio.stop", {})
