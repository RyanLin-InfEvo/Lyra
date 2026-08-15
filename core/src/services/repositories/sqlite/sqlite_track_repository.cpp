// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../../utils/sqlite_helper.h"
#include "sqlite_track_repository.h"

namespace lyra {

SqliteTrackRepository::SqliteTrackRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteTrackRepository::insert(const Track &track) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query1(db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'track', datetime('now'), datetime('now'))");
        query1.bind(1, track.id);
        query1.exec();

        SQLite::Statement query2(db,
                                 "INSERT INTO Track (id, work_id, pcm_hash, title, recording_year, "
                                 "recording_month, recording_day, recording_location, duration, "
                                 "isrc, musicbrainz_id, ytm_id, spotify_id) "
                                 "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) query2.bind(index, *val);
            else query2.bind(index);
        };

        query2.bind(1, track.id);
        bind_opt(2, track.work_id);
        query2.bind(3, track.pcm_hash);
        bind_opt(4, track.title);
        bind_opt(5, track.recording_year);
        bind_opt(6, track.recording_month);
        bind_opt(7, track.recording_day);
        bind_opt(8, track.recording_location);
        bind_opt(9, track.duration);
        bind_opt(10, track.isrc);
        bind_opt(11, track.musicbrainz_id);
        bind_opt(12, track.ytm_id);
        bind_opt(13, track.spotify_id);

        query2.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Track, std::string> SqliteTrackRepository::get(const std::string &track_id) {

    auto &db = m_context.get_db();

    SQLite::Statement query(db, "SELECT * FROM Track WHERE id = ?");
    query.bind(1, track_id);

    if (query.executeStep()) {
        Track track;
        track.id = query.getColumn("id").getString();
        track.pcm_hash = query.getColumn("pcm_hash").getString();
        track.work_id = SqliteHelper::get_optional<std::string>(query, "work_id");
        track.title = SqliteHelper::get_optional<std::string>(query, "title");
        track.recording_year = SqliteHelper::get_optional<int>(query, "recording_year");
        track.recording_month = SqliteHelper::get_optional<int>(query, "recording_month");
        track.recording_day = SqliteHelper::get_optional<int>(query, "recording_day");
        track.recording_location = SqliteHelper::get_optional<std::string>(query, "recording_location");
        track.duration = SqliteHelper::get_optional<int>(query, "duration");
        track.isrc = SqliteHelper::get_optional<std::string>(query, "isrc");
        track.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
        track.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
        track.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");
        return track;
    }
    return tl::unexpected("Track not found.");
}

tl::expected<void, std::string> SqliteTrackRepository::update(const TrackUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Track SET ";
        std::vector<std::string> fields;
        if (data.work_id) fields.emplace_back("work_id = ?");
        if (data.pcm_hash) fields.emplace_back("pcm_hash = ?");
        if (data.title) fields.emplace_back("title = ?");
        if (data.recording_year) fields.emplace_back("recording_year = ?");
        if (data.recording_month) fields.emplace_back("recording_month = ?");
        if (data.recording_day) fields.emplace_back("recording_day = ?");
        if (data.recording_location) fields.emplace_back("recording_location = ?");
        if (data.duration) fields.emplace_back("duration = ?");
        if (data.isrc) fields.emplace_back("isrc = ?");
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
        if (data.work_id) query.bind(bind_idx++, *data.work_id);
        if (data.pcm_hash) query.bind(bind_idx++, *data.pcm_hash);
        if (data.title) query.bind(bind_idx++, *data.title);
        if (data.recording_year) query.bind(bind_idx++, *data.recording_year);
        if (data.recording_month) query.bind(bind_idx++, *data.recording_month);
        if (data.recording_day) query.bind(bind_idx++, *data.recording_day);
        if (data.recording_location) query.bind(bind_idx++, *data.recording_location);
        if (data.duration) query.bind(bind_idx++, *data.duration);
        if (data.isrc) query.bind(bind_idx++, *data.isrc);
        if (data.musicbrainz_id) query.bind(bind_idx++, *data.musicbrainz_id);
        if (data.ytm_id) query.bind(bind_idx++, *data.ytm_id);
        if (data.spotify_id) query.bind(bind_idx++, *data.spotify_id);
        query.bind(bind_idx, data.id);

        if (query.exec() == 0) return tl::unexpected("Track ID not found.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::add_artist(const TrackArtistParams &params) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        {
            SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
            check_track.bind(1, params.track_id);
            if (!check_track.executeStep()) return tl::unexpected("Target Track not found.");
        }

        {
            SQLite::Statement check_artist(db, "SELECT 1 FROM Artist WHERE id = ?");
            check_artist.bind(1, params.artist_id);
            if (!check_artist.executeStep()) return tl::unexpected("Target Artist not found.");
        }

        SQLite::Statement query(db, "INSERT OR REPLACE INTO Track_Artist (track_id, artist_id, role, position) VALUES (?, ?, ?, ?)");
        query.bind(1, params.track_id);
        query.bind(2, params.artist_id);
        if (params.role) query.bind(3, ArtistRoleMapper::to_string(*params.role));
        else query.bind(3);
        if (params.position) query.bind(4, *params.position);
        else query.bind(4);

        query.exec();
        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, params.track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::remove_artist(const std::string &track_id, const std::string &artist_id) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "DELETE FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
        query.bind(1, track_id);
        query.bind(2, artist_id);

        if (query.exec() == 0) return tl::unexpected("Relation not found or already removed.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::update_artist(const TrackArtistParams &params) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "UPDATE Track_Artist SET role = COALESCE(?, role), "
                                    "position = COALESCE(?, position) WHERE track_id = ? AND "
                                    "artist_id = ?");
        if (params.role) query.bind(1, ArtistRoleMapper::to_string(*params.role));
        else query.bind(1);
        if (params.position) query.bind(2, *params.position);
        else query.bind(2);
        query.bind(3, params.track_id);
        query.bind(4, params.artist_id);

        if (query.exec() == 0) return tl::unexpected("Relation not found. Cannot update.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, params.track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::add_album(const TrackAlbumParams &params) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        {
            SQLite::Statement check_track(db, "SELECT 1 FROM Track WHERE id = ?");
            check_track.bind(1, params.track_id);
            if (!check_track.executeStep()) return tl::unexpected("Target Track not found.");
        }

        {
            SQLite::Statement check_album(db, "SELECT 1 FROM Album WHERE id = ?");
            check_album.bind(1, params.album_id);
            if (!check_album.executeStep()) return tl::unexpected("Target Album not found.");
        }

        SQLite::Statement query(db, "INSERT OR REPLACE INTO Track_Album (track_id, album_id, position) VALUES (?, ?, ?)");
        query.bind(1, params.track_id);
        query.bind(2, params.album_id);
        if (params.position) query.bind(3, *params.position);
        else query.bind(3);

        query.exec();
        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, params.track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::remove_album(const std::string &track_id, const std::string &album_id) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "DELETE FROM Track_Album WHERE track_id = ? AND album_id = ?");
        query.bind(1, track_id);
        query.bind(2, album_id);

        if (query.exec() == 0) return tl::unexpected("Relation not found or already removed.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteTrackRepository::update_album(const TrackAlbumParams &params) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "UPDATE Track_Album SET position = COALESCE(?, position) WHERE track_id = ? AND album_id = ?");
        if (params.position) query.bind(1, *params.position);
        else query.bind(1);
        query.bind(2, params.track_id);
        query.bind(3, params.album_id);

        if (query.exec() == 0) return tl::unexpected("Relation not found. Cannot update.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, params.track_id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}


tl::expected<PaginatedResult<Track>, std::string> SqliteTrackRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Track";
        std::string select_sql = "SELECT * FROM Track";

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

        std::vector<Track> items;
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
                Track track;
                track.id = select_query.getColumn("id").getString();
                track.pcm_hash = select_query.getColumn("pcm_hash").getString();
                track.work_id = SqliteHelper::get_optional<std::string>(select_query, "work_id");
                track.title = SqliteHelper::get_optional<std::string>(select_query, "title");
                track.recording_year = SqliteHelper::get_optional<int>(select_query, "recording_year");
                track.recording_month = SqliteHelper::get_optional<int>(select_query, "recording_month");
                track.recording_day = SqliteHelper::get_optional<int>(select_query, "recording_day");
                track.recording_location = SqliteHelper::get_optional<std::string>(select_query, "recording_location");
                track.duration = SqliteHelper::get_optional<int>(select_query, "duration");
                track.isrc = SqliteHelper::get_optional<std::string>(select_query, "isrc");
                track.musicbrainz_id = SqliteHelper::get_optional<std::string>(select_query, "musicbrainz_id");
                track.ytm_id = SqliteHelper::get_optional<std::string>(select_query, "ytm_id");
                track.spotify_id = SqliteHelper::get_optional<std::string>(select_query, "spotify_id");
                items.push_back(track);
            }
        }

        return PaginatedResult<Track>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<Track>, std::string> SqliteTrackRepository::get_by_title(const std::string &title) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT * FROM Track WHERE title = ? ORDER BY id ASC");
        query.bind(1, title);

        std::vector<Track> tracks;
        while (query.executeStep()) {
            Track track;
            track.id = query.getColumn("id").getString();
            track.pcm_hash = query.getColumn("pcm_hash").getString();
            track.work_id = SqliteHelper::get_optional<std::string>(query, "work_id");
            track.title = SqliteHelper::get_optional<std::string>(query, "title");
            track.recording_year = SqliteHelper::get_optional<int>(query, "recording_year");
            track.recording_month = SqliteHelper::get_optional<int>(query, "recording_month");
            track.recording_day = SqliteHelper::get_optional<int>(query, "recording_day");
            track.recording_location = SqliteHelper::get_optional<std::string>(query, "recording_location");
            track.duration = SqliteHelper::get_optional<int>(query, "duration");
            track.isrc = SqliteHelper::get_optional<std::string>(query, "isrc");
            track.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
            track.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
            track.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");
            tracks.push_back(track);
        }
        return tracks;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
