/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "sqlite_mappers.h"

namespace lyra {
namespace SqliteMappers {

Asset map_asset(SQLite::Statement &query) {
    Asset asset;
    asset.file_hash = query.getColumn("file_hash").getString();
    asset.mime_type = SqliteHelper::get_safe<std::string>(query, "mime_type", "");
    asset.asset_type = SqliteHelper::get_safe<std::string>(query, "asset_type", "");
    asset.file_size = SqliteHelper::get_safe<int>(query, "file_size", 0);
    asset.created_at = SqliteHelper::get_safe<std::string>(query, "created_at", "");
    return asset;
}

Audio map_audio(SQLite::Statement &query) {
    Audio audio;
    audio.pcm_hash = query.getColumn("pcm_hash").getString();
    audio.parent_hash = SqliteHelper::get_safe<std::string>(query, "parent_hash", "");
    audio.quality_score = SqliteHelper::get_safe<int>(query, "quality_score", 0);
    audio.bit_depth = SqliteHelper::get_safe<int>(query, "bit_depth", 0);
    audio.sample_rate = SqliteHelper::get_safe<int>(query, "sample_rate", 0);
    audio.channels = SqliteHelper::get_safe<int>(query, "channels", 0);
    audio.duration = SqliteHelper::get_safe<double>(query, "duration", 0.0);
    audio.integrated_loudness = SqliteHelper::get_safe<double>(query, "integrated_loudness", 0.0);
    audio.true_peak = SqliteHelper::get_safe<double>(query, "true_peak", 0.0);
    return audio;
}

Track map_track(SQLite::Statement &query) {
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

Album map_album(SQLite::Statement &query) {
    Album album;
    album.id = query.getColumn("id").getString();
    album.title = query.getColumn("title").getString();
    album.release_year = SqliteHelper::get_optional<int>(query, "release_year");
    album.release_month = SqliteHelper::get_optional<int>(query, "release_month");
    album.release_day = SqliteHelper::get_optional<int>(query, "release_day");
    return album;
}

Artist map_artist(SQLite::Statement &query) {
    Artist artist;
    artist.id = query.getColumn("id").getString();
    artist.name = query.getColumn("name").getString();
    artist.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
    artist.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
    artist.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");
    return artist;
}

Work map_work(SQLite::Statement &query) {
    Work work;
    work.id = query.getColumn("id").getString();
    work.title = query.getColumn("title").getString();
    work.composition_start_year = SqliteHelper::get_optional<int>(query, "composition_start_year");
    work.composition_end_year = SqliteHelper::get_optional<int>(query, "composition_end_year");
    work.composition_date_text = SqliteHelper::get_optional<std::string>(query, "composition_date_text");
    work.iswc = SqliteHelper::get_optional<std::string>(query, "iswc");
    work.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
    return work;
}

Playlist map_playlist(SQLite::Statement &query) {
    Playlist playlist;
    playlist.id = query.getColumn("id").getString();
    playlist.title = query.getColumn("title").getString();
    playlist.description = SqliteHelper::get_optional<std::string>(query, "description");
    return playlist;
}

Image map_image(SQLite::Statement &query) {
    Image img;
    img.image_hash = query.getColumn("image_hash").getString();
    img.file_hash = query.getColumn("file_hash").getString();
    img.width = SqliteHelper::get_safe<int>(query, "width", 0);
    img.height = SqliteHelper::get_safe<int>(query, "height", 0);
    img.dominant_color = SqliteHelper::get_safe<std::string>(query, "dominant_color", "");
    if (SqliteHelper::has_column(query, "role") && !query.isColumnNull("role")) {
        img.role = query.getColumn("role").getString();
    }
    return img;
}

} // namespace SqliteMappers
} // namespace lyra
