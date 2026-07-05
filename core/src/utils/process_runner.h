/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifdef _WIN32
#error "Windows is not supported by ProcessRunner"
#endif

#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>
#include <tl/expected.hpp>

namespace lyra {
namespace utils {

class ProcessRunner {
public:
    /**
     * Executes a process, reads its standard output in chunks, and invokes a callback.
     * 
     * @param args The command line arguments (first argument is the executable).
     * @param callback The callback invoked with each chunk of data read from standard output.
     * @param max_output_size If non-zero, limits the maximum number of bytes read.
     *                        If the limit is exceeded, the process is killed via SIGKILL
     *                        and an error is returned.
     * @return The process exit code on success, or an error string on failure.
     */
    static tl::expected<int, std::string> run(
        const std::vector<std::string>& args,
        std::function<void(const uint8_t* data, size_t size)> callback,
        size_t max_output_size = 0
    );
};

} // namespace utils
} // namespace lyra
