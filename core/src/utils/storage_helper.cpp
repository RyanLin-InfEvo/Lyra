/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "storage_helper.h"
#include "uuid_generator.h"
#include <system_error>

namespace lyra {
namespace utils {

TempCleanup::TempCleanup(std::filesystem::path path)
    : m_path(std::move(path)), m_active(true) {}

TempCleanup::~TempCleanup() {
    if (m_active && !m_path.empty()) {
        std::error_code ec;
        std::filesystem::remove(m_path, ec);
    }
}

void TempCleanup::dismiss() {
    m_active = false;
}

void TempCleanup::force_cleanup() {
    if (m_active && !m_path.empty()) {
        std::error_code ec;
        std::filesystem::remove(m_path, ec);
        m_active = false;
    }
}

std::filesystem::path StorageHelper::resolve_cas_dir(const std::string &storage_root, const std::string &file_hash) {
    if (file_hash.length() < 4) {
        return std::filesystem::path(storage_root) / "objects";
    }
    std::string xx = file_hash.substr(0, 2);
    std::string yy = file_hash.substr(2, 2);
    return std::filesystem::path(storage_root) / "objects" / xx / yy;
}

std::filesystem::path StorageHelper::resolve_cas_path(const std::string &storage_root, const std::string &file_hash, const std::string &extension) {
    return resolve_cas_dir(storage_root, file_hash) / (file_hash + extension);
}

std::filesystem::path StorageHelper::generate_temp_path(const std::string &storage_root, const std::string &extension) {
    const std::string temp_filename = UuidGenerator::generate_v4() + extension;
    return std::filesystem::path(storage_root) / "tmp" / temp_filename;
}

tl::expected<void, std::string> StorageHelper::copy_to_temp(const std::string &source_path, const std::filesystem::path &temp_path) {
    namespace fs = std::filesystem;
    const fs::path src_path(source_path);
    if (!fs::is_regular_file(src_path)) {
        return tl::unexpected("Source path does not exist or is not a regular file: " + source_path);
    }

    try {
        fs::create_directories(temp_path.parent_path());
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to create temporary directory: " + std::string(e.what()));
    }

    try {
        fs::copy_file(src_path, temp_path, fs::copy_options::overwrite_existing);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to copy source file to temp path: " + std::string(e.what()));
    }

    return {};
}

tl::expected<void, std::string> StorageHelper::move_to_cas(const std::filesystem::path &temp_path, const std::filesystem::path &target_path) {
    namespace fs = std::filesystem;
    try {
        fs::create_directories(target_path.parent_path());
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to create target directories: " + std::string(e.what()));
    }

    try {
        fs::rename(temp_path, target_path);
    } catch (const std::exception &e) {
        std::error_code ec;
        fs::copy_file(temp_path, target_path, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            return tl::unexpected("Failed to move/copy temp file to CAS path: " + ec.message());
        }
        fs::remove(temp_path, ec);
    }

    return {};
}

tl::expected<std::string, std::string> StorageHelper::find_file_by_prefix(const std::filesystem::path &dir, const std::string &prefix) {
    namespace fs = std::filesystem;
    if (!fs::exists(dir)) {
        return tl::unexpected("Directory not found: " + dir.string());
    }

    try {
        for (const auto &entry : fs::directory_iterator(dir)) {
            if (!entry.is_regular_file()) {
                continue;
            }
            std::string filename = entry.path().filename().string();
            if (filename.rfind(prefix, 0) == 0) {
                return entry.path().string();
            }
        }
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to scan directory: " + std::string(e.what()));
    }

    return tl::unexpected("File with prefix not found: " + prefix);
}

tl::expected<void, std::string> StorageHelper::remove_file(const std::filesystem::path &path) {
    namespace fs = std::filesystem;
    std::error_code ec;
    if (fs::exists(path)) {
        fs::remove(path, ec);
        if (ec) {
            return tl::unexpected("Failed to remove file: " + ec.message());
        }
    }
    return {};
}

tl::expected<uintmax_t, std::string> StorageHelper::get_file_size(const std::filesystem::path &path) {
    namespace fs = std::filesystem;
    try {
        return fs::file_size(path);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to determine file size: " + std::string(e.what()));
    }
}

} // namespace utils
} // namespace lyra
