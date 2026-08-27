// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../../utils/sqlite_mappers.h"
#include "sqlite_album_repository.h"

namespace lyra {

SqliteAlbumRepository::SqliteAlbumRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteAlbumRepository::insert(const Album &album) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query1(db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'album', datetime('now'), datetime('now'))");
        query1.bind(1, album.id);
        query1.exec();

        SQLite::Statement query2(db,
                                 "INSERT INTO Album (id, title, release_year, release_month, release_day) "
                                 "VALUES (?, ?, ?, ?, ?)");
        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) query2.bind(index, *val);
            else query2.bind(index);
        };
        query2.bind(1, album.id);
        query2.bind(2, album.title);
        bind_opt(3, album.release_year);
        bind_opt(4, album.release_month);
        bind_opt(5, album.release_day);

        query2.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Album, std::string> SqliteAlbumRepository::get(const std::string &album_id) {
    try {
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "SELECT * FROM Album WHERE id = ?");
        query.bind(1, album_id);

        auto album = SqliteHelper::fetch_one(query, SqliteMappers::map_album);
        if (album) {
            return *album;
        }
        return tl::unexpected("Album not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteAlbumRepository::update(const AlbumUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Album SET ";
        std::vector<std::string> fields;
        if (data.title) fields.emplace_back("title = ?");
        if (data.release_year) fields.emplace_back("release_year = ?");
        if (data.release_month) fields.emplace_back("release_month = ?");
        if (data.release_day) fields.emplace_back("release_day = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        if (data.title) query.bind(bind_idx++, *data.title);
        if (data.release_year) query.bind(bind_idx++, *data.release_year);
        if (data.release_month) query.bind(bind_idx++, *data.release_month);
        if (data.release_day) query.bind(bind_idx++, *data.release_day);
        query.bind(bind_idx, data.id);

        if (query.exec() == 0) return tl::unexpected("Album ID not found.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<PaginatedResult<Album>, std::string> SqliteAlbumRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Album";
        std::string select_sql = "SELECT * FROM Album";

        if (search.has_value()) {
            count_sql += R"( WHERE title LIKE ? ESCAPE '\' )";
            select_sql += R"( WHERE title LIKE ? ESCAPE '\' )";
        }

        select_sql += " ORDER BY title ASC, id ASC LIMIT ? OFFSET ?";

        int total = 0;
        {
            SQLite::Statement count_query(db, count_sql);
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                count_query.bind(1, query_param);
            }
            if (!count_query.executeStep()) {
                return tl::unexpected("Failed to get total count.");
            }
            total = count_query.getColumn(0).getInt();
        }

        SQLite::Statement select_query(db, select_sql);
        int bind_idx = 1;
        if (search.has_value()) {
            std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
            select_query.bind(bind_idx++, query_param);
        }
        select_query.bind(bind_idx++, limit);
        select_query.bind(bind_idx++, offset);

        std::vector<Album> items = SqliteHelper::fetch_all(select_query, SqliteMappers::map_album, limit);

        return PaginatedResult<Album>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<Album>, std::string> SqliteAlbumRepository::get_by_title(const std::string &title) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT * FROM Album WHERE title = ? ORDER BY id ASC");
        query.bind(1, title);

        return SqliteHelper::fetch_all(query, SqliteMappers::map_album);
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
