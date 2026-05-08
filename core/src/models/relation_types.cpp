/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "relation_types.h"

namespace lyra {
namespace ArtistRoleMapper {

// clang-format off
std::optional<ArtistRole> from_string(std::string_view role_str) {
    if (role_str == "main") return ArtistRole::Main;
    if (role_str == "featured") return ArtistRole::Featured;
    if (role_str == "remixer") return ArtistRole::Remixer;
    if (role_str == "producer") return ArtistRole::Producer;
    if (role_str == "conductor") return ArtistRole::Conductor;
    if (role_str == "performer") return ArtistRole::Performer;
    if (role_str == "engineer") return ArtistRole::Engineer;
    return std::nullopt;
}

const char* to_string(ArtistRole role) {
    switch (role) {
        case ArtistRole::Main: return "main";
        case ArtistRole::Featured: return "featured";
        case ArtistRole::Remixer: return "remixer";
        case ArtistRole::Producer: return "producer";
        case ArtistRole::Conductor: return "conductor";
        case ArtistRole::Performer: return "performer";
        case ArtistRole::Engineer: return "engineer";
        default: return "main";
    }
}
// clang-format on

} // namespace ArtistRoleMapper
} // namespace lyra

