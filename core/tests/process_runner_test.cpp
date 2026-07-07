/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/process_runner.h"
#include <cassert>
#include <chrono>
#include <iostream>
#include <signal.h>
#include <string>
#include <sys/types.h>
#include <thread>
#include <vector>

using namespace lyra::utils;

bool test_normal_execution() {
    std::cout << "Running test_normal_execution..." << std::endl;

    std::string output;
    auto callback = [&output](const uint8_t *data, size_t size) {
        output.append(reinterpret_cast<const char *>(data), size);
    };

    auto result = ProcessRunner::run({"/bin/sh", "-c", "echo -n 'hello world'"}, callback);
    if (!result) {
        std::cerr << "Test failed: " << result.error() << std::endl;
        return false;
    }

    if (result.value() != 0) {
        std::cerr << "Test failed: exit code is " << result.value() << ", expected 0" << std::endl;
        return false;
    }

    if (output != "hello world") {
        std::cerr << "Test failed: output was '" << output << "', expected 'hello world'" << std::endl;
        return false;
    }

    return true;
}

bool test_nonzero_exit() {
    std::cout << "Running test_nonzero_exit..." << std::endl;

    auto result = ProcessRunner::run({"/bin/sh", "-c", "exit 45"}, nullptr);
    if (!result) {
        std::cerr << "Test failed: got error unexpectedly: " << result.error() << std::endl;
        return false;
    }

    if (result.value() != 45) {
        std::cerr << "Test failed: got exit code " << result.value() << ", expected 45" << std::endl;
        return false;
    }

    return true;
}

bool test_output_limit_exceeded() {
    std::cout << "Running test_output_limit_exceeded..." << std::endl;

    std::string output;
    auto callback = [&output](const uint8_t *data, size_t size) {
        output.append(reinterpret_cast<const char *>(data), size);
    };

    // We output a 20-byte string, but set limit to 10 bytes.
    auto result = ProcessRunner::run({"/bin/sh", "-c", "echo -n '01234567890123456789'"}, callback, 10);
    if (result) {
        std::cerr << "Test failed: expected limit exceeded, but got exit code " << result.value() << std::endl;
        return false;
    }

    if (result.error().find("limit exceeded") == std::string::npos) {
        std::cerr << "Test failed: unexpected error message: " << result.error() << std::endl;
        return false;
    }

    std::cout << "Got expected error: " << result.error() << std::endl;

    return true;
}

bool test_output_limit_kill_hang() {
    std::cout << "Running test_output_limit_kill_hang..." << std::endl;

    auto start = std::chrono::steady_clock::now();
    // This command output is 10 bytes (since '1234567890' is 10 bytes), which exceeds limit of 5.
    // It then attempts to sleep 5 seconds.
    // If our limit killing works, the child process will be killed instantly, and we should not wait 5 seconds.
    auto result = ProcessRunner::run({"/bin/sh", "-c", "echo -n '1234567890'; sleep 5; echo -n 'more'"}, nullptr, 5);
    auto end = std::chrono::steady_clock::now();

    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    if (result) {
        std::cerr << "Test failed: expected limit exceeded, but got exit code " << result.value() << std::endl;
        return false;
    }

    if (elapsed > 2000) {
        std::cerr << "Test failed: execution took " << elapsed << "ms, indicating the child process was not killed instantly" << std::endl;
        return false;
    }

    std::cout << "Got expected limit-exceeded error: " << result.error() << std::endl;
    std::cout << "Hanging child killed instantly in " << elapsed << "ms" << std::endl;
    return true;
}

bool test_empty_arguments() {
    std::cout << "Running test_empty_arguments..." << std::endl;
    auto result = ProcessRunner::run({}, nullptr);
    if (result) {
        std::cerr << "Test failed: expected error on empty arguments, got " << result.value() << std::endl;
        return false;
    }
    std::cout << "Got expected empty arguments error: " << result.error() << std::endl;
    return true;
}

bool test_callback_exception_safety() {
    std::cout << "Running test_callback_exception_safety..." << std::endl;

    pid_t child_pid = -1;
    auto callback = [&child_pid](const uint8_t *data, size_t size) {
        std::string s(reinterpret_cast<const char *>(data), size);
        try {
            child_pid = std::stoi(s);
        } catch (...) {
            // Ignore parse errors if reading partial chunk
        }
        throw std::runtime_error("Simulated callback exception");
    };

    bool exception_caught = false;
    try {
        // Child prints its PID and sleeps
        ProcessRunner::run({"/bin/sh", "-c", "echo $$; sleep 5"}, callback);
    } catch (const std::runtime_error &e) {
        if (std::string(e.what()) == "Simulated callback exception") {
            exception_caught = true;
        }
    }

    if (!exception_caught) {
        std::cerr << "Test failed: exception was not caught" << std::endl;
        return false;
    }

    if (child_pid <= 0) {
        std::cerr << "Test failed: did not capture valid child PID" << std::endl;
        return false;
    }

    // Give OS a moment to reap the process
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    // Verify that the child process has been killed and reaped (returns ESRCH)
    int kill_res = kill(child_pid, 0);
    if (kill_res == 0 || errno != ESRCH) {
        std::cerr << "Test failed: child process " << child_pid
                  << " is still alive or zombie (kill return: " << kill_res
                  << ", errno: " << errno << ")" << std::endl;
        return false;
    }

    std::cout << "Verified child process " << child_pid << " was reaped on exception stack unwind." << std::endl;
    return true;
}

int main() {
    // clang-format off
    if (!test_normal_execution()) return 1;
    if (!test_nonzero_exit()) return 1;
    if (!test_output_limit_exceeded()) return 1;
    if (!test_output_limit_kill_hang()) return 1;
    if (!test_empty_arguments()) return 1;
    if (!test_callback_exception_safety()) return 1;
    // clang-format on

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
