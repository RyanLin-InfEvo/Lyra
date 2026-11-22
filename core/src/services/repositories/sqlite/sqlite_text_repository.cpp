// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "sqlite_text_repository.h"

#include <SQLiteCpp/SQLiteCpp.h>

#include "../../../utils/sqlite_mappers.h"

namespace lyra {

SqliteTextRepository::SqliteTextRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteTextRepository::insert(const Text &text) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();
            // Use ON CONFLICT(text_hash) DO NOTHING rather than INSERT OR IGNORE
            // so CHECK and FOREIGN KEY violations still fail loudly.
            SQLite::Statement query(
                db,
                "INSERT INTO Text (text_hash, file_hash, language, encoding, format) "
                "VALUES (?, ?, ?, ?, ?) "
                "ON CONFLICT(text_hash) DO NOTHING");
            query.bind(1, text.text_hash);
            query.bind(2, text.file_hash);
            if (text.language.empty()) {
                query.bind(3);
            } else {
                query.bind(3, text.language);
            }
            query.bind(4, text.encoding.empty() ? "utf-8" : text.encoding);
            query.bind(5, text.format);
            query.exec();
            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::optional<Text>, std::string> SqliteTextRepository::get(const std::string &text_hash) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(
            db,
            "SELECT text_hash, file_hash, language, encoding, format "
            "FROM Text WHERE text_hash = ?");
        query.bind(1, text_hash);

        return SqliteHelper::fetch_one(query, SqliteMappers::map_text);
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<bool, std::string> SqliteTextRepository::exists(const std::string &text_hash) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT 1 FROM Text WHERE text_hash = ?");
        query.bind(1, text_hash);
        bool found = query.executeStep();
        query.reset();
        return found;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<bool, std::string> SqliteTextRepository::entity_exists(const std::string &entity_id) {
    try {
        auto &db = m_context.get_db();
        SQLite::Statement query(db, "SELECT 1 FROM Entity WHERE id = ? AND entity_type != 'tag'");
        query.bind(1, entity_id);
        bool found = query.executeStep();
        query.reset();
        return found;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTextRepository::link_entity(
    const std::string &entity_id,
    const std::string &text_hash,
    const std::string &role) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_entity(db, "SELECT 1 FROM Entity WHERE id = ? AND entity_type != 'tag'");
                check_entity.bind(1, entity_id);
                if (!check_entity.executeStep()) {
                    check_entity.reset();
                    return tl::unexpected("Entity not found.");
                }
                check_entity.reset();
            }

            {
                SQLite::Statement check_text(db, "SELECT 1 FROM Text WHERE text_hash = ?");
                check_text.bind(1, text_hash);
                if (!check_text.executeStep()) {
                    check_text.reset();
                    return tl::unexpected("Text not found.");
                }
                check_text.reset();
            }

            SQLite::Statement query(
                db,
                "INSERT INTO Entity_Text (entity_id, text_hash, role) "
                "VALUES (?, ?, ?) "
                "ON CONFLICT(entity_id, text_hash) DO UPDATE SET role = excluded.role");
            query.bind(1, entity_id);
            query.bind(2, text_hash);
            query.bind(3, role);
            query.exec();
            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<void, std::string> SqliteTextRepository::unlink_entity(
    const std::string &entity_id,
    const std::string &text_hash) {
    try {
        return m_context.with_transaction([&]() -> tl::expected<void, std::string> {
            auto &db = m_context.get_db();

            {
                SQLite::Statement check_entity(db, "SELECT 1 FROM Entity WHERE id = ? AND entity_type != 'tag'");
                check_entity.bind(1, entity_id);
                if (!check_entity.executeStep()) {
                    check_entity.reset();
                    return tl::unexpected("Entity not found.");
                }
                check_entity.reset();
            }

            SQLite::Statement query(
                db,
                "DELETE FROM Entity_Text WHERE entity_id = ? AND text_hash = ?");
            query.bind(1, entity_id);
            query.bind(2, text_hash);
            if (query.exec() == 0) {
                return tl::unexpected("Relation not found.");
            }
            return {};
        });
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<std::vector<Text>, std::string> SqliteTextRepository::get_texts_by_entity(
    const std::string &entity_id,
    const std::optional<std::string> &role,
    const std::optional<std::string> &language) {
    try {
        auto &db = m_context.get_db();
        std::string sql =
            "SELECT t.text_hash, t.file_hash, t.language, t.encoding, t.format, et.role "
            "FROM Text t "
            "INNER JOIN Entity_Text et ON t.text_hash = et.text_hash "
            "WHERE et.entity_id = ?";
        if (role.has_value() && !role->empty()) {
            sql += " AND et.role = ?";
        }
        if (language.has_value()) {
            if (language->empty()) {
                sql += " AND (t.language IS NULL OR t.language = '')";
            } else {
                sql += " AND t.language = ?";
            }
        }
        sql += " ORDER BY et.role ASC, COALESCE(t.language, '') ASC, t.text_hash ASC";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        query.bind(bind_idx++, entity_id);
        if (role.has_value() && !role->empty()) {
            query.bind(bind_idx++, *role);
        }
        if (language.has_value() && !language->empty()) {
            query.bind(bind_idx++, *language);
        }

        return SqliteHelper::fetch_all(query, SqliteMappers::map_text);
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<int, std::string> SqliteTextRepository::count_entity_texts_by_slot(
    const std::string &entity_id,
    const std::string &role,
    const std::string &language,
    const std::optional<std::string> &exclude_text_hash) {
    try {
        auto &db = m_context.get_db();
        std::string sql =
            "SELECT COUNT(*) "
            "FROM Entity_Text et "
            "INNER JOIN Text t ON et.text_hash = t.text_hash "
            "WHERE et.entity_id = ? AND et.role = ? AND COALESCE(t.language, '') = ?";
        if (exclude_text_hash.has_value()) {
            sql += " AND et.text_hash != ?";
        }

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        query.bind(bind_idx++, entity_id);
        query.bind(bind_idx++, role);
        query.bind(bind_idx++, language);
        if (exclude_text_hash.has_value()) {
            query.bind(bind_idx++, *exclude_text_hash);
        }

        if (!query.executeStep()) {
            query.reset();
            return tl::unexpected("Failed to count entity texts by slot.");
        }
        int count = query.getColumn(0).getInt();
        query.reset();
        return count;
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
