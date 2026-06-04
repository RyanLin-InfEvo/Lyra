// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../utils/sqlite_helper.h"
#include "sqlite_asset_repository.h"

namespace lyra {

SqliteAssetRepository::SqliteAssetRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteAssetRepository::insert(const Asset &asset) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db,
                                 "INSERT INTO Asset (file_hash, mime_type, asset_type, file_size, created_at) "
                                 "VALUES (?, ?, ?, ?, datetime('now'))");
        query.bind(1, asset.file_hash);
        if (asset.mime_type.empty()) {
            query.bind(2);
        } else {
            query.bind(2, asset.mime_type);
        }
        if (asset.asset_type.empty()) {
            query.bind(3);
        } else {
            query.bind(3, asset.asset_type);
        }
        query.bind(4, asset.file_size);

        query.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteAssetRepository::update(const AssetUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Asset SET ";
        std::vector<std::string> fields;
        if (data.mime_type) fields.emplace_back("mime_type = ?");
        if (data.asset_type) fields.emplace_back("asset_type = ?");
        if (data.file_size) fields.emplace_back("file_size = ?");
        if (data.created_at) fields.emplace_back("created_at = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE file_hash = ?";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        if (data.mime_type) {
            if (data.mime_type->empty()) {
                query.bind(bind_idx++);
            } else {
                query.bind(bind_idx++, *data.mime_type);
            }
        }
        if (data.asset_type) {
            if (data.asset_type->empty()) {
                query.bind(bind_idx++);
            } else {
                query.bind(bind_idx++, *data.asset_type);
            }
        }
        if (data.file_size) query.bind(bind_idx++, *data.file_size);
        if (data.created_at) query.bind(bind_idx++, *data.created_at);
        query.bind(bind_idx, data.file_hash);

        if (query.exec() == 0) return tl::unexpected("Asset not found.");

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Asset, std::string> SqliteAssetRepository::get(const std::string &file_hash) {
    try {
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "SELECT * FROM Asset WHERE file_hash = ?");
        query.bind(1, file_hash);

        if (query.executeStep()) {
            Asset asset;
            asset.file_hash = query.getColumn("file_hash").getString();
            asset.mime_type = SqliteHelper::get_safe<std::string>(query, "mime_type", "");
            asset.asset_type = SqliteHelper::get_safe<std::string>(query, "asset_type", "");
            asset.file_size = query.getColumn("file_size").getInt();
            asset.created_at = query.getColumn("created_at").getString();
            return asset;
        }
        return tl::unexpected("Asset not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<PaginatedResult<Asset>, std::string> SqliteAssetRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Asset";
        std::string select_sql = "SELECT * FROM Asset";
        
        if (search.has_value()) {
            count_sql += R"( WHERE asset_type LIKE ? OR mime_type LIKE ? ESCAPE '\' )";
            select_sql += R"( WHERE asset_type LIKE ? OR mime_type LIKE ? ESCAPE '\' )";
        }
        
        select_sql += " ORDER BY file_hash ASC LIMIT ? OFFSET ?";
        
        int total = 0;
        {
            SQLite::Statement count_query(db, count_sql);
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                count_query.bind(1, query_param);
                count_query.bind(2, query_param);
            }
            if (!count_query.executeStep()) {
                return tl::unexpected("Failed to get total count.");
            }
            total = count_query.getColumn(0).getInt();
        }
        
        std::vector<Asset> items;
        items.reserve(limit);
        {
            SQLite::Statement select_query(db, select_sql);
            int bind_idx = 1;
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                select_query.bind(bind_idx++, query_param);
                select_query.bind(bind_idx++, query_param);
            }
            select_query.bind(bind_idx++, limit);
            select_query.bind(bind_idx++, offset);
            
            while (select_query.executeStep()) {
                Asset asset;
                asset.file_hash = select_query.getColumn("file_hash").getString();
                asset.mime_type = SqliteHelper::get_safe<std::string>(select_query, "mime_type", "");
                asset.asset_type = SqliteHelper::get_safe<std::string>(select_query, "asset_type", "");
                asset.file_size = select_query.getColumn("file_size").getInt();
                asset.created_at = select_query.getColumn("created_at").getString();
                items.push_back(asset);
            }
        }
        
        return PaginatedResult<Asset>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
