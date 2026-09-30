/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "playback_service.h"
#include "utils/audio_helper.h"
#include "utils/storage_helper.h"
#include <algorithm>
#include <cctype>
#include <iostream>

namespace lyra {

namespace {
std::string normalize_file_extension(const std::string &path) {
    std::filesystem::path p(path);
    std::string ext = p.extension().string();
    if (!ext.empty() && ext[0] == '.') {
        ext = ext.substr(1);
    }
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return ext;
}
} // namespace

PlaybackService::PlaybackService(
    std::filesystem::path storage_root,
    AudioEngine &audio_engine,
    ITrackRepository &track_repo,
    IAudioRepository &audio_repo,
    IAssetRepository &asset_repo)
    : m_storage_root(std::move(storage_root)),
      m_audio_engine(audio_engine),
      m_track_repo(track_repo),
      m_audio_repo(audio_repo),
      m_asset_repo(asset_repo) {}

// Polymorphic resolution dispatch: delegates to specific resolver depending on target type.
tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::resolve(
    const PlaybackTarget &target,
    const PlaybackOptions &options) {
    switch (target.type) {
        case PlaybackTargetType::DirectFile:
            return resolve_direct_file(target.identifier, options);
        case PlaybackTargetType::Asset:
            return resolve_asset(target.identifier, options);
        case PlaybackTargetType::Audio:
            return resolve_audio(target.identifier, options);
        case PlaybackTargetType::Track:
            return resolve_track(target.identifier, options);
    }
    return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "Unknown playback target type"});
}

tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::play(
    const PlaybackTarget &target,
    const PlaybackOptions &options) {

    // 1. Resolve target OUTSIDE m_mutex:
    //    Database queries, CAS directory checks, and candidate scoring can take non-trivial time.
    //    Executing resolution without holding the lock keeps real-time UI queries responsive.
    auto resolved_res = resolve(target, options);
    if (!resolved_res) {
        return tl::unexpected(resolved_res.error());
    }

    // 2. Decoder initialization OUTSIDE m_mutex:
    //    AudioEngine::play performs synchronous decoder initialization (FFmpeg/miniaudio pipeline setup)
    //    and resets engine stream buffers. This involves file I/O and codec parsing.
    //    Executing outside m_mutex guarantees that UI status and position queries do not hang.
    bool success = m_audio_engine.play(resolved_res->file_path, options.start_position_seconds);
    if (!success) {
        return tl::unexpected(PlaybackError{
            PlaybackErrorCode::EngineError,
            "Failed to initialize decoder for audio file: " + resolved_res->file_path});
    }

    // 3. Update playback state under m_mutex:
    //    - m_current_resolved is updated to the newly active stream.
    //    - m_next_resolved is unconditionally reset because explicit user playback overrides and
    //      invalidates any previously preloaded transition stream.
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_current_resolved = *resolved_res;
        m_next_resolved.reset();
    }

    return *resolved_res;
}

tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::preload_next(
    const PlaybackTarget &target,
    const PlaybackOptions &options) {

    // Cancellation case: An empty DirectFile target explicitly clears the preloaded stream.
    if (target.type == PlaybackTargetType::DirectFile && target.identifier.empty()) {
        m_audio_engine.preload_next("");
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            // Timing promotion: If the background engine already transitioned asynchronously into
            // m_next_resolved, promote it to m_current_resolved before resetting m_next_resolved.
            if (m_next_resolved.has_value() && m_audio_engine.get_current_file_path() == m_next_resolved->file_path) {
                m_current_resolved = m_next_resolved;
            }
            m_next_resolved.reset();
        }
        ResolvedPlayback empty_resolved;
        return empty_resolved;
    }

    // Resolve target OUTSIDE m_mutex to avoid lock contention during DB and CAS disk lookups.
    auto resolved_res = resolve(target, options);
    if (!resolved_res) {
        return tl::unexpected(resolved_res.error());
    }

    // Preload next track in AudioEngine OUTSIDE m_mutex (pre-allocates decoder buffers).
    bool success = m_audio_engine.preload_next(resolved_res->file_path);
    if (!success) {
        return tl::unexpected(PlaybackError{
            PlaybackErrorCode::EngineError,
            "Failed to preload next audio track: " + resolved_res->file_path});
    }

    // Synchronize state under m_mutex:
    // Handle the timing race where the engine finished playing the current stream and seamlessly
    // promoted the previous m_next_resolved to active before this preload call registered.
    // If so, promote m_next_resolved to m_current_resolved so active track metadata is preserved.
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_next_resolved.has_value() && m_audio_engine.get_current_file_path() == m_next_resolved->file_path) {
            m_current_resolved = m_next_resolved;
        }
        m_next_resolved = *resolved_res;
    }

    return *resolved_res;
}

bool PlaybackService::clear_preload_next() {
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        // Timing promotion check prior to clearing:
        // Ensure that if the preloaded track has already begun playback asynchronously in the engine,
        // its metadata is preserved in m_current_resolved rather than discarded.
        if (m_next_resolved.has_value() && m_audio_engine.get_current_file_path() == m_next_resolved->file_path) {
            m_current_resolved = m_next_resolved;
        }
        m_next_resolved.reset();
    }
    return m_audio_engine.preload_next("");
}

// Compares audio versions for a Track or Audio target using the Star Topology audio family.
tl::expected<VersionComparisonResult, PlaybackError> PlaybackService::compare_versions(
    const PlaybackTarget &target,
    const PlaybackOptions &options) {
    if (target.type == PlaybackTargetType::Track) {
        if (target.identifier.empty()) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "track_id cannot be empty"});
        }
        auto track_res = m_track_repo.get(target.identifier);
        if (!track_res) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Track not found: " + target.identifier});
        }
        if (track_res->pcm_hash.empty()) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::NoPlayableAsset, "Track has no associated audio"});
        }
        // Query the full version family connected to this track's root audio node
        auto versions_res = m_audio_repo.get_related_versions(track_res->pcm_hash);
        if (!versions_res || versions_res->empty()) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Audio not found: " + track_res->pcm_hash});
        }
        return compare_versions(*versions_res, options);
    } else if (target.type == PlaybackTargetType::Audio) {
        if (target.identifier.empty()) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "pcm_hash cannot be empty"});
        }
        auto audio_res = m_audio_repo.get(target.identifier);
        if (!audio_res) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Audio not found: " + target.identifier});
        }
        auto versions_res = m_audio_repo.get_related_versions(target.identifier);
        std::vector<Audio> candidates;
        if (versions_res && !versions_res->empty()) {
            candidates = *versions_res;
        } else {
            candidates.push_back(*audio_res);
        }
        return compare_versions(candidates, options);
    }

    return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "compare_versions requires Track or Audio target"});
}

tl::expected<VersionComparisonResult, PlaybackError> PlaybackService::compare_versions(
    const std::vector<std::string> &pcm_hashes,
    const PlaybackOptions &options) {
    if (pcm_hashes.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "pcm_hashes cannot be empty"});
    }
    std::vector<Audio> candidate_audios;
    candidate_audios.reserve(pcm_hashes.size());
    for (const auto &hash : pcm_hashes) {
        auto audio_res = m_audio_repo.get(hash);
        if (!audio_res) {
            return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Audio not found: " + hash});
        }
        candidate_audios.push_back(std::move(*audio_res));
    }
    return compare_versions(candidate_audios, options);
}

// Scores and sorts candidate audio versions using AudioScorer (4-tier arbitration canonical rules).
tl::expected<VersionComparisonResult, PlaybackError> PlaybackService::compare_versions(
    const std::vector<Audio> &candidate_audios,
    const PlaybackOptions &options) {
    auto versions = AudioScorer::score_and_sort_candidate_versions(candidate_audios, options.preferred_format);
    VersionComparisonResult result;
    result.recommended_master = versions.empty() ? "" : versions[0].pcm_hash;
    result.versions = std::move(versions);
    return result;
}

bool PlaybackService::pause() {
    return m_audio_engine.pause();
}

bool PlaybackService::resume() {
    return m_audio_engine.resume();
}

bool PlaybackService::stop() {
    // Synchronously clear both active and queued stream metadata under m_mutex,
    // ensuring subsequent status queries report an idle state.
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_current_resolved.reset();
        m_next_resolved.reset();
    }
    return m_audio_engine.stop();
}

bool PlaybackService::seek(double pos, bool relative) {
    return m_audio_engine.seek(pos, relative);
}

bool PlaybackService::set_volume(float vol) {
    return m_audio_engine.set_volume(vol);
}

AudioEngineState PlaybackService::get_state() const {
    return m_audio_engine.get_state_enum();
}

std::string PlaybackService::get_state_string() const {
    return m_audio_engine.get_state_string();
}

nlohmann::json PlaybackService::get_state_json() const {
    return m_audio_engine.get_state_json();
}

double PlaybackService::get_position() const {
    return m_audio_engine.get_position();
}

double PlaybackService::get_duration() const {
    return m_audio_engine.get_duration();
}

float PlaybackService::get_volume() const {
    return m_audio_engine.get_volume();
}

std::vector<AudioDeviceInfo> PlaybackService::list_devices() const {
    return m_audio_engine.list_devices();
}

std::string PlaybackService::get_output_device() const {
    return m_audio_engine.get_output_device();
}

bool PlaybackService::set_output_device(const std::string &device_id) {
    return m_audio_engine.set_output_device(device_id);
}

std::string PlaybackService::get_current_file_path() const {
    return m_audio_engine.get_current_file_path();
}

/**
 * @brief Retrieves the active stream's resolved metadata, performing lazy transition promotion.
 *
 * AudioEngine plays gapless streams asynchronously in its background thread. When the previous
 * track finishes, the engine automatically switches its active file path to the preloaded file.
 *
 * Here, we inspect the engine's active file path:
 * 1. If the engine has stopped, return std::nullopt.
 * 2. If current_engine_path matches m_next_resolved, an asynchronous transition has occurred.
 *    We promote m_next_resolved -> m_current_resolved and reset m_next_resolved.
 * 3. If current_engine_path differs from m_current_resolved, the engine has moved to an untracked
 *    state or stopped; return std::nullopt to prevent returning mismatched/stale metadata.
 */
std::optional<ResolvedPlayback> PlaybackService::get_current_resolved() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_audio_engine.get_state_enum() == AudioEngineState::STOPPED) {
        return std::nullopt;
    }

    std::string current_engine_path = m_audio_engine.get_current_file_path();
    if (m_next_resolved.has_value() && current_engine_path == m_next_resolved->file_path) {
        m_current_resolved = m_next_resolved;
        m_next_resolved.reset();
    }

    if (m_current_resolved.has_value() && current_engine_path != m_current_resolved->file_path) {
        return std::nullopt;
    }

    return m_current_resolved;
}

// Resolves a direct raw file path from disk, bypassing database and CAS lookups.
tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::resolve_direct_file(
    const std::string &path,
    const PlaybackOptions &options) {
    (void)options;
    if (path.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "file_path cannot be empty"});
    }
    std::error_code ec;
    if (!std::filesystem::is_regular_file(path, ec)) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::CasObjectMissing, "Audio file does not exist on disk: " + path});
    }

    std::string ext = normalize_file_extension(path);

    ResolvedPlayback resolved;
    resolved.file_path = path;
    resolved.format = ext;
    resolved.mime_type = "audio/" + (ext == "mp3" ? "mpeg" : ext);
    auto sz = std::filesystem::file_size(path, ec);
    if (!ec) {
        resolved.file_size = static_cast<int64_t>(sz);
    }

    if (ext == "flac" || ext == "wav" || ext == "alac" || ext == "aiff") {
        resolved.is_lossless = true;
    }

    return resolved;
}

// Resolves a physical CAS asset by its SHA-256 hash.
tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::resolve_asset(
    const std::string &file_hash,
    const PlaybackOptions &options) {
    (void)options;
    if (file_hash.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "file_hash cannot be empty"});
    }

    // Defensive validation: Ensure hash is exactly 64 hexadecimal characters to prevent path traversal
    bool is_valid_hash = (file_hash.length() == 64) && std::all_of(file_hash.begin(), file_hash.end(), [](unsigned char c) {
                             return std::isxdigit(c);
                         });
    if (!is_valid_hash) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "Invalid file hash format: " + file_hash});
    }

    auto asset_res = m_asset_repo.get(file_hash);
    if (!asset_res) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Asset not found: " + file_hash});
    }
    const auto &asset = *asset_res;

    // Resolve physical CAS storage path and verify existence on disk
    const std::filesystem::path target_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root.string(), file_hash);
    if (!std::filesystem::exists(target_dir)) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::CasObjectMissing, "Asset file not found in storage: " + file_hash});
    }

    auto find_res = utils::StorageHelper::find_file_by_prefix(target_dir, file_hash);
    if (!find_res.has_value() || !std::filesystem::exists(*find_res)) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::CasObjectMissing, "Asset file not found in storage: " + file_hash});
    }

    ResolvedPlayback resolved;
    resolved.file_hash = asset.file_hash;
    resolved.file_path = *find_res;
    resolved.file_size = asset.file_size;
    resolved.mime_type = asset.mime_type;
    resolved.format = normalize_file_extension(*find_res);

    // Reverse-lookup associated Audio entity to enrich playback metadata with stream fidelity attributes
    auto pcm_hashes_res = m_asset_repo.get_audio_by_asset(file_hash);
    if (pcm_hashes_res && !pcm_hashes_res->empty()) {
        std::string pcm_hash = (*pcm_hashes_res)[0];
        resolved.pcm_hash = pcm_hash;
        auto audio_res = m_audio_repo.get(pcm_hash);
        if (audio_res) {
            resolved.sample_rate = audio_res->sample_rate;
            resolved.bit_depth = audio_res->bit_depth;
            resolved.channels = audio_res->channels;

            auto qinfo = utils::AudioHelper::evaluate_quality(*audio_res, asset);
            resolved.is_lossless = qinfo.is_lossless;
            resolved.quality_score = qinfo.quality_score;
        }
    }

    return resolved;
}

// Resolves a canonical Audio entity (PCM hash) by ranking and selecting among its backing CAS assets.
tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::resolve_audio(
    const std::string &pcm_hash,
    const PlaybackOptions &options) {
    if (pcm_hash.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "pcm_hash cannot be empty"});
    }

    auto audio_res = m_audio_repo.get(pcm_hash);
    if (!audio_res) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Audio not found: " + pcm_hash});
    }
    const auto &audio = *audio_res;

    // Retrieve all physical assets encoding this PCM audio stream
    auto assets_res = m_asset_repo.get_assets_by_pcm(pcm_hash);
    if (!assets_res || assets_res->empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::CasObjectMissing, "No assets found for audio: " + pcm_hash});
    }

    // Rank candidate assets using 4-tier arbitration (format bonus, quality score, lossless priority, file size)
    auto candidates = AudioScorer::score_and_sort_candidate_assets(audio, *assets_res, options.preferred_format);

    // Resilient disk check loop:
    // Iterate candidate assets in descending priority to locate the highest-quality asset physically
    // present on disk. Gracefully falls back to secondary candidates if a primary file is missing.
    for (const auto &candidate : candidates) {
        const auto &asset = candidate.asset;
        const std::filesystem::path target_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root.string(), asset.file_hash);
        if (!std::filesystem::exists(target_dir)) {
            std::cerr << "[WARN] CAS physical file missing for asset: " << asset.file_hash << std::endl;
            continue;
        }

        auto find_res = utils::StorageHelper::find_file_by_prefix(target_dir, asset.file_hash);
        if (!find_res || !std::filesystem::exists(*find_res)) {
            std::cerr << "[WARN] CAS physical file missing for asset: " << asset.file_hash << std::endl;
            continue;
        }

        ResolvedPlayback resolved;
        resolved.pcm_hash = audio.pcm_hash;
        resolved.file_hash = asset.file_hash;
        resolved.file_path = *find_res;
        resolved.file_size = candidate.file_size;
        resolved.is_lossless = candidate.is_lossless;
        resolved.quality_score = candidate.base_quality_score;
        resolved.sample_rate = audio.sample_rate;
        resolved.bit_depth = audio.bit_depth;
        resolved.channels = audio.channels;
        resolved.mime_type = asset.mime_type;

        resolved.format = normalize_file_extension(*find_res);

        return resolved;
    }

    return tl::unexpected(PlaybackError{PlaybackErrorCode::CasObjectMissing, "Asset not found on disk"});
}

/**
 * @brief Resolves a library Track entity into a concrete playable stream.
 *
 * Implements Star Topology version arbitration:
 * - When `options.pin_version == false` (default):
 *   Discovers all related audio versions in the version family connected to `track.pcm_hash`.
 *   Evaluates each candidate version using `AudioScorer` to select the highest-quality version
 *   available (honoring any caller-specified `preferred_format`). This allows automatic promotion
 *   to a newly imported lossless master or higher-fidelity version.
 * - When `options.pin_version == true`:
 *   Bypasses version family discovery and directly resolves `track.pcm_hash`, ensuring playback
 *   remains strictly pinned to the user's explicitly selected version without auto-promotion.
 */
tl::expected<ResolvedPlayback, PlaybackError> PlaybackService::resolve_track(
    const std::string &track_id,
    const PlaybackOptions &options) {
    if (track_id.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::InvalidParameter, "track_id cannot be empty"});
    }

    auto track_res = m_track_repo.get(track_id);
    if (!track_res) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::TargetNotFound, "Track not found: " + track_id});
    }
    const auto &track = *track_res;

    if (track.pcm_hash.empty()) {
        return tl::unexpected(PlaybackError{PlaybackErrorCode::NoPlayableAsset, "Track has no associated audio"});
    }

    // Star Topology master resolution: arbitrate across the version family unless version is pinned
    if (!options.pin_version) {
        auto family_res = m_audio_repo.get_related_versions(track.pcm_hash);
        if (family_res && !family_res->empty()) {
            auto scored_versions = AudioScorer::score_and_sort_candidate_versions(*family_res, options.preferred_format);
            for (const auto &ver : scored_versions) {
                auto res = resolve_audio(ver.pcm_hash, options);
                if (res) {
                    res->track_id = track.id;
                    return res;
                }
            }
        }
    }

    // Direct resolution: pinned version or fallback when no alternatives exist in the version family
    auto resolved_res = resolve_audio(track.pcm_hash, options);
    if (!resolved_res) {
        return tl::unexpected(resolved_res.error());
    }

    resolved_res->track_id = track.id;
    return resolved_res;
}

} // namespace lyra
