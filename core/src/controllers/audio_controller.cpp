// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/audio.h"
#include "audio_controller.h"

namespace lyra {

using json = nlohmann::json;

AudioController::AudioController(IAudioRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> AudioController::create(Audio &audio) {
    return m_repo.insert(audio);
}

tl::expected<Audio, std::string> AudioController::get(const std::string &pcm_hash) {
    return m_repo.get(pcm_hash);
}

tl::expected<void, std::string> AudioController::update(const AudioUpdate &audio_update) {
    return m_repo.update(audio_update);
}

tl::expected<PaginatedResult<Audio>, std::string> AudioController::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return m_repo.list(offset, limit, search);
}

} // namespace lyra
