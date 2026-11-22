/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "text_service.h"

#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <memory>
#include <system_error>

#include "../models/asset.h"
#include "../utils/sha256.h"
#include "../utils/storage_helper.h"
#include "../utils/utf8_helper.h"
#include "database_context.h"
#include "repositories/i_asset_repository.h"
#include "repositories/i_text_repository.h"

namespace lyra {

namespace {

std::string trim_ascii_whitespace(std::string_view s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string_view::npos) {
        return "";
    }
    size_t end = s.find_last_not_of(" \t\r\n");
    return std::string(s.substr(start, end - start + 1));
}

constexpr bool is_ascii_digit(char c) noexcept {
    return c >= '0' && c <= '9';
}

std::string extension_for_format(std::string_view format) {
    if (format == "lrc") return ".lrc";
    if (format == "txt") return ".txt";
    if (format == "srt") return ".srt";
    if (format == "ttml") return ".ttml";
    return ".txt";
}

std::string mime_type_for_format(std::string_view format) {
    if (format == "lrc") return "text/x-lrc";
    if (format == "txt") return "text/plain";
    if (format == "srt") return "application/x-subrip";
    if (format == "ttml") return "application/ttml+xml";
    return "text/plain";
}

bool is_lrc_timestamp_at(std::string_view s, size_t pos) noexcept {
    const size_t n = s.size();
    if (pos >= n || s[pos] != '[') return false;
    ++pos;

    // 1-3 digit minute
    size_t min_digits = 0;
    while (pos < n && is_ascii_digit(s[pos]) && min_digits < 3) {
        ++pos;
        ++min_digits;
    }
    if (min_digits == 0 || pos >= n || s[pos] != ':') return false;
    ++pos;

    // 2 digit second (00..59)
    if (pos + 2 > n) return false;
    if (s[pos] < '0' || s[pos] > '5' || !is_ascii_digit(s[pos + 1])) return false;
    pos += 2;

    // Optional fractional seconds (.d .. .ddd or :dd)
    if (pos < n && (s[pos] == '.' || s[pos] == ':')) {
        ++pos;
        size_t frac_digits = 0;
        while (pos < n && is_ascii_digit(s[pos]) && frac_digits < 8) {
            ++pos;
            ++frac_digits;
        }
        if (frac_digits == 0) return false;
    }

    return pos < n && s[pos] == ']';
}

tl::expected<std::optional<std::string>, Error> validate_optional_language_filter(
    const std::optional<std::string> &language) {
    if (!language.has_value()) {
        return std::nullopt;
    }
    if (language->empty()) {
        return std::optional<std::string>("");
    }
    if (!TextService::is_valid_language(*language)) {
        return tl::unexpected(Error{
            ErrorType::InvalidValue,
            "Language must be valid UTF-8 (<= 64 bytes) without control characters."});
    }
    std::string trimmed = trim_ascii_whitespace(*language);
    if (trimmed.empty()) {
        return tl::unexpected(Error{ErrorType::InvalidValue, "Value of key 'language' should not be blank."});
    }
    return std::optional<std::string>(trimmed);
}

tl::expected<void, Error> validate_strict_identifier(std::string_view value, const char *key_name) {
    if (!utils::is_valid_utf8(value) ||
        utils::contains_control_chars(value, /*allow_multiline_whitespace=*/false)) {
        return tl::unexpected(Error{
            ErrorType::InvalidValue,
            std::string("Value of key '") + key_name + "' must be valid UTF-8 without control characters."});
    }
    if (value.empty() || value.front() == ' ' || value.back() == ' ') {
        return tl::unexpected(Error{
            ErrorType::InvalidValue,
            std::string("Value of key '") + key_name + "' must not be empty or have leading/trailing whitespace."});
    }
    return {};
}

} // namespace

bool TextService::is_valid_format(std::string_view format) {
    static constexpr std::array<std::string_view, 4> ALLOWED = {
        "lrc", "txt", "srt", "ttml"};
    for (const auto &item : ALLOWED) {
        if (format == item) return true;
    }
    return false;
}

bool TextService::is_valid_role(std::string_view role) {
    static constexpr std::array<std::string_view, 10> ALLOWED = {
        "lyrics",
        "lyrics_translation",
        "lyrics_transliteration",
        "description",
        "biography",
        "liner_notes",
        "credits",
        "review",
        "trivia",
        "other"};
    for (const auto &item : ALLOWED) {
        if (role == item) return true;
    }
    return false;
}

bool TextService::is_valid_utf8(std::string_view bytes) {
    return utils::is_valid_utf8(bytes);
}

bool TextService::contains_control_chars(std::string_view utf8, bool allow_multiline_whitespace) {
    return utils::contains_control_chars(utf8, allow_multiline_whitespace);
}

bool TextService::is_valid_language(std::string_view lang) {
    if (lang.size() > MAX_LANGUAGE_BYTES) {
        return false;
    }
    if (!is_valid_utf8(lang)) {
        return false;
    }
    return !contains_control_chars(lang, /*allow_multiline_whitespace=*/false);
}

std::string_view TextService::strip_utf8_bom(std::string_view text) { // strip leading U+FEFF UTF-8 BOM
    if (text.size() >= 3 &&
        static_cast<uint8_t>(text[0]) == 0xEF &&
        static_cast<uint8_t>(text[1]) == 0xBB &&
        static_cast<uint8_t>(text[2]) == 0xBF) {
        return text.substr(3);
    }
    return text;
}

std::string TextService::normalize_line_endings(std::string_view text) { // LF, \n
    size_t cr = text.find('\r');
    if (cr == std::string_view::npos) { // No `\r` in text
        return std::string(text);
    }

    std::string out;
    out.reserve(text.size());
    size_t start = 0;
    while (cr != std::string_view::npos) {
        out.append(text.data() + start, cr - start);
        out.push_back('\n');
        start = cr + 1;
        if (start < text.size() && text[start] == '\n') {
            ++start;
        }
        cr = text.find('\r', start);
    }
    if (start < text.size()) { // the last block of text
        out.append(text.data() + start, text.size() - start);
    }
    return out;
}

std::string TextService::compute_text_hash(
    const std::string &format,
    const std::string &language,
    const std::string &normalized_utf8) {
    utils::Sha256 sha;
    const uint8_t nul = 0;
    sha.update(format);
    sha.update(&nul, 1);
    sha.update(language);
    sha.update(&nul, 1);
    sha.update(normalized_utf8);
    return sha.finalize();
}

std::string TextService::detect_lyrics_format(std::string_view content) {
    content = strip_utf8_bom(content);
    const size_t n = content.size();
    size_t line_start = 0;
    while (line_start < n) {
        size_t pos = line_start;
        while (pos < n && (content[pos] == ' ' || content[pos] == '\t')) { // Space or Tab
            ++pos;                                                         // skip
        }
        if (pos < n && is_lrc_timestamp_at(content, pos)) {
            return "lrc";
        }

        // find next line start
        line_start = content.find_first_of("\r\n", pos);
        if (line_start == std::string_view::npos) {
            break;
        }
        if (line_start < n && content[line_start] == '\r') {
            ++line_start;
        }
        if (line_start < n && content[line_start] == '\n') {
            ++line_start;
        }
    }
    return "txt";
}

TextService::TextService(
    IDatabaseContext &db_context,
    IAssetRepository &asset_repo,
    ITextRepository &text_repo,
    const std::string &storage_root)
    : m_db_context(db_context),
      m_asset_repo(asset_repo),
      m_text_repo(text_repo),
      m_storage_root(storage_root) {}

tl::expected<SaveTextResult, Error> TextService::save_text(const SaveTextRequest &req) {
    // 1. Fail-fast input validation BEFORE any database I/O
    if (auto entity_res = validate_strict_identifier(req.entity_id, "entity_id"); !entity_res) {
        return tl::unexpected(entity_res.error());
    }
    if (!is_valid_role(req.role)) {
        return tl::unexpected(Error{ErrorType::InvalidValue, "Invalid text role: " + req.role});
    }

    // Check of has_content & has_hash, XOR
    const bool has_content = req.content.has_value();
    const bool has_hash = req.text_hash.has_value();
    if (!has_content && !has_hash) {
        return tl::unexpected(Error{ErrorType::MissingParameter, "Must provide either 'content' or 'text_hash'."});
    }
    if (has_content && has_hash) {
        return tl::unexpected(Error{ErrorType::InvalidValue, "Cannot provide both 'content' and 'text_hash'."});
    }
    //

    std::string target_hash;
    std::string normalized;
    std::string lang;

    if (has_hash) {                                               // Attach mode
        if (req.format.has_value() || req.language.has_value()) { // Check if both `format` & `language` is false in request
            return tl::unexpected(Error{
                ErrorType::InvalidValue,
                "Cannot specify 'format' or 'language' when attaching an existing 'text_hash'."});
        }
        if (auto hash_res = validate_strict_identifier(*req.text_hash, "text_hash"); !hash_res) {
            return tl::unexpected(hash_res.error());
        }
        target_hash = *req.text_hash;
    } else {                           // Content mode
        if (!req.format.has_value()) { // Require `format`
            return tl::unexpected(Error{ErrorType::MissingParameter, "Missing required parameter 'format' when saving 'content'."});
        }
        if (!is_valid_format(*req.format)) { // format validation check
            return tl::unexpected(Error{ErrorType::InvalidValue, "Invalid text format: " + *req.format});
        }
        if (req.content->size() > MAX_TEXT_CONTENT_BYTES) { // size check
            return tl::unexpected(Error{
                ErrorType::OutOfRange,
                "Text content exceeds maximum allowed size of 2 MiB."});
        }
        if (!is_valid_utf8(*req.content)) { // content validation check
            return tl::unexpected(Error{ErrorType::InvalidValue, "Text content must be valid UTF-8 without NUL bytes."});
        }
        // Control character policy (Core vs. UI):
        // - Core (fail-fast): Reject all C0/C1 control chars except `\t`, `\n`, and `\r`.
        //   Dont strip or alter `content` silently, so the input always matches its computed `text_hash`.
        // - UI (proactive cleanup): Local `.lrc`/`.txt` imports or clipboard pastes may contain invisible
        //   control chars (e.g., `\x0B`/`\x0C` from PDF/Word, or `U+0080..U+009F` from CP1252 misread as Latin-1).
        //   Detect them upfront and prompt the user to strip them or convert them to newlines before saving.
        if (contains_control_chars(*req.content, /*allow_multiline_whitespace=*/true)) {
            return tl::unexpected(Error{
                ErrorType::InvalidValue,
                "Text content must not contain control characters other than tab, LF, or CR."});
        }

        normalized = normalize_line_endings(strip_utf8_bom(*req.content));
        if (normalized.find_first_not_of(" \t\n") == std::string::npos) {
            return tl::unexpected(Error{ErrorType::InvalidValue, "Text content cannot be blank."});
        }

        if (req.language.has_value()) {
            if (!is_valid_language(*req.language)) {
                return tl::unexpected(Error{
                    ErrorType::InvalidValue,
                    "Language must be valid UTF-8 (<= 64 bytes) without control characters."});
            }
            lang = trim_ascii_whitespace(*req.language);
            if (!req.language->empty() && lang.empty()) {
                return tl::unexpected(Error{ErrorType::InvalidValue, "Value of key 'language' should not be blank."});
            }
        }
    }

    // 2. Verify target entity exists (excluding 'tag').
    auto ent_exists_res = m_text_repo.entity_exists(req.entity_id);
    if (!ent_exists_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, ent_exists_res.error()});
    }
    if (!ent_exists_res.value()) {
        return tl::unexpected(Error{ErrorType::NotFound, "Entity not found: " + req.entity_id});
    }

    // Mode A: Attach an existing Text record by text_hash.
    if (has_hash) {
        auto existing_res = m_text_repo.get(target_hash);
        if (!existing_res) {
            return tl::unexpected(Error{ErrorType::DatabaseError, existing_res.error()});
        }
        if (!existing_res.value().has_value()) {
            return tl::unexpected(Error{ErrorType::NotFound, "Text not found: " + target_hash});
        }

        Text text = *existing_res.value();
        int existing_same_slot_count = 0;

        try {
            auto tx = m_db_context.begin_transaction();

            // For UI design: when `text.save` detects one or more existing entries with the same `role` + `language` (`existing_same_slot_count > 0`),
            // the UI should notify the user and allow them to select whether to delete them (by calling `text.unlink`).
            auto link_res = m_text_repo.link_entity(req.entity_id, text.text_hash, req.role);
            if (!link_res) {
                if (link_res.error().find("Entity not found") != std::string::npos ||
                    link_res.error().find("Text not found") != std::string::npos) {
                    return tl::unexpected(Error{ErrorType::NotFound, link_res.error()});
                }
                return tl::unexpected(Error{ErrorType::DatabaseError, link_res.error()});
            }

            auto count_res = m_text_repo.count_entity_texts_by_slot(
                req.entity_id, req.role, text.language, text.text_hash);
            if (!count_res) {
                return tl::unexpected(Error{ErrorType::DatabaseError, count_res.error()});
            }
            existing_same_slot_count = count_res.value();

            tx->commit();
        } catch (const std::exception &e) {
            return tl::unexpected(Error{ErrorType::DatabaseError, e.what()});
        }

        text.role = req.role;
        return SaveTextResult{std::move(text), existing_same_slot_count};
    }

    // Mode B: Store new UTF-8 content into CAS and link to entity.
    const std::string file_hash = utils::Sha256::hash_string(normalized);
    const std::string text_hash = compute_text_hash(*req.format, lang, normalized);
    const std::string ext = extension_for_format(*req.format);
    const auto cas_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root, file_hash);
    const std::filesystem::path target_path = utils::StorageHelper::resolve_cas_path(m_storage_root, file_hash, ext);

    std::filesystem::path staged_temp_path;
    std::unique_ptr<utils::TempCleanup> temp_cleanup;
    auto stage_temp_file = [&]() -> tl::expected<void, Error> {
        if (!staged_temp_path.empty()) {
            return {};
        }
        const std::filesystem::path tmp = utils::StorageHelper::generate_temp_path(m_storage_root, ext);
        auto cleanup_guard = std::make_unique<utils::TempCleanup>(tmp);

        try {
            std::filesystem::create_directories(tmp.parent_path());
        } catch (const std::exception &e) {
            return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to prepare temp directory: " + std::string(e.what())});
        }

        {
            std::ofstream out(tmp, std::ios::binary);
            if (!out.is_open()) {
                return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to open temporary text file for writing."});
            }
            out.write(normalized.data(), static_cast<std::streamsize>(normalized.size()));
            out.flush();
            if (!out.good()) {
                return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to write text content to temporary file."});
            }
        }

        staged_temp_path = tmp;
        temp_cleanup = std::move(cleanup_guard);
        return {};
    };

    // Fast-path hint: stage temp file outside SQLite's write lock when CAS blob appears absent.
    {
        auto hint_match = utils::StorageHelper::find_file_by_prefix(cas_dir, file_hash);
        std::error_code hint_ec;
        if (!hint_match.has_value() || !std::filesystem::exists(hint_match.value(), hint_ec) || hint_ec) {
            if (auto stage_res = stage_temp_file(); !stage_res) {
                return tl::unexpected(stage_res.error());
            }
        }
    }

    Text text;
    text.text_hash = text_hash;
    text.file_hash = file_hash;
    text.language = lang;
    text.encoding = "utf-8";
    text.format = *req.format;
    text.role = req.role;

    int existing_same_slot_count = 0;

    struct CasRollbackGuard {
        bool active = false;
        std::filesystem::path path;
        ~CasRollbackGuard() noexcept {
            if (active && !path.empty()) {
                std::error_code ec;
                std::filesystem::remove(path, ec);
            }
        }
    };

    try {
        // Acquire BEGIN IMMEDIATE first so CAS presence check, publication, DB writes, and
        // rollback orphan removal are serialized across threads and processes (no TOCTOU).
        auto tx = m_db_context.begin_transaction();
        CasRollbackGuard cas_guard;

        auto asset_existed_res = m_asset_repo.exists(file_hash);
        if (!asset_existed_res) {
            return tl::unexpected(Error{ErrorType::DatabaseError, "Failed to query Asset existence: " + asset_existed_res.error()});
        }
        const bool asset_existed_in_db = asset_existed_res.value();

        auto disk_match = utils::StorageHelper::find_file_by_prefix(cas_dir, file_hash);
        bool disk_exists = false;
        if (disk_match.has_value()) {
            std::error_code exist_ec;
            bool exists = std::filesystem::exists(disk_match.value(), exist_ec);
            if (exist_ec) {
                return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to inspect CAS file: " + exist_ec.message()});
            }
            disk_exists = exists;
        } else if (disk_match.error().find("Failed to ") != std::string::npos) {
            return tl::unexpected(Error{ErrorType::OperationFailed, disk_match.error()});
        }

        if (!disk_exists) {
            if (auto stage_res = stage_temp_file(); !stage_res) {
                return tl::unexpected(stage_res.error());
            }
            auto move_res = utils::StorageHelper::move_to_cas_if_absent(staged_temp_path, target_path);
            if (!move_res.has_value()) {
                return tl::unexpected(Error{ErrorType::OperationFailed, move_res.error()});
            }
            if (temp_cleanup) {
                temp_cleanup->dismiss();
            }
            if (move_res.value() && !asset_existed_in_db) {
                cas_guard.active = true;
                cas_guard.path = target_path;
            }
        }

        Asset asset;
        asset.file_hash = file_hash;
        asset.mime_type = mime_type_for_format(*req.format);
        asset.asset_type = "text";
        asset.file_size = static_cast<int>(normalized.size());

        auto asset_res = m_asset_repo.insert_if_absent(asset);
        if (!asset_res) {
            return tl::unexpected(Error{ErrorType::DatabaseError, "Failed to insert Asset: " + asset_res.error()});
        }

        auto text_res = m_text_repo.insert(text);
        if (!text_res) {
            return tl::unexpected(Error{ErrorType::DatabaseError, "Failed to insert Text: " + text_res.error()});
        }

        // For UI design: when `text.save` detects one or more existing entries with the same `role` + `language` (`existing_same_slot_count > 0`),
        // the UI should notify the user and allow them to select whether to delete them (by calling `text.unlink`).
        auto link_res = m_text_repo.link_entity(req.entity_id, text.text_hash, req.role);
        if (!link_res) {
            if (link_res.error().find("Entity not found") != std::string::npos ||
                link_res.error().find("Text not found") != std::string::npos) {
                return tl::unexpected(Error{ErrorType::NotFound, link_res.error()});
            }
            return tl::unexpected(Error{ErrorType::DatabaseError, "Failed to link Entity_Text: " + link_res.error()});
        }

        auto count_res = m_text_repo.count_entity_texts_by_slot(
            req.entity_id, req.role, lang, text.text_hash);
        if (!count_res) {
            return tl::unexpected(Error{ErrorType::DatabaseError, count_res.error()});
        }
        existing_same_slot_count = count_res.value();

        // Disarm CAS orphan cleanup BEFORE commit(); never unlink after releasing BEGIN IMMEDIATE.
        cas_guard.active = false;
        tx->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(Error{ErrorType::DatabaseError, e.what()});
    }

    return SaveTextResult{std::move(text), existing_same_slot_count};
}

tl::expected<std::string, Error> TextService::read_cas_content(const std::string &file_hash) const {
    const auto cas_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root, file_hash);
    auto find_res = utils::StorageHelper::find_file_by_prefix(cas_dir, file_hash);
    if (!find_res.has_value()) {
        if (find_res.error().find("Failed to ") != std::string::npos) {
            return tl::unexpected(Error{ErrorType::OperationFailed, find_res.error()});
        }
        return tl::unexpected(Error{ErrorType::AssetNotFound, "CAS text file missing for file_hash: " + file_hash});
    }
    std::error_code ec;
    const bool file_exists = std::filesystem::exists(find_res.value(), ec);
    if (ec) {
        return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to inspect CAS text file: " + ec.message()});
    }
    if (!file_exists) {
        return tl::unexpected(Error{ErrorType::AssetNotFound, "CAS text file missing for file_hash: " + file_hash});
    }

    const std::filesystem::path path(find_res.value());
    auto size_res = utils::StorageHelper::get_file_size(path);
    if (!size_res) {
        return tl::unexpected(Error{ErrorType::OperationFailed, size_res.error()});
    }
    if (size_res.value() > MAX_TEXT_CONTENT_BYTES) {
        return tl::unexpected(Error{ErrorType::OutOfRange, "CAS text file exceeds maximum allowed size of 2 MiB."});
    }

    std::ifstream in(path, std::ios::binary);
    if (!in.is_open()) {
        return tl::unexpected(Error{ErrorType::OperationFailed, "Failed to open CAS text file: " + path.string()});
    }

    std::string content(static_cast<size_t>(size_res.value()), '\0');
    if (!content.empty()) {
        in.read(content.data(), static_cast<std::streamsize>(content.size()));
        if (in.bad() || static_cast<uintmax_t>(in.gcount()) != size_res.value()) {
            return tl::unexpected(Error{ErrorType::OperationFailed, "Failed or truncated read of CAS text file: " + path.string()});
        }
    }

    if (!is_valid_utf8(content)) {
        return tl::unexpected(Error{ErrorType::OperationFailed, "Corrupted stored CAS text file (invalid UTF-8)."});
    }

    return content;
}

tl::expected<TextContentResult, Error> TextService::get_text_by_hash(const std::string &text_hash) {
    if (auto hash_res = validate_strict_identifier(text_hash, "text_hash"); !hash_res) {
        return tl::unexpected(hash_res.error());
    }

    auto text_res = m_text_repo.get(text_hash);
    if (!text_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, text_res.error()});
    }
    if (!text_res.value().has_value()) {
        return tl::unexpected(Error{ErrorType::NotFound, "Text not found: " + text_hash});
    }

    auto content_res = read_cas_content(text_res.value()->file_hash);
    if (!content_res) {
        return tl::unexpected(content_res.error());
    }

    return TextContentResult{*text_res.value(), std::move(content_res.value())};
}

tl::expected<TextContentResult, Error> TextService::get_entity_text(
    const std::string &entity_id,
    const std::optional<std::string> &role,
    const std::optional<std::string> &language) {
    if (auto entity_res = validate_strict_identifier(entity_id, "entity_id"); !entity_res) {
        return tl::unexpected(entity_res.error());
    }
    if (role.has_value() && !is_valid_role(*role)) {
        return tl::unexpected(Error{ErrorType::InvalidValue, "Invalid text role: " + *role});
    }
    auto lang_filter = validate_optional_language_filter(language);
    if (!lang_filter) {
        return tl::unexpected(lang_filter.error());
    }

    auto exists_res = m_text_repo.entity_exists(entity_id);
    if (!exists_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, exists_res.error()});
    }
    if (!exists_res.value()) {
        return tl::unexpected(Error{ErrorType::NotFound, "Entity not found: " + entity_id});
    }

    auto matches_res = m_text_repo.get_texts_by_entity(entity_id, role, *lang_filter);
    if (!matches_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, matches_res.error()});
    }

    const auto &matches = matches_res.value();
    if (matches.empty()) {
        return tl::unexpected(Error{ErrorType::NotFound, "No matching text found for entity: " + entity_id});
    }
    if (matches.size() > 1) {
        return tl::unexpected(Error{
            ErrorType::Conflict,
            "Multiple matching texts found for entity '" + entity_id +
                "'. Specify 'role'/'language' or call 'text.get_entity_texts' and fetch by 'text_hash'."});
    }

    auto content_res = read_cas_content(matches[0].file_hash);
    if (!content_res) {
        return tl::unexpected(content_res.error());
    }

    return TextContentResult{matches[0], std::move(content_res.value())};
}

tl::expected<std::vector<Text>, Error> TextService::get_entity_texts(
    const std::string &entity_id,
    const std::optional<std::string> &role,
    const std::optional<std::string> &language) {
    if (auto entity_res = validate_strict_identifier(entity_id, "entity_id"); !entity_res) {
        return tl::unexpected(entity_res.error());
    }
    if (role.has_value() && !is_valid_role(*role)) {
        return tl::unexpected(Error{ErrorType::InvalidValue, "Invalid text role: " + *role});
    }
    auto lang_filter = validate_optional_language_filter(language);
    if (!lang_filter) {
        return tl::unexpected(lang_filter.error());
    }

    auto exists_res = m_text_repo.entity_exists(entity_id);
    if (!exists_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, exists_res.error()});
    }
    if (!exists_res.value()) {
        return tl::unexpected(Error{ErrorType::NotFound, "Entity not found: " + entity_id});
    }

    auto texts_res = m_text_repo.get_texts_by_entity(entity_id, role, *lang_filter);
    if (!texts_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, texts_res.error()});
    }

    return texts_res.value();
}

tl::expected<void, Error> TextService::unlink_entity_text(
    const std::string &entity_id,
    const std::string &text_hash) {
    if (auto entity_res = validate_strict_identifier(entity_id, "entity_id"); !entity_res) {
        return tl::unexpected(entity_res.error());
    }
    if (auto hash_res = validate_strict_identifier(text_hash, "text_hash"); !hash_res) {
        return tl::unexpected(hash_res.error());
    }

    auto res = m_text_repo.unlink_entity(entity_id, text_hash);
    if (!res) {
        if (res.error().find("Entity not found") != std::string::npos) {
            return tl::unexpected(Error{ErrorType::NotFound, "Entity not found: " + entity_id});
        }
        if (res.error().find("Relation not found") != std::string::npos) {
            return tl::unexpected(Error{ErrorType::RelationNotFound, "Relation between Entity and Text not found."});
        }
        return tl::unexpected(Error{ErrorType::DatabaseError, res.error()});
    }
    return {};
}

} // namespace lyra
