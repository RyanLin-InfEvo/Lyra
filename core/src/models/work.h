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

struct Work {
    std::string id;
    std::string title;
    std::optional<uint16_t> composition_start_year;
    std::optional<uint16_t> composition_end_year;
    std::optional<std::string> composition_date_text;
    std::optional<std::string> iswc;
    std::optional<std::string> musicbrainz_id;
};

struct WorkUpdate {
    std::string id;
    std::optional<std::string> title;
    std::optional<uint16_t> composition_start_year;
    std::optional<uint16_t> composition_end_year;
    std::optional<std::string> composition_date_text;
    std::optional<std::string> iswc;
    std::optional<std::string> musicbrainz_id;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(title, composition_start_year, composition_end_year,
                                    composition_date_text, iswc, musicbrainz_id);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Work, id, title, composition_start_year, composition_end_year, composition_date_text, iswc, musicbrainz_id)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(WorkUpdate, id, title, composition_start_year, composition_end_year, composition_date_text, iswc, musicbrainz_id)

} // namespace lyra
