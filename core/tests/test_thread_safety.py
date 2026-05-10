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
        num_threads = 100
        iterations = 20
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

        print(f"\n[Thread Safety Test] Completed with {len(errors)} errors.")
        for err in errors[:5]: # Only print the first few errors
            print(f"  - {err}")
            
        self.assertEqual(len(errors), 0, f"Thread safety test failed with {len(errors)} errors!")

if __name__ == "__main__":
    unittest.main()
