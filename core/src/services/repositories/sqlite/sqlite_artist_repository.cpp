// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../../utils/sqlite_helper.h"
#include "sqlite_artist_repository.h"

namespace lyra {

SqliteArtistRepository::SqliteArtistRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteArtistRepository::insert(const Artist &artist) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        // insert into Entity table
        SQLite::Statement query1(db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'artist', datetime('now'), datetime('now'))");
        query1.bind(1, artist.id);
        query1.exec();

        // insert into Artist table
        SQLite::Statement query2(db, "INSERT INTO Artist (id, name, musicbrainz_id, "
                                     "spotify_id, ytm_id) VALUES (?, ?, ?, ?, ?)");

        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) {
                query2.bind(index, *val);
            } else {
                query2.bind(index);
            }
        };

        query2.bind(1, artist.id);
        query2.bind(2, artist.name);
        bind_opt(3, artist.musicbrainz_id);
        bind_opt(4, artist.spotify_id);
        bind_opt(5, artist.ytm_id);

        query2.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }

    return {};
}

tl::expected<void, std::string> SqliteArtistRepository::update(const ArtistUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        // Build Dynamic SQL Query
        std::string sql = "UPDATE Artist SET ";
        std::vector<std::string> fields;
        fields.reserve(4);

        if (data.name) fields.emplace_back("name = ?");
        if (data.musicbrainz_id) fields.emplace_back("musicbrainz_id = ?");
        if (data.ytm_id) fields.emplace_back("ytm_id = ?");
        if (data.spotify_id) fields.emplace_back("spotify_id = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Statement query(db, sql);

        int bind_idx = 1;
        if (data.name) query.bind(bind_idx++, *data.name);
        if (data.musicbrainz_id) query.bind(bind_idx++, *data.musicbrainz_id);
        if (data.ytm_id) query.bind(bind_idx++, *data.ytm_id);
        if (data.spotify_id) query.bind(bind_idx++, *data.spotify_id);
        query.bind(bind_idx, data.id);

        int affected_rows = query.exec();
        if (affected_rows == 0) return tl::unexpected("Artist ID not found.");

        // Update successful, sync Entity updated_at
        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }

    return {};
}

tl::expected<Artist, std::string> SqliteArtistRepository::get(const std::string &artist_id) {

    auto &db = m_context.get_db();

    SQLite::Statement query(db, "SELECT * FROM Artist WHERE id = ?");
    query.bind(1, artist_id);

    if (query.executeStep()) {
        Artist artist;
        artist.id = query.getColumn("id").getString();
        artist.name = query.getColumn("name").getString();
        artist.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
        artist.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
        artist.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");
        return artist;
    }

    return tl::unexpected("Artist not found.");
}

tl::expected<PaginatedResult<Artist>, std::string> SqliteArtistRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Artist";
        std::string select_sql = "SELECT * FROM Artist";

        if (search.has_value()) {
            count_sql += R"( WHERE name LIKE ? ESCAPE '\' )";
            select_sql += R"( WHERE name LIKE ? ESCAPE '\' )";
        }

        select_sql += " ORDER BY name ASC, id ASC LIMIT ? OFFSET ?";

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

        std::vector<Artist> items;
        items.reserve(limit);
        {
            SQLite::Statement select_query(db, select_sql);
            int bind_idx = 1;
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                select_query.bind(bind_idx++, query_param);
            }
            select_query.bind(bind_idx++, limit);
            select_query.bind(bind_idx++, offset);

            while (select_query.executeStep()) {
                Artist artist;
                artist.id = select_query.getColumn("id").getString();
                artist.name = select_query.getColumn("name").getString();
                artist.musicbrainz_id = SqliteHelper::get_optional<std::string>(select_query, "musicbrainz_id");
                artist.ytm_id = SqliteHelper::get_optional<std::string>(select_query, "ytm_id");
                artist.spotify_id = SqliteHelper::get_optional<std::string>(select_query, "spotify_id");
                items.push_back(artist);
            }
        }

        return PaginatedResult<Artist>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<Artist>, std::string> SqliteArtistRepository::get_by_name(const std::string &name) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT * FROM Artist WHERE name = ? ORDER BY id ASC");
        query.bind(1, name);

        std::vector<Artist> artists;
        while (query.executeStep()) {
            Artist artist;
            artist.id = query.getColumn("id").getString();
            artist.name = query.getColumn("name").getString();
            artist.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
            artist.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
            artist.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");
            artists.push_back(artist);
        }
        return artists;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
