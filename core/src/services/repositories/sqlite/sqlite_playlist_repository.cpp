// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_playlist_repository.h"

namespace lyra {

SqlitePlaylistRepository::SqlitePlaylistRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Playlist", "playlist", "title") {}

tl::expected<void, std::string> SqlitePlaylistRepository::insert(const Playlist &playlist) {
    return SqliteEntityRepository::insert(playlist);
}

tl::expected<void, std::string> SqlitePlaylistRepository::update(const PlaylistUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Playlist, std::string> SqlitePlaylistRepository::get(const std::string &playlist_id) {
    return SqliteEntityRepository::get(playlist_id);
}

tl::expected<PaginatedResult<Playlist>, std::string> SqlitePlaylistRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return SqliteEntityRepository::list(offset, limit, search);
}

tl::expected<std::vector<Playlist>, std::string> SqlitePlaylistRepository::get_by_title(const std::string &title) {
    return get_by_field("title", title);
}

tl::expected<void, std::string> SqlitePlaylistRepository::do_insert(SQLite::Database &db, const Playlist &playlist) {
    SQLite::Statement query(db, "INSERT INTO Playlist (id, title, description) VALUES (?, ?, ?)");
    query.bind(1, playlist.id);
    query.bind(2, playlist.title);
    bind_optional(query, 3, playlist.description);
    query.exec();
    return {};
}

void SqlitePlaylistRepository::build_update(SqliteUpdateBuilder &builder, const PlaylistUpdate &data) const {
    builder.set("title", data.title)
        .set("description", data.description);
}

tl::expected<void, std::string> SqlitePlaylistRepository::add_track(
    const std::string &playlist_id, const std::string &track_id, std::optional<int> position) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_playlist(db, "SELECT 1 FROM Playlist WHERE id = ?");
                check_playlist.bind(1, playlist_id);
                if (!check_playlist.executeStep()) {
                    return tl::unexpected("Playlist ID not found.");
                }
            }

            {
                SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
                check_track.bind(1, track_id);
                if (!check_track.executeStep()) {
                    return tl::unexpected("Track ID not found.");
                }
            }

            SQLite::Statement query(
                db, "INSERT OR REPLACE INTO Playlist_Track (playlist_id, track_id, position) VALUES (?, ?, ?)");
            query.bind(1, playlist_id);
            query.bind(2, track_id);
            if (position) {
                query.bind(3, *position);
            } else {
                query.bind(3);
            }
            query.exec();

            return touch_entity(playlist_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqlitePlaylistRepository::remove_track(
    const std::string &playlist_id, const std::string &track_id) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            SQLite::Statement query(
                db, "DELETE FROM Playlist_Track WHERE playlist_id = ? AND track_id = ?");
            query.bind(1, playlist_id);
            query.bind(2, track_id);

            if (query.exec() == 0) {
                return tl::unexpected("Track not found in playlist.");
            }

            return touch_entity(playlist_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<std::string>, std::string> SqlitePlaylistRepository::get_tracks(
    const std::string &playlist_id) {
    try {
        auto &db = m_context.get_db();

        SQLite::Statement query(
            db, "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? ORDER BY position ASC, track_id ASC");
        query.bind(1, playlist_id);
        return SqliteHelper::fetch_all(query, [](SQLite::Statement &q) {
            return q.getColumn(0).getString();
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::string, std::string> SqlitePlaylistRepository::get_first_track_id(
    const std::string &playlist_id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(
            db, "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? ORDER BY position ASC LIMIT 1");
        query.bind(1, playlist_id);

        auto track_id = SqliteHelper::fetch_one(query, [](SQLite::Statement &q) {
            return q.getColumn(0).getString();
        });
        if (track_id)
            return *track_id;
        return tl::unexpected("Playlist is empty.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
