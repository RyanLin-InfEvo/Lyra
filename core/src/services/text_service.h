/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <tl/expected.hpp>
#include <vector>

#include "../models/text.h"
#include "../utils/make_error.h"

namespace lyra {

class IDatabaseContext;
class IAssetRepository;
class ITextRepository;

struct SaveTextRequest {
    std::string entity_id;
    std::string role;
    std::optional<std::string> content = std::nullopt;
    std::optional<std::string> text_hash = std::nullopt;
    std::optional<std::string> format = std::nullopt;
    std::optional<std::string> language = std::nullopt;
};

struct SaveTextResult {
    Text text;
    int existing_same_slot_count = 0;
};

struct TextContentResult {
    Text text;
    std::string content;
};

class TextService {
  public:
    static constexpr size_t MAX_TEXT_CONTENT_BYTES = 2 * 1024 * 1024; // 2 MiB
    static constexpr size_t MAX_LANGUAGE_BYTES = 64;

    static bool is_valid_format(std::string_view format);
    static bool is_valid_role(std::string_view role);
    static bool is_valid_utf8(std::string_view bytes);
    static bool contains_control_chars(std::string_view utf8, bool allow_multiline_whitespace = false);
    static bool is_valid_language(std::string_view lang);
    static std::string_view strip_utf8_bom(std::string_view text);
    static std::string normalize_line_endings(std::string_view text);
    static std::string compute_text_hash(
        const std::string &format,
        const std::string &language,
        const std::string &normalized_utf8);
    static std::string detect_lyrics_format(std::string_view content);

    TextService(
        IDatabaseContext &db_context,
        IAssetRepository &asset_repo,
        ITextRepository &text_repo,
        const std::string &storage_root);

    tl::expected<SaveTextResult, Error> save_text(const SaveTextRequest &req);
    tl::expected<TextContentResult, Error> get_text_by_hash(const std::string &text_hash);
    tl::expected<TextContentResult, Error> get_entity_text(
        const std::string &entity_id,
        const std::optional<std::string> &role = std::nullopt,
        const std::optional<std::string> &language = std::nullopt);
    tl::expected<std::vector<Text>, Error> get_entity_texts(
        const std::string &entity_id,
        const std::optional<std::string> &role = std::nullopt,
        const std::optional<std::string> &language = std::nullopt);
    tl::expected<void, Error> unlink_entity_text(
        const std::string &entity_id,
        const std::string &text_hash);

  private:
    tl::expected<std::string, Error> read_cas_content(const std::string &file_hash) const;

    IDatabaseContext &m_db_context;
    IAssetRepository &m_asset_repo;
    ITextRepository &m_text_repo;
    std::string m_storage_root;
};

} // namespace lyra
