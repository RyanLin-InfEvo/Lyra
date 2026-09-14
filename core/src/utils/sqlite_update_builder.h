// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "sqlite_helper.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <tl/expected.hpp>
#include <type_traits>
#include <utility>
#include <vector>

namespace lyra {

namespace detail {
/// @brief Type trait primary template: defaults to false for any arbitrary type T.
template <typename T>
struct is_optional : std::false_type {};

/// @brief Type trait specialization: returns true if T is an instantiation of std::optional<U>.
template <typename T>
struct is_optional<std::optional<T>> : std::true_type {};

/// @brief Helper variable template for checking whether T is an std::optional.
template <typename T>
inline constexpr bool is_optional_v = is_optional<T>::value;
} // namespace detail

/**
 * @brief Lightweight, type-safe builder for dynamic SQLite UPDATE statements.
 *
 * Supports partial update semantics (e.g. PATCH) by chaining `.set("col_name", std::optional<T>)`.
 * Builds parameterized queries (`UPDATE "table" SET "col1" = ?, "col2" = ? WHERE "id" = ?`)
 * with identifier double-quoting to prevent keyword collisions, and uses type-erased lambdas
 * for deferred parameter binding and affected row count validation upon execution.
 */
class SqliteUpdateBuilder {
  public:
    /**
     * @brief Constructs a builder for the specified table without setting a WHERE clause.
     * @param table_name Name of the target SQLite table.
     */
    explicit SqliteUpdateBuilder(std::string table_name)
        : m_table_name(std::move(table_name)) {}

    /**
     * @brief Constructs a builder and configures an initial primary key equality condition.
     * @param table_name Name of the target SQLite table.
     * @param id The entity primary key value.
     * @param id_column Column name for the primary key (defaults to "id").
     */
    SqliteUpdateBuilder(std::string table_name, std::string id, std::string id_column = "id")
        : m_table_name(std::move(table_name)) {
        where_id(std::move(id), std::move(id_column));
    }

    /**
     * @brief Conditionally stages an update for a column if the optional contains a value.
     *
     * If @p val has a value, appends `"\"col_name\" = ?"` to the assignment list and captures
     * the value in a type-erased lambda binder. If @p val is std::nullopt, the column is skipped.
     *
     * @tparam T The underlying data type.
     * @param col_name Target column name.
     * @param val Optional value to be updated.
     * @return Reference to this builder for method chaining.
     */
    template <typename T>
    SqliteUpdateBuilder &set(const std::string &col_name, const std::optional<T> &val) {
        if (val.has_value()) {
            m_assignments.push_back(SqliteHelper::quote_identifier(col_name) + " = ?");
            // Capture value copy in a type-erased closure for deferred binding.
            if constexpr (std::is_convertible_v<T, std::string_view>) {
                m_binders.push_back([v = std::string(*val)](SQLite::Statement &stmt, int index) {
                    stmt.bind(index, v);
                });
            } else {
                m_binders.push_back([v = *val](SQLite::Statement &stmt, int index) {
                    stmt.bind(index, v);
                });
            }
        }
        return *this;
    }

    /**
     * @brief Unconditionally stages an update for a column with a non-optional value.
     *
     * Uses C++20 concepts (`requires`) to prevent overload ambiguity when an std::optional is passed.
     *
     * @tparam T The value type (must not be an std::optional).
     * @param col_name Target column name.
     * @param val The value to be set.
     * @return Reference to this builder for method chaining.
     */
    template <typename T>
        requires(!detail::is_optional_v<std::decay_t<T>>)
    SqliteUpdateBuilder &set(const std::string &col_name, const T &val) {
        m_assignments.push_back(SqliteHelper::quote_identifier(col_name) + " = ?");
        // Capture value copy in a type-erased closure for deferred binding.
        if constexpr (std::is_convertible_v<T, std::string_view>) {
            m_binders.push_back([v = std::string(val)](SQLite::Statement &stmt, int index) {
                stmt.bind(index, v);
            });
        } else {
            m_binders.push_back([v = val](SQLite::Statement &stmt, int index) {
                stmt.bind(index, v);
            });
        }
        return *this;
    }

    /**
     * @brief Configures a WHERE equality clause on the entity ID column.
     * @param id The entity ID value to match.
     * @param id_column The ID column name (defaults to "id").
     * @return Reference to this builder for method chaining.
     */
    SqliteUpdateBuilder &where_id(std::string id, std::string id_column = "id") {
        m_where_clause = SqliteHelper::quote_identifier(id_column) + " = ?";
        m_where_binder = [id_val = std::move(id)](SQLite::Statement &stmt, int idx) {
            stmt.bind(idx, id_val);
        };
        return *this;
    }

    /**
     * @brief Sets a custom error message to return when execution affects 0 rows.
     * @param message Custom not-found error message.
     * @return Reference to this builder for method chaining.
     */
    SqliteUpdateBuilder &set_not_found_message(std::string message) {
        m_not_found_message = std::move(message);
        return *this;
    }

    /**
     * @brief Checks whether any column assignments have been staged.
     * @return true if no columns were staged for update; false otherwise.
     */
    [[nodiscard]] bool empty() const noexcept {
        return m_assignments.empty();
    }

    /**
     * @brief Returns the count of staged column assignments.
     * @return Number of columns to update.
     */
    [[nodiscard]] size_t size() const noexcept {
        return m_assignments.size();
    }

    /**
     * @brief Constructs the parameterized SQL string.
     * @return Formatted UPDATE SQL query, or an empty string if no assignments were staged.
     */
    [[nodiscard]] std::string build_sql() const {
        if (m_assignments.empty()) {
            return "";
        }
        std::string sql = "UPDATE " + SqliteHelper::quote_identifier(m_table_name) + " SET ";
        for (size_t i = 0; i < m_assignments.size(); ++i) {
            sql += m_assignments[i];
            if (i + 1 < m_assignments.size()) {
                sql += ", ";
            }
        }
        if (!m_where_clause.empty()) {
            sql += " WHERE " + m_where_clause;
        }
        return sql;
    }

    /**
     * @brief Prepares and executes the UPDATE statement against the database.
     *
     * 1. If no assignments were staged, returns success immediately (no-op).
     * 2. Sequentially binds all SET parameters followed by the WHERE clause parameter.
     * 3. Executes the query and checks affected rows count; if 0 rows were affected,
     *    returns an unexpected error indicating the record was not found.
     *
     * @param db Reference to SQLiteCpp Database connection.
     * @return tl::expected containing void on success, or an error string on failure.
     */
    tl::expected<void, std::string> execute(SQLite::Database &db) const {
        if (m_where_clause.empty()) {
            return tl::unexpected("Safety Error: Refusing to execute UPDATE without a WHERE clause.");
        }
        if (m_assignments.empty()) {
            return {};
        }
        try {
            std::string sql = build_sql();
            SQLite::Statement query(db, sql);
            int bind_idx = 1;

            // Bind all SET column parameters (1-indexed in SQLiteCpp)
            for (const auto &binder : m_binders) {
                binder(query, bind_idx++);
            }

            // Bind WHERE clause parameter if present
            if (m_where_binder) {
                m_where_binder(query, bind_idx++);
            }

            int affected_rows = query.exec();
            if (affected_rows == 0) {
                return tl::unexpected(m_not_found_message.empty()
                                          ? (m_table_name + " ID not found.")
                                          : m_not_found_message);
            }
            return {};
        } catch (const std::exception &e) {
            return tl::unexpected(e.what());
        }
    }

  private:
    std::string m_table_name;
    std::string m_where_clause;
    std::function<void(SQLite::Statement &, int)> m_where_binder;
    std::string m_not_found_message;

    // Staged SQL fragments for the SET clause (e.g. "title = ?")
    std::vector<std::string> m_assignments;

    // Type-erased lambdas to bind each column value to SQLite::Statement sequentially
    std::vector<std::function<void(SQLite::Statement &, int)>> m_binders;
};

} // namespace lyra
