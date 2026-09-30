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

/**
 * @brief Represents a physical storage Asset evaluated as a candidate for a canonical Audio stream.
 *
 * An Audio entity (unique PCM acoustic content) may have multiple physical representations
 * (e.g., a FLAC master, an MP3 transcode, an AAC web stream). This structure pairs the Asset
 * with its computed fidelity scores and physical properties for arbitration.
 */
struct ScoredCandidateAsset {
    Asset asset;

    /// Effective composite score used for ranking and sorting (incorporates base quality
    /// score plus optional lossless and preferred format bonuses).
    int quality_score = 0;

    /// Objective baseline quality score calculated directly from acoustic stream attributes
    /// (sample rate, bit depth, channels, bitrate) via AudioHelper::evaluate_quality.
    int base_quality_score = 0;

    /// True if the asset is encoded in a lossless/uncompressed container (e.g. FLAC, ALAC, WAV).
    bool is_lossless = false;

    /// Physical file size in bytes, utilized as a Tier-3 tie-break.
    int64_t file_size = 0;

    /// Content-Addressed Storage (CAS) SHA-256 hash, utilized as a Tier-4 deterministic tie-break.
    std::string file_hash;

    /// Returns the unique identifier for canonical tie-breaking.
    const std::string &identifier() const { return file_hash; }
};

/**
 * @brief Represents an Audio version candidate evaluated within a Star Topology version family.
 *
 * In Lyra's audio version topology, multiple Audio entities may be related as variants or
 * remasters of each other. This structure captures the version's fidelity metrics.
 */
struct ScoredAudioVersion {
    std::string pcm_hash;
    std::string format;

    /// Natural quality score from evaluate_quality without transient ranking bonuses.
    /// This is the canonical score exposed in API responses and UI inspection cards.
    int quality_score = 0;

    /// Composite ranking score with bonuses (e.g. PREFERRED_FORMAT_BONUS) applied.
    /// Used strictly for internal sorting and recommended master arbitration.
    int ranking_score = 0;

    /// True if this audio version originates from a lossless asset.
    bool is_lossless = false;

    /// Physical size of the primary asset backing this version, used for Tier-3 tie-break.
    int64_t file_size = 0;

    /// True if this node acts as the root master in the version family.
    bool is_master = false;

    /// Returns the canonical PCM hash for Tier-4 deterministic tie-breaking.
    const std::string &identifier() const { return pcm_hash; }
};

/**
 * @brief 4-Tier Canonical Arbitration Comparator.
 *
 * Implements Lyra's standardized 4-tier decision hierarchy for choosing between audio candidates:
 *
 * 1. **Tier 1 - Quality / Ranking Score (DESC):**
 *    Higher numerical quality/ranking score takes immediate precedence. This ensures higher
 *    sample rates, higher bit depths, and format preferences dominate.
 * 2. **Tier 2 - Lossless Priority (DESC):**
 *    If quality scores are equal, lossless codecs (FLAC, ALAC, WAV) strictly outrank lossy
 *    codecs (MP3, AAC, Opus).
 * 3. **Tier 3 - File Size Tie-Break (DESC):**
 *    If quality and lossless status are identical, the larger file is preferred as a proxy
 *    for higher average bitrate or less aggressive compression.
 * 4. **Tier 4 - Deterministic Identifier Tie-Break (ASC):**
 *    If all acoustic and physical metrics are equal, candidates are sorted lexicographically
 *    by their unique identifier (`file_hash` or `pcm_hash`). This eliminates non-deterministic
 *    ordering across runs, compilers, and database query plans.
 */
template <typename T>
struct FourTierComparator {
    bool operator()(const T &a, const T &b) const {
        // Tier 1: Quality / Ranking score (DESC)
        if (a.quality_score != b.quality_score) {
            return a.quality_score > b.quality_score;
        }
        // Tier 2: Lossless priority (DESC)
        if (a.is_lossless != b.is_lossless) {
            return a.is_lossless && !b.is_lossless;
        }
        // Tier 3: File size tie-break (DESC)
        if (a.file_size != b.file_size) {
            return a.file_size > b.file_size;
        }
        // Tier 4: Deterministic identifier tie-break (ASC)
        return a.identifier() < b.identifier();
    }
};

/**
 * @brief Specialization of FourTierComparator for ScoredAudioVersion.
 *
 * Uses `ranking_score` for Tier-1 sorting to allow format preference bonuses
 * to guide version arbitration while preserving the natural `quality_score` for display.
 */
template <>
struct FourTierComparator<ScoredAudioVersion> {
    bool operator()(const ScoredAudioVersion &a, const ScoredAudioVersion &b) const {
        // Tier 1: Ranking score (DESC)
        if (a.ranking_score != b.ranking_score) {
            return a.ranking_score > b.ranking_score;
        }
        // Tier 2: Lossless priority (DESC)
        if (a.is_lossless != b.is_lossless) {
            return a.is_lossless && !b.is_lossless;
        }
        // Tier 3: File size tie-break (DESC)
        if (a.file_size != b.file_size) {
            return a.file_size > b.file_size;
        }
        // Tier 4: Deterministic identifier tie-break (ASC)
        return a.identifier() < b.identifier();
    }
};

using CandidateAssetComparator = FourTierComparator<ScoredCandidateAsset>;
using AudioVersionComparator = FourTierComparator<ScoredAudioVersion>;

/**
 * @brief Stateless scoring engine and arbitration service for assets and audio versions.
 */
class AudioScorer {
  public:
    /// Scoring bonus added to candidate assets when encoded in a lossless format.
    /// Ensures lossless assets reliably outrank lossy assets with similar nominal sample rates.
    static constexpr int LOSSLESS_BONUS = 500;

    /// High-priority scoring bonus added when a candidate matches the caller's preferred format.
    /// Outweighs default natural quality differences to honor explicit user or platform format constraints.
    static constexpr int PREFERRED_FORMAT_BONUS = 1000;

    /**
     * @brief Scores an individual candidate Asset backing an Audio entity.
     *
     * @param audio Parent Audio entity providing acoustic context.
     * @param asset Physical Asset candidate to evaluate.
     * @param preferred_format Optional format filter/preference string (e.g. "flac").
     * @param apply_lossless_bonus If true, grants LOSSLESS_BONUS to lossless formats.
     * @return Fully populated `ScoredCandidateAsset`.
     */
    static ScoredCandidateAsset score_candidate_asset(
        const Audio &audio,
        const Asset &asset,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = true);

    /**
     * @brief Evaluates and sorts all candidate Assets for an Audio entity using 4-tier arbitration.
     *
     * @param audio Parent Audio entity.
     * @param assets Vector of candidate assets.
     * @param preferred_format Optional format preference.
     * @param apply_lossless_bonus If true, grants LOSSLESS_BONUS to lossless candidates.
     * @return Sorted vector of candidate assets in descending order of preference.
     */
    static std::vector<ScoredCandidateAsset> score_and_sort_candidate_assets(
        const Audio &audio,
        const std::vector<Asset> &assets,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = true);

    /**
     * @brief Scores a single Audio version candidate within a version family.
     *
     * @param audio Audio version entity to evaluate.
     * @param preferred_format Optional format preference.
     * @param apply_lossless_bonus If true, applies lossless bonus to ranking score.
     * @return Fully populated `ScoredAudioVersion`.
     */
    static ScoredAudioVersion score_candidate_version(
        const Audio &audio,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = false);

    /**
     * @brief Evaluates and ranks candidate Audio versions across a version family.
     *
     * @param candidate_audios Vector of candidate Audio versions.
     * @param preferred_format Optional format preference.
     * @param apply_lossless_bonus If true, applies lossless bonus to ranking score.
     * @return Ranked vector of audio versions, with top-ranked master at index 0.
     */
    static std::vector<ScoredAudioVersion> score_and_sort_candidate_versions(
        const std::vector<Audio> &candidate_audios,
        const std::optional<std::string> &preferred_format = std::nullopt,
        bool apply_lossless_bonus = false);

    // Direct comparator helpers
    static bool compare_candidate_assets(const ScoredCandidateAsset &a, const ScoredCandidateAsset &b);
    static bool compare_audio_versions(const ScoredAudioVersion &a, const ScoredAudioVersion &b);
};

} // namespace lyra
