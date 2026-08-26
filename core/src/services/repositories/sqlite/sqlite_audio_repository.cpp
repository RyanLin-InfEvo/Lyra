// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <vector>

#include "../../../utils/sqlite_helper.h"
#include "sqlite_audio_repository.h"

namespace lyra {

SqliteAudioRepository::SqliteAudioRepository(IDatabaseContext &context)
    : m_context(context) {}

tl::expected<void, std::string> SqliteAudioRepository::insert(const Audio &audio) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        SQLite::Statement query(db,
                                "INSERT INTO Audio (pcm_hash, parent_hash, quality_score, bit_depth, sample_rate, channels, duration, integrated_loudness, true_peak) "
                                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        query.bind(1, audio.pcm_hash);
        if (audio.parent_hash.empty()) {
            query.bind(2);
        } else {
            query.bind(2, audio.parent_hash);
        }
        query.bind(3, audio.quality_score);
        query.bind(4, audio.bit_depth);
        query.bind(5, audio.sample_rate);
        query.bind(6, audio.channels);
        query.bind(7, audio.duration);
        query.bind(8, audio.integrated_loudness);
        query.bind(9, audio.true_peak);

        query.exec();
        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<void, std::string> SqliteAudioRepository::update(const AudioUpdate &data) {
    try {
        auto transaction = m_context.begin_transaction();
        auto &db = m_context.get_db();

        std::string sql = "UPDATE Audio SET ";
        std::vector<std::string> fields;
        if (data.parent_hash) fields.emplace_back("parent_hash = ?");
        if (data.quality_score) fields.emplace_back("quality_score = ?");
        if (data.bit_depth) fields.emplace_back("bit_depth = ?");
        if (data.sample_rate) fields.emplace_back("sample_rate = ?");
        if (data.channels) fields.emplace_back("channels = ?");
        if (data.duration) fields.emplace_back("duration = ?");
        if (data.integrated_loudness) fields.emplace_back("integrated_loudness = ?");
        if (data.true_peak) fields.emplace_back("true_peak = ?");

        if (fields.empty()) return {};

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1) sql += ", ";
        }
        sql += " WHERE pcm_hash = ?";

        SQLite::Statement query(db, sql);
        int bind_idx = 1;
        if (data.parent_hash) {
            if (data.parent_hash->empty()) {
                query.bind(bind_idx++);
            } else {
                query.bind(bind_idx++, *data.parent_hash);
            }
        }
        if (data.quality_score) query.bind(bind_idx++, *data.quality_score);
        if (data.bit_depth) query.bind(bind_idx++, *data.bit_depth);
        if (data.sample_rate) query.bind(bind_idx++, *data.sample_rate);
        if (data.channels) query.bind(bind_idx++, *data.channels);
        if (data.duration) query.bind(bind_idx++, *data.duration);
        if (data.integrated_loudness) query.bind(bind_idx++, *data.integrated_loudness);
        if (data.true_peak) query.bind(bind_idx++, *data.true_peak);
        query.bind(bind_idx, data.pcm_hash);

        if (query.exec() == 0) return tl::unexpected("Audio not found.");

        transaction->commit();
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
    return {};
}

tl::expected<Audio, std::string> SqliteAudioRepository::get(const std::string &pcm_hash) {
    try {
        auto &db = m_context.get_db();

        SQLite::Statement query(db, "SELECT * FROM Audio WHERE pcm_hash = ?");
        query.bind(1, pcm_hash);

        if (query.executeStep()) {
            Audio audio;
            audio.pcm_hash = query.getColumn("pcm_hash").getString();
            audio.parent_hash = SqliteHelper::get_safe<std::string>(query, "parent_hash", "");
            audio.quality_score = query.getColumn("quality_score").getInt();
            audio.bit_depth = query.getColumn("bit_depth").getInt();
            audio.sample_rate = query.getColumn("sample_rate").getInt();
            audio.channels = query.getColumn("channels").getInt();
            audio.duration = query.getColumn("duration").getDouble();
            audio.integrated_loudness = query.getColumn("integrated_loudness").getDouble();
            audio.true_peak = query.getColumn("true_peak").getDouble();

            SQLite::Statement asset_query(
                db,
                "SELECT a.file_hash, a.mime_type, a.asset_type, a.file_size, a.created_at "
                "FROM Audio_Asset aa JOIN Asset a ON aa.file_hash = a.file_hash "
                "WHERE aa.pcm_hash = ?");
            asset_query.bind(1, pcm_hash);

            while (asset_query.executeStep()) {
                Asset asset;
                asset.file_hash = asset_query.getColumn("file_hash").getString();
                asset.mime_type = SqliteHelper::get_safe<std::string>(asset_query, "mime_type", "");
                asset.asset_type = SqliteHelper::get_safe<std::string>(asset_query, "asset_type", "");
                asset.file_size = SqliteHelper::get_safe<int>(asset_query, "file_size", 0);
                asset.created_at = SqliteHelper::get_safe<std::string>(asset_query, "created_at", "");
                audio.assets.push_back(asset);
            }

            return audio;
        }
        return tl::unexpected("Audio not found.");
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

tl::expected<PaginatedResult<Audio>, std::string> SqliteAudioRepository::list(
    int offset, int limit, const std::optional<std::string> &search) {
    try {
        auto &db = m_context.get_db();
        std::string count_sql = "SELECT COUNT(*) FROM Audio";
        std::string select_sql = "SELECT * FROM Audio";

        if (search.has_value()) {
            count_sql += R"( WHERE parent_hash LIKE ? ESCAPE '\' )";
            select_sql += R"( WHERE parent_hash LIKE ? ESCAPE '\' )";
        }

        select_sql += " ORDER BY pcm_hash ASC LIMIT ? OFFSET ?";

        int total = 0;
        {
            SQLite::Statement count_query(db, count_sql);
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                count_query.bind(1, query_param);
            }
            if (!count_query.executeStep()) {
                return tl::unexpected("Failed to get total count.");
            }
            total = count_query.getColumn(0).getInt();
        }

        std::vector<Audio> items;
        items.reserve(limit);
        {
            SQLite::Statement select_query(db, select_sql);
            int bind_idx = 1;
            if (search.has_value()) {
                std::string query_param = "%" + SqliteHelper::escape_like(search.value(), '\\') + "%";
                select_query.bind(bind_idx++, query_param);
            }
            select_query.bind(bind_idx++, limit);
            select_query.bind(bind_idx++, offset);

            while (select_query.executeStep()) {
                Audio audio;
                audio.pcm_hash = select_query.getColumn("pcm_hash").getString();
                audio.parent_hash = SqliteHelper::get_safe<std::string>(select_query, "parent_hash", "");
                audio.quality_score = select_query.getColumn("quality_score").getInt();
                audio.bit_depth = select_query.getColumn("bit_depth").getInt();
                audio.sample_rate = select_query.getColumn("sample_rate").getInt();
                audio.channels = select_query.getColumn("channels").getInt();
                audio.duration = select_query.getColumn("duration").getDouble();
                audio.integrated_loudness = select_query.getColumn("integrated_loudness").getDouble();
                audio.true_peak = select_query.getColumn("true_peak").getDouble();
                items.push_back(audio);
            }
        }

        return PaginatedResult<Audio>{
            .items = std::move(items),
            .total = total,
            .offset = offset,
            .limit = limit,
        };
    } catch (const std::exception &e) {
        return tl::unexpected(e.what());
    }
}

} // namespace lyra
