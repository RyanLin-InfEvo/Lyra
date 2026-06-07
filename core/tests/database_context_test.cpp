// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <iostream>
#include <string>
#include <SQLiteCpp/SQLiteCpp.h>
#include "../src/services/database_context.h"
#include "../src/utils/uuid_generator.h"

using namespace lyra;

int main(int argc, char* argv[]) {
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
