# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import hashlib
import time
import os
import threading
from concurrent.futures import ThreadPoolExecutor

# Define the task (must be picklable if using Process, but Thread avoids this issue here)
def benchmark_task(algo_name, size_mb):
    # Setup
    chunk_size = 1024 * 1024 # 1MB
    target_bytes = size_mb * 1024 * 1024
    iterations = target_bytes // chunk_size
    
    # Pre-generate random chunk (simulate file read)
    chunk = os.urandom(chunk_size)
    
    # Init Hasher
    if algo_name == 'md5':
        h = hashlib.md5()
    else:
        h = hashlib.sha256()
        
    # Run Hash
    start = time.time()
    for _ in range(iterations):
        h.update(chunk)
    h.hexdigest()
    return time.time() - start

def run_threaded_benchmark(file_size_mb, count, max_workers):
    print(f"--- Benchmark (Threaded): {file_size_mb}MB x {count} tasks ---")
    
    for algo in ['md5', 'sha256']:
        print(f"Running {algo.upper()}...")
        start_global = time.time()
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(benchmark_task, algo, file_size_mb) for _ in range(count)]
            times = [f.result() for f in futures]
            
        total_time = time.time() - start_global
        throughput = (file_size_mb * count) / total_time
        print(f"  Total Time: {total_time:.2f}s")
        print(f"  Throughput: {throughput:.2f} MB/s")

# Run scaled-down version for VM
# 100MB file size, 16 files total, 4 threads
run_threaded_benchmark(100, 200, 20)