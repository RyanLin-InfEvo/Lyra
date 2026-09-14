// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_artist_repository.h"

namespace lyra {

SqliteArtistRepository::SqliteArtistRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Artist", "artist", "name") {}

tl::expected<void, std::string> SqliteArtistRepository::insert(const Artist &artist) {
    return SqliteEntityRepository::insert(artist);
}

tl::expected<void, std::string> SqliteArtistRepository::update(const ArtistUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Artist, std::string> SqliteArtistRepository::get(const std::string &artist_id) {
    return SqliteEntityRepository::get(artist_id);
}

tl::expected<PaginatedResult<Artist>, std::string> SqliteArtistRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return SqliteEntityRepository::list(offset, limit, search);
}

tl::expected<std::vector<Artist>, std::string> SqliteArtistRepository::get_by_name(const std::string &name) {
    return get_by_field("name", name);
}

tl::expected<void, std::string> SqliteArtistRepository::do_insert(SQLite::Database &db, const Artist &artist) {
    SQLite::Statement query(db,
                            "INSERT INTO Artist (id, name, musicbrainz_id, spotify_id, ytm_id) "
                            "VALUES (?, ?, ?, ?, ?)");
    query.bind(1, artist.id);
    query.bind(2, artist.name);
    bind_optional(query, 3, artist.musicbrainz_id);
    bind_optional(query, 4, artist.spotify_id);
    bind_optional(query, 5, artist.ytm_id);
    query.exec();
    return {};
}

void SqliteArtistRepository::build_update(SqliteUpdateBuilder &builder, const ArtistUpdate &data) const {
    builder.set("name", data.name)
        .set("musicbrainz_id", data.musicbrainz_id)
        .set("ytm_id", data.ytm_id)
        .set("spotify_id", data.spotify_id);
}

} // namespace lyra
