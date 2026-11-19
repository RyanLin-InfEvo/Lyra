// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "../src/controllers/source_data_controller.h"
#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_source_data_repository.h"
#include "../src/utils/uuid_generator.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <cstdio>
#include <iostream>
#include <string>

using namespace lyra;

namespace {

bool check(bool cond, const std::string &msg) {
    if (!cond) {
        std::cerr << "FAILED: " << msg << "\n";
        return false;
    }
    return true;
}

bool test_schema_and_index(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='table' AND name='Source_Data'");
        if (!check(q.executeStep(), "Source_Data table missing")) return false;
    }
    {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_SourceData_file_hash'");
        if (!check(q.executeStep(), "idx_SourceData_file_hash index missing")) return false;
    }
    return true;
}

bool test_source_data_crud_and_guards(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    SqliteAssetRepository asset_repo(ctx);
    SqliteSourceDataRepository sd_repo(ctx);
    SourceDataController controller(sd_repo);

    // 1. Insert without existing Asset should fail
    SourceData orphan;
    orphan.file_hash = "nonexistent_hash_0000";
    orphan.source_type = "local_import";
    orphan.original_path = "/tmp/orphan.flac";
    auto orphan_res = controller.create(orphan);
    if (!check(!orphan_res.has_value(), "create with missing asset should fail")) return false;
    if (!check(orphan_res.error().find("Asset not found") != std::string::npos,
               "expected 'Asset not found' error, got: " + orphan_res.error())) return false;

    // 2. get_by_asset for missing Asset should fail with Asset not found
    auto missing_asset_res = controller.get_by_asset("nonexistent_hash_0000");
    if (!check(!missing_asset_res.has_value(), "get_by_asset on missing asset should fail")) return false;
    if (!check(missing_asset_res.error().find("Asset not found") != std::string::npos,
               "expected 'Asset not found' on missing asset")) return false;

    // 3. Create Asset without SourceData -> get_by_asset fails with SourceData not found
    Asset asset;
    asset.file_hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    asset.mime_type = "audio/flac";
    asset.asset_type = "audio";
    asset.file_size = 1024;
    if (!check(asset_repo.insert(asset).has_value(), "asset insert failed")) return false;

    auto no_sd_res = controller.get_by_asset(asset.file_hash);
    if (!check(!no_sd_res.has_value(), "get_by_asset with no source_data should fail")) return false;
    if (!check(no_sd_res.error().find("SourceData not found") != std::string::npos,
               "expected 'SourceData not found', got: " + no_sd_res.error())) return false;

    // 3b. Direct repository insert with empty id should fail
    SourceData empty_id_sd;
    empty_id_sd.id = "";
    empty_id_sd.file_hash = asset.file_hash;
    empty_id_sd.source_type = "local_import";
    auto empty_id_res = sd_repo.insert(empty_id_sd);
    if (!check(!empty_id_res.has_value(), "direct repo insert with empty id should fail")) return false;
    if (!check(empty_id_res.error().find("id cannot be empty") != std::string::npos,
               "expected empty id error, got: " + empty_id_res.error())) return false;

    // 4. Create first SourceData via controller (server-side UUID + created_at)
    SourceData sd1;
    sd1.id = "client-spoofed-id";
    sd1.file_hash = asset.file_hash;
    sd1.source_type = "cd_rip";
    sd1.original_path = "/rips/album/01.flac";
    sd1.note = "EAC AccurateRip verified";
    auto c1 = controller.create(sd1);
    if (!check(c1.has_value(), "create sd1 failed: " + (c1 ? "" : c1.error()))) return false;
    if (!check(sd1.id != "client-spoofed-id" && sd1.id.size() == 36, "server must generate UUID")) return false;
    if (!check(!sd1.created_at.empty(), "created_at must be populated")) return false;

    auto got1 = controller.get_by_asset(asset.file_hash);
    if (!check(got1.has_value(), "get_by_asset failed")) return false;
    if (!check(got1->id == sd1.id && got1->source_type == "cd_rip" &&
                   got1->original_path == "/rips/album/01.flac" &&
                   got1->note == "EAC AccurateRip verified",
               "sd1 field mismatch")) return false;

    // 5. Create second SourceData for same asset -> get_by_asset returns latest, list_by_asset returns both
    SourceData sd2;
    sd2.file_hash = asset.file_hash;
    sd2.source_type = "digital_download";
    sd2.original_path = "";
    sd2.note = "";
    auto c2 = controller.create(sd2);
    if (!check(c2.has_value(), "create sd2 failed")) return false;

    auto got_latest = controller.get_by_asset(asset.file_hash);
    if (!check(got_latest.has_value() && got_latest->id == sd2.id, "get_by_asset should return latest record")) return false;
    if (!check(got_latest->original_path.empty() && got_latest->note.empty(), "empty fields should map cleanly")) return false;

    auto all_sd = controller.list_by_asset(asset.file_hash);
    if (!check(all_sd.has_value() && all_sd->size() == 2, "list_by_asset should return 2 records")) return false;
    if (!check(all_sd->at(0).id == sd2.id && all_sd->at(1).id == sd1.id, "list_by_asset should order newest first"))
        return false;

    // 6. ON DELETE CASCADE when parent Asset is deleted
    {
        auto &db = ctx.get_db();
        SQLite::Statement del(db, "DELETE FROM Asset WHERE file_hash = ?");
        del.bind(1, asset.file_hash);
        if (!check(del.exec() == 1, "asset delete failed")) return false;
    }

    auto after_cascade = sd_repo.get(sd1.id);
    if (!check(!after_cascade.has_value(), "sd1 should be cascade-deleted with Asset")) return false;
    auto after_cascade2 = sd_repo.get(sd2.id);
    if (!check(!after_cascade2.has_value(), "sd2 should be cascade-deleted with Asset")) return false;

    return true;
}

} // namespace

int main() {
    const std::string db_path = "source_data_repository_test.db";
    std::remove(db_path.c_str());

    bool ok = true;
    ok &= test_schema_and_index(db_path);
    ok &= test_source_data_crud_and_guards(db_path);

    std::remove(db_path.c_str());
    std::remove((db_path + "-wal").c_str());
    std::remove((db_path + "-shm").c_str());

    if (!ok) {
        return 1;
    }
    std::cout << "ALL_TESTS_PASSED\n";
    return 0;
}
