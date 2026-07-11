/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <tl/expected.hpp>

namespace lyra {
namespace utils {

class TempCleanup {
public:
    explicit TempCleanup(std::filesystem::path path);
    ~TempCleanup();
    void dismiss();
    void force_cleanup();

private:
    std::filesystem::path m_path;
    bool m_active = true;
};

class StorageHelper {
public:
    // CAS directory resolving:
    // Resolves the directory storage_root/objects/xx/yy where xx and yy are the first 2 and second 2 hex characters of the file_hash.
    static std::filesystem::path resolve_cas_dir(const std::string &storage_root, const std::string &file_hash);

    // Resolves the target file path in CAS: storage_root/objects/xx/yy/file_hash.ext
    static std::filesystem::path resolve_cas_path(const std::string &storage_root, const std::string &file_hash, const std::string &extension);

    // Temp path generation:
    // Generates a temp path storage_root/tmp/<uuid>.<ext>
    static std::filesystem::path generate_temp_path(const std::string &storage_root, const std::string &extension);

    // Safe file copying to temp:
    // Ensures temp directory exists and copies the file from source_path to temp_path.
    static tl::expected<void, std::string> copy_to_temp(const std::string &source_path, const std::filesystem::path &temp_path);

    // Moving files to CAS (with rename/copy fallback):
    // Moves temp_path to target_path (creating target parent dir if needed).
    // Uses rename, and falls back to copy & delete on failure.
    static tl::expected<void, std::string> move_to_cas(const std::filesystem::path &temp_path, const std::filesystem::path &target_path);

    // Directory scanning:
    // Finds a file in a target directory that starts with the given file_hash prefix.
    static tl::expected<std::string, std::string> find_file_by_prefix(const std::filesystem::path &dir, const std::string &prefix);

    // Cleanups:
    // Safely removes a file.
    static tl::expected<void, std::string> remove_file(const std::filesystem::path &path);

    // Helper to get file size
    static tl::expected<uintmax_t, std::string> get_file_size(const std::filesystem::path &path);
};

} // namespace utils
} // namespace lyra
