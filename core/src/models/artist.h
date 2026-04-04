/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "../utils/optional_helper.h"

namespace lyra {

struct Artist {
    std::string id;
    std::string name;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;
};

struct ArtistUpdate {
    std::string id;
    std::optional<std::string> name;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(name, musicbrainz_id, ytm_id, spotify_id);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Artist, id, name, musicbrainz_id, ytm_id, spotify_id)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(ArtistUpdate, id, name, musicbrainz_id, ytm_id, spotify_id)

} // namespace lyra
