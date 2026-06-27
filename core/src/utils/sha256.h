/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <string>

namespace lyra {
namespace utils {

class Sha256 {
  public:
    Sha256();
    void update(const uint8_t *data, size_t length);
    void update(const std::string &data);
    std::string finalize();

    static std::string hash_string(const std::string &str);
    static std::string hash_file(const std::string &filepath);

  private:
    void transform(const uint8_t *message);

    uint32_t m_state[8];
    uint64_t m_bitlen;
    uint8_t m_data[64];
    uint32_t m_datalen;
};

} // namespace utils
} // namespace lyra
