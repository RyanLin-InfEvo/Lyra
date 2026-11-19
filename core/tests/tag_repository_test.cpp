// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_tag_repository.h"
#include "../src/utils/uuid_generator.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <cstdio>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra;

namespace {

bool check(bool cond, const std::string &msg) {
    if (!cond) {
        std::cerr << "FAILED: " << msg << "\n";
        return false;
    }
    return true;
}

bool test_schema_and_indexes(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    auto &db = ctx.get_db();

    {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_Tag_name'");
        if (!check(q.executeStep(), "idx_Tag_name index missing")) return false;
    }
    {
        SQLite::Statement q(db, "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_Entity_Tag_tag_id'");
        if (!check(q.executeStep(), "idx_Entity_Tag_tag_id index missing")) return false;
    }
    return true;
}

bool test_tag_crud_and_categories(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    SqliteTagRepository tag_repo(ctx);

    const std::vector<std::string> categories = {"general", "mood", "era", "style", "quality", "genre"};
    std::vector<std::string> ids;

    for (const auto &cat : categories) {
        Tag t;
        t.id = UuidGenerator::generate_v4();
        t.name = "Tag_" + cat;
        t.category = cat;
        auto res = tag_repo.insert(t);
        if (!check(res.has_value(), "insert failed for category " + cat + ": " + (res ? "" : res.error()))) return false;
        ids.push_back(t.id);

        auto got = tag_repo.get(t.id);
        if (!check(got.has_value(), "get failed for " + t.id)) return false;
        if (!check(got->category == cat, "category mismatch for " + cat)) return false;
        if (!check(got->created_at.has_value() && !got->created_at->empty(), "created_at should be populated")) return false;
    }

    // List with category filter
    auto mood_list = tag_repo.list(0, 50, std::nullopt, std::string("mood"));
    if (!check(mood_list.has_value(), "list by category failed")) return false;
    if (!check(mood_list->total == 1 && mood_list->items.size() == 1, "expected 1 mood tag")) return false;
    if (!check(mood_list->items[0].name == "Tag_mood", "expected Tag_mood")) return false;

    // List with search + pagination
    auto all_list = tag_repo.list(1, 2, std::string("Tag_"), std::nullopt);
    if (!check(all_list.has_value(), "paginated list failed")) return false;
    if (!check(all_list->total == 6 && all_list->items.size() == 2, "expected total=6 and 2 items on page")) return false;

    // Delete tag
    auto del_res = tag_repo.delete_tag(ids[0]);
    if (!check(del_res.has_value(), "delete_tag failed")) return false;
    if (!check(!tag_repo.get(ids[0]).has_value(), "deleted tag should not be found")) return false;
    if (!check(!tag_repo.delete_tag(ids[0]).has_value(), "deleting non-existent tag should fail")) return false;

    return true;
}

bool test_entity_tag_many_to_many_and_cascade(const std::string &db_path) {
    SqliteDatabaseContext ctx(db_path);
    SqliteTagRepository tag_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);

    Artist artist;
    artist.id = UuidGenerator::generate_v4();
    artist.name = "Miles Davis";
    if (!check(artist_repo.insert(artist).has_value(), "artist insert failed")) return false;

    Tag t1{.id = UuidGenerator::generate_v4(), .name = "Post-Bop", .category = "genre"};
    Tag t2{.id = UuidGenerator::generate_v4(), .name = "Audiophile", .category = "quality"};
    if (!check(tag_repo.insert(t1).has_value(), "t1 insert failed")) return false;
    if (!check(tag_repo.insert(t2).has_value(), "t2 insert failed")) return false;

    // Assign multiple tags to the same entity (composite PK (entity_id, tag_id))
    if (!check(tag_repo.assign_to_entity(artist.id, t1.id).has_value(), "assign t1 failed")) return false;
    if (!check(tag_repo.assign_to_entity(artist.id, t2.id).has_value(), "assign t2 failed")) return false;
    // Idempotent re-assign
    if (!check(tag_repo.assign_to_entity(artist.id, t1.id).has_value(), "idempotent assign failed")) return false;

    auto tags = tag_repo.get_entity_tags(artist.id);
    if (!check(tags.has_value() && tags->size() == 2, "expected 2 tags on artist")) return false;

    // Remove one tag
    if (!check(tag_repo.remove_from_entity(artist.id, t1.id).has_value(), "remove t1 failed")) return false;
    if (!check(!tag_repo.remove_from_entity(artist.id, t1.id).has_value(), "removing absent relation should fail")) return false;

    tags = tag_repo.get_entity_tags(artist.id);
    if (!check(tags.has_value() && tags->size() == 1 && tags->at(0).id == t2.id, "expected only t2 remaining")) return false;

    // Deleting tag t2 cascades to Entity_Tag
    if (!check(tag_repo.delete_tag(t2.id).has_value(), "delete t2 failed")) return false;
    tags = tag_repo.get_entity_tags(artist.id);
    if (!check(tags.has_value() && tags->empty(), "expected 0 tags after cascade delete")) return false;

    // Missing entity/tag guards
    if (!check(!tag_repo.assign_to_entity(UuidGenerator::generate_v4(), t1.id).has_value(), "assign to missing entity should fail")) return false;
    if (!check(!tag_repo.assign_to_entity(artist.id, UuidGenerator::generate_v4()).has_value(), "assign missing tag should fail")) return false;
    if (!check(!tag_repo.assign_to_entity(t1.id, t1.id).has_value(), "assign tag to tag should fail")) return false;
    if (!check(!tag_repo.get_entity_tags(UuidGenerator::generate_v4()).has_value(), "get_entity_tags for missing entity should fail")) return false;
    if (!check(!tag_repo.get_entity_tags(t1.id).has_value(), "get_entity_tags for tag entity should fail")) return false;

    return true;
}

} // namespace

int main() {
    const std::string db_path = "tag_repository_test.db";
    std::remove(db_path.c_str());

    bool ok = true;
    ok &= test_schema_and_indexes(db_path);
    ok &= test_tag_crud_and_categories(db_path);
    ok &= test_entity_tag_many_to_many_and_cascade(db_path);

    std::remove(db_path.c_str());
    std::remove((db_path + "-wal").c_str());
    std::remove((db_path + "-shm").c_str());

    if (!ok) {
        return 1;
    }
    std::cout << "ALL_TESTS_PASSED\n";
    return 0;
}
