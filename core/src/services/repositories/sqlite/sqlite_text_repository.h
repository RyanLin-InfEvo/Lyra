// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_text_repository.h"

namespace lyra {

class SqliteTextRepository : public ITextRepository {
  public:
    explicit SqliteTextRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Text &text) override;
    tl::expected<std::optional<Text>, std::string> get(const std::string &text_hash) override;
    tl::expected<bool, std::string> exists(const std::string &text_hash) override;
    tl::expected<bool, std::string> entity_exists(const std::string &entity_id) override;
    tl::expected<void, std::string> link_entity(
        const std::string &entity_id,
        const std::string &text_hash,
        const std::string &role) override;
    tl::expected<void, std::string> unlink_entity(
        const std::string &entity_id,
        const std::string &text_hash) override;
    tl::expected<std::vector<Text>, std::string> get_texts_by_entity(
        const std::string &entity_id,
        const std::optional<std::string> &role = std::nullopt,
        const std::optional<std::string> &language = std::nullopt) override;
    tl::expected<int, std::string> count_entity_texts_by_slot(
        const std::string &entity_id,
        const std::string &role,
        const std::string &language,
        const std::optional<std::string> &exclude_text_hash = std::nullopt) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
