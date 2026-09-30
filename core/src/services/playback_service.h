/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "models/asset.h"
#include "models/audio.h"
#include "models/track.h"
#include "services/audio_engine.h"
#include "services/audio_scorer.h"
#include "services/repositories/i_asset_repository.h"
#include "services/repositories/i_audio_repository.h"
#include "services/repositories/i_track_repository.h"
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

/**
 * @brief Discriminator for polymorphic playback targets.
 *
 * Lyra supports resolving audio streams from multiple domain abstractions:
 * - Track: High-level library metadata entity with associated audio version families.
 * - Audio: Canonical PCM-level entity representing unique acoustic content.
 * - Asset: Physical CAS storage file record identified by its SHA-256 hash.
 * - DirectFile: Direct absolute filesystem path (bypasses CAS and database).
 */
enum class PlaybackTargetType {
    Track,
    Audio,
    Asset,
    DirectFile
};

/**
 * @brief Polymorphic playback target specifying the audio source to resolve and play.
 */
struct PlaybackTarget {
    PlaybackTargetType type{PlaybackTargetType::DirectFile};
    std::string identifier;

    PlaybackTarget() = default;
    PlaybackTarget(PlaybackTargetType t, std::string id)
        : type(t), identifier(std::move(id)) {}

    static PlaybackTarget from_track(std::string track_id) {
        return PlaybackTarget(PlaybackTargetType::Track, std::move(track_id));
    }
    static PlaybackTarget from_audio(std::string pcm_hash) {
        return PlaybackTarget(PlaybackTargetType::Audio, std::move(pcm_hash));
    }
    static PlaybackTarget from_asset(std::string file_hash) {
        return PlaybackTarget(PlaybackTargetType::Asset, std::move(file_hash));
    }
    static PlaybackTarget from_file(std::string path) {
        return PlaybackTarget(PlaybackTargetType::DirectFile, std::move(path));
    }
};

/**
 * @brief Configuration options controlling audio resolution and playback behavior.
 */
struct PlaybackOptions {
    /// Desired audio container/codec format (e.g., "flac", "mp3", "opus").
    /// Overrides default quality ranking by applying a scoring bonus.
    std::optional<std::string> preferred_format = std::nullopt;

    /// Starting playback position in seconds (defaults to 0.0 for beginning of track).
    double start_position_seconds = 0.0;

    /// Pin version flag:
    /// - When false (default): Resolving a Track target triggers Star Topology version
    ///   arbitration across the audio family, dynamically selecting the highest-quality
    ///   or preferred master version available.
    /// - When true: Version family discovery is bypassed; the track's explicitly assigned
    ///   PCM audio version is played directly without auto-promotion.
    bool pin_version = false;
};

/**
 * @brief Fully resolved playback descriptor ready for decoder consumption.
 *
 * Contains physical storage metadata (file path, CAS hash, byte size)
 * alongside acoustic stream attributes (sample rate, bit depth, channels, quality score).
 */
struct ResolvedPlayback {
    std::string track_id;
    std::string pcm_hash;
    std::string file_hash;
    std::string file_path;
    std::string format;
    int sample_rate = 0;
    int bit_depth = 0;
    int channels = 0;
    int64_t file_size = 0;
    bool is_lossless = false;
    int quality_score = 0;
    std::string mime_type;
};

/**
 * @brief Granular domain error codes for target resolution and playback failures.
 */
enum class PlaybackErrorCode {
    Success,
    TargetNotFound,   ///< Target entity (Track, Audio, or Asset) does not exist in the database.
    NoPlayableAsset,  ///< Track exists but has no linked Audio or playable CAS assets.
    CasObjectMissing, ///< Referenced CAS storage file is missing from physical disk.
    EngineError,      ///< Low-level audio engine failed to open or initialize the decoder.
    InvalidParameter  ///< Client provided invalid or malformed request parameters.
};

/**
 * @brief Domain error structure capturing error classification and diagnostic messages.
 */
struct PlaybackError {
    PlaybackErrorCode code{PlaybackErrorCode::Success};
    std::string message;
};

/**
 * @brief Detailed report from audio version family evaluation and arbitration.
 */
struct VersionComparisonResult {
    std::string recommended_master;           ///< PCM hash of the top-ranked audio version.
    std::vector<ScoredAudioVersion> versions; ///< All evaluated versions ranked in descending order.
};

/**
 * @brief Central orchestrator and facade service for Lyra's audio playback subsystem.
 *
 * ### Architectural Responsibilities:
 * 1. **Polymorphic Target Resolution:**
 *    Resolves heterogeneous targets (`DirectFile`, `Asset`, `Audio`, `Track`) into a concrete
 *    playable file path backed by physical disk storage or CAS (Content-Addressed Storage).
 * 2. **Star Topology Version Arbitration:**
 *    When resolving Track entities, arbitrates across the audio version family (root master
 *    and related variants) using `AudioScorer` to select the highest-fidelity playable version,
 *    respecting format preferences and version pinning rules (`pin_version`).
 * 3. **Transport Forwarding & State Facade:**
 *    Acts as the primary facade for playback controls (play, pause, resume, stop, seek, volume,
 *    device selection), forwarding transport commands to the underlying `AudioEngine`.
 * 4. **Gapless & Seamless Transition State Maintenance:**
 *    Tracks the currently playing audio stream (`m_current_resolved`) and queued next stream
 *    (`m_next_resolved`) across asynchronous audio engine boundaries, handling timing promotions
 *    when the background engine transitions between tracks.
 *
 * ### Concurrency & Thread-Safety Model:
 * - **Internal Lock Scope (`m_mutex`):**
 *   The internal mutex strictly guards metadata state transitions (`m_current_resolved`,
 *   `m_next_resolved`).
 * - **Decoupled Execution & Lock Granularity Minimization:**
 *   All heavy, potentially blocking operations—including database repository queries, CAS disk
 *   lookups, filesystem stats, and `AudioEngine` decoder calls (`play()`, `preload_next()`)—MUST
 *   be executed **outside** `m_mutex`.
 * - **Rationale:**
 *   Audio decoding setup, disk I/O, and storage access can take tens or hundreds of milliseconds.
 *   Holding `m_mutex` during these calls would block high-frequency, real-time UI queries
 *   (such as `get_position()`, `get_state()`, and volume checks), degrading UI responsiveness.
 */
class PlaybackService {
  public:
    PlaybackService(
        std::filesystem::path storage_root,
        AudioEngine &audio_engine,
        ITrackRepository &track_repo,
        IAudioRepository &audio_repo,
        IAssetRepository &asset_repo);

    /**
     * @brief Resolves a playback target into a fully qualified `ResolvedPlayback` descriptor.
     *
     * This is a pure resolution query that does not modify the engine state or active stream.
     *
     * @param target Polymorphic target descriptor (Track, Audio, Asset, or DirectFile).
     * @param options Playback options (preferred format, version pinning).
     * @return `ResolvedPlayback` on success, or `PlaybackError` detailing failure cause.
     */
    tl::expected<ResolvedPlayback, PlaybackError> resolve(
        const PlaybackTarget &target,
        const PlaybackOptions &options = {});

    /**
     * @brief Resolves the target and starts immediate playback on the audio engine.
     *
     * Upon starting playback, any previously queued transition stream (`m_next_resolved`)
     * is unconditionally reset, as explicit user playback invalidates prior preload queues.
     *
     * @param target Polymorphic target descriptor.
     * @param options Playback options (start position, preferred format, version pinning).
     * @return `ResolvedPlayback` on success, or `PlaybackError` on resolution/engine failure.
     */
    tl::expected<ResolvedPlayback, PlaybackError> play(
        const PlaybackTarget &target,
        const PlaybackOptions &options = {});

    /**
     * @brief Resolves and preloads the next audio track for seamless, gapless playback.
     *
     * Preloads the resolved file into the audio engine buffer. Inspects the engine's active
     * file path before registering the new preload: if the engine has already transitioned
     * into the previously queued track asynchronously, `m_next_resolved` is promoted to
     * `m_current_resolved` before being overwritten.
     *
     * Passing an empty DirectFile target cancels the pending preload.
     *
     * @param target Polymorphic target descriptor.
     * @param options Playback options.
     * @return `ResolvedPlayback` on success, or `PlaybackError` on resolution/engine failure.
     */
    tl::expected<ResolvedPlayback, PlaybackError> preload_next(
        const PlaybackTarget &target,
        const PlaybackOptions &options = {});

    /**
     * @brief Clears any pending preloaded next track from both service state and engine.
     *
     * Performs engine path inspection prior to clearing: if the preloaded track has already
     * started playing asynchronously, it is promoted to `m_current_resolved` instead of lost.
     *
     * @return True if successfully cleared.
     */
    bool clear_preload_next();

    /**
     * @brief Compares and ranks all candidate audio versions for a given Track or Audio target.
     *
     * Evaluates versions using 4-tier arbitration rules (quality score, lossless status,
     * file size tie-break, deterministic hash ordering).
     *
     * @param target Track or Audio target.
     * @param options Playback options (preferred format bonus).
     * @return Ranked comparison result on success, or `PlaybackError`.
     */
    tl::expected<VersionComparisonResult, PlaybackError> compare_versions(
        const PlaybackTarget &target,
        const PlaybackOptions &options = {});

    /**
     * @brief Compares and ranks candidate audio versions from an explicit list of PCM hashes.
     */
    tl::expected<VersionComparisonResult, PlaybackError> compare_versions(
        const std::vector<std::string> &pcm_hashes,
        const PlaybackOptions &options = {});

    /**
     * @brief Compares and ranks pre-fetched Audio entity candidates.
     */
    tl::expected<VersionComparisonResult, PlaybackError> compare_versions(
        const std::vector<Audio> &candidate_audios,
        const PlaybackOptions &options = {});

    // Transport forwarding methods (thin facades to AudioEngine)
    bool pause();
    bool resume();
    bool stop();
    bool seek(double pos, bool relative = false);
    bool set_volume(float vol);
    AudioEngineState get_state() const;
    std::string get_state_string() const;
    nlohmann::json get_state_json() const;
    double get_position() const;
    double get_duration() const;
    float get_volume() const;
    std::vector<AudioDeviceInfo> list_devices() const;
    std::string get_output_device() const;
    bool set_output_device(const std::string &device_id);
    std::string get_current_file_path() const;

    /**
     * @brief Retrieves the active stream's resolved metadata, synchronizing transitions.
     *
     * If the background audio engine transitioned seamlessly into `m_next_resolved`,
     * this method atomically promotes `m_next_resolved` to `m_current_resolved`.
     *
     * @return `ResolvedPlayback` if currently active, or `std::nullopt` if stopped/idle.
     */
    std::optional<ResolvedPlayback> get_current_resolved() const;

    AudioEngine &get_audio_engine() { return m_audio_engine; }
    const AudioEngine &get_audio_engine() const { return m_audio_engine; }

  private:
    std::filesystem::path m_storage_root;
    AudioEngine &m_audio_engine;
    ITrackRepository &m_track_repo;
    IAudioRepository &m_audio_repo;
    IAssetRepository &m_asset_repo;

    /// Mutex protecting internal transition metadata (m_current_resolved and m_next_resolved).
    /// Long-running operations (CAS lookups, disk I/O, engine decoding) must NOT hold this lock.
    mutable std::mutex m_mutex;
    mutable std::optional<ResolvedPlayback> m_current_resolved;
    mutable std::optional<ResolvedPlayback> m_next_resolved;

    tl::expected<ResolvedPlayback, PlaybackError> resolve_direct_file(
        const std::string &path,
        const PlaybackOptions &options);

    tl::expected<ResolvedPlayback, PlaybackError> resolve_asset(
        const std::string &file_hash,
        const PlaybackOptions &options);

    tl::expected<ResolvedPlayback, PlaybackError> resolve_audio(
        const std::string &pcm_hash,
        const PlaybackOptions &options);

    tl::expected<ResolvedPlayback, PlaybackError> resolve_track(
        const std::string &track_id,
        const PlaybackOptions &options);
};

} // namespace lyra
