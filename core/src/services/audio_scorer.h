/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "models/asset.h"
#include "models/audio.h"
#include "utils/audio_helper.h"
#include <algorithm>
#include <optional>
#include <string>
#include <vector>

namespace lyra {

struct ScoredCandidateAsset {
    Asset asset;
    int quality_score = 0;      // Effective score for ranking/sorting (with bonuses)
    int base_quality_score = 0; // Pure base quality score from evaluate_quality
    bool is_lossless = false;
    int64_t file_size = 0;
    std::string file_hash;

    const std::string &identifier() const { return file_hash; }
};

struct ScoredAudioVersion {
    std::string pcm_hash;
    std::string format;
    int quality_score = 0; // Natural quality score from evaluate_quality (reported in API)
    int ranking_score = 0; // Score with bonuses if applicable
    bool is_lossless = false;
    int64_t file_size = 0;
    bool is_master = false;

    const std::string &identifier() const { return pcm_hash; }
};

// 4-Tier Canonical Comparator:
// 1. quality_score (DESC)
// 2. is_lossless (DESC)
// 3. file_size (DESC)
// 4. identifier/hash (ASC)
template <typename T>
struct FourTierComparator {
    bool operator()(const T &a, const T &b) const {
        if (a.quality_score != b.quality_score) {
            return a.quality_score > b.quality_score;
        }
        if (a.is_lossless != b.is_lossless) {
            return a.is_lossless && !b.is_lossless;
        }
        if (a.file_size != b.file_size) {
            return a.file_size > b.file_size;
        }
        return a.identifier() < b.identifier();
    }
};

using CandidateAssetComparator = FourTierComparator<ScoredCandidateAsset>;
using AudioVersionComparator = FourTierComparator<ScoredAudioVersion>;

class AudioScorer {
  public:
    static constexpr int LOSSLESS_BONUS = 500;
    static constexpr int PREFERRED_FORMAT_BONUS = 1000;

    // Score a single candidate asset for an Audio entity
    static ScoredCandidateAsset score_candidate_asset(
        const Audio &audio,
        const Asset &asset,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = true);

    // Score and sort candidate assets for an Audio entity using the 4-tier comparator
    static std::vector<ScoredCandidateAsset> score_and_sort_candidate_assets(
        const Audio &audio,
        const std::vector<Asset> &assets,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = true);

    // Score a single candidate Audio version across a version family
    static ScoredAudioVersion score_candidate_version(
        const Audio &audio,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = false);

    // Score and sort candidate Audio versions across a version family using the 4-tier comparator
    static std::vector<ScoredAudioVersion> score_and_sort_candidate_versions(
        const std::vector<Audio> &candidate_audios,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = false);

    // Direct comparator helpers
    static bool compare_candidate_assets(const ScoredCandidateAsset &a, const ScoredCandidateAsset &b);
    static bool compare_audio_versions(const ScoredAudioVersion &a, const ScoredAudioVersion &b);
};

} // namespace lyra
