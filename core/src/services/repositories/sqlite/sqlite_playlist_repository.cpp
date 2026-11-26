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
            db,
            "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? "
            "ORDER BY (position IS NULL) ASC, position ASC, track_id ASC");
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
            db,
            "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? "
            "ORDER BY (position IS NULL) ASC, position ASC, track_id ASC LIMIT 1");
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

tl::expected<void, std::string> SqlitePlaylistRepository::delete_playlist(
    const std::string &playlist_id) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_playlist(db, "SELECT 1 FROM Playlist WHERE id = ?");
                check_playlist.bind(1, playlist_id);
                const bool exists = check_playlist.executeStep();
                check_playlist.reset();
                if (!exists) {
                    return tl::unexpected("Playlist not found.");
                }
            }

            {
                SQLite::Statement del_tracks(db, "DELETE FROM Playlist_Track WHERE playlist_id = ?");
                del_tracks.bind(1, playlist_id);
                del_tracks.exec();
                del_tracks.reset();
            }

            {
                SQLite::Statement del_playlist(db, "DELETE FROM Playlist WHERE id = ?");
                del_playlist.bind(1, playlist_id);
                const int affected = del_playlist.exec();
                del_playlist.reset();
                if (affected == 0) {
                    return tl::unexpected("Playlist not found.");
                }
            }

            {
                SQLite::Statement del_entity(
                    db, "DELETE FROM Entity WHERE id = ? AND entity_type = 'playlist'");
                del_entity.bind(1, playlist_id);
                const int affected = del_entity.exec();
                del_entity.reset();
                if (affected == 0) {
                    return tl::unexpected("Playlist not found.");
                }
            }

            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<std::string>, std::string> SqlitePlaylistRepository::reorder_tracks(
    const std::string &playlist_id, int old_index, int new_index) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<std::vector<std::string>, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_playlist(db, "SELECT 1 FROM Playlist WHERE id = ?");
                check_playlist.bind(1, playlist_id);
                const bool exists = check_playlist.executeStep();
                check_playlist.reset();
                if (!exists) {
                    return tl::unexpected("Playlist not found.");
                }
            }

            std::vector<std::string> track_ids;
            {
                SQLite::Statement select_tracks(
                    db,
                    "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? "
                    "ORDER BY (position IS NULL) ASC, position ASC, track_id ASC");
                select_tracks.bind(1, playlist_id);
                track_ids = SqliteHelper::fetch_all(select_tracks, [](SQLite::Statement &q) {
                    return q.getColumn(0).getString();
                });
            }

            if (track_ids.empty() || old_index < 0 || new_index < 0 ||
                static_cast<size_t>(old_index) >= track_ids.size() ||
                static_cast<size_t>(new_index) >= track_ids.size()) {
                return tl::unexpected("Index out of range.");
            }

            if (old_index == new_index) {
                return track_ids;
            }

            std::string moved = std::move(track_ids[static_cast<size_t>(old_index)]);
            track_ids.erase(track_ids.begin() + old_index);
            track_ids.insert(track_ids.begin() + new_index, std::move(moved));

            {
                SQLite::Statement update_stmt(
                    db,
                    "UPDATE Playlist_Track SET position = ? WHERE playlist_id = ? AND track_id = ?");
                for (size_t i = 0; i < track_ids.size(); ++i) {
                    update_stmt.reset();
                    update_stmt.clearBindings();
                    update_stmt.bind(1, static_cast<int>(i));
                    update_stmt.bind(2, playlist_id);
                    update_stmt.bind(3, track_ids[i]);
                    if (update_stmt.exec() != 1) {
                        update_stmt.reset();
                        return tl::unexpected("Failed to update playlist track position.");
                    }
                }
                update_stmt.reset();
            }

            if (auto touch_res = touch_entity(playlist_id); !touch_res) {
                return tl::unexpected(touch_res.error());
            }

            return track_ids;
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
