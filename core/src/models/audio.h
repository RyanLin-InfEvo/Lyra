/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include "../utils/optional_helper.h"
#include "asset.h"
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

namespace lyra {

struct Audio {
    std::string pcm_hash;
    std::string parent_hash;
    int quality_score = 0;
    int bit_depth = 0;
    int sample_rate = 0;
    int channels = 0;
    double duration = 0.0;
    double integrated_loudness = 0.0;
    double true_peak = 0.0;
    std::vector<Asset> assets;
};

struct AudioUpdate {
    std::string pcm_hash;
    std::optional<std::string> parent_hash;
    std::optional<int> quality_score;
    std::optional<int> bit_depth;
    std::optional<int> sample_rate;
    std::optional<int> channels;
    std::optional<double> duration;
    std::optional<double> integrated_loudness;
    std::optional<double> true_peak;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(
            parent_hash, quality_score, bit_depth, sample_rate, channels, duration,
            integrated_loudness, true_peak);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Audio, pcm_hash, parent_hash, quality_score, bit_depth, sample_rate, channels, duration, integrated_loudness, true_peak, assets)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(AudioUpdate, pcm_hash, parent_hash, quality_score, bit_depth, sample_rate, channels, duration, integrated_loudness, true_peak)

} // namespace lyra
