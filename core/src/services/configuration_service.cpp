// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "services/configuration_service.h"
#include "services/audio_engine.h"
#include "services/audio_sinks/audio_sink_factory.h"
#include "services/database_context.h"
#include "utils/make_error.h"

#include <SQLiteCpp/SQLiteCpp.h>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fmt/core.h>
#include <limits>
#include <optional>
#include <unordered_map>
#include <vector>

namespace lyra {

ConfigurationService::ConfigurationService(IDatabaseContext &db_context,
                                           const std::string &storage_root,
                                           AudioEngine *audio_engine)
    : m_db_context(db_context),
      m_storage_root(storage_root),
      m_audio_engine(audio_engine) {
    if (m_audio_engine) {
        m_audio_engine->set_config_downgrade_callback(
            [this](const std::string &category, const std::string &key, const nlohmann::json &value) {
                sync_runtime_downgrade(category, key, value);
            });
    }
    seed_defaults();
    load_config();
    apply_runtime_settings();
}

ConfigurationService::~ConfigurationService() {
    if (m_audio_engine) {
        m_audio_engine->set_config_downgrade_callback(nullptr);
    }
}

void ConfigurationService::sync_runtime_downgrade(const std::string &category,
                                                  const std::string &key,
                                                  const nlohmann::json &value) {
    const auto *spec = find_spec(category, key);
    if (!spec) {
        return;
    }

    {
        std::unique_lock<std::mutex> lock(m_mutex);
        if (m_is_updating && m_updating_thread_id != std::this_thread::get_id()) {
            m_cv.wait(lock, [this]() { return !m_is_updating; });
        }
    }

    if (m_audio_engine) {
        if (category == "audio") {
            if (key == "output_device_id" && value.is_string()) {
                if (m_audio_engine->get_output_device() != value.get<std::string>()) {
                    return;
                }
            } else if (key == "buffer_size_frames" && value.is_number_integer()) {
                if (static_cast<int>(m_audio_engine->get_buffer_size_frames()) != value.get<int>()) {
                    return;
                }
            } else if (key == "exclusive_mode" && value.is_boolean()) {
                if (m_audio_engine->get_exclusive_mode() != value.get<bool>()) {
                    return;
                }
            }
        }
    }

    std::unique_lock<std::mutex> lock(m_mutex);
    if (m_is_updating && m_updating_thread_id != std::this_thread::get_id()) {
        m_cv.wait(lock, [this]() { return !m_is_updating; });
    }

    spec->commit_value(value, *this);

    if (spec->is_persisted) {
        try {
            m_db_context.with_transaction([&]() {
                auto &db = m_db_context.get_db();
                SQLite::Statement stmt(
                    db,
                    "INSERT INTO System_Config (key, value, updated_at) "
                    "VALUES (?, ?, datetime('now')) "
                    "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = "
                    "datetime('now');");
                stmt.bind(1, spec->full_key);
                stmt.bind(2, spec->to_db_string(value));
                if (stmt.exec() == 0) {
                    throw std::runtime_error("Failed to update config key: " + spec->full_key);
                }
                stmt.reset();
            });
        } catch (...) {
        }
    }
}

const std::vector<SettingSpec> &ConfigurationService::get_specs() {
    static const std::vector<SettingSpec> specs = {
        // database.cache_size_kb
        {
            .category = "database",
            .key = "cache_size_kb",
            .full_key = "database.cache_size_kb",
            .type = SettingType::Int,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = std::to_string(DEFAULT_CACHE_SIZE_KB),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                int64_t v = val.get<int64_t>();
                if (v < MIN_CACHE_SIZE_KB) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.cache_size_kb must be at least 1024 KiB"});
                }
                if (v > std::numeric_limits<int>::max()) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.cache_size_kb exceeds maximum integer value"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    int64_t parsed = std::stoll(str, &idx);
                    if (idx != str.size() || parsed < MIN_CACHE_SIZE_KB || parsed > std::numeric_limits<int>::max()) {
                        return false;
                    }
                    svc.m_cache_size_kb = static_cast<int>(parsed);
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_cache_size_kb = DEFAULT_CACHE_SIZE_KB; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                return val.get<int>() != svc.m_cache_size_kb;
            },
            .to_db_string = [](const json &val) -> std::string {
                return std::to_string(val.get<int>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_cache_size_kb = val.get<int>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_cache_size(val.get<int>()); },
        },
        // database.mmap_size_bytes
        {
            .category = "database",
            .key = "mmap_size_bytes",
            .full_key = "database.mmap_size_bytes",
            .type = SettingType::Int64,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = std::to_string(DEFAULT_MMAP_SIZE_BYTES),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                int64_t v = val.get<int64_t>();
                if (v < MIN_MMAP_SIZE_BYTES) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.mmap_size_bytes cannot be negative"});
                }
                if (v > MAX_MMAP_SIZE_BYTES) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.mmap_size_bytes exceeds maximum allowed limit (100 GB)"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    int64_t parsed = std::stoll(str, &idx);
                    if (idx != str.size() || parsed < MIN_MMAP_SIZE_BYTES || parsed > MAX_MMAP_SIZE_BYTES) {
                        return false;
                    }
                    svc.m_mmap_size_bytes = parsed;
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_mmap_size_bytes = DEFAULT_MMAP_SIZE_BYTES; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                return val.get<int64_t>() != svc.m_mmap_size_bytes;
            },
            .to_db_string = [](const json &val) -> std::string {
                return std::to_string(val.get<int64_t>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_mmap_size_bytes = val.get<int64_t>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_mmap_size(val.get<int64_t>()); },
        },
        // database.busy_timeout_ms
        {
            .category = "database",
            .key = "busy_timeout_ms",
            .full_key = "database.busy_timeout_ms",
            .type = SettingType::Int,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = std::to_string(DEFAULT_BUSY_TIMEOUT_MS),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                int64_t v = val.get<int64_t>();
                if (v < MIN_BUSY_TIMEOUT_MS) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.busy_timeout_ms must be at least 1000 ms"});
                }
                if (v > std::numeric_limits<int>::max()) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "database.busy_timeout_ms exceeds maximum integer value"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    int64_t parsed = std::stoll(str, &idx);
                    if (idx != str.size() || parsed < MIN_BUSY_TIMEOUT_MS || parsed > std::numeric_limits<int>::max()) {
                        return false;
                    }
                    svc.m_busy_timeout_ms = static_cast<int>(parsed);
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_busy_timeout_ms = DEFAULT_BUSY_TIMEOUT_MS; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                return val.get<int>() != svc.m_busy_timeout_ms;
            },
            .to_db_string = [](const json &val) -> std::string {
                return std::to_string(val.get<int>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_busy_timeout_ms = val.get<int>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_busy_timeout(val.get<int>()); },
        },
        // database.wal_autocheckpoint
        {
            .category = "database",
            .key = "wal_autocheckpoint",
            .full_key = "database.wal_autocheckpoint",
            .type = SettingType::Int,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = std::to_string(DEFAULT_WAL_AUTOCHECKPOINT),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                int64_t v = val.get<int64_t>();
                if (v < MIN_WAL_AUTOCHECKPOINT) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         "database.wal_autocheckpoint must be at least 10 frames"});
                }
                if (v > std::numeric_limits<int>::max()) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         "database.wal_autocheckpoint exceeds maximum integer value"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    int64_t parsed = std::stoll(str, &idx);
                    if (idx != str.size() || parsed < MIN_WAL_AUTOCHECKPOINT || parsed > std::numeric_limits<int>::max()) {
                        return false;
                    }
                    svc.m_wal_autocheckpoint = static_cast<int>(parsed);
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_wal_autocheckpoint = DEFAULT_WAL_AUTOCHECKPOINT; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                return val.get<int>() != svc.m_wal_autocheckpoint;
            },
            .to_db_string = [](const json &val) -> std::string {
                return std::to_string(val.get<int>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_wal_autocheckpoint = val.get<int>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_wal_autocheckpoint(val.get<int>()); },
        },
        // audio.output_device_id
        {
            .category = "audio",
            .key = "output_device_id",
            .full_key = "audio.output_device_id",
            .type = SettingType::String,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = DEFAULT_OUTPUT_DEVICE_ID,
            .validate = [](const json &val, const ConfigurationService &svc) -> std::optional<json> {
                std::string dev = val.get<std::string>();
                if (dev.empty()) {
                    return ApiResponse::error(
                        {ErrorType::InvalidValue, "audio.output_device_id cannot be empty"});
                }
                bool is_custom = (svc.m_audio_engine && svc.m_audio_engine->is_custom_sink_set());
                if (!is_custom && !is_valid_audio_device_id(dev)) {
                    return ApiResponse::error(
                        {ErrorType::InvalidValue, "audio.output_device_id is unrecognized: " + dev});
                }
                if (!svc.m_audio_engine && !is_audio_device_available(dev)) {
                    return ApiResponse::error(
                        {ErrorType::InvalidValue, "Failed to set audio output device: " + dev});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                if (str.empty()) {
                    return false;
                }
                svc.m_output_device_id = str;
                return true;
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_output_device_id = DEFAULT_OUTPUT_DEVICE_ID; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                std::string dev = val.get<std::string>();
                std::string cur_dev =
                    svc.m_audio_engine ? svc.m_audio_engine->get_output_device() : svc.m_output_device_id;
                return dev != svc.m_output_device_id || dev != cur_dev;
            },
            .to_db_string = [](const json &val) -> std::string {
                return val.get<std::string>();
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_output_device_id = val.get<std::string>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_output_device(val.get<std::string>()); },
            .preflight = [](const json &val, ConfigurationService &svc) -> PreflightResult {
                if (!svc.m_audio_engine) {
                    return RollbackAction{};
                }
                std::string dev = val.get<std::string>();
                std::string old_dev = svc.m_audio_engine->get_output_device();
                if (!svc.m_audio_engine->set_output_device(dev)) {
                    return tl::unexpected(ApiResponse::error(
                        {ErrorType::InvalidValue, "Failed to set audio output device: " + dev}));
                }
                return [engine = svc.m_audio_engine, old_dev]() {
                    if (!engine->set_output_device(old_dev)) {
                        engine->restore_output_device(old_dev);
                    }
                };
            },
        },
        // audio.volume
        {
            .category = "audio",
            .key = "volume",
            .full_key = "audio.volume",
            .type = SettingType::Double,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = fmt::format("{:.1f}", DEFAULT_VOLUME),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                double v = val.get<double>();
                if (std::isnan(v) || !std::isfinite(v) || v < 0.0 || v > 1.0) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange, "audio.volume must be between 0.0 and 1.0"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    double parsed = std::stod(str, &idx);
                    if (idx != str.size() || std::isnan(parsed) || !std::isfinite(parsed) || parsed < 0.0 || parsed > 1.0) {
                        return false;
                    }
                    svc.m_volume = parsed;
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_volume = DEFAULT_VOLUME; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                double v = val.get<double>();
                double cur_vol =
                    svc.m_audio_engine ? static_cast<double>(svc.m_audio_engine->get_volume()) : svc.m_volume;
                return std::abs(v - svc.m_volume) >= 1e-4 || std::abs(v - cur_vol) >= 1e-4;
            },
            .to_db_string = [](const json &val) -> std::string {
                return fmt::format("{}", val.get<double>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_volume = val.get<double>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_volume(val.get<double>()); },
        },
        // audio.buffer_size_frames
        {
            .category = "audio",
            .key = "buffer_size_frames",
            .full_key = "audio.buffer_size_frames",
            .type = SettingType::Int,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = std::to_string(DEFAULT_BUFFER_SIZE_FRAMES),
            .validate = [](const json &val, const ConfigurationService &) -> std::optional<json> {
                int64_t v = val.get<int64_t>();
                if (v < MIN_BUFFER_SIZE_FRAMES || v > MAX_BUFFER_SIZE_FRAMES) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("audio.buffer_size_frames must be between {} and {} frames",
                                     MIN_BUFFER_SIZE_FRAMES, MAX_BUFFER_SIZE_FRAMES)});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                try {
                    size_t idx = 0;
                    int64_t parsed = std::stoll(str, &idx);
                    if (idx != str.size() || parsed < MIN_BUFFER_SIZE_FRAMES || parsed > MAX_BUFFER_SIZE_FRAMES) {
                        return false;
                    }
                    svc.m_buffer_size_frames = static_cast<int>(parsed);
                    return true;
                } catch (...) {
                    return false;
                }
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_buffer_size_frames = DEFAULT_BUFFER_SIZE_FRAMES; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                int v = val.get<int>();
                int cur = svc.m_audio_engine ? static_cast<int>(svc.m_audio_engine->get_buffer_size_frames())
                                             : svc.m_buffer_size_frames;
                return v != svc.m_buffer_size_frames || v != cur;
            },
            .to_db_string = [](const json &val) -> std::string {
                return std::to_string(val.get<int>());
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_buffer_size_frames = val.get<int>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_buffer_size_frames(val.get<int>()); },
            .preflight = [](const json &val, ConfigurationService &svc) -> PreflightResult {
                if (!svc.m_audio_engine) {
                    return RollbackAction{};
                }
                int frames = val.get<int>();
                uint32_t old_buffer_size = svc.m_audio_engine->get_buffer_size_frames();
                if (!svc.m_audio_engine->set_buffer_size_frames(static_cast<uint32_t>(frames))) {
                    return tl::unexpected(ApiResponse::error(
                        {ErrorType::InvalidValue,
                         "Failed to set audio buffer size frames: " + std::to_string(frames)}));
                }
                return [engine = svc.m_audio_engine, old_buffer_size]() {
                    engine->set_buffer_size_frames(old_buffer_size);
                };
            },
        },
        // audio.exclusive_mode
        {
            .category = "audio",
            .key = "exclusive_mode",
            .full_key = "audio.exclusive_mode",
            .type = SettingType::Bool,
            .is_persisted = true,
            .is_read_only = false,
            .default_string = DEFAULT_EXCLUSIVE_MODE ? "true" : "false",
            .validate = [](const json &, const ConfigurationService &) -> std::optional<json> {
                return std::nullopt;
            },
            .load_from_string = [](const std::string &str, ConfigurationService &svc) -> bool {
                if (str == "true") {
                    svc.m_exclusive_mode = true;
                    return true;
                } else if (str == "false") {
                    svc.m_exclusive_mode = false;
                    return true;
                }
                return false;
            },
            .reset_to_default = [](ConfigurationService &svc) { svc.m_exclusive_mode = DEFAULT_EXCLUSIVE_MODE; },
            .has_changed = [](const json &val, const ConfigurationService &svc) -> bool {
                bool v = val.get<bool>();
                bool cur = svc.m_audio_engine ? svc.m_audio_engine->get_exclusive_mode()
                                              : svc.m_exclusive_mode;
                return v != svc.m_exclusive_mode || v != cur;
            },
            .to_db_string = [](const json &val) -> std::string {
                return val.get<bool>() ? "true" : "false";
            },
            .commit_value = [](const json &val, ConfigurationService &svc) { svc.m_exclusive_mode = val.get<bool>(); },
            .apply = [](const json &val, ConfigurationService &svc) { svc.apply_exclusive_mode(val.get<bool>()); },
            .preflight = [](const json &val, ConfigurationService &svc) -> PreflightResult {
                if (!svc.m_audio_engine) {
                    return RollbackAction{};
                }
                bool exc = val.get<bool>();
                bool old_exclusive_mode = svc.m_audio_engine->get_exclusive_mode();
                if (!svc.m_audio_engine->set_exclusive_mode(exc)) {
                    return tl::unexpected(ApiResponse::error(
                        {ErrorType::InvalidValue, "Failed to set audio exclusive mode"}));
                }
                return [engine = svc.m_audio_engine, old_exclusive_mode]() {
                    engine->set_exclusive_mode(old_exclusive_mode);
                };
            },
        },
        // storage.storage_root
        {
            .category = "storage",
            .key = "storage_root",
            .full_key = "storage.storage_root",
            .type = SettingType::String,
            .is_persisted = false,
            .is_read_only = true,
            .default_string = "",
            .validate = [](const json &val, const ConfigurationService &svc) -> std::optional<json> {
                std::string req_root = val.get<std::string>();
                bool match = false;
                try {
                    match = (std::filesystem::weakly_canonical(req_root) ==
                             std::filesystem::weakly_canonical(svc.m_storage_root));
                } catch (...) {
                    match = (req_root == svc.m_storage_root);
                }
                if (!match) {
                    return ApiResponse::error(
                        {ErrorType::InvalidValue, "storage_root is read-only and cannot be modified"});
                }
                return std::nullopt;
            },
            .load_from_string = [](const std::string &, ConfigurationService &) -> bool {
                return true;
            },
            .reset_to_default = [](ConfigurationService &) {},
            .has_changed = [](const json &, const ConfigurationService &) -> bool {
                return false;
            },
            .to_db_string = [](const json &) -> std::string {
                return "";
            },
            .commit_value = [](const json &, ConfigurationService &) {},
            .apply = [](const json &, ConfigurationService &) {},
        },
    };
    return specs;
}

const SettingSpec *ConfigurationService::find_spec(const std::string &category,
                                                   const std::string &key) {
    for (const auto &spec : get_specs()) {
        if (spec.category == category && spec.key == key) {
            return &spec;
        }
    }
    return nullptr;
}

bool ConfigurationService::is_known_category(const std::string &category) {
    for (const auto &spec : get_specs()) {
        if (spec.category == category) {
            return true;
        }
    }
    return false;
}

void ConfigurationService::seed_defaults() {
    m_db_context.with_transaction([&]() {
        auto &db = m_db_context.get_db();
        SQLite::Statement stmt(db,
                               "INSERT OR IGNORE INTO System_Config (key, value) VALUES (?, ?);");
        for (const auto &spec : get_specs()) {
            if (!spec.is_persisted) {
                continue;
            }
            stmt.reset();
            stmt.bind(1, spec.full_key);
            stmt.bind(2, spec.default_string);
            stmt.exec();
        }
        stmt.reset();
    });
}

void ConfigurationService::load_config() {
    std::lock_guard<std::mutex> lock(m_mutex);
    auto &db = m_db_context.get_db();
    std::vector<std::pair<std::string, std::string>> keys_to_heal;

    std::unordered_map<std::string, std::string> kv;
    {
        SQLite::Statement query(db, "SELECT key, value FROM System_Config;");
        while (query.executeStep()) {
            kv.emplace(query.getColumn(0).getString(), query.getColumn(1).getString());
        }
        query.reset();
    }

    for (const auto &spec : get_specs()) {
        if (!spec.is_persisted) {
            continue;
        }

        auto it = kv.find(spec.full_key);
        if (it == kv.end()) {
            keys_to_heal.emplace_back(spec.full_key, spec.default_string);
            spec.reset_to_default(*this);
            continue;
        }

        bool ok = spec.load_from_string(it->second, *this);
        if (!ok) {
            keys_to_heal.emplace_back(spec.full_key, spec.default_string);
            spec.reset_to_default(*this);
        }
    }

    if (!keys_to_heal.empty()) {
        try {
            m_db_context.with_transaction([&]() {
                auto &db_tx = m_db_context.get_db();
                SQLite::Statement heal_stmt(
                    db_tx,
                    "INSERT INTO System_Config (key, value, updated_at) "
                    "VALUES (?, ?, datetime('now')) "
                    "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = "
                    "datetime('now');");
                for (const auto &[k, def_val] : keys_to_heal) {
                    heal_stmt.reset();
                    heal_stmt.bind(1, k);
                    heal_stmt.bind(2, def_val);
                    heal_stmt.exec();
                }
                heal_stmt.reset();
            });
        } catch (...) {
        }
    }
}

json ConfigurationService::get_config_json_unlocked() const {
    return json{
        {"storage", {{"storage_root", m_storage_root}}},
        {"database",
         {{"cache_size_kb", m_cache_size_kb},
          {"mmap_size_bytes", m_mmap_size_bytes},
          {"busy_timeout_ms", m_busy_timeout_ms},
          {"wal_autocheckpoint", m_wal_autocheckpoint}}},
        {"audio",
         {{"output_device_id", m_output_device_id},
          {"volume", m_volume},
          {"buffer_size_frames", m_buffer_size_frames},
          {"exclusive_mode", m_exclusive_mode}}}};
}

json ConfigurationService::get_config_json() const {
    int cache_size_kb;
    int64_t mmap_size_bytes;
    int busy_timeout_ms;
    int wal_autocheckpoint;
    std::string output_device_id;
    double volume;
    int buffer_size_frames;
    bool exclusive_mode;
    std::string storage_root;
    bool updating;
    AudioEngine *engine;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        cache_size_kb = m_cache_size_kb;
        mmap_size_bytes = m_mmap_size_bytes;
        busy_timeout_ms = m_busy_timeout_ms;
        wal_autocheckpoint = m_wal_autocheckpoint;
        output_device_id = m_output_device_id;
        volume = m_volume;
        buffer_size_frames = m_buffer_size_frames;
        exclusive_mode = m_exclusive_mode;
        storage_root = m_storage_root;
        updating = m_is_updating;
        engine = m_audio_engine;
    }

    if (engine && !updating) {
        output_device_id = engine->get_output_device();
        volume = static_cast<double>(engine->get_volume());
        buffer_size_frames = static_cast<int>(engine->get_buffer_size_frames());
        exclusive_mode = engine->get_exclusive_mode();
    }

    return json{
        {"storage", {{"storage_root", storage_root}}},
        {"database",
         {{"cache_size_kb", cache_size_kb},
          {"mmap_size_bytes", mmap_size_bytes},
          {"busy_timeout_ms", busy_timeout_ms},
          {"wal_autocheckpoint", wal_autocheckpoint}}},
        {"audio",
         {{"output_device_id", output_device_id},
          {"volume", volume},
          {"buffer_size_frames", buffer_size_frames},
          {"exclusive_mode", exclusive_mode}}}};
}

void ConfigurationService::apply_cache_size(int kb) {
    try {
        m_db_context.get_db().exec(fmt::format("PRAGMA cache_size = -{};", kb));
    } catch (...) {
    }
}

void ConfigurationService::apply_mmap_size(int64_t bytes) {
    try {
        m_db_context.get_db().exec(fmt::format("PRAGMA mmap_size = {};", bytes));
    } catch (...) {
    }
}

void ConfigurationService::apply_busy_timeout(int ms) {
    try {
        m_db_context.get_db().setBusyTimeout(ms);
    } catch (...) {
    }
}

void ConfigurationService::apply_wal_autocheckpoint(int frames) {
    try {
        m_db_context.get_db().exec(fmt::format("PRAGMA wal_autocheckpoint = {};", frames));
    } catch (...) {
    }
}

void ConfigurationService::apply_volume(double vol) {
    if (m_audio_engine) {
        m_audio_engine->set_volume(static_cast<float>(vol));
    }
}

void ConfigurationService::apply_output_device(const std::string &dev) {
    if (m_audio_engine) {
        if (m_audio_engine->get_output_device() == dev) {
            return;
        }
        m_audio_engine->set_output_device(dev);
    }
}

void ConfigurationService::apply_buffer_size_frames(int frames) {
    if (frames < MIN_BUFFER_SIZE_FRAMES || frames > MAX_BUFFER_SIZE_FRAMES) {
        return;
    }
    if (m_audio_engine) {
        if (m_audio_engine->get_buffer_size_frames() == static_cast<uint32_t>(frames)) {
            return;
        }
        m_audio_engine->set_buffer_size_frames(static_cast<uint32_t>(frames));
    }
}

void ConfigurationService::apply_exclusive_mode(bool exclusive) {
    if (m_audio_engine) {
        if (m_audio_engine->get_exclusive_mode() == exclusive) {
            return;
        }
        m_audio_engine->set_exclusive_mode(exclusive);
    }
}

void ConfigurationService::apply_database_settings() {
    int cache_size_kb;
    int64_t mmap_size_bytes;
    int wal_autocheckpoint;
    int busy_timeout_ms;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        cache_size_kb = m_cache_size_kb;
        mmap_size_bytes = m_mmap_size_bytes;
        wal_autocheckpoint = m_wal_autocheckpoint;
        busy_timeout_ms = m_busy_timeout_ms;
    }

    apply_cache_size(cache_size_kb);
    apply_mmap_size(mmap_size_bytes);
    apply_busy_timeout(busy_timeout_ms);
    apply_wal_autocheckpoint(wal_autocheckpoint);
}

void ConfigurationService::apply_audio_settings() {
    double volume;
    std::string output_device_id;
    int buffer_size_frames;
    bool exclusive_mode;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        volume = m_volume;
        output_device_id = m_output_device_id;
        buffer_size_frames = m_buffer_size_frames;
        exclusive_mode = m_exclusive_mode;
    }
    apply_volume(volume);
    if (m_audio_engine) {
        m_audio_engine->restore_output_device(output_device_id);
    }
    apply_buffer_size_frames(buffer_size_frames);
    apply_exclusive_mode(exclusive_mode);
}

void ConfigurationService::apply_runtime_settings() {
    apply_database_settings();
    apply_audio_settings();
}

tl::expected<json, json> ConfigurationService::update_config(const json &params) {
    if (!params.is_object()) {
        return tl::unexpected(ApiResponse::error(
            {ErrorType::InvalidCommandFormat,
             "'params' must be a JSON object, got " + std::string(params.type_name())}));
    }

    if (params.empty()) {
        return tl::unexpected(ApiResponse::error(
            {ErrorType::InvalidValue, "No settings provided to update"}));
    }

    // Check for unknown top-level sections (Anti-Phantom Settings)
    for (auto it = params.begin(); it != params.end(); ++it) {
        const std::string &section = it.key();
        if (!is_known_category(section)) {
            return tl::unexpected(ApiResponse::error(
                {ErrorType::InvalidValue,
                 "Unknown configuration category: '" + section + "' (phantom settings not allowed)"}));
        }
    }

    // Check sections are JSON objects
    for (auto it = params.begin(); it != params.end(); ++it) {
        if (!it.value().is_object()) {
            return tl::unexpected(ApiResponse::error(
                {ErrorType::InvalidValue, "'" + it.key() + "' must be a JSON object"}));
        }
    }

    // Check for unknown keys, null values, and count total provided keys
    size_t total_keys_provided = 0;
    for (auto it = params.begin(); it != params.end(); ++it) {
        const std::string &section = it.key();
        total_keys_provided += it.value().size();
        for (auto sec_it = it.value().begin(); sec_it != it.value().end(); ++sec_it) {
            const std::string &k = sec_it.key();
            const auto *spec = find_spec(section, k);
            if (!spec) {
                return tl::unexpected(ApiResponse::error(
                    {ErrorType::InvalidValue,
                     "Unknown " + section + " configuration key: '" + k + "' (phantom settings not allowed)"}));
            }
            if (sec_it.value().is_null()) {
                return tl::unexpected(ApiResponse::error(
                    {ErrorType::InvalidValue, "Value of '" + section + "." + k + "' cannot be null"}));
            }
        }
    }

    if (total_keys_provided == 0) {
        return tl::unexpected(ApiResponse::error(
            {ErrorType::InvalidValue, "No settings provided to update"}));
    }

    // Type validation
    for (auto it = params.begin(); it != params.end(); ++it) {
        const std::string &section = it.key();
        for (auto sec_it = it.value().begin(); sec_it != it.value().end(); ++sec_it) {
            const auto *spec = find_spec(section, sec_it.key());
            const auto &val = sec_it.value();

            bool type_valid = false;
            std::string expected_type_name;
            switch (spec->type) {
                case SettingType::Int:
                case SettingType::Int64:
                    type_valid = val.is_number_integer();
                    expected_type_name = "an integer";
                    break;
                case SettingType::Double:
                    type_valid = val.is_number();
                    expected_type_name = "a number";
                    break;
                case SettingType::String:
                    type_valid = val.is_string();
                    expected_type_name = "a string";
                    break;
                case SettingType::Bool:
                    type_valid = val.is_boolean();
                    expected_type_name = "a boolean";
                    break;
            }

            if (!type_valid) {
                return tl::unexpected(ApiResponse::error(
                    {ErrorType::InvalidValue,
                     "'" + spec->full_key + "' must be " + expected_type_name}));
            }
        }
    }

    std::unique_lock<std::mutex> lock(m_mutex);
    if (m_is_updating && m_updating_thread_id == std::this_thread::get_id()) {
        return tl::unexpected(ApiResponse::error(
            {ErrorType::OperationFailed, "Configuration update already in progress"}));
    }
    m_cv.wait(lock, [this]() { return !m_is_updating; });

    m_is_updating = true;
    m_updating_thread_id = std::this_thread::get_id();
    struct UpdatingGuard {
        ConfigurationService &svc;
        std::unique_lock<std::mutex> &lk;
        bool active{true};
        ~UpdatingGuard() {
            if (active) {
                if (!lk.owns_lock()) {
                    lk.lock();
                }
                svc.m_is_updating = false;
                svc.m_updating_thread_id = std::thread::id{};
                svc.m_cv.notify_all();
            }
        }
        void dismiss() {
            if (active) {
                if (!lk.owns_lock()) {
                    lk.lock();
                }
                svc.m_is_updating = false;
                svc.m_updating_thread_id = std::thread::id{};
                svc.m_cv.notify_all();
                active = false;
            }
        }
    } updating_guard{*this, lock};

    // Unlock m_mutex during validate loop to avoid holding m_mutex while calling
    // m_audio_engine or enumerating hardware devices.
    // m_is_updating is true, so other update_config calls are safely serialized.
    lock.unlock();

    // Value & boundary validation
    for (auto it = params.begin(); it != params.end(); ++it) {
        const std::string &section = it.key();
        for (auto sec_it = it.value().begin(); sec_it != it.value().end(); ++sec_it) {
            const auto *spec = find_spec(section, sec_it.key());
            auto err = spec->validate(sec_it.value(), *this);
            if (err) {
                lock.lock();
                updating_guard.dismiss();
                return tl::unexpected(*err);
            }
        }
    }

    lock.lock();

    std::vector<const SettingSpec *> changed_specs;
    std::vector<std::pair<std::string, std::string>> db_updates;

    // Check for changes and collect DB updates
    for (auto it = params.begin(); it != params.end(); ++it) {
        const std::string &section = it.key();
        for (auto sec_it = it.value().begin(); sec_it != it.value().end(); ++sec_it) {
            const auto *spec = find_spec(section, sec_it.key());
            if (spec && spec->has_changed(sec_it.value(), *this)) {
                changed_specs.push_back(spec);
                if (spec->is_persisted) {
                    db_updates.emplace_back(spec->full_key, spec->to_db_string(sec_it.value()));
                }
            }
        }
    }

    // If no values changed, return current config without writing to DB or invoking appliers
    if (changed_specs.empty()) {
        updating_guard.dismiss();
        lock.unlock();
        return get_config_json();
    }

    // Table-driven Pre-flight & LIFO Rollback
    std::vector<RollbackAction> rollback_stack;
    bool has_preflight = std::any_of(
        changed_specs.begin(), changed_specs.end(),
        [](const SettingSpec *s) { return static_cast<bool>(s->preflight); });

    if (has_preflight) {
        // Unlock m_mutex before pre-flight hardware reconfigurations to prevent lock-inversion deadlocks
        lock.unlock();

        for (const auto *spec : changed_specs) {
            if (spec->preflight) {
                const auto &val = params[spec->category][spec->key];
                auto res = spec->preflight(val, *this);
                if (!res) {
                    // Pre-flight failed: roll back all previously executed actions in reverse (LIFO) order
                    for (auto it = rollback_stack.rbegin(); it != rollback_stack.rend(); ++it) {
                        if (*it) (*it)();
                    }
                    lock.lock();
                    updating_guard.dismiss();
                    return tl::unexpected(res.error());
                }
                if (*res) {
                    rollback_stack.push_back(std::move(*res));
                }
            }
        }

        // Pre-flights succeeded: re-lock m_mutex to persist to DB and commit memory values
        lock.lock();
    }

    // Persist changed settings to SQLite
    if (!db_updates.empty()) {
        try {
            m_db_context.with_transaction([&]() {
                auto &db = m_db_context.get_db();
                SQLite::Statement stmt(
                    db,
                    "INSERT INTO System_Config (key, value, updated_at) "
                    "VALUES (?, ?, datetime('now')) "
                    "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = "
                    "datetime('now');");
                for (const auto &[key, val] : db_updates) {
                    stmt.reset();
                    stmt.bind(1, key);
                    stmt.bind(2, val);
                    if (stmt.exec() == 0) {
                        throw std::runtime_error("Failed to update config key: " + key);
                    }
                }
                stmt.reset();
            });
        } catch (const std::exception &e) {
            if (!rollback_stack.empty()) {
                lock.unlock();
                for (auto it = rollback_stack.rbegin(); it != rollback_stack.rend(); ++it) {
                    if (*it) (*it)();
                }
                lock.lock();
            }
            updating_guard.dismiss();
            return tl::unexpected(ApiResponse::error({ErrorType::DatabaseError, e.what()}));
        }
    }

    // Commit changed values into service state under lock
    for (const auto *spec : changed_specs) {
        spec->commit_value(params[spec->category][spec->key], *this);
    }

    lock.unlock();

    // Invoke fine-grained appliers only for settings without preflight (which were already reconfigured)
    for (const auto *spec : changed_specs) {
        if (!spec->preflight) {
            spec->apply(params[spec->category][spec->key], *this);
        }
    }

    lock.lock();
    updating_guard.dismiss();
    lock.unlock();

    return get_config_json();
}

} // namespace lyra
