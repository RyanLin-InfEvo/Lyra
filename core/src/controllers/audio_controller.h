// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/audio.h"
#include "../services/repositories/i_audio_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class AudioController {
  public:
    explicit AudioController(IAudioRepository &repo);

    tl::expected<void, std::string> create(Audio &audio);
    tl::expected<Audio, std::string> get(const std::string &pcm_hash);
    tl::expected<void, std::string> update(const AudioUpdate &audio_update);
    tl::expected<PaginatedResult<Audio>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);

  private:
    IAudioRepository &m_repo;
};

} // namespace lyra
