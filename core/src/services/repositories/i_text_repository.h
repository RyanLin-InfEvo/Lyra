// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/text.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class ITextRepository {
  public:
    virtual ~ITextRepository() = default;

    virtual tl::expected<void, std::string> insert(const Text &text) = 0;
    virtual tl::expected<std::optional<Text>, std::string> get(const std::string &text_hash) = 0;
    virtual tl::expected<bool, std::string> exists(const std::string &text_hash) = 0;
    /// Checks whether the target entity exists (excluding 'tag' entities, which cannot hold text).
    virtual tl::expected<bool, std::string> entity_exists(const std::string &entity_id) = 0;
    virtual tl::expected<void, std::string> link_entity(
        const std::string &entity_id,
        const std::string &text_hash,
        const std::string &role) = 0;
    virtual tl::expected<void, std::string> unlink_entity(
        const std::string &entity_id,
        const std::string &text_hash) = 0;
    virtual tl::expected<std::vector<Text>, std::string> get_texts_by_entity(
        const std::string &entity_id,
        const std::optional<std::string> &role = std::nullopt,
        const std::optional<std::string> &language = std::nullopt) = 0;
    virtual tl::expected<int, std::string> count_entity_texts_by_slot(
        const std::string &entity_id,
        const std::string &role,
        const std::string &language,
        const std::optional<std::string> &exclude_text_hash = std::nullopt) = 0;
};

} // namespace lyra
