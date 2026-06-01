// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../utils/sqlite_helper.h"
#include "sqlite_work_repository.h"

namespace lyra {

SqliteWorkRepository::SqliteWorkRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteWorkRepository::insert(const Work &work) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query1(db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'work', datetime('now'), datetime('now'))");
        query1.bind(1, work.id);
        query1.exec();

        SQLite::Statement query2(db, "INSERT INTO Work (id, title, composition_start_year, "
                                      "composition_end_year, composition_date_text, iswc, "
                                      "musicbrainz_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) query2.bind(index, *val);
            else query2.bind(index);
        };
        query2.bind(1, work.id);
        query2.bind(2, work.title);
        bind_opt(3, work.composition_start_year);
        bind_opt(4, work.composition_end_year);
        bind_opt(5, work.composition_date_text);
        bind_opt(6, work.iswc);
        bind_opt(7, work.musicbrainz_id);

        query2.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Work, std::string> SqliteWorkRepository::get(const std::string &work_id) {

    auto &db = m_context.get_db();

    SQLite::Statement query(db, "SELECT * FROM Work WHERE id = ?");
    query.bind(1, work_id);

    if (query.executeStep()) {
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
    return tl::unexpected("Work not found.");
}

tl::expected<void, std::string> SqliteWorkRepository::update(const WorkUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Work SET ";
        std::vector<std::string> fields;
        if (data.title) fields.emplace_back("title = ?");
        if (data.composition_start_year) fields.emplace_back("composition_start_year = ?");
        if (data.composition_end_year) fields.emplace_back("composition_end_year = ?");
        if (data.composition_date_text) fields.emplace_back("composition_date_text = ?");
        if (data.iswc) fields.emplace_back("iswc = ?");
        if (data.musicbrainz_id) fields.emplace_back("musicbrainz_id = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        if (data.title) query.bind(bind_idx++, *data.title);
        if (data.composition_start_year) query.bind(bind_idx++, *data.composition_start_year);
        if (data.composition_end_year) query.bind(bind_idx++, *data.composition_end_year);
        if (data.composition_date_text) query.bind(bind_idx++, *data.composition_date_text);
        if (data.iswc) query.bind(bind_idx++, *data.iswc);
        if (data.musicbrainz_id) query.bind(bind_idx++, *data.musicbrainz_id);
        query.bind(bind_idx, data.id);

        if (query.exec() == 0) return tl::unexpected("Work ID not found.");

        SQLite::Statement update_entity(db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<PaginatedResult<Work>, std::string> SqliteWorkRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Work";
        std::string select_sql = "SELECT * FROM Work";
        
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
        
        std::vector<Work> items;
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
                Work work;
                work.id = select_query.getColumn("id").getString();
                work.title = select_query.getColumn("title").getString();
                work.composition_start_year = SqliteHelper::get_optional<int>(select_query, "composition_start_year");
                work.composition_end_year = SqliteHelper::get_optional<int>(select_query, "composition_end_year");
                work.composition_date_text = SqliteHelper::get_optional<std::string>(select_query, "composition_date_text");
                work.iswc = SqliteHelper::get_optional<std::string>(select_query, "iswc");
                work.musicbrainz_id = SqliteHelper::get_optional<std::string>(select_query, "musicbrainz_id");
                items.push_back(work);
            }
        }
        
        return PaginatedResult<Work>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
