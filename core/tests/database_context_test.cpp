// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "../src/services/database_context.h"
#include "../src/utils/uuid_generator.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <iostream>
#include <string>

using namespace lyra;

bool test_nested_savepoint_rollback_and_commit(const std::string &db_path) {
    std::cout << "Running test_nested_savepoint_rollback_and_commit..." << std::endl;
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    // 1. Create a temporary test table
    db.exec("CREATE TABLE IF NOT EXISTS test_tx (id INTEGER PRIMARY KEY, val TEXT);");
    db.exec("DELETE FROM test_tx;"); // ensure clean state

    try {
        // 2. Outer transaction (depth = 0)
        auto tx_outer = ctx.begin_transaction();
        db.exec("INSERT INTO test_tx (id, val) VALUES (1, 'outer');");

        // 3. Inner savepoint 1 (depth = 1)
        {
            auto tx_inner_1 = ctx.begin_transaction();
            db.exec("INSERT INTO test_tx (id, val) VALUES (2, 'nested_1');");

            // 4. Inner savepoint 2 (depth = 2)
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
                    std::cerr << "Inner rollback failed: (3, 'nested_2') still exists" << std::endl;
                    return false;
                }
                SQLite::Statement query_outer(db, "SELECT COUNT(*) FROM test_tx WHERE id = 1;");
                if (!query_outer.executeStep() || query_outer.getColumn(0).getInt() != 1) {
                    std::cerr << "Inner rollback side effect: (1, 'outer') does not exist" << std::endl;
                    return false;
                }
                SQLite::Statement query_inner_1(db, "SELECT COUNT(*) FROM test_tx WHERE id = 2;");
                if (!query_inner_1.executeStep() || query_inner_1.getColumn(0).getInt() != 1) {
                    std::cerr << "Inner rollback side effect: (2, 'nested_1') does not exist" << std::endl;
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
                std::cerr << "Inner commit failed: (2, 'nested_1') does not exist inside active outer transaction" << std::endl;
                return false;
            }
        }

        // Rollback tx_outer
        // This should roll back EVERYTHING, including the committed nested_1!
        tx_outer.reset(); // implicitly rolls back since commit() is not called
    } catch (const std::exception &e) {
        std::cerr << "Savepoint test failed with exception: " << e.what() << std::endl;
        return false;
    }

    // Verify outer rollback: both (1, 'outer') and (2, 'nested_1') must be gone!
    {
        SQLite::Statement query(db, "SELECT COUNT(*) FROM test_tx;");
        if (query.executeStep() && query.getColumn(0).getInt() != 0) {
            std::cerr << "Outer rollback failed: table is not empty" << std::endl;
            return false;
        }
    }

    // Clean up
    db.exec("DROP TABLE test_tx;");
    return true;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <db_path>\n";
        return 2;
    }
    std::string db_path1 = argv[1];
    std::string db_path2 = db_path1 + "_2";

    try {
        SqliteDatabaseContext ctx1(db_path1);
        SqliteDatabaseContext ctx2(db_path2);

        // 1. Begin transaction on ctx1. This sets the shared tl_depth = 1 (if bug is present).
        auto tx1 = ctx1.begin_transaction();

        // 2. Begin transaction on ctx2.
        // Due to the bug (shared tl_depth = 1), ctx2 believes a transaction is already active
        // and starts a SAVEPOINT sp_1 instead of a real database transaction on db2.
        auto tx2 = ctx2.begin_transaction();

        // 3. Insert an artist using ctx2's connection with a unique random UUID
        std::string artist_id = UuidGenerator::generate_v4();
        {
            auto &db2 = ctx2.get_db();
            db2.exec("INSERT INTO Entity (id, entity_type) VALUES ('" + artist_id + "', 'artist');");
            db2.exec("INSERT INTO Artist (id, name) VALUES ('" + artist_id + "', 'Test Nested Artist');");
        }

        // 4. Commit tx2.
        // Due to the bug, tx2 is a SAVEPOINT transaction, so it runs "RELEASE SAVEPOINT sp_1;".
        // However, since there is no outer transaction active on ctx2's SQLite connection,
        // SQLite's implicit transaction remains active and UNCOMMITTED!
        tx2->commit();

        // 5. Query from a separate independent connection db3 pointing to db_path2.
        // If the bug is present, the transaction on ctx2 was NOT committed, so db3 cannot see the new artist.
        // If the bug is fixed (independent tl_depth), the transaction on ctx2 was a real transaction
        // that successfully committed, making the artist visible on db3.
        SQLite::Database db3(db_path2, SQLite::OPEN_READONLY);
        SQLite::Statement query(db3, "SELECT COUNT(*) FROM Artist WHERE id = ?");
        query.bind(1, artist_id);
        int count = 0;
        if (query.executeStep()) {
            count = query.getColumn(0).getInt();
        }

        // Rollback/commit tx1 to clean up
        tx1->commit();

        if (!test_nested_savepoint_rollback_and_commit(db_path1)) {
            std::cerr << "test_nested_savepoint_rollback_and_commit FAILED\n";
            return 4;
        }

        if (count == 0) {
            std::cout << "BUG_PRESENT\n";
            return 1; // Exit code 1 indicates the bug is present
        } else {
            std::cout << "BUG_FIXED\n";
            return 0; // Exit code 0 indicates the bug is fixed
        }

    } catch (const std::exception &e) {
        std::cerr << "Test crashed with error: " << e.what() << "\n";
        return 3;
    }
}
