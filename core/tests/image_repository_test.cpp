/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/models/asset.h"
#include "../src/models/image.h"
#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_image_repository.h"
#include <cassert>
#include <filesystem>
#include <iostream>

using namespace lyra;

bool test_image_insert_and_get(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_image_insert_and_get..." << std::endl;
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = image_repo.get("nonexistent-image-hash");
    assert(!get_nonexistent.has_value());
    assert(get_nonexistent.error() == "Image not found.");

    // 2. Insert Asset first (foreign key requirement)
    Asset asset;
    asset.file_hash = "file-hash-img1";
    asset.mime_type = "image/jpeg";
    asset.asset_type = "image";
    asset.file_size = 102400;
    auto insert_asset_res = asset_repo.insert(asset);
    assert(insert_asset_res.has_value());

    // 3. Insert Image
    Image img;
    img.image_hash = "img-hash-123456";
    img.file_hash = asset.file_hash;
    img.width = 1920;
    img.height = 1080;
    img.dominant_color = "#FF5733";

    auto insert_res = image_repo.insert(img);
    assert(insert_res.has_value());

    // 4. Get inserted Image
    auto get_res = image_repo.get(img.image_hash);
    assert(get_res.has_value());
    assert(get_res.value().image_hash == img.image_hash);
    assert(get_res.value().file_hash == img.file_hash);
    assert(get_res.value().width == img.width);
    assert(get_res.value().height == img.height);
    assert(get_res.value().dominant_color == img.dominant_color);

    std::cout << "test_image_insert_and_get: SUCCESS" << std::endl;
    return true;
}

bool test_image_list(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_image_list..." << std::endl;
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);

    // Prepare 3 assets and images
    for (int i = 1; i <= 3; ++i) {
        std::string file_hash = "file-hash-list-" + std::to_string(i);
        std::string img_hash = "img-hash-list-" + std::to_string(i);

        Asset asset;
        asset.file_hash = file_hash;
        asset.mime_type = "image/png";
        asset.asset_type = "image";
        asset.file_size = 204800;
        assert(asset_repo.insert(asset).has_value());

        Image img;
        img.image_hash = img_hash;
        img.file_hash = file_hash;
        img.width = 800 * i;
        img.height = 600 * i;
        img.dominant_color = "#00000" + std::to_string(i);
        assert(image_repo.insert(img).has_value());
    }

    // List all (offset=0, limit=10)
    auto list_all = image_repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all.value().total >= 3);
    assert(!list_all.value().items.empty());

    // List with search filter
    auto list_search = image_repo.list(0, 10, "img-hash-list-2");
    assert(list_search.has_value());
    assert(list_search.value().total == 1);
    assert(list_search.value().items[0].image_hash == "img-hash-list-2");

    std::cout << "test_image_list: SUCCESS" << std::endl;
    return true;
}

bool test_image_entity_links(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_image_entity_links..." << std::endl;
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);

    // Prepare Asset & Image
    Asset asset;
    asset.file_hash = "file-hash-entity-1";
    asset.mime_type = "image/jpeg";
    asset.asset_type = "image";
    asset.file_size = 51200;
    assert(asset_repo.insert(asset).has_value());

    Image img;
    img.image_hash = "img-hash-entity-1";
    img.file_hash = asset.file_hash;
    img.width = 500;
    img.height = 500;
    img.dominant_color = "#FFFFFF";
    assert(image_repo.insert(img).has_value());

    std::string entity_id = "album-id-99999";

    // 1. Link to non-existent entity should fail
    auto link_fail_entity = image_repo.link_entity(entity_id, img.image_hash, "front");
    assert(!link_fail_entity.has_value());
    assert(link_fail_entity.error() == "Target Entity not found.");

    // 2. Insert Entity record in DB
    auto &db = ctx.get_db();
    db.exec("INSERT INTO Entity (id, entity_type) VALUES ('" + entity_id + "', 'album');");

    // 3. Link to non-existent image should fail
    auto link_fail_img = image_repo.link_entity(entity_id, "nonexistent-img-hash", "front");
    assert(!link_fail_img.has_value());
    assert(link_fail_img.error() == "Target Image not found.");

    // 4. Link valid entity and image
    auto link_res = image_repo.link_entity(entity_id, img.image_hash, "front");
    assert(link_res.has_value());

    // 5. Get images by entity
    auto images_res = image_repo.get_images_by_entity(entity_id);
    assert(images_res.has_value());
    assert(images_res.value().size() == 1);
    assert(images_res.value()[0].image_hash == img.image_hash);
    assert(images_res.value()[0].file_hash == img.file_hash);

    // 6. Unlink entity
    auto unlink_res = image_repo.unlink_entity(entity_id, img.image_hash);
    assert(unlink_res.has_value());

    // Verify unlinked
    auto images_after_unlink = image_repo.get_images_by_entity(entity_id);
    assert(images_after_unlink.has_value());
    assert(images_after_unlink.value().empty());

    std::cout << "test_image_entity_links: SUCCESS" << std::endl;
    return true;
}

int main() {
    std::string db_path = "test_image_repo.db";
    std::filesystem::remove(db_path);

    bool success = true;
    try {
        SqliteDatabaseContext ctx(db_path);
        if (!test_image_insert_and_get(ctx)) success = false;
        if (!test_image_list(ctx)) success = false;
        if (!test_image_entity_links(ctx)) success = false;
    } catch (const std::exception &e) {
        std::cerr << "Exception in image_repository_test: " << e.what() << std::endl;
        success = false;
    }

    std::filesystem::remove(db_path);
    if (success) {
        std::cout << "ALL_IMAGE_REPOSITORY_TESTS_PASSED" << std::endl;
        return 0;
    } else {
        std::cerr << "SOME IMAGE REPOSITORY TESTS FAILED" << std::endl;
        return 1;
    }
}
