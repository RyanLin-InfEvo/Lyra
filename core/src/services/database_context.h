// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>
#include <string>
#include <tl/expected.hpp>
#include <type_traits>

namespace lyra {

namespace detail {
template <typename T>
struct is_expected_type : std::false_type {};

template <typename T, typename E>
struct is_expected_type<tl::expected<T, E>> : std::true_type {};

template <typename T>
inline constexpr bool is_expected_v = is_expected_type<std::decay_t<T>>::value;
} // namespace detail

/**
 * @brief Interface for transaction management.
 * Ensures RAII-based commit/rollback and thread-safety.
 */
class ITransaction {
  public:
    virtual ~ITransaction() = default;
    virtual void commit() = 0;
};

/**
 * @brief Interface for database access and transaction coordination (Unit of Work).
 */
class IDatabaseContext {
  public:
    virtual ~IDatabaseContext() = default;

    /**
     * @brief Begins a new transaction and returns a RAII guard.
     */
    virtual std::unique_ptr<ITransaction> begin_transaction() = 0;

    /**
     * @brief Provides direct access to the database for repository operations.
     */
    virtual SQLite::Database &get_db() = 0;

    /**
     * @brief Executes an action within a transaction.
     * Automatically commits if the action succeeds (or if tl::expected has_value()),
     * and rolls back if an exception is thrown or error returned.
     */
    template <typename Func>
    auto with_transaction(Func &&action) -> decltype(action()) {
        auto tx = begin_transaction();
        using ReturnType = decltype(action());
        if constexpr (std::is_same_v<ReturnType, void>) {
            action();
            tx->commit();
            return;
        } else {
            auto result = action();
            if constexpr (detail::is_expected_v<ReturnType>) {
                if (result.has_value()) {
                    tx->commit();
                }
            } else {
                tx->commit();
            }
            return result;
        }
    }
};

class SqliteDatabaseContext : public IDatabaseContext {
  public:
    explicit SqliteDatabaseContext(const std::string &db_path);

    std::unique_ptr<ITransaction> begin_transaction() override;
    SQLite::Database &get_db() override;

  private:
    std::string m_db_path;

    void init_schema();

    // Internal implementation of the transaction guard
    class SqliteTransaction : public ITransaction {
      public:
        SqliteTransaction(SQLite::Database &db, int &depth)
            : m_db(db), m_depth(depth) {
            if (m_depth == 0) {
                m_db.exec("BEGIN IMMEDIATE;");
            } else {
                m_savepoint_name = "sp_" + std::to_string(m_depth);
                m_db.exec("SAVEPOINT " + m_savepoint_name + ";");
            }
            m_depth++;
        }

        ~SqliteTransaction() {
            if (!m_committed) {
                try {
                    if (m_savepoint_name.empty()) {
                        m_db.exec("ROLLBACK;");
                    } else {
                        m_db.exec("ROLLBACK TO SAVEPOINT " + m_savepoint_name + ";");
                        m_db.exec("RELEASE SAVEPOINT " + m_savepoint_name + ";");
                    }
                } catch (...) {
                    // Critical: Destructors must not throw.
                }
            }
            m_depth--;
        }

        void commit() override {
            if (m_committed) return;
            if (m_savepoint_name.empty()) {
                m_db.exec("COMMIT;");
                try {
                    m_db.exec("PRAGMA wal_checkpoint(PASSIVE);");
                } catch (...) {
                }
            } else {
                m_db.exec("RELEASE SAVEPOINT " + m_savepoint_name + ";");
            }
            m_committed = true;
        }

      private:
        SQLite::Database &m_db;
        int &m_depth;
        std::string m_savepoint_name;
        bool m_committed = false;
    };
};

} // namespace lyra
