// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>
#include <string>

namespace lyra {

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
