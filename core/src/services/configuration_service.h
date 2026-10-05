// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <functional>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

using json = nlohmann::json;

class IDatabaseContext;
class AudioEngine;
class ConfigurationService;

enum class SettingType {
    Int,
    Int64,
    Double,
    String
};

struct SettingSpec {
    std::string category;
    std::string key;
    std::string full_key;
    SettingType type;
    bool is_persisted{true};
    bool is_read_only{false};
    std::string default_string;

    std::function<std::optional<json>(const json &val, const ConfigurationService &svc)> validate;
    std::function<bool(const std::string &str, ConfigurationService &svc)> load_from_string;
    std::function<void(ConfigurationService &svc)> reset_to_default;
    std::function<bool(const json &val, const ConfigurationService &svc)> has_changed;
    std::function<std::string(const json &val)> to_db_string;
    std::function<void(const json &val, ConfigurationService &svc)> commit_value;
    std::function<void(const json &val, ConfigurationService &svc)> apply;
};

class ConfigurationService {
  public:
    static constexpr int DEFAULT_CACHE_SIZE_KB = 131072; // 128 MiB
    static constexpr int MIN_CACHE_SIZE_KB = 1024;       // 1 MiB

    static constexpr int64_t DEFAULT_MMAP_SIZE_BYTES = 536870912; // 512 MiB
    static constexpr int64_t MIN_MMAP_SIZE_BYTES = 0;
    static constexpr int64_t MAX_MMAP_SIZE_BYTES = 100LL * 1024 * 1024 * 1024; // 100 GiB

    static constexpr int DEFAULT_BUSY_TIMEOUT_MS = 30000; // 30 sec
    static constexpr int MIN_BUSY_TIMEOUT_MS = 1000;      // 1 sec

    static constexpr int DEFAULT_WAL_AUTOCHECKPOINT = 1000;
    static constexpr int MIN_WAL_AUTOCHECKPOINT = 10;

    static constexpr double DEFAULT_VOLUME = 1.0;
    static constexpr const char *DEFAULT_OUTPUT_DEVICE_ID = "default";

    ConfigurationService(IDatabaseContext &db_context,
                         const std::string &storage_root,
                         AudioEngine *audio_engine = nullptr);
    ~ConfigurationService() = default;

    json get_config_json() const;
    tl::expected<json, json> update_config(const json &params);

    void apply_runtime_settings();
    void apply_database_settings();
    void apply_audio_settings();

    // Fine-grained per-key appliers
    void apply_cache_size(int kb);
    void apply_mmap_size(int64_t bytes);
    void apply_busy_timeout(int ms);
    void apply_wal_autocheckpoint(int frames);
    void apply_volume(double vol);
    void apply_output_device(const std::string &dev);

    const std::string &get_storage_root() const { return m_storage_root; }

    static const std::vector<SettingSpec> &get_specs();
    static const SettingSpec *find_spec(const std::string &category, const std::string &key);
    static bool is_known_category(const std::string &category);

  private:
    friend struct SettingSpec;

    IDatabaseContext &m_db_context;
    std::string m_storage_root;
    AudioEngine *m_audio_engine{nullptr};

    mutable std::mutex m_mutex;
    int m_cache_size_kb{DEFAULT_CACHE_SIZE_KB};
    int64_t m_mmap_size_bytes{DEFAULT_MMAP_SIZE_BYTES};
    int m_busy_timeout_ms{DEFAULT_BUSY_TIMEOUT_MS};
    int m_wal_autocheckpoint{DEFAULT_WAL_AUTOCHECKPOINT};
    std::string m_output_device_id{DEFAULT_OUTPUT_DEVICE_ID};
    double m_volume{DEFAULT_VOLUME};

    void seed_defaults();
    void load_config();
    json get_config_json_unlocked() const;
};

} // namespace lyra
