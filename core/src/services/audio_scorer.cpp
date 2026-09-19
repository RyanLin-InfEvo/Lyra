/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_scorer.h"

namespace lyra {

// Evaluates and computes the quality score of a single physical audio asset.
// Combines base audio specs (sample rate, bit depth, channels, bitrate) with conditional
// bonuses (lossless fidelity bonus +500 and caller-preferred format bonus +1000)
// to produce a ScoredCandidateAsset for candidate ranking and playback resolution.
ScoredCandidateAsset AudioScorer::score_candidate_asset(
    const Audio &audio,
    const Asset &asset,
    const std::optional<std::string> &preferred_format,
    bool apply_lossless_bonus) {
    auto qinfo = utils::AudioHelper::evaluate_quality(audio, asset);
    int score = qinfo.quality_score;
    if (apply_lossless_bonus && qinfo.is_lossless) {
        score += LOSSLESS_BONUS;
    }
    if (preferred_format.has_value() && !preferred_format->empty() &&
        utils::AudioHelper::matches_format(asset, *preferred_format)) {
        score += PREFERRED_FORMAT_BONUS;
    }

    return ScoredCandidateAsset{
        .asset = asset,
        .quality_score = score,
        .base_quality_score = qinfo.quality_score,
        .is_lossless = qinfo.is_lossless,
        .file_size = asset.file_size,
        .file_hash = asset.file_hash};
}

// Scores and sorts all candidate physical assets under a given Audio entity.
// Evaluates quality metrics and bonuses for each candidate asset, then sorts the list
// from highest to lowest priority using the canonical 4-tier comparator
// (quality_score DESC -> is_lossless DESC -> file_size DESC -> file_hash ASC).
std::vector<ScoredCandidateAsset> AudioScorer::score_and_sort_candidate_assets(
    const Audio &audio,
    const std::vector<Asset> &assets,
    const std::optional<std::string> &preferred_format,
    bool apply_lossless_bonus) {
    std::vector<ScoredCandidateAsset> candidates;
    candidates.reserve(assets.size());

    for (const auto &asset : assets) {
        candidates.push_back(score_candidate_asset(audio, asset, preferred_format, apply_lossless_bonus));
    }

    std::sort(candidates.begin(), candidates.end(), FourTierComparator<ScoredCandidateAsset>{});
    return candidates;
}

// Evaluates the overall quality rating of an Audio version entity across its associated assets.
// Detects the peak audio fidelity and format among its physical assets, computes the quality score
// along with lossless and format preference bonuses, and produces a ScoredAudioVersion struct
// for cross-version ranking and recommended master selection.
ScoredAudioVersion AudioScorer::score_candidate_version(
    const Audio &audio,
    const std::optional<std::string> &preferred_format,
    bool apply_lossless_bonus) {
    auto qinfo = utils::AudioHelper::evaluate_quality(audio);
    int score = qinfo.quality_score;
    if (apply_lossless_bonus && qinfo.is_lossless) {
        score += LOSSLESS_BONUS;
    }
    if (preferred_format.has_value() && !preferred_format->empty()) {
        bool match = false;
        for (const auto &asset : audio.assets) {
            if (utils::AudioHelper::matches_format(asset, *preferred_format)) {
                match = true;
                break;
            }
        }
        if (match) {
            score += PREFERRED_FORMAT_BONUS;
        }
    }

    ScoredAudioVersion version;
    version.pcm_hash = audio.pcm_hash;
    version.format = qinfo.format;
    version.quality_score = apply_lossless_bonus ? score : qinfo.quality_score;
    version.ranking_score = score;
    version.is_lossless = qinfo.is_lossless;
    version.file_size = qinfo.file_size;
    version.is_master = false;
    return version;
}

// Scores and ranks all audio version candidates across a version family (Star Topology).
// Evaluates fidelity for each audio version, sorts them using the canonical 4-tier comparator,
// and automatically designates the top-ranked candidate as the recommended master (is_master = true).
std::vector<ScoredAudioVersion> AudioScorer::score_and_sort_candidate_versions(
    const std::vector<Audio> &candidate_audios,
    const std::optional<std::string> &preferred_format,
    bool apply_lossless_bonus) {
    std::vector<ScoredAudioVersion> versions;
    versions.reserve(candidate_audios.size());

    for (const auto &audio : candidate_audios) {
        versions.push_back(score_candidate_version(audio, preferred_format, apply_lossless_bonus));
    }

    std::sort(versions.begin(), versions.end(), FourTierComparator<ScoredAudioVersion>{});

    if (!versions.empty()) {
        versions[0].is_master = true;
    }

    return versions;
}

// Public helper: Compares two candidate physical assets according to the canonical 4-tier priority rules.
bool AudioScorer::compare_candidate_assets(const ScoredCandidateAsset &a, const ScoredCandidateAsset &b) {
    return FourTierComparator<ScoredCandidateAsset>{}(a, b);
}

// Public helper: Compares two candidate audio versions according to the canonical 4-tier priority rules.
bool AudioScorer::compare_audio_versions(const ScoredAudioVersion &a, const ScoredAudioVersion &b) {
    return FourTierComparator<ScoredAudioVersion>{}(a, b);
}

} // namespace lyra
