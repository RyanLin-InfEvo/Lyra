// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../utils/sqlite_helper.h"
#include "sqlite_playlist_repository.h"

namespace lyra {

SqlitePlaylistRepository::SqlitePlaylistRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqlitePlaylistRepository::insert(const Playlist &playlist) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query1(db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'playlist', datetime('now'), datetime('now'))");
        query1.bind(1, playlist.id);
        query1.exec();

        SQLite::Statement query2(db, "INSERT INTO Playlist (id, title, description) VALUES (?, ?, ?)");
        query2.bind(1, playlist.id);
        query2.bind(2, playlist.title);
        if (playlist.description) query2.bind(3, *playlist.description);
        else query2.bind(3);

        query2.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Playlist, std::string> SqlitePlaylistRepository::get(const std::string &playlist_id) {

    auto &db = m_context.get_db();

    SQLite::Statement query(db, "SELECT * FROM Playlist WHERE id = ?");
    query.bind(1, playlist_id);

    if (query.executeStep()) {
        Playlist playlist;
        playlist.id = query.getColumn("id").getString();
        playlist.title = query.getColumn("title").getString();
        playlist.description = SqliteHelper::get_optional<std::string>(query, "description");
        return playlist;
    }
    return tl::unexpected("Playlist not found.");
}

tl::expected<void, std::string> SqlitePlaylistRepository::update(const PlaylistUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Playlist SET ";
        std::vector<std::string> fields;
        if (data.title) fields.emplace_back("title = ?");
        if (data.description) fields.emplace_back("description = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        if (data.title) query.bind(bind_idx++, *data.title);
        if (data.description) query.bind(bind_idx++, *data.description);
        query.bind(bind_idx, data.id);

        if (query.exec() == 0) return tl::unexpected("Playlist ID not found.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqlitePlaylistRepository::add_track(const std::string &playlist_id,
                                                               const std::string &track_id,
                                                               std::optional<int> position) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement check_playlist(db, "SELECT 1 FROM Playlist WHERE id = ?");
        check_playlist.bind(1, playlist_id);
        if (!check_playlist.executeStep()) return tl::unexpected("Playlist ID not found.");

        SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
        check_track.bind(1, track_id);
        if (!check_track.executeStep()) return tl::unexpected("Track ID not found.");

        SQLite::Statement query(db, "INSERT OR REPLACE INTO Playlist_Track (playlist_id, track_id, position) VALUES (?, ?, ?)");
        query.bind(1, playlist_id);
        query.bind(2, track_id);
        if (position) query.bind(3, *position);
        else query.bind(3);

        query.exec();
        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, playlist_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqlitePlaylistRepository::remove_track(const std::string &playlist_id,
                                                                  const std::string &track_id) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "DELETE FROM Playlist_Track WHERE playlist_id = ? AND track_id = ?");
        query.bind(1, playlist_id);
        query.bind(2, track_id);

        if (query.exec() == 0) return tl::unexpected("Track not found in playlist.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, playlist_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

std::vector<std::string> SqlitePlaylistRepository::get_tracks(const std::string &playlist_id) {

    auto &db = m_context.get_db();
    std::vector<std::string> track_ids;

    SQLite::Statement query(db, "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? ORDER BY position ASC, track_id ASC");
    query.bind(1, playlist_id);
    while (query.executeStep()) {
        track_ids.push_back(query.getColumn(0).getString());
    }
    return track_ids;
}

} // namespace lyra
