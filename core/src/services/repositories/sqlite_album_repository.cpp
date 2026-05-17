// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../utils/sqlite_helper.h"
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

    auto &db = m_context.get_db();

    SQLite::Statement query(db, "SELECT * FROM Album WHERE id = ?");
    query.bind(1, album_id);

    if (query.executeStep()) {
        Album album;
        album.id = query.getColumn("id").getString();
        album.title = query.getColumn("title").getString();
        album.release_year = SqliteHelper::get_optional<int>(query, "release_year");
        album.release_month = SqliteHelper::get_optional<int>(query, "release_month");
        album.release_day = SqliteHelper::get_optional<int>(query, "release_day");
        return album;
    }
    return tl::unexpected("Album not found.");
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

} // namespace lyra
