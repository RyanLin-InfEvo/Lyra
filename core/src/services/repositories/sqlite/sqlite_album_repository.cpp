// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_album_repository.h"

namespace lyra {

SqliteAlbumRepository::SqliteAlbumRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Album", "album", "title") {}

tl::expected<void, std::string> SqliteAlbumRepository::insert(const Album &album) {
    return SqliteEntityRepository::insert(album);
}

tl::expected<void, std::string> SqliteAlbumRepository::update(const AlbumUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Album, std::string> SqliteAlbumRepository::get(const std::string &album_id) {
    return SqliteEntityRepository::get(album_id);
}

tl::expected<PaginatedResult<Album>, std::string> SqliteAlbumRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return SqliteEntityRepository::list(offset, limit, search);
}

tl::expected<std::vector<Album>, std::string> SqliteAlbumRepository::get_by_title(const std::string &title) {
    return get_by_field("title", title);
}

tl::expected<void, std::string> SqliteAlbumRepository::do_insert(SQLite::Database &db, const Album &album) {
    SQLite::Statement query(db,
                            "INSERT INTO Album (id, title, release_year, release_month, release_day) "
                            "VALUES (?, ?, ?, ?, ?)");
    query.bind(1, album.id);
    query.bind(2, album.title);
    bind_optional(query, 3, album.release_year);
    bind_optional(query, 4, album.release_month);
    bind_optional(query, 5, album.release_day);
    query.exec();
    return {};
}

void SqliteAlbumRepository::build_update(SqliteUpdateBuilder &builder, const AlbumUpdate &data) const {
    builder.set("title", data.title)
        .set("release_year", data.release_year)
        .set("release_month", data.release_month)
        .set("release_day", data.release_day);
}

} // namespace lyra
