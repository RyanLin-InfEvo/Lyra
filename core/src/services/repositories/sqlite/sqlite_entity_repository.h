// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <SQLiteCpp/SQLiteCpp.h>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <utility>
#include <vector>

#include "../../../utils/paginated_result.h"
#include "../../../utils/sqlite_helper.h"
#include "../../../utils/sqlite_mappers.h"
#include "../../../utils/sqlite_update_builder.h"
#include "../../database_context.h"

namespace lyra {

/**
 * @brief Generic base repository for Lyra Entity tables.
 *
 * Encapsulates the Entity transaction lifecycle, dynamic UPDATE building,
 * get-by-id, field lookups, search pagination with LIKE escaping, and
 * dual-defense Entity.updated_at synchronization.
 *
 * @tparam TEntity The concrete entity model type (e.g. Album, Artist)
 * @tparam TUpdate The corresponding update payload type (e.g. AlbumUpdate, ArtistUpdate)
 */
template <typename TEntity, typename TUpdate>
class SqliteEntityRepository {
  public:
    SqliteEntityRepository(IDatabaseContext &context,
                           std::string table_name,
                           std::string entity_type,
                           std::string default_search_field)
        : m_context(context),
          m_table_name(std::move(table_name)),
          m_entity_type(std::move(entity_type)),
          m_default_search_field(std::move(default_search_field)) {}

    virtual ~SqliteEntityRepository() = default;

    /**
     * @brief Inserts the entity into the Entity table and the concrete table atomically.
     */
    virtual tl::expected<void, std::string> insert(const TEntity &entity) {
        try {
            return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
                auto &db = m_context.get_db();

                SQLite::Statement entity_stmt(
                    db,
                    "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                    "VALUES (?, ?, datetime('now'), datetime('now'))");
                entity_stmt.bind(1, entity.id);
                entity_stmt.bind(2, m_entity_type);
                entity_stmt.exec();

                auto res = do_insert(db, entity);
                if (!res) {
                    return res;
                }

                return {};
            });
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Performs a dynamic partial update atomically.
     */
    virtual tl::expected<void, std::string> update(const TUpdate &data) {
        try {
            return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
                auto &db = m_context.get_db();

                SqliteUpdateBuilder builder(m_table_name, data.id);
                build_update(builder, data);

                if (builder.empty()) {
                    auto exists = get(data.id);
                    if (!exists) {
                        return tl::unexpected(m_table_name + " ID not found.");
                    }
                    return {};
                }

                auto res = builder.execute(db);
                if (!res) {
                    return res;
                }

                return {};
            });
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Fetches an entity by its primary ID.
     */
    virtual tl::expected<TEntity, std::string> get(const std::string &id) {
        try {
            auto &db = m_context.get_db();
            std::string sql = "SELECT * FROM " + SqliteHelper::quote_identifier(m_table_name) +
                              " WHERE " + SqliteHelper::quote_identifier("id") + " = ?";
            SQLite::Statement query(db, sql);
            query.bind(1, id);

            auto entity = SqliteHelper::fetch_one<TEntity>(query);
            if (entity) {
                return *entity;
            }
            return tl::unexpected(m_table_name + " not found.");
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Paginated listing with optional search on the default search field.
     */
    virtual tl::expected<PaginatedResult<TEntity>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) {
        try {
            auto &db = m_context.get_db();
            const std::string table = SqliteHelper::quote_identifier(m_table_name);
            const std::string search_field = SqliteHelper::quote_identifier(m_default_search_field);
            const std::string id_col = SqliteHelper::quote_identifier("id");

            std::string count_sql = "SELECT COUNT(*) FROM " + table;
            std::string select_sql = "SELECT * FROM " + table;

            if (search.has_value()) {
                count_sql += " WHERE " + search_field + R"( LIKE ? ESCAPE '\' )";
                select_sql += " WHERE " + search_field + R"( LIKE ? ESCAPE '\' )";
            }

            select_sql += " ORDER BY " + search_field + " ASC, " + id_col + " ASC LIMIT ? OFFSET ?";

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

            SQLite::Statement select_query(db, select_sql);
            int bind_idx = 1;
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                select_query.bind(bind_idx++, query_param);
            }
            select_query.bind(bind_idx++, limit);
            select_query.bind(bind_idx++, offset);

            std::vector<TEntity> items = SqliteHelper::fetch_all<TEntity>(select_query, limit);

            return PaginatedResult<TEntity>{
                .items = std::move(items),
                .total = total,
                .offset = offset,
                .limit = limit,
            };
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Finds multiple entities by matching a specific column value.
     */
    template <typename ValueType>
    tl::expected<std::vector<TEntity>, std::string> get_by_field(
        const std::string &field_name,
        const ValueType &val,
        const std::string &order_by_col = "id",
        bool ascending = true) {
        try {
            auto &db = m_context.get_db();
            std::string sql = "SELECT * FROM " + SqliteHelper::quote_identifier(m_table_name) +
                              " WHERE " + SqliteHelper::quote_identifier(field_name) + " = ?";
            if (!order_by_col.empty()) {
                sql += " ORDER BY " + SqliteHelper::quote_identifier(order_by_col) + (ascending ? " ASC" : " DESC");
            }
            SQLite::Statement query(db, sql);
            query.bind(1, val);

            return SqliteHelper::fetch_all<TEntity>(query);
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Finds at most one entity by matching a specific column value.
     */
    template <typename ValueType>
    tl::expected<std::optional<TEntity>, std::string> get_one_by_field(
        const std::string &field_name,
        const ValueType &val) {
        try {
            auto &db = m_context.get_db();
            std::string sql = "SELECT * FROM " + SqliteHelper::quote_identifier(m_table_name) +
                              " WHERE " + SqliteHelper::quote_identifier(field_name) + " = ? LIMIT 1";
            SQLite::Statement query(db, sql);
            query.bind(1, val);

            return SqliteHelper::fetch_one<TEntity>(query);
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Updates the Entity.updated_at timestamp to datetime('now').
     */
    tl::expected<void, std::string> touch_entity(const std::string &id) {
        try {
            auto &db = m_context.get_db();
            std::string sql = "UPDATE " + SqliteHelper::quote_identifier("Entity") + " SET " +
                              SqliteHelper::quote_identifier("updated_at") +
                              " = datetime('now') WHERE " +
                              SqliteHelper::quote_identifier("id") + " = ?";
            SQLite::Statement update_entity(db, sql);
            update_entity.bind(1, id);
            update_entity.exec();
            return {};
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

    /**
     * @brief Helper to bind std::optional values to a SQLite::Statement.
     */
    template <typename T>
    static void bind_optional(SQLite::Statement &stmt, int index, const std::optional<T> &val) {
        if (val.has_value()) {
            stmt.bind(index, *val);
        } else {
            stmt.bind(index);
        }
    }

    [[nodiscard]] IDatabaseContext &context() noexcept { return m_context; }
    [[nodiscard]] const IDatabaseContext &context() const noexcept { return m_context; }
    [[nodiscard]] const std::string &table_name() const noexcept { return m_table_name; }
    [[nodiscard]] const std::string &entity_type() const noexcept { return m_entity_type; }
    [[nodiscard]] const std::string &default_search_field() const noexcept { return m_default_search_field; }

  protected:
    virtual tl::expected<void, std::string> do_insert(SQLite::Database &db, const TEntity &entity) = 0;
    virtual void build_update(SqliteUpdateBuilder &builder, const TUpdate &data) const = 0;

    IDatabaseContext &m_context;
    std::string m_table_name;
    std::string m_entity_type;
    std::string m_default_search_field;
};

} // namespace lyra
