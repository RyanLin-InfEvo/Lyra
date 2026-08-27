/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/album.h"
#include "../models/artist.h"
#include "../models/asset.h"
#include "../models/audio.h"
#include "../models/image.h"
#include "../models/playlist.h"
#include "../models/track.h"
#include "../models/work.h"
#include "sqlite_helper.h"
#include <SQLiteCpp/SQLiteCpp.h>

namespace lyra {
namespace SqliteMappers {

Asset map_asset(SQLite::Statement &query);
Audio map_audio(SQLite::Statement &query);
Track map_track(SQLite::Statement &query);
Album map_album(SQLite::Statement &query);
Artist map_artist(SQLite::Statement &query);
Work map_work(SQLite::Statement &query);
Playlist map_playlist(SQLite::Statement &query);
Image map_image(SQLite::Statement &query);

template <typename T>
T map(SQLite::Statement &query);

template <>
inline Asset map<Asset>(SQLite::Statement &query) {
    return map_asset(query);
}

template <>
inline Audio map<Audio>(SQLite::Statement &query) {
    return map_audio(query);
}

template <>
inline Track map<Track>(SQLite::Statement &query) {
    return map_track(query);
}

template <>
inline Album map<Album>(SQLite::Statement &query) {
    return map_album(query);
}

template <>
inline Artist map<Artist>(SQLite::Statement &query) {
    return map_artist(query);
}

template <>
inline Work map<Work>(SQLite::Statement &query) {
    return map_work(query);
}

template <>
inline Playlist map<Playlist>(SQLite::Statement &query) {
    return map_playlist(query);
}

template <>
inline Image map<Image>(SQLite::Statement &query) {
    return map_image(query);
}

} // namespace SqliteMappers

namespace SqliteHelper {

template <typename T>
inline std::optional<T> fetch_one(SQLite::Statement &query) {
    if (query.executeStep()) {
        return SqliteMappers::map<T>(query);
    }
    return std::nullopt;
}

template <typename T>
inline std::vector<T> fetch_all(SQLite::Statement &query, size_t reserve_count = 0) {
    std::vector<T> items;
    if (reserve_count > 0) {
        items.reserve(reserve_count);
    }
    while (query.executeStep()) {
        items.push_back(SqliteMappers::map<T>(query));
    }
    return items;
}

} // namespace SqliteHelper
} // namespace lyra
