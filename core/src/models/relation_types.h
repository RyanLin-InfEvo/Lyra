/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include "../utils/optional_helper.h"
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <string_view>

namespace lyra {

enum class ArtistRole { Main, Featured, Remixer, Producer, Conductor, Performer, Engineer };

NLOHMANN_JSON_SERIALIZE_ENUM(ArtistRole, {
                                             {ArtistRole::Main, "main"},
                                             {ArtistRole::Featured, "featured"},
                                             {ArtistRole::Remixer, "remixer"},
                                             {ArtistRole::Producer, "producer"},
                                             {ArtistRole::Conductor, "conductor"},
                                             {ArtistRole::Performer, "performer"},
                                             {ArtistRole::Engineer, "engineer"},
                                         })

struct TrackArtistParams {
    std::string track_id;
    std::string artist_id;
    std::optional<ArtistRole> role = std::nullopt;
    std::optional<int> position = std::nullopt;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(TrackArtistParams, track_id, artist_id, role,
                                                position)

namespace ArtistRoleMapper {
const char* to_string(ArtistRole role);
std::optional<ArtistRole> from_string(std::string_view role_str);
} // namespace ArtistRoleMapper

} // namespace lyra
