// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../../utils/sqlite_helper.h"
#include "sqlite_image_repository.h"

namespace lyra {

SqliteImageRepository::SqliteImageRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteImageRepository::insert(const Image &image) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db,
                                "INSERT INTO Image (image_hash, file_hash, width, height, dominant_color) "
                                "VALUES (?, ?, ?, ?, ?)");
        query.bind(1, image.image_hash);
        query.bind(2, image.file_hash);
        query.bind(3, image.width);
        query.bind(4, image.height);
        if (!image.dominant_color.empty()) {
            query.bind(5, image.dominant_color);
        } else {
            query.bind(5);
        }

        query.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Image, std::string> SqliteImageRepository::get(const std::string &image_hash) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db,
                                "SELECT image_hash, file_hash, width, height, dominant_color "
                                "FROM Image WHERE image_hash = ?");
        query.bind(1, image_hash);

        if (query.executeStep()) {
            Image img;
            img.image_hash = query.getColumn("image_hash").getString();
            img.file_hash = query.getColumn("file_hash").getString();
            img.width = query.getColumn("width").getInt();
            img.height = query.getColumn("height").getInt();
            img.dominant_color = SqliteHelper::get_safe<std::string>(query, "dominant_color", "");
            return img;
        }
        return tl::unexpected("Image not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<PaginatedResult<Image>, std::string> SqliteImageRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Image";
        std::string select_sql = "SELECT image_hash, file_hash, width, height, dominant_color FROM Image";

        if (search.has_value() && !search->empty()) {
            count_sql += R"( WHERE image_hash LIKE ? ESCAPE '\' OR file_hash LIKE ? ESCAPE '\' )";
            select_sql += R"( WHERE image_hash LIKE ? ESCAPE '\' OR file_hash LIKE ? ESCAPE '\' )";
        }

        select_sql += " ORDER BY image_hash ASC LIMIT ? OFFSET ?";

        int total = 0;
        {
            SQLite::Statement count_query(db, count_sql);
            if (search.has_value() && !search->empty()) {
                std::string param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                count_query.bind(1, param);
                count_query.bind(2, param);
            }
            if (!count_query.executeStep()) {
                return tl::unexpected("Failed to get total count.");
            }
            total = count_query.getColumn(0).getInt();
        }

        std::vector<Image> items;
        items.reserve(limit);
        {
            SQLite::Statement select_query(db, select_sql);
            int bind_idx = 1;
            if (search.has_value() && !search->empty()) {
                std::string param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                select_query.bind(bind_idx++, param);
                select_query.bind(bind_idx++, param);
            }
            select_query.bind(bind_idx++, limit);
            select_query.bind(bind_idx++, offset);

            while (select_query.executeStep()) {
                Image img;
                img.image_hash = select_query.getColumn("image_hash").getString();
                img.file_hash = select_query.getColumn("file_hash").getString();
                img.width = select_query.getColumn("width").getInt();
                img.height = select_query.getColumn("height").getInt();
                img.dominant_color = SqliteHelper::get_safe<std::string>(select_query, "dominant_color", "");
                items.push_back(img);
            }
        }

        return PaginatedResult<Image>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteImageRepository::link_entity(
    const std::string &entity_id, const std::string &image_hash,
    const std::optional<std::string> &role) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        {
            SQLite::Statement check_entity(db, "SELECT 1 FROM Entity WHERE id = ?");
            check_entity.bind(1, entity_id);
            if (!check_entity.executeStep()) {
                return tl::unexpected("Target Entity not found.");
            }
        }

        {
            SQLite::Statement check_image(db, "SELECT 1 FROM Image WHERE image_hash = ?");
            check_image.bind(1, image_hash);
            if (!check_image.executeStep()) {
                return tl::unexpected("Target Image not found.");
            }
        }

        SQLite::Statement query(db,
                                "INSERT OR REPLACE INTO Entity_Images (entity_id, image_hash, role) "
                                "VALUES (?, ?, ?)");
        query.bind(1, entity_id);
        query.bind(2, image_hash);
        if (role.has_value() && !role->empty()) {
            query.bind(3, *role);
        } else {
            query.bind(3);
        }

        query.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteImageRepository::unlink_entity(
    const std::string &entity_id, const std::string &image_hash) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "DELETE FROM Entity_Images WHERE entity_id = ? AND image_hash = ?");
        query.bind(1, entity_id);
        query.bind(2, image_hash);

        if (query.exec() == 0) {
            return tl::unexpected("Relation not found or already removed.");
        }

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<std::vector<Image>, std::string> SqliteImageRepository::get_images_by_entity(
    const std::string &entity_id, const std::optional<std::string> &role) {
    try {
        auto &db = m_context.get_db();
        std::string sql =
            "SELECT i.image_hash, i.file_hash, i.width, i.height, i.dominant_color, ei.role "
            "FROM Image i "
            "JOIN Entity_Images ei ON i.image_hash = ei.image_hash "
            "WHERE ei.entity_id = ?";
        if (role.has_value() && !role->empty()) sql += " AND ei.role = ?";
        sql += " ORDER BY i.image_hash ASC";

        SQLite::Statement query(db, sql);
        query.bind(1, entity_id);
        if (role.has_value() && !role->empty()) query.bind(2, *role);

        std::vector<Image> images;
        while (query.executeStep()) {
            Image img;
            img.image_hash = query.getColumn("image_hash").getString();
            img.file_hash = query.getColumn("file_hash").getString();
            img.width = query.getColumn("width").getInt();
            img.height = query.getColumn("height").getInt();
            img.dominant_color = SqliteHelper::get_safe<std::string>(query, "dominant_color", "");
            if (!query.isColumnNull("role")) img.role = query.getColumn("role").getString();
            images.push_back(img);
        }
        return images;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<Image, std::string> SqliteImageRepository::get_artist_latest_album_cover(
    const std::string &artist_id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(
            db,
            "SELECT i.image_hash, i.file_hash, i.width, i.height, i.dominant_color, ei.role "
            "FROM Image i "
            "JOIN Entity_Images ei ON i.image_hash = ei.image_hash "
            "JOIN Album a ON ei.entity_id = a.id "
            "JOIN Track_Album ta ON a.id = ta.album_id "
            "JOIN Track_Artist tar ON ta.track_id = tar.track_id "
            "WHERE tar.artist_id = ? "
            "ORDER BY a.release_year DESC, a.release_month DESC, a.release_day DESC, a.id ASC "
            "LIMIT 1");
        query.bind(1, artist_id);

        if (query.executeStep()) {
            Image img;
            img.image_hash = query.getColumn("image_hash").getString();
            img.file_hash = query.getColumn("file_hash").getString();
            img.width = query.getColumn("width").getInt();
            img.height = query.getColumn("height").getInt();
            img.dominant_color = SqliteHelper::get_safe<std::string>(query, "dominant_color", "");
            if (!query.isColumnNull("role")) img.role = query.getColumn("role").getString();
            return img;
        }
        return tl::unexpected("No album cover image found for artist.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<bool, std::string> SqliteImageRepository::entity_exists(const std::string &entity_id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT 1 FROM Entity WHERE id = ?");
        query.bind(1, entity_id);
        return query.executeStep();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
