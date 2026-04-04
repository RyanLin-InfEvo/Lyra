/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <optional>
#include <string_view>

namespace lyra {

enum class ArtistRole {
    Main,
    Featured,
    Remixer,
    Producer,
    Conductor,
    Performer,
    Engineer
};

struct TrackArtistParams {
    std::string_view track_id;
    std::string_view artist_id;
    ArtistRole role;
    std::optional<int> position = std::nullopt;
};

namespace ArtistRoleMapper {
std::string_view to_string(ArtistRole role);
std::optional<ArtistRole> from_string(std::string_view role_str);
} // namespace ArtistRoleMapper

} // namespace lyra
