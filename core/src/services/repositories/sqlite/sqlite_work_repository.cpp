// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_work_repository.h"

namespace lyra {

SqliteWorkRepository::SqliteWorkRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Work", "work", "title") {}

tl::expected<void, std::string> SqliteWorkRepository::insert(const Work &work) {
    return SqliteEntityRepository::insert(work);
}

tl::expected<void, std::string> SqliteWorkRepository::update(const WorkUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Work, std::string> SqliteWorkRepository::get(const std::string &work_id) {
    return SqliteEntityRepository::get(work_id);
}

tl::expected<PaginatedResult<Work>, std::string> SqliteWorkRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return SqliteEntityRepository::list(offset, limit, search);
}

tl::expected<std::vector<Work>, std::string> SqliteWorkRepository::get_by_title(const std::string &title) {
    return get_by_field("title", title);
}

tl::expected<std::optional<Work>, std::string> SqliteWorkRepository::get_by_iswc(const std::string &iswc) {
    return get_one_by_field("iswc", iswc);
}

tl::expected<std::vector<Work>, std::string> SqliteWorkRepository::get_by_musicbrainz_id(
    const std::string &musicbrainz_id) {
    return get_by_field("musicbrainz_id", musicbrainz_id);
}

tl::expected<void, std::string> SqliteWorkRepository::do_insert(SQLite::Database &db, const Work &work) {
    SQLite::Statement query(db,
                            "INSERT INTO Work (id, title, composition_start_year, "
                            "composition_end_year, composition_date_text, iswc, "
                            "musicbrainz_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
    query.bind(1, work.id);
    query.bind(2, work.title);
    bind_optional(query, 3, work.composition_start_year);
    bind_optional(query, 4, work.composition_end_year);
    bind_optional(query, 5, work.composition_date_text);
    bind_optional(query, 6, work.iswc);
    bind_optional(query, 7, work.musicbrainz_id);
    query.exec();
    return {};
}

void SqliteWorkRepository::build_update(SqliteUpdateBuilder &builder, const WorkUpdate &data) const {
    builder.set("title", data.title)
        .set("composition_start_year", data.composition_start_year)
        .set("composition_end_year", data.composition_end_year)
        .set("composition_date_text", data.composition_date_text)
        .set("iswc", data.iswc)
        .set("musicbrainz_id", data.musicbrainz_id);
}

} // namespace lyra
