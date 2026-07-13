// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_audio_repository.h"

namespace lyra {

class SqliteAudioRepository : public IAudioRepository {
  public:
    explicit SqliteAudioRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Audio &audio) override;
    tl::expected<void, std::string> update(const AudioUpdate &update_data) override;
    tl::expected<Audio, std::string> get(const std::string &pcm_hash) override;
    tl::expected<PaginatedResult<Audio>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
