// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_source_data_repository.h"

#include "../../../utils/sqlite_mappers.h"
#include <SQLiteCpp/SQLiteCpp.h>

namespace lyra {

namespace {

bool asset_exists(SQLite::Database &db, const std::string &file_hash) {
    SQLite::Statement stmt(db, "SELECT 1 FROM Asset WHERE file_hash = ?");
    stmt.bind(1, file_hash);
    bool exists = stmt.executeStep();
    stmt.reset();
    return exists;
}

} // namespace

SqliteSourceDataRepository::SqliteSourceDataRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteSourceDataRepository::insert(const SourceData &source_data) {
    if (source_data.id.empty()) {
        return tl::unexpected("SourceData id cannot be empty.");
    }
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            if (!asset_exists(db, source_data.file_hash)) {
                return tl::unexpected("Asset not found.");
            }

            SQLite::Statement query(
                db,
                "INSERT INTO Source_Data (id, file_hash, source_type, original_path, created_at, note) "
                "VALUES (?, ?, ?, ?, datetime('now'), ?)");
            query.bind(1, source_data.id);
            query.bind(2, source_data.file_hash);
            if (source_data.source_type.empty()) {
                query.bind(3);
            } else {
                query.bind(3, source_data.source_type);
            }
            if (source_data.original_path.empty()) {
                query.bind(4);
            } else {
                query.bind(4, source_data.original_path);
            }
            if (source_data.note.empty()) {
                query.bind(5);
            } else {
                query.bind(5, source_data.note);
            }

            if (query.exec() == 0) {
                return tl::unexpected("Failed to insert Source_Data.");
            }
            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<SourceData, std::string> SqliteSourceDataRepository::get(const std::string &id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(
            db,
            "SELECT id, file_hash, source_type, original_path, created_at, note "
            "FROM Source_Data WHERE id = ?");
        query.bind(1, id);

        auto sd = SqliteHelper::fetch_one<SourceData>(query);
        if (sd) {
            return *sd;
        }
        return tl::unexpected("SourceData not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<SourceData, std::string> SqliteSourceDataRepository::get_by_asset(const std::string &file_hash) {
    try {
        auto &db = m_context.get_db();

        if (!asset_exists(db, file_hash)) {
            return tl::unexpected("Asset not found.");
        }

        SQLite::Statement query(
            db,
            "SELECT id, file_hash, source_type, original_path, created_at, note "
            "FROM Source_Data WHERE file_hash = ? "
            "ORDER BY created_at DESC, rowid DESC LIMIT 1");
        query.bind(1, file_hash);

        auto sd = SqliteHelper::fetch_one<SourceData>(query);
        if (sd) {
            return *sd;
        }
        return tl::unexpected("SourceData not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<SourceData>, std::string> SqliteSourceDataRepository::list_by_asset(
    const std::string &file_hash) {
    try {
        auto &db = m_context.get_db();

        if (!asset_exists(db, file_hash)) {
            return tl::unexpected("Asset not found.");
        }

        SQLite::Statement query(
            db,
            "SELECT id, file_hash, source_type, original_path, created_at, note "
            "FROM Source_Data WHERE file_hash = ? "
            "ORDER BY created_at DESC, rowid DESC");
        query.bind(1, file_hash);

        return SqliteHelper::fetch_all<SourceData>(query);
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
