// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_track_repository.h"

namespace lyra {

SqliteTrackRepository::SqliteTrackRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Track", "track", "title") {}

tl::expected<void, std::string> SqliteTrackRepository::insert(const Track &track) {
    return SqliteEntityRepository::insert(track);
}

tl::expected<void, std::string> SqliteTrackRepository::update(const TrackUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Track, std::string> SqliteTrackRepository::get(const std::string &track_id) {
    return SqliteEntityRepository::get(track_id);
}

tl::expected<PaginatedResult<Track>, std::string> SqliteTrackRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return SqliteEntityRepository::list(offset, limit, search);
}

tl::expected<std::vector<Track>, std::string> SqliteTrackRepository::get_by_title(const std::string &title) {
    return get_by_field("title", title);
}

tl::expected<std::vector<Track>, std::string> SqliteTrackRepository::get_by_pcm_hash(const std::string &pcm_hash) {
    return get_by_field("pcm_hash", pcm_hash);
}

tl::expected<void, std::string> SqliteTrackRepository::do_insert(SQLite::Database &db, const Track &track) {
    SQLite::Statement query(db,
                            "INSERT INTO Track (id, work_id, pcm_hash, title, recording_year, "
                            "recording_month, recording_day, recording_location, duration, "
                            "isrc, musicbrainz_id, ytm_id, spotify_id) "
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    query.bind(1, track.id);
    bind_optional(query, 2, track.work_id);
    query.bind(3, track.pcm_hash);
    bind_optional(query, 4, track.title);
    bind_optional(query, 5, track.recording_year);
    bind_optional(query, 6, track.recording_month);
    bind_optional(query, 7, track.recording_day);
    bind_optional(query, 8, track.recording_location);
    bind_optional(query, 9, track.duration);
    bind_optional(query, 10, track.isrc);
    bind_optional(query, 11, track.musicbrainz_id);
    bind_optional(query, 12, track.ytm_id);
    bind_optional(query, 13, track.spotify_id);
    query.exec();
    return {};
}

void SqliteTrackRepository::build_update(SqliteUpdateBuilder &builder, const TrackUpdate &data) const {
    builder.set("work_id", data.work_id)
        .set("pcm_hash", data.pcm_hash)
        .set("title", data.title)
        .set("recording_year", data.recording_year)
        .set("recording_month", data.recording_month)
        .set("recording_day", data.recording_day)
        .set("recording_location", data.recording_location)
        .set("duration", data.duration)
        .set("isrc", data.isrc)
        .set("musicbrainz_id", data.musicbrainz_id)
        .set("ytm_id", data.ytm_id)
        .set("spotify_id", data.spotify_id);
}

tl::expected<void, std::string> SqliteTrackRepository::add_artist(const TrackArtistParams &params) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
                check_track.bind(1, params.track_id);
                if (!check_track.executeStep()) {
                    return tl::unexpected("Target Track not found.");
                }
            }

            {
                SQLite::Statement check_artist(db, "SELECT 1 FROM Artist WHERE id = ?");
                check_artist.bind(1, params.artist_id);
                if (!check_artist.executeStep()) {
                    return tl::unexpected("Target Artist not found.");
                }
            }

            SQLite::Statement query(
                db, "INSERT OR REPLACE INTO Track_Artist (track_id, artist_id, role, position) VALUES (?, ?, ?, ?)");
            query.bind(1, params.track_id);
            query.bind(2, params.artist_id);
            if (params.role) {
                query.bind(3, ArtistRoleMapper::to_string(*params.role));
            } else {
                query.bind(3);
            }
            if (params.position) {
                query.bind(4, *params.position);
            } else {
                query.bind(4);
            }
            query.exec();

            return touch_entity(params.track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTrackRepository::remove_artist(
    const std::string &track_id, const std::string &artist_id) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            SQLite::Statement query(db, "DELETE FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
            query.bind(1, track_id);
            query.bind(2, artist_id);

            if (query.exec() == 0) {
                return tl::unexpected("Relation not found or already removed.");
            }

            return touch_entity(track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTrackRepository::update_artist(const TrackArtistParams &params) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            SQLite::Statement query(
                db,
                "UPDATE Track_Artist SET role = COALESCE(?, role), "
                "position = COALESCE(?, position) WHERE track_id = ? AND "
                "artist_id = ?");
            if (params.role) {
                query.bind(1, ArtistRoleMapper::to_string(*params.role));
            } else {
                query.bind(1);
            }
            if (params.position) {
                query.bind(2, *params.position);
            } else {
                query.bind(2);
            }
            query.bind(3, params.track_id);
            query.bind(4, params.artist_id);

            if (query.exec() == 0) {
                return tl::unexpected("Relation not found. Cannot update.");
            }

            return touch_entity(params.track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTrackRepository::add_album(const TrackAlbumParams &params) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
                check_track.bind(1, params.track_id);
                if (!check_track.executeStep()) {
                    return tl::unexpected("Target Track not found.");
                }
            }

            {
                SQLite::Statement check_album(db, "SELECT 1 FROM Album WHERE id = ?");
                check_album.bind(1, params.album_id);
                if (!check_album.executeStep()) {
                    return tl::unexpected("Target Album not found.");
                }
            }

            SQLite::Statement query(
                db, "INSERT OR REPLACE INTO Track_Album (track_id, album_id, position) VALUES (?, ?, ?)");
            query.bind(1, params.track_id);
            query.bind(2, params.album_id);
            if (params.position) {
                query.bind(3, *params.position);
            } else {
                query.bind(3);
            }
            query.exec();

            return touch_entity(params.track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTrackRepository::remove_album(
    const std::string &track_id, const std::string &album_id) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            SQLite::Statement query(db, "DELETE FROM Track_Album WHERE track_id = ? AND album_id = ?");
            query.bind(1, track_id);
            query.bind(2, album_id);

            if (query.exec() == 0) {
                return tl::unexpected("Relation not found or already removed.");
            }

            return touch_entity(track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTrackRepository::update_album(const TrackAlbumParams &params) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            SQLite::Statement query(
                db, "UPDATE Track_Album SET position = COALESCE(?, position) WHERE track_id = ? AND album_id = ?");
            if (params.position) {
                query.bind(1, *params.position);
            } else {
                query.bind(1);
            }
            query.bind(2, params.track_id);
            query.bind(3, params.album_id);

            if (query.exec() == 0) {
                return tl::unexpected("Relation not found. Cannot update.");
            }

            return touch_entity(params.track_id);
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::optional<std::string>, std::string> SqliteTrackRepository::get_album_id_by_track(
    const std::string &track_id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT album_id FROM Track_Album WHERE track_id = ? LIMIT 1");
        query.bind(1, track_id);
        return SqliteHelper::fetch_one(query, [](SQLite::Statement &q) {
            return q.getColumn("album_id").getString();
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
