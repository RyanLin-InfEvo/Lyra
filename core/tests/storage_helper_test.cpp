/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/storage_helper.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra::utils;

bool test_cas_resolving(const std::string &temp_dir) {
    std::cout << "Running test_cas_resolving..." << std::endl;

    std::string hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    auto cas_dir = StorageHelper::resolve_cas_dir(temp_dir, hash);
    auto expected_dir = std::filesystem::path(temp_dir) / "objects" / "01" / "23";
    if (cas_dir != expected_dir) {
        std::cerr << "CAS dir mismatch. Expected: " << expected_dir << ", Got: " << cas_dir << std::endl;
        return false;
    }

    auto cas_path = StorageHelper::resolve_cas_path(temp_dir, hash, ".wav");
    auto expected_path = expected_dir / (hash + ".wav");
    if (cas_path != expected_path) {
        std::cerr << "CAS path mismatch. Expected: " << expected_path << ", Got: " << cas_path << std::endl;
        return false;
    }

    return true;
}

bool test_temp_path_generation(const std::string &temp_dir) {
    std::cout << "Running test_temp_path_generation..." << std::endl;

    auto temp_path = StorageHelper::generate_temp_path(temp_dir, ".wav");
    if (temp_path.parent_path() != std::filesystem::path(temp_dir) / "tmp") {
        std::cerr << "Temp path parent mismatch. Got: " << temp_path.parent_path() << std::endl;
        return false;
    }
    if (temp_path.extension() != ".wav") {
        std::cerr << "Temp path extension mismatch. Got: " << temp_path.extension() << std::endl;
        return false;
    }

    return true;
}

bool test_copy_to_temp_and_cleanup(const std::string &temp_dir) {
    std::cout << "Running test_copy_to_temp_and_cleanup..." << std::endl;

    std::string src_file = temp_dir + "/src_test.wav";
    {
        std::ofstream f(src_file);
        f << "dummy audio content";
    }

    auto temp_path = StorageHelper::generate_temp_path(temp_dir, ".wav");
    {
        TempCleanup cleanup{temp_path};

        auto res = StorageHelper::copy_to_temp(src_file, temp_path);
        if (!res.has_value()) {
            std::cerr << "Copy to temp failed: " << res.error() << std::endl;
            return false;
        }

        if (!std::filesystem::exists(temp_path)) {
            std::cerr << "Temp file does not exist after copy" << std::endl;
            return false;
        }

        // Test file size helper
        auto size_res = StorageHelper::get_file_size(temp_path);
        if (!size_res.has_value() || size_res.value() != 19) {
            std::cerr << "File size mismatch or failed: " << size_res.value() << std::endl;
            return false;
        }
    }

    // Now cleanup destructor should have deleted the temp file
    if (std::filesystem::exists(temp_path)) {
        std::cerr << "Temp file was not cleaned up by TempCleanup destructor" << std::endl;
        return false;
    }

    return true;
}

bool test_move_to_cas_and_dismiss(const std::string &temp_dir) {
    std::cout << "Running test_move_to_cas_and_dismiss..." << std::endl;

    std::string src_file = temp_dir + "/src_test2.wav";
    {
        std::ofstream f(src_file);
        f << "some more dummy content";
    }

    auto temp_path = StorageHelper::generate_temp_path(temp_dir, ".wav");
    TempCleanup cleanup{temp_path};

    auto copy_res = StorageHelper::copy_to_temp(src_file, temp_path);
    assert(copy_res.has_value());

    std::string hash = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
    auto cas_path = StorageHelper::resolve_cas_path(temp_dir, hash, ".wav");

    auto move_res = StorageHelper::move_to_cas(temp_path, cas_path);
    if (!move_res.has_value()) {
        std::cerr << "Move to CAS failed: " << move_res.error() << std::endl;
        return false;
    }

    cleanup.dismiss();

    if (!std::filesystem::exists(cas_path)) {
        std::cerr << "CAS file not found after move" << std::endl;
        return false;
    }

    if (std::filesystem::exists(temp_path)) {
        std::cerr << "Temp file still exists after move" << std::endl;
        return false;
    }

    // Test directory scanning
    auto cas_dir = StorageHelper::resolve_cas_dir(temp_dir, hash);
    auto find_res = StorageHelper::find_file_by_prefix(cas_dir, hash);
    if (!find_res.has_value()) {
        std::cerr << "Find file by prefix failed: " << find_res.error() << std::endl;
        return false;
    }

    if (find_res.value() != cas_path.string()) {
        std::cerr << "Find file by prefix path mismatch. Got: " << find_res.value() << std::endl;
        return false;
    }

    // Test safe remove
    auto remove_res = StorageHelper::remove_file(cas_path);
    if (!remove_res.has_value()) {
        std::cerr << "Remove file failed: " << remove_res.error() << std::endl;
        return false;
    }

    if (std::filesystem::exists(cas_path)) {
        std::cerr << "File still exists after remove_file" << std::endl;
        return false;
    }

    // Stray files sharing prefix without '.' delimiter must NOT match
    {
        std::filesystem::create_directories(cas_dir);
        std::filesystem::path stray_underscore = cas_dir / (hash + "_stray");
        std::filesystem::path stray_extra = cas_dir / (hash + "extra.txt");
        {
            std::ofstream f1(stray_underscore);
            f1 << "stray1";
            std::ofstream f2(stray_extra);
            f2 << "stray2";
        }
        auto stray_res = StorageHelper::find_file_by_prefix(cas_dir, hash);
        std::filesystem::remove(stray_underscore);
        std::filesystem::remove(stray_extra);
        if (stray_res.has_value()) {
            std::cerr << "find_file_by_prefix falsely matched stray prefix file: " << stray_res.value() << std::endl;
            return false;
        }
    }

    // [MED-2] Empty prefix in find_file_by_prefix must fail (must not match dotfiles like .tmp_foo)
    {
        std::filesystem::create_directories(cas_dir);
        std::filesystem::path dotfile = cas_dir / ".tmp_foo";
        {
            std::ofstream f(dotfile);
            f << "dot";
        }
        auto empty_prefix_res = StorageHelper::find_file_by_prefix(cas_dir, "");
        std::filesystem::remove(dotfile);
        if (empty_prefix_res.has_value()) {
            std::cerr << "find_file_by_prefix(\"\") falsely matched: " << empty_prefix_res.value() << std::endl;
            return false;
        }
    }

    // [MED-2] move_to_cas_if_absent: first publish returns true, duplicate returns false and preserves original
    {
        auto target = StorageHelper::resolve_cas_path(temp_dir, hash, ".txt");
        auto tmp1 = StorageHelper::generate_temp_path(temp_dir, ".txt");
        std::filesystem::create_directories(tmp1.parent_path());
        {
            std::ofstream f(tmp1, std::ios::binary);
            f << "original_cas_payload";
        }
        auto r1 = StorageHelper::move_to_cas_if_absent(tmp1, target);
        if (!r1.has_value() || !r1.value()) {
            std::cerr << "move_to_cas_if_absent first publish should return true" << std::endl;
            return false;
        }
        if (std::filesystem::exists(tmp1) || !std::filesystem::exists(target)) {
            std::cerr << "move_to_cas_if_absent first publish file state invalid" << std::endl;
            return false;
        }

        auto tmp2 = StorageHelper::generate_temp_path(temp_dir, ".txt");
        {
            std::ofstream f(tmp2, std::ios::binary);
            f << "overwrite_attempt";
        }
        auto r2 = StorageHelper::move_to_cas_if_absent(tmp2, target);
        if (!r2.has_value() || r2.value()) {
            std::cerr << "move_to_cas_if_absent duplicate publish should return false" << std::endl;
            return false;
        }
        if (std::filesystem::exists(tmp2)) {
            std::cerr << "move_to_cas_if_absent should delete redundant temp file on duplicate" << std::endl;
            return false;
        }
        std::ifstream verify(target, std::ios::binary);
        std::string content((std::istreambuf_iterator<char>(verify)), std::istreambuf_iterator<char>());
        if (content != "original_cas_payload") {
            std::cerr << "move_to_cas_if_absent clobbered existing target! Got: " << content << std::endl;
            return false;
        }
        StorageHelper::remove_file(target);
    }

    return true;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <temp_dir>\n";
        return 2;
    }
    std::string temp_dir = argv[1];

    if (!test_cas_resolving(temp_dir))
        return 1;
    if (!test_temp_path_generation(temp_dir))
        return 1;
    if (!test_copy_to_temp_and_cleanup(temp_dir))
        return 1;
    if (!test_move_to_cas_and_dismiss(temp_dir))
        return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
