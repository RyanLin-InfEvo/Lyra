// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "../src/services/database_context.h"
#include "../src/utils/uuid_generator.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <iostream>
#include <string>

using namespace lyra;

namespace {
struct TableCleaner {
    SQLite::Database &db;
    std::string name;
    ~TableCleaner() {
        try {
            db.exec("DROP TABLE IF EXISTS " + name + ";");
        } catch (...) {
        }
    }
};
} // namespace

bool test_basic_transaction(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    TableCleaner cleaner{db, "test_basic"};
    db.exec("CREATE TABLE IF NOT EXISTS test_basic (id INTEGER PRIMARY KEY, val TEXT);");
    db.exec("DELETE FROM test_basic;");

    try {
        // Test commit
        {
            auto tx = ctx.begin_transaction();
            db.exec("INSERT INTO test_basic (id, val) VALUES (1, 'commit_test');");
            tx->commit();
        }

        {
            SQLite::Statement query(db, "SELECT COUNT(*) FROM test_basic WHERE id = 1;");
            if (!query.executeStep() || query.getColumn(0).getInt() != 1) {
                std::cerr << "test_basic_transaction FAILED: committed row missing\n";
                return false;
            }
        }

        // Test rollback on scope exit
        {
            auto tx = ctx.begin_transaction();
            db.exec("INSERT INTO test_basic (id, val) VALUES (2, 'rollback_test');");
            // No commit called
        } // `tx` been destruct

        {
            SQLite::Statement query(db, "SELECT COUNT(*) FROM test_basic WHERE id = 2;");
            if (query.executeStep() && query.getColumn(0).getInt() != 0) {
                std::cerr << "test_basic_transaction FAILED: uncommitted row was not rolled back\n";
                return false;
            }
        }
    } catch (const std::exception &e) {
        std::cerr << "test_basic_transaction failed with exception: " << e.what() << "\n";
        return false;
    }

    return true;
}

bool test_savepoint_rollback(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    TableCleaner cleaner{db, "test_sp"};
    db.exec("CREATE TABLE IF NOT EXISTS test_sp (id INTEGER PRIMARY KEY, val TEXT);");
    db.exec("DELETE FROM test_sp;");

    try {
        auto tx_outer = ctx.begin_transaction();
        db.exec("INSERT INTO test_sp (id, val) VALUES (1, 'outer');");

        {
            auto tx_inner = ctx.begin_transaction();
            db.exec("INSERT INTO test_sp (id, val) VALUES (2, 'inner');");
            // tx_inner rolls back on scope exit
        }

        // Outer tx commits
        tx_outer->commit();

        SQLite::Statement query_outer(db, "SELECT COUNT(*) FROM test_sp WHERE id = 1;");
        if (!query_outer.executeStep() || query_outer.getColumn(0).getInt() != 1) {
            std::cerr << "test_savepoint_rollback FAILED: outer row missing\n";
            return false;
        }

        SQLite::Statement query_inner(db, "SELECT COUNT(*) FROM test_sp WHERE id = 2;");
        if (query_inner.executeStep() && query_inner.getColumn(0).getInt() != 0) {
            std::cerr << "test_savepoint_rollback FAILED: inner rolled-back row exists\n";
            return false;
        }
    } catch (const std::exception &e) {
        std::cerr << "test_savepoint_rollback failed with exception: " << e.what() << "\n";
        return false;
    }

    return true;
}

bool test_nested_savepoint_rollback_and_commit(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    TableCleaner cleaner{db, "test_tx"};
    db.exec("CREATE TABLE IF NOT EXISTS test_tx (id INTEGER PRIMARY KEY, val TEXT);");
    db.exec("DELETE FROM test_tx;");

    try {
        // Outer transaction (depth = 0)
        auto tx_outer = ctx.begin_transaction();
        db.exec("INSERT INTO test_tx (id, val) VALUES (1, 'outer');");

        // Inner savepoint 1 (depth = 1)
        {
            auto tx_inner_1 = ctx.begin_transaction();
            db.exec("INSERT INTO test_tx (id, val) VALUES (2, 'nested_1');");

            // Inner savepoint 2 (depth = 2)
            {
                auto tx_inner_2 = ctx.begin_transaction();
                db.exec("INSERT INTO test_tx (id, val) VALUES (3, 'nested_2');");
                // Rollback tx_inner_2 implicitly by leaving block without commit
            }

            // Verify inner rollback: (3, "nested_2") should be removed
            // but (1, "outer") and (2, "nested_1") should remain.
            {
                SQLite::Statement query(db, "SELECT COUNT(*) FROM test_tx WHERE id = 3;");
                if (query.executeStep() && query.getColumn(0).getInt() != 0) {
                    std::cerr << "Inner rollback failed: (3, 'nested_2') still exists\n";
                    return false;
                }
                SQLite::Statement query_outer(db, "SELECT COUNT(*) FROM test_tx WHERE id = 1;");
                if (!query_outer.executeStep() || query_outer.getColumn(0).getInt() != 1) {
                    std::cerr << "Inner rollback side effect: (1, 'outer') does not exist\n";
                    return false;
                }
                SQLite::Statement query_inner_1(db, "SELECT COUNT(*) FROM test_tx WHERE id = 2;");
                if (!query_inner_1.executeStep() || query_inner_1.getColumn(0).getInt() != 1) {
                    std::cerr << "Inner rollback side effect: (2, 'nested_1') does not exist\n";
                    return false;
                }
            }

            // Commit tx_inner_1
            tx_inner_1->commit();
        }

        // Verify tx_inner_1 commit (but outer transaction is still uncommitted)
        {
            SQLite::Statement query_inner_1(db, "SELECT COUNT(*) FROM test_tx WHERE id = 2;");
            if (!query_inner_1.executeStep() || query_inner_1.getColumn(0).getInt() != 1) {
                std::cerr << "Inner commit failed: (2, 'nested_1') does not exist inside active outer transaction\n";
                return false;
            }
        }

        // Rollback tx_outer
        // This should roll back EVERYTHING, including the committed nested_1!
        tx_outer.reset(); // implicitly rolls back since commit() is not called

        // Verify outer rollback: both (1, 'outer') and (2, 'nested_1') must be gone!
        {
            SQLite::Statement query(db, "SELECT COUNT(*) FROM test_tx;");
            if (query.executeStep() && query.getColumn(0).getInt() != 0) {
                std::cerr << "Outer rollback failed: table is not empty\n";
                return false;
            }
        }
    } catch (const std::exception &e) {
        std::cerr << "test_nested_savepoint_rollback_and_commit failed with exception: " << e.what() << "\n";
        return false;
    }

    return true;
}

bool test_context_isolation(const std::string &db_path1, const std::string &db_path2) {
    try {
        SqliteDatabaseContext ctx1(db_path1);
        SqliteDatabaseContext ctx2(db_path2);

        // 1. Begin transaction on ctx1.
        auto tx1 = ctx1.begin_transaction();

        // 2. Begin transaction on ctx2.
        // Multiple context instances on the same thread must maintain independent transaction depths.
        auto tx2 = ctx2.begin_transaction();

        // 3. Insert an artist using ctx2's connection with a unique random UUID
        std::string artist_id = UuidGenerator::generate_v4();
        {
            auto &db2 = ctx2.get_db();
            db2.exec("INSERT INTO Entity (id, entity_type) VALUES ('" + artist_id + "', 'artist');");
            db2.exec("INSERT INTO Artist (id, name) VALUES ('" + artist_id + "', 'Test Nested Artist');");
        }

        // 4. Commit tx2.
        tx2->commit();

        // 5. Query from an independent connection db3 pointing to db_path2.
        SQLite::Database db3(db_path2, SQLite::OPEN_READONLY);
        SQLite::Statement query(db3, "SELECT COUNT(*) FROM Artist WHERE id = ?");
        query.bind(1, artist_id);
        int count = 0;
        if (query.executeStep()) {
            count = query.getColumn(0).getInt();
        }

        tx1->commit();

        if (count == 0) {
            std::cerr << "test_context_isolation FAILED: artist not committed on ctx2\n";
            return false;
        }
        return true;

    } catch (const std::exception &e) {
        std::cerr << "test_context_isolation failed with exception: " << e.what() << "\n";
        return false;
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <db_path>\n";
        return 2;
    }
    std::string db_path1 = argv[1];
    std::string db_path2 = db_path1 + "_2";

    bool all_passed = true;

    std::cout << "[1/4] Running test_basic_transaction..." << std::endl;
    if (!test_basic_transaction(db_path1)) {
        std::cerr << "test_basic_transaction FAILED\n";
        all_passed = false;
    }

    std::cout << "[2/4] Running test_savepoint_rollback..." << std::endl;
    if (!test_savepoint_rollback(db_path1)) {
        std::cerr << "test_savepoint_rollback FAILED\n";
        all_passed = false;
    }

    std::cout << "[3/4] Running test_nested_savepoint_rollback_and_commit..." << std::endl;
    if (!test_nested_savepoint_rollback_and_commit(db_path1)) {
        std::cerr << "test_nested_savepoint_rollback_and_commit FAILED\n";
        all_passed = false;
    }

    std::cout << "[4/4] Running test_context_isolation..." << std::endl;
    if (!test_context_isolation(db_path1, db_path2)) {
        std::cerr << "test_context_isolation FAILED\n";
        all_passed = false;
    }

    if (all_passed) {
        std::cout << "All database context tests passed successfully! BUG_FIXED\n";
        return 0;
    } else {
        std::cerr << "Some database context tests failed. BUG_PRESENT\n";
        return 1;
    }
}
