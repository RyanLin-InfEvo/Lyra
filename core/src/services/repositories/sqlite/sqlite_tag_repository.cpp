// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_tag_repository.h"

namespace lyra {

SqliteTagRepository::SqliteTagRepository(IDatabaseContext &context)
    : SqliteEntityRepository(context, "Tag", "tag", "name") {}

tl::expected<void, std::string> SqliteTagRepository::insert(const Tag &tag) {
    return SqliteEntityRepository::insert(tag);
}

tl::expected<void, std::string> SqliteTagRepository::update(const TagUpdate &update_data) {
    return SqliteEntityRepository::update(update_data);
}

tl::expected<Tag, std::string> SqliteTagRepository::get(const std::string &tag_id) {
    return SqliteEntityRepository::get(tag_id);
}

tl::expected<void, std::string> SqliteTagRepository::delete_tag(const std::string &tag_id) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();
            SQLite::Statement query(db, "DELETE FROM Entity WHERE id = ? AND entity_type = 'tag'");
            query.bind(1, tag_id);
            if (query.exec() == 0) {
                return tl::unexpected("Tag not found.");
            }
            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<PaginatedResult<Tag>, std::string> SqliteTagRepository::list(
    int offset,
    int limit,
    const std::optional<std::string> &search,
    const std::optional<std::string> &category) {
    try {
        auto &db = m_context.get_db();

        std::vector<std::string> conditions;
        if (search.has_value()) {
            conditions.emplace_back(R"("name" LIKE ? ESCAPE '\')");
        }
        if (category.has_value()) {
            conditions.emplace_back(R"("category" = ?)");
        }

        std::string where_clause;
        for (size_t i = 0; i < conditions.size(); ++i) {
            where_clause += (i == 0 ? " WHERE " : " AND ") + conditions[i];
        }

        std::string count_sql = "SELECT COUNT(*) FROM \"Tag\"" + where_clause;
        std::string select_sql =
            "SELECT * FROM \"Tag\"" + where_clause + R"( ORDER BY "name" ASC, "id" ASC LIMIT ? OFFSET ?)";

        int total = 0;
        {
            SQLite::Statement count_query(db, count_sql);
            int bind_idx = 1;
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(*search, '\\') + "%";
                count_query.bind(bind_idx++, query_param);
            }
            if (category.has_value()) {
                count_query.bind(bind_idx++, *category);
            }
            if (!count_query.executeStep()) {
                return tl::unexpected("Failed to get total count.");
            }
            total = count_query.getColumn(0).getInt();
        }

        SQLite::Statement select_query(db, select_sql);
        int bind_idx = 1;
        if (search.has_value()) {
            std::string query_param = "%" + SqliteHelper::escape_like(*search, '\\') + "%";
            select_query.bind(bind_idx++, query_param);
        }
        if (category.has_value()) {
            select_query.bind(bind_idx++, *category);
        }
        select_query.bind(bind_idx++, limit);
        select_query.bind(bind_idx++, offset);

        std::vector<Tag> items = SqliteHelper::fetch_all<Tag>(select_query, limit);

        return PaginatedResult<Tag>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTagRepository::do_insert(SQLite::Database &db, const Tag &tag) {
    SQLite::Statement query(db, "INSERT INTO Tag (id, name, category) VALUES (?, ?, ?)");
    query.bind(1, tag.id);
    query.bind(2, tag.name);
    query.bind(3, tag.category.empty() ? "general" : tag.category);
    query.exec();
    return {};
}

void SqliteTagRepository::build_update(SqliteUpdateBuilder &builder, const TagUpdate &data) const {
    builder.set("name", data.name)
        .set("category", data.category);
}

namespace {

tl::expected<void, std::string> check_entity_exists(
    SQLite::Database &db,
    const std::string &entity_id,
    const std::optional<std::string> &entity_type) {
    if (entity_type.has_value()) {
        SQLite::Statement stmt(db, "SELECT 1 FROM Entity WHERE id = ? AND entity_type = ?");
        stmt.bind(1, entity_id);
        stmt.bind(2, *entity_type);
        if (!stmt.executeStep()) {
            return tl::unexpected("Entity not found.");
        }
    } else {
        SQLite::Statement stmt(db, "SELECT 1 FROM Entity WHERE id = ? AND entity_type != 'tag'");
        stmt.bind(1, entity_id);
        if (!stmt.executeStep()) {
            return tl::unexpected("Entity not found.");
        }
    }
    return {};
}

} // namespace

tl::expected<void, std::string> SqliteTagRepository::assign_to_entity(
    const std::string &entity_id,
    const std::string &tag_id,
    const std::optional<std::string> &entity_type) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            if (auto ent_res = check_entity_exists(db, entity_id, entity_type); !ent_res) {
                return ent_res;
            }

            {
                SQLite::Statement check_tag(db, "SELECT 1 FROM Tag WHERE id = ?");
                check_tag.bind(1, tag_id);
                if (!check_tag.executeStep()) {
                    return tl::unexpected("Tag not found.");
                }
            }

            SQLite::Statement query(
                db, "INSERT OR IGNORE INTO Entity_Tag (entity_id, tag_id) VALUES (?, ?)");
            query.bind(1, entity_id);
            query.bind(2, tag_id);
            query.exec();

            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTagRepository::remove_from_entity(
    const std::string &entity_id,
    const std::string &tag_id,
    const std::optional<std::string> &entity_type) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            if (auto ent_res = check_entity_exists(db, entity_id, entity_type); !ent_res) {
                return ent_res;
            }

            SQLite::Statement query(
                db, "DELETE FROM Entity_Tag WHERE entity_id = ? AND tag_id = ?");
            query.bind(1, entity_id);
            query.bind(2, tag_id);

            if (query.exec() == 0) {
                return tl::unexpected("Relation not found.");
            }

            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<Tag>, std::string> SqliteTagRepository::get_entity_tags(
    const std::string &entity_id,
    const std::optional<std::string> &entity_type) {
    try {
        auto &db = m_context.get_db();

        if (auto ent_res = check_entity_exists(db, entity_id, entity_type); !ent_res) {
            return tl::unexpected(ent_res.error());
        }

        SQLite::Statement query(
            db,
            "SELECT t.* FROM Tag t "
            "INNER JOIN Entity_Tag et ON t.id = et.tag_id "
            "WHERE et.entity_id = ? "
            "ORDER BY t.name ASC, t.id ASC");
        query.bind(1, entity_id);

        return SqliteHelper::fetch_all<Tag>(query);
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
