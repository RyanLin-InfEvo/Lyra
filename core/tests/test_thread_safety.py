# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unittest
import threading
from base_test_case import BaseLyraTestCase

class TestThreadSafety(BaseLyraTestCase):
    def test_concurrent_creation(self):
        """
        Test if concurrent Artist creation from multiple threads causes crashes or database errors.
        """
        num_threads = 20
        iterations = 50
        errors = []

        def worker(thread_id):
            for i in range(iterations):
                payload = {
                    "command": "CreateArtist",
                    "params": {
                        "name": f"Thread-{thread_id}-Artist-{i}"
                    }
                }
                try:
                    # Call the underlying C function directly to simulate real concurrency
                    response = self.raw_dispatch(payload)
                    if response.get("code") != 201:
                        errors.append(f"Thread {thread_id} failed with: {response}")
                except Exception as e:
                    errors.append(f"Thread {thread_id} crashed: {e}")

        threads = []
        for i in range(num_threads):
            t = threading.Thread(target=worker, args=(i,))
            threads.append(t)
            t.start()

        for t in threads:
            t.join()

        print(f"\n[Thread Safety Test - Write Only] Completed with {len(errors)} errors.")
        for err in errors[:5]: # Only print the first few errors
            print(f"  - {err}")
            
        self.assertEqual(len(errors), 0, f"Thread safety test failed with {len(errors)} errors!")

    def test_mixed_read_write(self):
        """
        Test concurrent reads and writes to verify ConnectionPool stability.
        """
        num_read_threads = 30
        num_write_threads = 10
        iterations = 30
        errors = []

        # 1. Pre-populate some data
        artist_ids = []
        for i in range(10):
            res = self.dispatch("CreateArtist", {"name": f"Base-Artist-{i}"})
            artist_ids.append(res["data"]["id"])

        def reader(thread_id):
            import random
            for i in range(iterations):
                target_id = random.choice(artist_ids)
                try:
                    res = self.dispatch("GetArtist", {"id": target_id})
                    if res.get("code") != 200:
                        errors.append(f"Read Thread {thread_id} failed: {res}")
                except Exception as e:
                    errors.append(f"Read Thread {thread_id} crashed: {e}")

        def writer(thread_id):
            for i in range(iterations):
                try:
                    res = self.dispatch("CreateArtist", {"name": f"Writer-{thread_id}-Artist-{i}"})
                    if res.get("code") != 201:
                        errors.append(f"Write Thread {thread_id} failed: {res}")
                except Exception as e:
                    errors.append(f"Write Thread {thread_id} crashed: {e}")

        threads = []
        for i in range(num_read_threads):
            threads.append(threading.Thread(target=reader, args=(i,)))
        for i in range(num_write_threads):
            threads.append(threading.Thread(target=writer, args=(i,)))

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        print(f"\n[Thread Safety Test - Mixed] Completed with {len(errors)} errors.")
        self.assertEqual(len(errors), 0, f"Mixed concurrency test failed with {len(errors)} errors!")

if __name__ == "__main__":
    unittest.main()
