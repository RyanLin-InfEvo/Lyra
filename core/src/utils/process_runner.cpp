/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifdef _WIN32
#error "Windows is not supported by ProcessRunner"
#endif

#include "process_runner.h"
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <cstring>
#include <cerrno>
#include <iostream>

namespace lyra {
namespace utils {

namespace {

struct SafeFD {
    int fd = -1;
    SafeFD() = default;
    explicit SafeFD(int f) : fd(f) {}
    ~SafeFD() {
        if (fd != -1) {
            ::close(fd);
        }
    }
    void close() {
        if (fd != -1) {
            ::close(fd);
            fd = -1;
        }
    }
    int get() const { return fd; }
};

struct SafeProcess {
    pid_t pid = -1;
    bool reaped = false;
    explicit SafeProcess(pid_t p) : pid(p) {}
    ~SafeProcess() {
        if (pid != -1 && !reaped) {
            ::kill(pid, SIGKILL);
            int status = 0;
            pid_t res;
            do {
                res = ::waitpid(pid, &status, 0);
            } while (res == -1 && errno == EINTR);
        }
    }
    void disarm() { reaped = true; }
};

} // namespace

tl::expected<int, std::string> ProcessRunner::run(
    const std::vector<std::string>& args,
    std::function<void(const uint8_t* data, size_t size)> callback,
    size_t max_output_size
) {
    if (args.empty()) {
        return tl::unexpected("Arguments list is empty");
    }

    int pipe_fds[2];
    if (pipe(pipe_fds) == -1) {
        return tl::unexpected("Failed to create pipe: " + std::string(strerror(errno)));
    }
    SafeFD read_fd(pipe_fds[0]);
    SafeFD write_fd(pipe_fds[1]);

    pid_t pid = fork();
    if (pid == -1) {
        return tl::unexpected("Failed to fork: " + std::string(strerror(errno)));
    }

    if (pid == 0) {
        // Child process
        read_fd.close(); // Close read end

        // Redirect stdin to /dev/null to prevent child from hanging on parent's stdin
        int dev_null = open("/dev/null", O_RDONLY);
        if (dev_null != -1) {
            dup2(dev_null, STDIN_FILENO);
            ::close(dev_null);
        }

        // Redirect stdout to pipe
        if (dup2(write_fd.get(), STDOUT_FILENO) == -1) {
            _exit(127);
        }
        write_fd.close(); // Close original write end after duplication

        // Prepare arguments for execvp
        std::vector<char*> argv;
        argv.reserve(args.size() + 1);
        for (const auto& arg : args) {
            argv.push_back(const_cast<char*>(arg.c_str()));
        }
        argv.push_back(nullptr);

        execvp(argv[0], argv.data());
        // If execvp fails
        _exit(127);
    }

    // Parent process
    write_fd.close(); // Close write end in parent
    SafeProcess child_proc(pid);

    uint8_t buffer[4096];
    size_t total_read_bytes = 0;
    bool limit_exceeded = false;
    std::string read_error_msg = "";

    while (true) {
        ssize_t bytes_read = read(read_fd.get(), buffer, sizeof(buffer));
        if (bytes_read < 0) {
            if (errno == EINTR) {
                continue;
            }
            read_error_msg = "Read error: " + std::string(strerror(errno));
            break;
        }
        if (bytes_read == 0) {
            // EOF reached
            break;
        }

        if (max_output_size > 0 && (total_read_bytes + bytes_read) > max_output_size) {
            limit_exceeded = true;
            break;
        }

        if (callback) {
            callback(buffer, bytes_read);
        }
        total_read_bytes += bytes_read;
    }

    read_fd.close();

    if (limit_exceeded) {
        // SafeProcess destructor will automatically kill and wait for child
        return tl::unexpected("Output limit exceeded limit of " + std::to_string(max_output_size) + " bytes");
    }

    if (!read_error_msg.empty()) {
        // SafeProcess destructor will automatically kill and wait for child
        return tl::unexpected(read_error_msg);
    }

    int status = 0;
    pid_t res;
    do {
        res = waitpid(pid, &status, 0);
    } while (res == -1 && errno == EINTR);

    child_proc.disarm(); // Child already waited for

    if (res == -1) {
        return tl::unexpected("Failed to wait for child process: " + std::string(strerror(errno)));
    }

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        return tl::unexpected("Child process terminated by signal " + std::to_string(WTERMSIG(status)));
    } else {
        return tl::unexpected("Child process terminated abnormally");
    }
}

} // namespace utils
} // namespace lyra
