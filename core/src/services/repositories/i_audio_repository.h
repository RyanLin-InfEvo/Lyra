// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/audio.h"
#include "../../utils/paginated_result.h"
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class IAudioRepository {
  public:
    virtual ~IAudioRepository() = default;

    virtual tl::expected<void, std::string> insert(const Audio &audio) = 0;
    virtual tl::expected<void, std::string> update(const AudioUpdate &update_data) = 0;
    virtual tl::expected<Audio, std::string> get(const std::string &pcm_hash) = 0;
    virtual tl::expected<PaginatedResult<Audio>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;
    virtual tl::expected<std::vector<Audio>, std::string> get_related_versions(
        const std::string &pcm_hash) = 0;
};

} // namespace lyra
