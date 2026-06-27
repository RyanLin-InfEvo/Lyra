/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/sha256.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra::utils;

bool test_hash_string() {
    std::cout << "Running test_hash_string..." << std::endl;

    // Test 1: Empty string
    if (Sha256::hash_string("") != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") {
        std::cerr << "Test 1 failed: hash of empty string is incorrect" << std::endl;
        return false;
    }

    // Test 2: "abc"
    if (Sha256::hash_string("abc") != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") {
        std::cerr << "Test 2 failed: hash of 'abc' is incorrect" << std::endl;
        return false;
    }

    // Test 3: 50 bytes
    std::string str_50 = "abcdbcdecdefdefgefghfghighijhijkjiklklmlmnopslepat";
    if (Sha256::hash_string(str_50) != "d48b4b7344d850a496795af14b655b9577feec5d6c36537424c4f265604dd94c") {
        std::cerr << "Test 3 failed: hash of 50-byte string is incorrect" << std::endl;
        return false;
    }

    // Test 4: 64 bytes (exactly block size)
    std::string str_64 = "1234567890123456789012345678901234567890123456789012345678901234";
    if (Sha256::hash_string(str_64) != "676491965ed3ec50cb7a63ee96315480a95c54426b0b72bca8a0d4ad1285ad55") {
        std::cerr << "Test 4 failed: hash of 64-byte string is incorrect" << std::endl;
        return false;
    }

    // Test 5: 65 bytes
    std::string str_65 = "12345678901234567890123456789012345678901234567890123456789012345";
    if (Sha256::hash_string(str_65) != "71fbbf9bcb342cdc7768b7d494089e947ac411548fd9fd6f67bb7a207928027d") {
        std::cerr << "Test 5 failed: hash of 65-byte string is incorrect" << std::endl;
        return false;
    }

    return true;
}

bool test_incremental_update() {
    std::cout << "Running test_incremental_update..." << std::endl;

    Sha256 sha;
    sha.update("abc");
    if (sha.finalize() != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") {
        std::cerr << "Incremental update test 1 failed" << std::endl;
        return false;
    }

    Sha256 sha2;
    sha2.update("abcdbcdecdefdefgefghfghighijhijkjiklklmlmn");
    sha2.update("opslepat");
    if (sha2.finalize() != "d48b4b7344d850a496795af14b655b9577feec5d6c36537424c4f265604dd94c") {
        std::cerr << "Incremental update test 2 failed" << std::endl;
        return false;
    }

    // Test uint8_t update
    Sha256 sha3;
    uint8_t data[] = {'a', 'b', 'c'};
    sha3.update(data, 3);
    if (sha3.finalize() != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") {
        std::cerr << "Incremental update test 3 (uint8_t) failed" << std::endl;
        return false;
    }

    return true;
}

bool test_hash_file(const std::string &temp_dir) {
    std::cout << "Running test_hash_file..." << std::endl;

    std::string empty_file_path = temp_dir + "/empty.bin";
    std::string small_file_path = temp_dir + "/small.bin";
    std::string large_file_path = temp_dir + "/large.bin";
    std::string exact_buffer_file_path = temp_dir + "/exact_buffer.bin";
    std::string exact_multiple_file_path = temp_dir + "/exact_multiple.bin";

    // 1. Empty file
    {
        std::ofstream f(empty_file_path, std::ios::binary);
    }
    if (Sha256::hash_file(empty_file_path) != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") {
        std::cerr << "File hash of empty file incorrect" << std::endl;
        return false;
    }

    // 2. Small file
    {
        std::ofstream f(small_file_path, std::ios::binary);
        f << "abc";
    }
    if (Sha256::hash_file(small_file_path) != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") {
        std::cerr << "File hash of small file incorrect" << std::endl;
        return false;
    }

    // 3. Exact buffer size (32768 bytes)
    {
        std::ofstream f(exact_buffer_file_path, std::ios::binary);
        std::string block(32768, 'A');
        f << block;
    }
    std::string block_data(32768, 'A');
    std::string expected_exact_hash = Sha256::hash_string(block_data);
    if (Sha256::hash_file(exact_buffer_file_path) != expected_exact_hash) {
        std::cerr << "File hash of exact buffer sized file incorrect. Expected: "
                  << expected_exact_hash << ", Got: " << Sha256::hash_file(exact_buffer_file_path) << std::endl;
        return false;
    }

    // 4. Large file (greater than 32768 bytes, e.g. 50000 bytes)
    {
        std::ofstream f(large_file_path, std::ios::binary);
        std::string block(50000, 'B');
        f << block;
    }
    std::string large_block_data(50000, 'B');
    std::string expected_large_hash = Sha256::hash_string(large_block_data);
    if (Sha256::hash_file(large_file_path) != expected_large_hash) {
        std::cerr << "File hash of large file incorrect. Expected: "
                  << expected_large_hash << ", Got: " << Sha256::hash_file(large_file_path) << std::endl;
        return false;
    }

    // 5. Exact multiple of buffer size (65536 bytes)
    {
        std::ofstream f(exact_multiple_file_path, std::ios::binary);
        std::string block(65536, 'C');
        f << block;
    }
    std::string mult_block_data(65536, 'C');
    std::string expected_mult_hash = Sha256::hash_string(mult_block_data);
    if (Sha256::hash_file(exact_multiple_file_path) != expected_mult_hash) {
        std::cerr << "File hash of exact multiple sized file incorrect" << std::endl;
        return false;
    }

    // 6. Non-existent file
    if (Sha256::hash_file(temp_dir + "/nonexistent.bin") != "") {
        std::cerr << "File hash of non-existent file should be empty string" << std::endl;
        return false;
    }

    return true;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <temp_dir>\n";
        return 2;
    }
    std::string temp_dir = argv[1];

    if (!test_hash_string())
        return 1;
    if (!test_incremental_update())
        return 1;
    if (!test_hash_file(temp_dir))
        return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
