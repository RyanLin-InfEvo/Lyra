// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "../src/models/asset.h"
#include "../src/models/track.h"
#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_text_repository.h"
#include "../src/services/repositories/sqlite/sqlite_track_repository.h"
#include "../src/services/text_service.h"
#include "../src/utils/audio_helper.h"
#include "../src/utils/sha256.h"
#include "../src/utils/storage_helper.h"
#include "../src/utils/uuid_generator.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

using namespace lyra;

namespace {

bool check(bool cond, const std::string &msg) {
    if (!cond) {
        std::cerr << "FAILED: " << msg << "\n";
        return false;
    }
    return true;
}

struct TempDirGuard {
    std::filesystem::path path;
    explicit TempDirGuard(const std::string &name)
        : path(std::filesystem::temp_directory_path() / (name + "_" + UuidGenerator::generate_v4())) {
        std::filesystem::create_directories(path);
    }
    ~TempDirGuard() {
        std::error_code ec;
        std::filesystem::remove_all(path, ec);
    }
};

void append_synchsafe_u32(std::vector<uint8_t> &buf, uint32_t size) {
    buf.push_back(static_cast<uint8_t>((size >> 21) & 0x7F));
    buf.push_back(static_cast<uint8_t>((size >> 14) & 0x7F));
    buf.push_back(static_cast<uint8_t>((size >> 7) & 0x7F));
    buf.push_back(static_cast<uint8_t>(size & 0x7F));
}

void append_id3v24_uslt_frame(std::vector<uint8_t> &frames, const std::array<char, 3> &lang, const std::string &desc,
                              const std::string &text) {
    const uint32_t payload_size = static_cast<uint32_t>(1 + 3 + desc.size() + 1 + text.size());
    frames.push_back('U');
    frames.push_back('S');
    frames.push_back('L');
    frames.push_back('T');
    append_synchsafe_u32(frames, payload_size);
    frames.push_back(0x00);
    frames.push_back(0x00);
    frames.push_back(0x03); // UTF-8
    frames.push_back(static_cast<uint8_t>(lang[0]));
    frames.push_back(static_cast<uint8_t>(lang[1]));
    frames.push_back(static_cast<uint8_t>(lang[2]));
    frames.insert(frames.end(), desc.begin(), desc.end());
    frames.push_back(0x00);
    frames.insert(frames.end(), text.begin(), text.end());
}

bool write_mp3_with_id3v24_uslt(const std::string &base_mp3_path, const std::string &out_mp3_path,
                                const std::vector<uint8_t> &frames) {
    std::ifstream in(base_mp3_path, std::ios::binary | std::ios::ate);
    if (!in) return false;
    const std::streamsize total_size = in.tellg();
    if (total_size < 0) return false;
    in.seekg(0, std::ios::beg);
    std::vector<uint8_t> audio(static_cast<size_t>(total_size));
    if (total_size > 0 && !in.read(reinterpret_cast<char *>(audio.data()), total_size)) return false;

    size_t offset = 0;
    if (audio.size() >= 10 && audio[0] == 'I' && audio[1] == 'D' && audio[2] == '3') {
        const size_t tag_size = (static_cast<size_t>(audio[6] & 0x7F) << 21) |
                                (static_cast<size_t>(audio[7] & 0x7F) << 14) |
                                (static_cast<size_t>(audio[8] & 0x7F) << 7) | static_cast<size_t>(audio[9] & 0x7F);
        if (10 + tag_size <= audio.size()) {
            offset = 10 + tag_size;
        }
    }

    std::vector<uint8_t> header = {'I', 'D', '3', 0x04, 0x00, 0x00};
    append_synchsafe_u32(header, static_cast<uint32_t>(frames.size()));

    std::ofstream out(out_mp3_path, std::ios::binary | std::ios::trunc);
    if (!out) return false;
    out.write(reinterpret_cast<const char *>(header.data()), static_cast<std::streamsize>(header.size()));
    out.write(reinterpret_cast<const char *>(frames.data()), static_cast<std::streamsize>(frames.size()));
    if (offset < audio.size()) {
        out.write(reinterpret_cast<const char *>(audio.data() + offset),
                  static_cast<std::streamsize>(audio.size() - offset));
    }
    return out.good();
}

bool test_schema_indexes_and_constraints(const std::filesystem::path &root) {
    const std::string db_path = (root / "schema.db").string();
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    const char *tables[] = {"Text", "Entity_Text"};
    for (const char *tbl : tables) {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='table' AND name=?");
        q.bind(1, tbl);
        if (!check(q.executeStep(), std::string("Missing table: ") + tbl)) return false;
    }

    const char *indexes[] = {"idx_Text_file_hash", "idx_EntityText_text_hash", "idx_EntityText_entity_role"};
    for (const char *idx : indexes) {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='index' AND name=?");
        q.bind(1, idx);
        if (!check(q.executeStep(), std::string("Missing index: ") + idx)) return false;
    }

    SQLite::Statement idx_cols(db, "PRAGMA index_info('idx_EntityText_entity_role')");
    std::vector<std::string> entity_role_cols;
    while (idx_cols.executeStep()) {
        entity_role_cols.push_back(idx_cols.getColumn(2).getString());
    }
    if (!check(entity_role_cols == std::vector<std::string>{"entity_id", "role", "text_hash"},
               "idx_EntityText_entity_role must cover (entity_id, role, text_hash)"))
        return false;

    SqliteAssetRepository asset_repo(ctx);
    SqliteTextRepository text_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    Asset asset;
    asset.file_hash = "1111111111111111111111111111111111111111111111111111111111111111";
    asset.mime_type = "text/plain";
    asset.asset_type = "text";
    asset.file_size = 10;
    if (!check(asset_repo.insert(asset).has_value(), "asset insert failed")) return false;

    // Invalid format must fail CHECK constraint (ON CONFLICT DO NOTHING must not swallow it)
    Text bad_fmt;
    bad_fmt.text_hash = "2222222222222222222222222222222222222222222222222222222222222222";
    bad_fmt.file_hash = asset.file_hash;
    bad_fmt.format = "pdf";
    auto bad_fmt_res = text_repo.insert(bad_fmt);
    if (!check(!bad_fmt_res.has_value(), "invalid format 'pdf' must fail CHECK constraint")) return false;

    // Valid text insert
    Text good_txt;
    good_txt.text_hash = "3333333333333333333333333333333333333333333333333333333333333333";
    good_txt.file_hash = asset.file_hash;
    good_txt.format = "txt";
    good_txt.language = "zh-TW";
    if (!check(text_repo.insert(good_txt).has_value(), "valid text insert failed")) return false;

    // Create Track entity
    Track track;
    track.id = UuidGenerator::generate_v4();
    track.pcm_hash = "4444444444444444444444444444444444444444444444444444444444444444";
    track.title = "Test Track";
    if (!check(track_repo.insert(track).has_value(), "track insert failed")) return false;

    // Invalid role must fail CHECK constraint
    auto bad_role_res = text_repo.link_entity(track.id, good_txt.text_hash, "invalid_role");
    if (!check(!bad_role_res.has_value(), "invalid role must fail CHECK constraint")) return false;

    // Valid link + ON DELETE CASCADE on Entity
    if (!check(text_repo.link_entity(track.id, good_txt.text_hash, "lyrics").has_value(), "valid link failed"))
        return false;

    {
        SQLite::Statement del_ent(db, "DELETE FROM Entity WHERE id = ?");
        del_ent.bind(1, track.id);
        if (!check(del_ent.exec() == 1, "entity delete failed")) return false;
    }
    {
        SQLite::Statement chk_rel(db, "SELECT COUNT(*) FROM Entity_Text WHERE entity_id = ?");
        chk_rel.bind(1, track.id);
        if (!check(chk_rel.executeStep() && chk_rel.getColumn(0).getInt() == 0,
                   "Entity_Text should cascade delete when Entity is deleted"))
            return false;
    }

    // Re-link to another track and test ON DELETE CASCADE when Asset is deleted
    Track track2;
    track2.id = UuidGenerator::generate_v4();
    track2.pcm_hash = "5555555555555555555555555555555555555555555555555555555555555555";
    track2.title = "Test Track 2";
    if (!check(track_repo.insert(track2).has_value(), "track2 insert failed")) return false;
    if (!check(text_repo.link_entity(track2.id, good_txt.text_hash, "lyrics").has_value(), "link2 failed"))
        return false;

    {
        SQLite::Statement del_asset(db, "DELETE FROM Asset WHERE file_hash = ?");
        del_asset.bind(1, asset.file_hash);
        if (!check(del_asset.exec() == 1, "asset delete failed")) return false;
    }
    if (!check(!text_repo.exists(good_txt.text_hash).value_or(true),
               "Text should cascade delete when Asset is deleted"))
        return false;
    {
        SQLite::Statement chk_rel2(db, "SELECT COUNT(*) FROM Entity_Text WHERE entity_id = ?");
        chk_rel2.bind(1, track2.id);
        if (!check(chk_rel2.executeStep() && chk_rel2.getColumn(0).getInt() == 0,
                   "Entity_Text should cascade delete when Text is cascade deleted"))
            return false;
    }

    return true;
}

bool test_normalization_utf8_and_three_layer_dedup(const std::filesystem::path &root) {
    const std::string storage_root = (root / "storage").string();
    std::filesystem::create_directories(storage_root);
    const std::string db_path = (root / "storage" / "lyra.db").string();

    SqliteDatabaseContext ctx(db_path);
    SqliteAssetRepository asset_repo(ctx);
    SqliteTextRepository text_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    TextService service(ctx, asset_repo, text_repo, storage_root);

    Track track;
    track.id = UuidGenerator::generate_v4();
    track.pcm_hash = "6666666666666666666666666666666666666666666666666666666666666666";
    track.title = "UTF-8 Track";
    if (!check(track_repo.insert(track).has_value(), "track insert failed")) return false;

    const std::string crlf_lyrics = "[00:01.00]繁體中文歌詞 🎵\r\n[00:05.50]第二行\r[00:10.00]日本語テキスト";
    const std::string lf_lyrics = "[00:01.00]繁體中文歌詞 🎵\n[00:05.50]第二行\n[00:10.00]日本語テキスト";

    // 1. Save CRLF+CR content as lrc (zh-TW)
    SaveTextRequest req1;
    req1.entity_id = track.id;
    req1.role = "lyrics";
    req1.content = crlf_lyrics;
    req1.format = "lrc";
    req1.language = "zh-TW";
    auto res1 = service.save_text(req1);
    if (!check(res1.has_value(), "save_text req1 failed: " + (res1 ? "" : res1.error().message))) return false;
    if (!check(res1->existing_same_slot_count == 0, "first save should have 0 existing same slot")) return false;

    // 2. Save LF-only identical content with same format & language -> exact same text_hash & file_hash
    SaveTextRequest req2 = req1;
    req2.content = lf_lyrics;
    auto res2 = service.save_text(req2);
    if (!check(res2.has_value(), "save_text req2 failed")) return false;
    if (!check(res2->text.file_hash == res1->text.file_hash, "CRLF/CR/LF must produce identical file_hash"))
        return false;
    if (!check(res2->text.text_hash == res1->text.text_hash, "CRLF/CR/LF must produce identical text_hash"))
        return false;

    // 3. Save identical bytes as format='txt', language='ja' -> SAME file_hash, DIFFERENT text_hash, ONLY ONE CAS file on disk
    SaveTextRequest req3;
    req3.entity_id = track.id;
    req3.role = "lyrics_translation";
    req3.content = lf_lyrics;
    req3.format = "txt";
    req3.language = "ja";
    auto res3 = service.save_text(req3);
    if (!check(res3.has_value(), "save_text req3 failed")) return false;
    if (!check(res3->text.file_hash == res1->text.file_hash, "same UTF-8 bytes must share file_hash")) return false;
    if (!check(res3->text.text_hash != res1->text.text_hash, "different format/language must produce distinct text_hash"))
        return false;

    const auto cas_dir = utils::StorageHelper::resolve_cas_dir(storage_root, res1->text.file_hash);
    int physical_count = 0;
    for (const auto &entry : std::filesystem::directory_iterator(cas_dir)) {
        if (entry.is_regular_file() &&
            entry.path().filename().string().rfind(res1->text.file_hash, 0) == 0) {
            ++physical_count;
        }
    }
    if (!check(physical_count == 1, "expected exactly 1 physical CAS file in objects/xx/yy/, got " + std::to_string(physical_count)))
        return false;

    // Read back both via text_hash
    auto got1 = service.get_text_by_hash(res1->text.text_hash);
    if (!check(got1.has_value() && got1->content == lf_lyrics, "roundtrip normalized UTF-8 content mismatch for res1"))
        return false;
    auto got3 = service.get_text_by_hash(res3->text.text_hash);
    if (!check(got3.has_value() && got3->content == lf_lyrics, "roundtrip normalized UTF-8 content mismatch for res3"))
        return false;

    // 4. Reject invalid UTF-8 and embedded NUL without creating orphan CAS files
    const std::string bad_utf8("\xFF\xFE\x80", 3);
    const std::string bad_utf8_hash = utils::Sha256::hash_string(bad_utf8);
    SaveTextRequest req_bad_utf8{track.id, "lyrics", bad_utf8, std::nullopt, "txt", std::nullopt};
    auto res_bad_utf8 = service.save_text(req_bad_utf8);
    if (!check(!res_bad_utf8.has_value() && res_bad_utf8.error().type == ErrorType::InvalidValue,
               "invalid UTF-8 must be rejected with InvalidValue"))
        return false;
    if (!check(!std::filesystem::exists(utils::StorageHelper::resolve_cas_path(storage_root, bad_utf8_hash, ".txt")),
               "invalid UTF-8 must not write any CAS file"))
        return false;

    const std::string with_nul = std::string("abc") + '\0' + "def";
    SaveTextRequest req_nul{track.id, "lyrics", with_nul, std::nullopt, "txt", std::nullopt};
    auto res_nul = service.save_text(req_nul);
    if (!check(!res_nul.has_value() && res_nul.error().type == ErrorType::InvalidValue,
               "embedded NUL byte must be rejected with InvalidValue"))
        return false;

    // 5. Reject overlong UTF-8 and UTF-16 surrogate
    const std::string overlong("\xC0\xAF", 2);
    const std::string surrogate("\xED\xA0\x80", 3);
    if (!check(!TextService::is_valid_utf8(overlong), "overlong UTF-8 must be rejected")) return false;
    if (!check(!TextService::is_valid_utf8(surrogate), "UTF-16 surrogate must be rejected")) return false;

    // 6. [LOW-2] BOM stripping & BOM+whitespace rejection
    SaveTextRequest req_bom_ws{track.id, "lyrics", std::string("\xEF\xBB\xBF   \r\n\t "), std::nullopt, "txt", std::nullopt};
    auto res_bom_ws = service.save_text(req_bom_ws);
    if (!check(!res_bom_ws.has_value() && res_bom_ws.error().type == ErrorType::InvalidValue,
               "BOM + whitespace-only content must be rejected"))
        return false;

    SaveTextRequest req_bom{track.id, "other", std::string("\xEF\xBB\xBF") + lf_lyrics, std::nullopt, "lrc", "zh-TW"};
    auto res_bom = service.save_text(req_bom);
    if (!check(res_bom.has_value(), "BOM-prefixed save failed")) return false;
    if (!check(res_bom->text.file_hash == res1->text.file_hash && res_bom->text.text_hash == res1->text.text_hash,
               "UTF-8 BOM must be stripped so hashes match non-BOM"))
        return false;

    // 7. [HIGH-2] & [LOW-1] Language validation (embedded NUL, control chars, invalid UTF-8, > 64 bytes, whitespace-only)
    auto res_lang_ws = service.save_text(SaveTextRequest{track.id, "lyrics", "Hi", std::nullopt, "txt", std::string("   ")});
    if (!check(!res_lang_ws.has_value() && res_lang_ws.error().type == ErrorType::InvalidValue,
               "whitespace-only non-empty language must be rejected"))
        return false;
    auto res_lang_nul = service.save_text(SaveTextRequest{track.id, "lyrics", "Hi", std::nullopt, "txt", std::string("en\0x", 4)});
    if (!check(!res_lang_nul.has_value() && res_lang_nul.error().type == ErrorType::InvalidValue,
               "language with NUL byte must be rejected"))
        return false;
    auto res_lang_ctrl = service.save_text(SaveTextRequest{track.id, "lyrics", "Hi", std::nullopt, "txt", std::string("en\x01")});
    if (!check(!res_lang_ctrl.has_value() && res_lang_ctrl.error().type == ErrorType::InvalidValue,
               "language with control char must be rejected"))
        return false;
    auto res_lang_utf8 = service.save_text(SaveTextRequest{track.id, "lyrics", "Hi", std::nullopt, "txt", std::string("\xFF\xFE")});
    if (!check(!res_lang_utf8.has_value() && res_lang_utf8.error().type == ErrorType::InvalidValue,
               "language with invalid UTF-8 must be rejected"))
        return false;
    auto res_lang_long = service.save_text(SaveTextRequest{track.id, "lyrics", "Hi", std::nullopt, "txt", std::string(65, 'a')});
    if (!check(!res_lang_long.has_value() && res_lang_long.error().type == ErrorType::InvalidValue,
               "language > 64 bytes must be rejected"))
        return false;

    // 8. [HIGH-3] Untagged language ("") filtering alongside tagged language
    Track track_untagged;
    track_untagged.id = UuidGenerator::generate_v4();
    track_untagged.pcm_hash = "7777777777777777777777777777777777777777777777777777777777777777";
    track_untagged.title = "Untagged Filter Track";
    if (!check(track_repo.insert(track_untagged).has_value(), "track_untagged insert failed")) return false;
    auto u_none = service.save_text(SaveTextRequest{track_untagged.id, "lyrics", "Untagged lyric", std::nullopt, "txt", std::nullopt});
    auto u_en = service.save_text(SaveTextRequest{track_untagged.id, "lyrics", "English lyric", std::nullopt, "txt", "en"});
    if (!check(u_none.has_value() && u_en.has_value(), "untagged filter setup failed")) return false;

    auto only_untagged = service.get_entity_texts(track_untagged.id, std::string("lyrics"), std::string(""));
    if (!check(only_untagged.has_value() && only_untagged->size() == 1 &&
                   only_untagged->at(0).text_hash == u_none->text.text_hash,
               "get_entity_texts with empty string language must return only untagged slot"))
        return false;
    auto single_untagged = service.get_entity_text(track_untagged.id, std::string("lyrics"), std::string(""));
    if (!check(single_untagged.has_value() && single_untagged->content == "Untagged lyric",
               "get_entity_text with empty string language must disambiguate untagged lyric"))
        return false;

    // 9. [MED-4] Fail-fast validation ordering and C++ blank text_hash guards
    auto fail_fast = service.save_text(SaveTextRequest{UuidGenerator::generate_v4(), "lyrics", "   ", std::nullopt, "txt", std::nullopt});
    if (!check(!fail_fast.has_value() && fail_fast.error().type == ErrorType::InvalidValue,
               "blank content with nonexistent entity_id must fail fast with InvalidValue"))
        return false;
    auto blank_get = service.get_text_by_hash("   ");
    if (!check(!blank_get.has_value() && blank_get.error().type == ErrorType::InvalidValue,
               "blank text_hash in get_text_by_hash must return InvalidValue"))
        return false;
    auto blank_unlink = service.unlink_entity_text(track.id, "   ");
    if (!check(!blank_unlink.has_value() && blank_unlink.error().type == ErrorType::InvalidValue,
               "blank text_hash in unlink_entity_text must return InvalidValue"))
        return false;

    // 10. [MED-5] Corrupted CAS UTF-8 returns OperationFailed (not InvalidValue)
    {
        auto disk_file = utils::StorageHelper::find_file_by_prefix(
            utils::StorageHelper::resolve_cas_dir(storage_root, u_none->text.file_hash),
            u_none->text.file_hash);
        if (!check(disk_file.has_value(), "expected CAS file on disk for corruption test")) return false;
        {
            std::ofstream corrupt_out(*disk_file, std::ios::binary | std::ios::trunc);
            corrupt_out.write("\xFF\xFE\x80", 3);
        }
        auto corrupt_res = service.get_text_by_hash(u_none->text.text_hash);
        if (!check(!corrupt_res.has_value() && corrupt_res.error().type == ErrorType::OperationFailed,
                   "corrupted CAS UTF-8 file must return OperationFailed"))
            return false;
    }

    return true;
}

bool test_crit1_self_heal_and_concurrent_cas(const std::filesystem::path &root) {
    const std::string storage_root = (root / "concurrent_storage").string();
    std::filesystem::create_directories(storage_root);
    const std::string db_path = (root / "concurrent_storage" / "lyra.db").string();

    SqliteDatabaseContext ctx(db_path);
    SqliteAssetRepository asset_repo(ctx);
    SqliteTextRepository text_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    TextService service(ctx, asset_repo, text_repo, storage_root);

    // Test A: Asset row exists in DB, but physical CAS file is missing -> save_text must self-heal CAS blob
    Track heal_track;
    heal_track.id = UuidGenerator::generate_v4();
    heal_track.pcm_hash = "8888888888888888888888888888888888888888888888888888888888888888";
    heal_track.title = "Self Heal Track";
    if (!check(track_repo.insert(heal_track).has_value(), "heal_track insert failed")) return false;

    const std::string heal_content = "Self heal lyrics content";
    const std::string heal_file_hash = utils::Sha256::hash_string(heal_content);
    Asset orphan_db_asset;
    orphan_db_asset.file_hash = heal_file_hash;
    orphan_db_asset.mime_type = "text/plain";
    orphan_db_asset.asset_type = "text";
    orphan_db_asset.file_size = static_cast<int>(heal_content.size());
    if (!check(asset_repo.insert(orphan_db_asset).has_value(), "orphan db asset insert failed")) return false;

    auto heal_save = service.save_text(SaveTextRequest{heal_track.id, "lyrics", heal_content, std::nullopt, "txt", std::nullopt});
    if (!check(heal_save.has_value(), "save_text with existing DB Asset failed")) return false;
    auto heal_read = service.get_text_by_hash(heal_save->text.text_hash);
    if (!check(heal_read.has_value() && heal_read->content == heal_content,
               "CRIT-1 Test A failed: CAS file was not healed when Asset row already existed"))
        return false;

    // Test B: [HIGH-1] Cross-format concurrent identical saves across 8 threads (same file_hash, mixed formats)
    constexpr int kThreads = 8;
    const std::array<const char *, kThreads> langs = {"en", "ja", "fr", "de", "ko", "zh-TW", "es", "it"};
    const std::array<const char *, kThreads> fmts = {"lrc", "txt", "srt", "ttml", "lrc", "txt", "srt", "ttml"};
    std::vector<Track> tracks;
    for (int i = 0; i < kThreads; ++i) {
        Track t;
        t.id = UuidGenerator::generate_v4();
        t.pcm_hash = "999999999999999999999999999999999999999999999999999999999999999" + std::to_string(i);
        t.title = "Concurrent Track " + std::to_string(i);
        if (!check(track_repo.insert(t).has_value(), "concurrent track insert failed")) return false;
        tracks.push_back(t);
    }

    const std::string shared_content = "[00:01.00]Concurrent Shared Lyrics Line\n[00:05.00]Second Line";
    const std::string shared_file_hash = utils::Sha256::hash_string(shared_content);
    std::vector<tl::expected<SaveTextResult, Error>> results(kThreads, tl::unexpected(Error{ErrorType::DatabaseError, "uninit"}));
    std::vector<std::thread> workers;
    for (int i = 0; i < kThreads; ++i) {
        workers.emplace_back([&, i]() {
            SqliteAssetRepository t_asset_repo(ctx);
            SqliteTextRepository t_text_repo(ctx);
            TextService t_service(ctx, t_asset_repo, t_text_repo, storage_root);
            results[i] = t_service.save_text(
                SaveTextRequest{tracks[i].id, "lyrics", shared_content, std::nullopt, std::string(fmts[i]), std::string(langs[i])});
        });
    }
    for (auto &w : workers) {
        w.join();
    }

    for (int i = 0; i < kThreads; ++i) {
        if (!check(results[i].has_value(),
                   "HIGH-1 Test B failed on thread " + std::to_string(i) + ": " +
                       (results[i] ? "" : results[i].error().message)))
            return false;
        auto got = service.get_text_by_hash(results[i]->text.text_hash);
        if (!check(got.has_value() && got->content == shared_content,
                   "HIGH-1 Test B failed: CAS blob corrupted/deleted after concurrent save on thread " + std::to_string(i)))
            return false;
    }

    const auto shared_cas_dir = utils::StorageHelper::resolve_cas_dir(storage_root, shared_file_hash);
    int physical_count = 0;
    for (const auto &entry : std::filesystem::directory_iterator(shared_cas_dir)) {
        if (entry.is_regular_file() &&
            entry.path().filename().string().rfind(shared_file_hash, 0) == 0) {
            ++physical_count;
        }
    }
    if (!check(physical_count == 1,
               "HIGH-1 failed: expected exactly 1 physical CAS file across mixed formats, got " +
                   std::to_string(physical_count)))
        return false;

    // Test C: [CRIT-1] Rollback orphan cleanup under BEGIN IMMEDIATE
    struct FailLinkTextRepo : public ITextRepository {
        ITextRepository &inner;
        explicit FailLinkTextRepo(ITextRepository &r) : inner(r) {}
        tl::expected<void, std::string> insert(const Text &t) override { return inner.insert(t); }
        tl::expected<std::optional<Text>, std::string> get(const std::string &h) override { return inner.get(h); }
        tl::expected<bool, std::string> exists(const std::string &h) override { return inner.exists(h); }
        tl::expected<bool, std::string> entity_exists(const std::string &id) override { return inner.entity_exists(id); }
        tl::expected<void, std::string> link_entity(const std::string &, const std::string &, const std::string &) override {
            return tl::unexpected("Simulated link failure");
        }
        tl::expected<void, std::string> unlink_entity(const std::string &e, const std::string &h) override {
            return inner.unlink_entity(e, h);
        }
        tl::expected<std::vector<Text>, std::string> get_texts_by_entity(
            const std::string &e, const std::optional<std::string> &r, const std::optional<std::string> &l) override {
            return inner.get_texts_by_entity(e, r, l);
        }
        tl::expected<int, std::string> count_entity_texts_by_slot(
            const std::string &e, const std::string &r, const std::string &l, const std::optional<std::string> &ex) override {
            return inner.count_entity_texts_by_slot(e, r, l, ex);
        }
    } fail_repo(text_repo);
    TextService fail_service(ctx, asset_repo, fail_repo, storage_root);

    const std::string rollback_new_content = "Rollback fresh orphan test content";
    const std::string rollback_new_hash = utils::Sha256::hash_string(rollback_new_content);
    auto rb_new_res = fail_service.save_text(SaveTextRequest{heal_track.id, "lyrics", rollback_new_content, std::nullopt, "txt", std::nullopt});
    if (!check(!rb_new_res.has_value() && rb_new_res.error().type == ErrorType::DatabaseError,
               "simulated link failure should fail save_text with DatabaseError"))
        return false;
    if (!check(!utils::StorageHelper::find_file_by_prefix(
                    utils::StorageHelper::resolve_cas_dir(storage_root, rollback_new_hash), rollback_new_hash)
                    .has_value(),
               "CRIT-1 Test C failed: fresh CAS blob was left orphaned on rollback"))
        return false;

    const std::string rollback_healed_content = "Rollback pre-existing asset test content";
    const std::string rollback_healed_hash = utils::Sha256::hash_string(rollback_healed_content);
    Asset pre_asset;
    pre_asset.file_hash = rollback_healed_hash;
    pre_asset.mime_type = "text/plain";
    pre_asset.asset_type = "text";
    pre_asset.file_size = static_cast<int>(rollback_healed_content.size());
    if (!check(asset_repo.insert(pre_asset).has_value(), "pre_asset insert failed")) return false;
    auto rb_heal_res = fail_service.save_text(SaveTextRequest{heal_track.id, "lyrics", rollback_healed_content, std::nullopt, "txt", std::nullopt});
    if (!check(!rb_heal_res.has_value() && rb_heal_res.error().type == ErrorType::DatabaseError,
               "simulated link failure should fail save_text with DatabaseError"))
        return false;
    if (!check(utils::StorageHelper::find_file_by_prefix(
                   utils::StorageHelper::resolve_cas_dir(storage_root, rollback_healed_hash), rollback_healed_hash)
                   .has_value(),
               "CRIT-1 Test C failed: pre-existing DB asset's healed CAS blob was wrongly deleted on rollback"))
        return false;

    return true;
}

bool test_detect_format_and_embedded_lyrics(const std::filesystem::path &root) {
    // detect_lyrics_format checks
    if (!check(TextService::detect_lyrics_format("[00:12.30]Hello") == "lrc", "standard LRC failed")) return false;
    if (!check(TextService::detect_lyrics_format("[1:05]Short minute") == "lrc", "1-digit min LRC failed")) return false;
    if (!check(TextService::detect_lyrics_format("[00:12.30][00:45.00]Multi") == "lrc", "multi-tag LRC failed"))
        return false;
    if (!check(TextService::detect_lyrics_format("[ar:Artist]\n[ti:Title]\nPlain text line") == "txt",
               "metadata-only headers must fall back to txt"))
        return false;
    if (!check(TextService::detect_lyrics_format("[00:99]Invalid seconds") == "txt",
               "out-of-range seconds should not match lrc"))
        return false;
    if (!check(TextService::detect_lyrics_format("Just plain lyrics\nLine 2") == "txt", "plain lyrics failed"))
        return false;
    // [LOW-2] Line-start anchoring and 3-digit minutes
    if (!check(TextService::detect_lyrics_format("Guitar solo at [2:30]") == "txt",
               "mid-line bracketed time must not trigger lrc"))
        return false;
    if (!check(TextService::detect_lyrics_format("[102:15.00]Long live set") == "lrc",
               "3-digit minute timestamp must be detected as lrc"))
        return false;

    // Embedded lyrics extraction via ffmpeg + AudioHelper::extract_metadata
    const std::string wav = (root / "tone.wav").string();
    const std::string flac = (root / "tagged.flac").string();
    const std::string mp3 = (root / "tagged.mp3").string();

    std::string cmd_wav = "ffmpeg -y -f lavfi -i sine=frequency=440:duration=0.3 \"" + wav + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_wav.c_str()) == 0, "ffmpeg wav generation failed")) return false;

    std::string cmd_flac =
        "ffmpeg -y -i \"" + wav +
        "\" -metadata \"lyrics=[00:01.00]FLAC 歌詞\" -metadata \"unsyncedlyrics=Plain fallback\""
        " -metadata \"lyrics-author=Bob\" -metadata \"lyrics-url=https://example.com\""
        " -metadata \"lyrics-copyright=2026\" -metadata \"lyrics-by=Credit Author\""
        " -metadata \"lyrics-web-link=https://example.com/web\""
        " -metadata \"lyrics-sub-title=Subtitle\" -metadata \"lyrics-alt-source=Mirror\""
        " -metadata \"lyrics-raw-data=RawData\" -metadata \"lyrics-author-url=https://example.com/author\""
        " -metadata \"lyrics-foo-bar=IgnoredDesc\" -metadata \"lyrics-eng-live=LiveEngIgnored\""
        " -metadata \"lyrics-no-go=NoGo\" -metadata \"lyrics-en-ok=EnOk\""
        " -metadata \"lyrics-en-xx=EnXx\" -metadata \"lyrics-id-000=IdZero\""
        " -metadata \"lyrics-source-alt=https://mirror.example.com\" -metadata \"lyrics-cover-art=ArtCredit\""
        " -metadata \"lyrics-copyright-inc=Corp\" -metadata \"lyrics-release-day=2026-01-01\""
        " -metadata \"lyrics-author-=TrailingDash\" -metadata \"lyrics-=EmptyDash\""
        " -metadata \"lyrics-zh-tw=[00:01.00]繁體\" -metadata \"lyrics-xxx=UnknownLang\""
        " -metadata \"lyrics-cmn-hant-tw=國語繁體\" -metadata \"lyrics-yue-hk=廣東話\""
        " -metadata \"lyrics-fil-ph=Tagalog\""
        " -metadata \"lyrics-zh-cmn-hant-tw=國語extlang\" -metadata \"lyrics-zh-yue-hk=粵語extlang\""
        " -metadata \"lyrics-zh-yue=粵語無地區\" -metadata \"lyrics-ja-latn-hepburn=Romaji\""
        " -metadata \"lyrics-zh-latn-pinyin=Pinyin\""
        " -metadata \"lyrics-ja-latn-heploc=DeprecatedStandalone\""
        " -metadata \"lyrics-en:us=Colon Sep\" -metadata \"lyrics-zh-hant-tw=繁體台灣\""
        " -metadata \"lyrics-es-419=Español\" -metadata \"lyrics-en-tw-hant=InvalidOrder\" \"" +
        flac + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_flac.c_str()) == 0, "ffmpeg flac generation failed")) return false;

    std::string cmd_mp3 =
        "ffmpeg -y -i \"" + wav +
        "\" -c:a libmp3lame -id3v2_version 3 -metadata \"lyrics-eng=English verse\" -metadata \"lyrics-jpn=[00:02.00]日本語\" \"" +
        mp3 + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_mp3.c_str()) == 0, "ffmpeg mp3 generation failed")) return false;

    auto flac_meta = utils::AudioHelper::extract_metadata(flac);
    if (!check(flac_meta.has_value(), "flac extract_metadata failed")) return false;
    if (!check(flac_meta->embedded_lyrics.size() == 15,
               "expected 15 valid embedded lyrics in flac (ignoring false-positive/invalid tags), got " +
                   std::to_string(flac_meta->embedded_lyrics.size())))
        return false;

    auto has_embedded_lyric = [](const std::vector<utils::EmbeddedLyricsTag> &list, const std::string &lang,
                                 const std::string &content) {
        for (const auto &lyr : list) {
            if (lyr.language == lang && lyr.content == content) return true;
        }
        return false;
    };
    const auto &fl = flac_meta->embedded_lyrics;
    if (!check(has_embedded_lyric(fl, "", "[00:01.00]FLAC 歌詞") &&
                   has_embedded_lyric(fl, "", "Plain fallback") &&
                   has_embedded_lyric(fl, "zh-TW", "[00:01.00]繁體") &&
                   has_embedded_lyric(fl, "", "UnknownLang") &&
                   has_embedded_lyric(fl, "cmn-Hant-TW", "國語繁體") &&
                   has_embedded_lyric(fl, "yue-HK", "廣東話") &&
                   has_embedded_lyric(fl, "fil-PH", "Tagalog") &&
                   has_embedded_lyric(fl, "en", "Colon Sep") &&
                   has_embedded_lyric(fl, "zh-Hant-TW", "繁體台灣") &&
                   has_embedded_lyric(fl, "es-419", "Español") &&
                   has_embedded_lyric(fl, "zh-cmn-Hant-TW", "國語extlang") &&
                   has_embedded_lyric(fl, "zh-yue-HK", "粵語extlang") &&
                   has_embedded_lyric(fl, "zh-yue", "粵語無地區") &&
                   has_embedded_lyric(fl, "ja-Latn-hepburn", "Romaji") &&
                   has_embedded_lyric(fl, "zh-Latn-pinyin", "Pinyin"),
               "BCP-47 / 3-letter ISO-639 / extlang / variant embedded lyrics parsing/normalization failed"))
        return false;

    auto mp3_meta = utils::AudioHelper::extract_metadata(mp3);
    if (!check(mp3_meta.has_value(), "mp3 extract_metadata failed")) return false;
    if (!check(mp3_meta->embedded_lyrics.size() == 2,
               "expected 2 embedded lyrics in mp3, got " + std::to_string(mp3_meta->embedded_lyrics.size())))
        return false;

    bool saw_eng = false;
    bool saw_jpn = false;
    for (const auto &lyr : mp3_meta->embedded_lyrics) {
        if (lyr.language == "eng" && lyr.content == "English verse") saw_eng = true;
        if (lyr.language == "jpn" && lyr.content == "[00:02.00]日本語") saw_jpn = true;
    }
    if (!check(saw_eng && saw_jpn, "mp3 lyrics-eng / lyrics-jpn tags were not extracted properly")) return false;

    // Real binary ID3v2.4 USLT frame tests (FFmpeg emits lyrics-<desc>-<lang>, lyrics-<lang>, lyrics-, etc.)
    const std::string uslt_base_mp3 = (root / "uslt_base.mp3").string();
    const std::string uslt_mp3 = (root / "uslt.mp3").string();
    std::string cmd_uslt_base =
        "ffmpeg -y -i \"" + wav + "\" -c:a libmp3lame -id3v2_version 0 \"" + uslt_base_mp3 + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_uslt_base.c_str()) == 0, "ffmpeg uslt base mp3 generation failed")) return false;

    std::vector<uint8_t> uslt_frames;
    append_id3v24_uslt_frame(uslt_frames, {'e', 'n', 'g'}, "", "Plain Eng USLT");
    append_id3v24_uslt_frame(uslt_frames, {'e', 'n', 'g'}, "Live Version", "Live Eng USLT");
    append_id3v24_uslt_frame(uslt_frames, {'j', 'p', 'n'}, "Sub", "Sub Jpn USLT");
    append_id3v24_uslt_frame(uslt_frames, {'j', 'p', 'n'}, "TV", "TV Jpn USLT");
    append_id3v24_uslt_frame(uslt_frames, {'x', 'x', 'x'}, "Main", "XXX Main USLT");
    append_id3v24_uslt_frame(uslt_frames, {'u', 'n', 'd'}, "Live", "UND Live USLT");
    append_id3v24_uslt_frame(uslt_frames, {'e', 'n', 'g'}, "Foo-Bar", "Dash Desc USLT");
    append_id3v24_uslt_frame(uslt_frames, {'j', 'p', 'n'}, "foo:bar", "Colon Desc USLT");
    append_id3v24_uslt_frame(uslt_frames, {' ', ' ', ' '}, "", "Space Lang USLT");
    append_id3v24_uslt_frame(uslt_frames, {'\0', '\0', '\0'}, "", "Nul Lang USLT");
    append_id3v24_uslt_frame(uslt_frames, {' ', ' ', ' '}, "DescSpace", "Space Desc USLT");
    append_id3v24_uslt_frame(uslt_frames, {'\0', '\0', '\0'}, "DescNul", "Nul Desc USLT");
    append_id3v24_uslt_frame(uslt_frames, {'e', 'n', ' '}, "Live", "Padded Space En USLT");
    append_id3v24_uslt_frame(uslt_frames, {'e', 'n', '\0'}, "LiveNul", "Padded Nul En USLT");
    append_id3v24_uslt_frame(uslt_frames, {'j', 'a', '\0'}, "zh", "Padded Nul Ja Desc Zh USLT");
    append_id3v24_uslt_frame(uslt_frames, {'z', 'x', 'x'}, "en:instrumental", "Ignored ZXX Colon Desc");
    if (!check(write_mp3_with_id3v24_uslt(uslt_base_mp3, uslt_mp3, uslt_frames),
               "failed to write binary ID3v2.4 USLT mp3"))
        return false;

    auto uslt_meta = utils::AudioHelper::extract_metadata(uslt_mp3);
    if (!check(uslt_meta.has_value(), "uslt mp3 extract_metadata failed")) return false;
    if (!check(uslt_meta->embedded_lyrics.size() == 15,
               "expected 15 USLT embedded lyrics in uslt.mp3, got " +
                   std::to_string(uslt_meta->embedded_lyrics.size())))
        return false;

    const auto &ul = uslt_meta->embedded_lyrics;
    if (!check(has_embedded_lyric(ul, "eng", "Plain Eng USLT") &&
                   has_embedded_lyric(ul, "eng", "Live Eng USLT") &&
                   has_embedded_lyric(ul, "jpn", "Sub Jpn USLT") &&
                   has_embedded_lyric(ul, "jpn", "TV Jpn USLT") &&
                   has_embedded_lyric(ul, "", "XXX Main USLT") &&
                   has_embedded_lyric(ul, "", "UND Live USLT") &&
                   has_embedded_lyric(ul, "eng", "Dash Desc USLT") &&
                   has_embedded_lyric(ul, "jpn", "Colon Desc USLT") &&
                   has_embedded_lyric(ul, "", "Space Lang USLT") &&
                   has_embedded_lyric(ul, "", "Nul Lang USLT") &&
                   has_embedded_lyric(ul, "", "Space Desc USLT") &&
                   has_embedded_lyric(ul, "", "Nul Desc USLT") &&
                   has_embedded_lyric(ul, "en", "Padded Space En USLT") &&
                   has_embedded_lyric(ul, "en", "Padded Nul En USLT") &&
                   has_embedded_lyric(ul, "ja", "Padded Nul Ja Desc Zh USLT"),
               "ID3v2.4 USLT language/descriptor parsing mismatch"))
        return false;

    // Ogg Vorbis exercising streams[*].tags and M4A format.tags coverage
    const std::string ogg = (root / "tagged.ogg").string();
    std::string cmd_ogg =
        "ffmpeg -y -i \"" + wav + "\" -c:a libvorbis"
                                  " -metadata:s:a:0 \"lyrics-en=Ogg Stream En\" -metadata:s:a:0 \"lyrics-zh-tw=Ogg Stream TW\""
                                  " -metadata:s:a:0 \"lyrics-source-alt=Ignored\" -metadata:s:a:0 \"lyrics-no-go=Ignored\""
                                  " -metadata:s:a:0 \"lyrics-author-=Ignored\" \"" +
        ogg + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_ogg.c_str()) == 0, "ffmpeg ogg generation failed")) return false;

    auto ogg_meta = utils::AudioHelper::extract_metadata(ogg);
    if (!check(ogg_meta.has_value(), "ogg extract_metadata failed")) return false;
    if (!check(ogg_meta->embedded_lyrics.size() == 2 &&
                   has_embedded_lyric(ogg_meta->embedded_lyrics, "en", "Ogg Stream En") &&
                   has_embedded_lyric(ogg_meta->embedded_lyrics, "zh-TW", "Ogg Stream TW"),
               "ogg streams[*].tags embedded lyrics extraction mismatch"))
        return false;

    const std::string m4a = (root / "tagged.m4a").string();
    std::string cmd_m4a =
        "ffmpeg -y -i \"" + wav + "\" -c:a aac -metadata \"lyrics=M4A Embedded\" \"" + m4a + "\" > /dev/null 2>&1";
    if (!check(std::system(cmd_m4a.c_str()) == 0, "ffmpeg m4a generation failed")) return false;

    auto m4a_meta = utils::AudioHelper::extract_metadata(m4a);
    if (!check(m4a_meta.has_value(), "m4a extract_metadata failed")) return false;
    if (!check(m4a_meta->embedded_lyrics.size() == 1 &&
                   has_embedded_lyric(m4a_meta->embedded_lyrics, "", "M4A Embedded"),
               "m4a embedded lyrics extraction mismatch"))
        return false;

    return true;
}

bool test_language_validation() {
    // Valid cases
    if (!check(TextService::is_valid_language(""), "empty language should be valid")) return false;
    if (!check(TextService::is_valid_language("zh-TW"), "zh-TW should be valid")) return false;
    if (!check(TextService::is_valid_language("Traditional Chinese"), "ASCII space in language should be valid"))
        return false;
    if (!check(TextService::is_valid_language("日本語"), "UTF-8 language should be valid")) return false;
    if (!check(TextService::is_valid_language("\xC2\xA0"), "U+00A0 (boundary after C1 controls) should be valid"))
        return false;
    if (!check(TextService::is_valid_language("\xC3\x80"), "U+00C0 should be valid")) return false;
    if (!check(TextService::is_valid_language(std::string(64, 'a')), "64-byte language should be valid")) return false;

    // Invalid length
    if (!check(!TextService::is_valid_language(std::string(65, 'a')), "65-byte language should be rejected"))
        return false;

    // Invalid C0 / DEL control characters
    if (!check(!TextService::is_valid_language("\x01"), "U+0001 should be rejected")) return false;
    if (!check(!TextService::is_valid_language("\x1F"), "U+001F should be rejected")) return false;
    if (!check(!TextService::is_valid_language("\x7F"), "U+007F DEL should be rejected")) return false;
    if (!check(!TextService::is_valid_language("en\tUS"), "TAB control character should be rejected")) return false;
    if (!check(!TextService::is_valid_language("en\nUS"), "LF control character should be rejected")) return false;

    // Invalid C1 control characters (U+0080 ~ U+009F -> UTF-8 0xC2 0x80 ~ 0xC2 0x9F)
    if (!check(!TextService::is_valid_language("\xC2\x80"), "U+0080 C1 control character should be rejected"))
        return false;
    if (!check(!TextService::is_valid_language("\xC2\x85"), "U+0085 NEL C1 control character should be rejected"))
        return false;
    if (!check(!TextService::is_valid_language("\xC2\x9F"), "U+009F C1 control character should be rejected"))
        return false;
    if (!check(!TextService::is_valid_language("zh\xC2\x9F-TW"), "embedded C1 control character should be rejected"))
        return false;

    // Direct unit tests for TextService::contains_control_chars (allow_multiline_whitespace = false vs true)
    if (!check(!TextService::contains_control_chars("", false), "empty string has no control chars")) return false;
    if (!check(!TextService::contains_control_chars("\xEF\xBB\xBF"
                                                    "hello \xC2\xA0\xE2\x80\x8D",
                                                    false),
               "BOM, U+00A0, and U+200D ZWJ should not be treated as control chars (strict)"))
        return false;
    if (!check(!TextService::contains_control_chars("\xEF\xBB\xBF\t\r\n\xC2\xA0\xE2\x80\x8D", true),
               "tab/CR/LF, BOM, U+00A0, and U+200D ZWJ should be allowed when multiline whitespace is permitted"))
        return false;
    if (!check(TextService::contains_control_chars("a\tb", false), "tab should be flagged when multiline=false"))
        return false;
    if (!check(TextService::contains_control_chars("a\nb", false), "LF should be flagged when multiline=false"))
        return false;
    if (!check(TextService::contains_control_chars("a\rb", false), "CR should be flagged when multiline=false"))
        return false;
    if (!check(!TextService::contains_control_chars("a\t\r\nb", true), "tab/CR/LF allowed when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\x01"
                                                   "b",
                                                   true),
               "SOH flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\x0b"
                                                   "b",
                                                   true),
               "VT flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\x0c"
                                                   "b",
                                                   true),
               "FF flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\x1b"
                                                   "b",
                                                   true),
               "ESC flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\x7f"
                                                   "b",
                                                   true),
               "DEL flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\xC2\x80"
                                                   "b",
                                                   true),
               "U+0080 flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\xC2\x85"
                                                   "b",
                                                   true),
               "U+0085 NEL flagged even when multiline=true"))
        return false;
    if (!check(TextService::contains_control_chars("a\xC2\x9F"
                                                   "b",
                                                   true),
               "U+009F flagged even when multiline=true"))
        return false;

    // UTF-8 boundary cases and malformed lead-byte sequences
    if (!check(TextService::is_valid_utf8("\xF4\x8F\xBF\xBF"), "U+10FFFF should be valid UTF-8")) return false;
    if (!check(!TextService::is_valid_utf8("\xF4\x90\x80\x80"), "U+110000 (> max codepoint) should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xE0\x9F\xBF"), "overlong 3-byte sequence should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xED\xA0\x80"), "UTF-16 surrogate U+D800 should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xE0\xA0"), "truncated 3-byte sequence should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xF0\x8F\xBF\xBF"), "overlong 4-byte sequence should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\x80"), "lone continuation byte 0x80 should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xF5\x80\x80\x80"), "invalid lead byte 0xF5 should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xC2"), "truncated 2-byte sequence should be invalid UTF-8"))
        return false;
    if (!check(!TextService::is_valid_utf8("\xF0\x90\x80"), "truncated 4-byte sequence should be invalid UTF-8"))
        return false;
    if (!check(TextService::is_valid_utf8("\xE0\xA0\x80"), "U+0800 lower 3-byte boundary should be valid UTF-8"))
        return false;
    if (!check(TextService::is_valid_utf8("\xED\x9F\xBF"), "U+D7FF pre-surrogate boundary should be valid UTF-8"))
        return false;
    if (!check(TextService::is_valid_utf8("\xEE\x80\x80"), "U+E000 post-surrogate boundary should be valid UTF-8"))
        return false;
    if (!check(TextService::is_valid_utf8("\xF0\x90\x80\x80"), "U+10000 lower 4-byte boundary should be valid UTF-8"))
        return false;
    if (!check(TextService::contains_control_chars(std::string("a\0b", 3), true),
               "embedded NUL must be flagged even when multiline=true"))
        return false;
    if (!check(!TextService::contains_control_chars("\xC2", true),
               "trailing lone 0xC2 should not OOB in contains_control_chars"))
        return false;
    if (!check(TextService::contains_control_chars("\xC2\x7F", true),
               "malformed 0xC2 followed by DEL must be flagged"))
        return false;
    if (!check(TextService::contains_control_chars("\xC2\x01", true),
               "malformed 0xC2 followed by ASCII control char must still be flagged"))
        return false;
    if (!check(TextService::contains_control_chars("\xC2\xC2\x80", true),
               "malformed 0xC2 followed by C1 sequence must still be flagged"))
        return false;

    // normalize_line_endings fast-path + chunk-copy boundary cases
    if (!check(TextService::normalize_line_endings("") == "", "normalize empty string")) return false;
    if (!check(TextService::normalize_line_endings("a\nb\n") == "a\nb\n", "normalize pure LF fast-path"))
        return false;
    if (!check(TextService::normalize_line_endings("a\r") == "a\n", "normalize trailing CR")) return false;
    if (!check(TextService::normalize_line_endings("a\r\n") == "a\n", "normalize trailing CRLF")) return false;
    if (!check(TextService::normalize_line_endings("\r") == "\n", "normalize single CR")) return false;
    if (!check(TextService::normalize_line_endings("\r\n") == "\n", "normalize single CRLF")) return false;
    if (!check(TextService::normalize_line_endings("\r\r\n") == "\n\n", "normalize consecutive CR+CRLF")) return false;
    if (!check(TextService::normalize_line_endings("a\r\nb\rc\nd") == "a\nb\nc\nd", "normalize mixed line endings"))
        return false;

    return true;
}

bool test_content_control_char_validation(const std::filesystem::path &root) {
    const std::string storage_root = (root / "storage_ctrl").string();
    std::filesystem::create_directories(storage_root);
    const std::string db_path = (root / "storage_ctrl" / "lyra.db").string();

    SqliteDatabaseContext ctx(db_path);
    SqliteAssetRepository asset_repo(ctx);
    SqliteTextRepository text_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    TextService service(ctx, asset_repo, text_repo, storage_root);

    Track track;
    track.id = UuidGenerator::generate_v4();
    track.pcm_hash = "7777777777777777777777777777777777777777777777777777777777777777";
    track.title = "Control Char Validation Track";
    if (!check(track_repo.insert(track).has_value(), "track insert failed")) return false;

    // Valid content: tabs, CRLF/CR/LF, leading UTF-8 BOM, U+00A0, ZWJ emoji
    std::string valid_hash;
    {
        SaveTextRequest req;
        req.entity_id = track.id;
        req.role = "lyrics";
        req.format = "txt";
        req.language = "en";
        req.content = "\xEF\xBB\xBFline1\tword\r\nline2\rline3\n\xC2\xA0\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6";
        auto res = service.save_text(req);
        if (!check(res.has_value(), "valid multiline UTF-8 content with BOM, U+00A0, and ZWJ should be accepted")) {
            return false;
        }
        valid_hash = res->text.text_hash;
    }

    // Disallowed C0 non-whitespace, DEL, and C1 control characters
    struct BadCase {
        const char *label;
        std::string content;
    };
    const std::vector<BadCase> bad_cases = {
        {"C0 SOH (0x01)", "a\x01"
                          "b"},
        {"C0 BEL (0x07)", "a\x07"
                          "b"},
        {"C0 BS (0x08)", "a\x08"
                         "b"},
        {"C0 VT (0x0B)", "a\x0b"
                         "b"},
        {"C0 FF (0x0C)", "a\x0c"
                         "b"},
        {"C0 ESC (0x1B)", "a\x1b[31mb"},
        {"C0 US (0x1F)", "a\x1f"
                         "b"},
        {"DEL (0x7F)", "a\x7f"
                       "b"},
        {"C1 PAD (U+0080)", "a\xC2\x80"
                            "b"},
        {"C1 NEL (U+0085)", "a\xC2\x85"
                            "b"},
        {"C1 PU2 mojibake (U+0092)", "a\xC2\x92"
                                     "b"},
        {"C1 CSI (U+009B)", "a\xC2\x9B"
                            "b"},
        {"C1 APC (U+009F)", "a\xC2\x9F"
                            "b"},
    };

    for (const auto &bc : bad_cases) {
        SaveTextRequest req;
        req.entity_id = track.id;
        req.role = "lyrics";
        req.format = "txt";
        req.content = bc.content;
        auto res = service.save_text(req);
        if (!check(!res.has_value(), std::string("save_text should reject ") + bc.label)) {
            return false;
        }
        if (!check(res.error().type == ErrorType::InvalidValue,
                   std::string("save_text should return InvalidValue for ") + bc.label)) {
            return false;
        }
    }

    // Size-check precedence: oversized payload containing ESC must still fail with OutOfRange
    {
        SaveTextRequest req;
        req.entity_id = track.id;
        req.role = "lyrics";
        req.format = "txt";
        req.content = std::string(TextService::MAX_TEXT_CONTENT_BYTES, 'a') + "\x1b";
        auto res = service.save_text(req);
        if (!check(!res.has_value() && res.error().type == ErrorType::OutOfRange,
                   "oversized content with control character must still return OutOfRange")) {
            return false;
        }
    }

    // Fail-fast InvalidValue for control chars / invalid UTF-8 / outer spaces in text_hash across all TextService APIs
    const std::vector<std::pair<std::string, std::string>> bad_hashes = {
        {"leading space", " " + valid_hash},
        {"trailing space", valid_hash + " "},
        {"empty", ""},
        {"spaces only", "   "},
        {"leading tab", "\t" + valid_hash},
        {"trailing LF", valid_hash + "\n"},
        {"ESC", "abc\x1b"},
        {"C1 U+0080", "abc\xC2\x80"},
        {"embedded NUL", std::string("abc\0def", 7)},
        {"invalid UTF-8", "\xFF"},
    };
    for (const auto &[label, bad_hash] : bad_hashes) {
        SaveTextRequest attach_req;
        attach_req.entity_id = track.id;
        attach_req.role = "other";
        attach_req.text_hash = bad_hash;
        auto r1 = service.save_text(attach_req);
        if (!check(!r1.has_value() && r1.error().type == ErrorType::InvalidValue,
                   "save_text(attach) must fail-fast InvalidValue for bad text_hash: " + label)) {
            return false;
        }
        auto r2 = service.get_text_by_hash(bad_hash);
        if (!check(!r2.has_value() && r2.error().type == ErrorType::InvalidValue,
                   "get_text_by_hash must fail-fast InvalidValue for bad text_hash: " + label)) {
            return false;
        }
        auto r3 = service.unlink_entity_text(track.id, bad_hash);
        if (!check(!r3.has_value() && r3.error().type == ErrorType::InvalidValue,
                   "unlink_entity_text must fail-fast InvalidValue for bad text_hash: " + label)) {
            return false;
        }
    }

    // Fail-fast InvalidValue for control chars / invalid UTF-8 / outer spaces in entity_id
    const std::vector<std::pair<std::string, std::string>> bad_entities = {
        {"leading space", " " + track.id},
        {"trailing space", track.id + " "},
        {"empty", ""},
        {"spaces only", "   "},
        {"embedded NUL", std::string("id\0bad", 6)},
        {"leading tab", "\t" + track.id},
        {"ESC", "id\x1b"},
        {"C1 U+0080", "id\xC2\x80"},
        {"invalid UTF-8", "\xFF"},
    };
    for (const auto &[label, bad_eid] : bad_entities) {
        SaveTextRequest req;
        req.entity_id = bad_eid;
        req.role = "lyrics";
        req.format = "txt";
        req.content = "hello";
        auto r1 = service.save_text(req);
        if (!check(!r1.has_value() && r1.error().type == ErrorType::InvalidValue,
                   "save_text must fail-fast InvalidValue for bad entity_id: " + label)) {
            return false;
        }
        auto r2 = service.get_entity_text(bad_eid);
        if (!check(!r2.has_value() && r2.error().type == ErrorType::InvalidValue,
                   "get_entity_text must fail-fast InvalidValue for bad entity_id: " + label)) {
            return false;
        }
        auto r3 = service.get_entity_texts(bad_eid);
        if (!check(!r3.has_value() && r3.error().type == ErrorType::InvalidValue,
                   "get_entity_texts must fail-fast InvalidValue for bad entity_id: " + label)) {
            return false;
        }
        auto r4 = service.unlink_entity_text(bad_eid, valid_hash);
        if (!check(!r4.has_value() && r4.error().type == ErrorType::InvalidValue,
                   "unlink_entity_text must fail-fast InvalidValue for bad entity_id: " + label)) {
            return false;
        }
    }

    // Direct C++ path: get_entity_text / get_entity_texts reject C0, C1, invalid UTF-8 language
    for (const std::string &bad_lang : {std::string("en\x01"), std::string("en\xC2\x85"), std::string("\xFF")}) {
        auto r1 = service.get_entity_text(track.id, std::nullopt, bad_lang);
        if (!check(!r1.has_value() && r1.error().type == ErrorType::InvalidValue,
                   "get_entity_text must reject invalid language")) {
            return false;
        }
        auto r2 = service.get_entity_texts(track.id, std::nullopt, bad_lang);
        if (!check(!r2.has_value() && r2.error().type == ErrorType::InvalidValue,
                   "get_entity_texts must reject invalid language")) {
            return false;
        }
    }

    return true;
}

} // namespace

int main() {
    TempDirGuard root("lyra_text_service_test");

    bool ok = true;
    ok &= test_language_validation();
    ok &= test_content_control_char_validation(root.path);
    ok &= test_schema_indexes_and_constraints(root.path);
    ok &= test_normalization_utf8_and_three_layer_dedup(root.path);
    ok &= test_crit1_self_heal_and_concurrent_cas(root.path);
    ok &= test_detect_format_and_embedded_lyrics(root.path);

    if (!ok) {
        return 1;
    }
    std::cout << "ALL_TESTS_PASSED\n";
    return 0;
}
