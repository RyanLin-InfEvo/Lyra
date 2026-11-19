// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "source_data_controller.h"
#include "../utils/uuid_generator.h"

namespace lyra {

SourceDataController::SourceDataController(ISourceDataRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> SourceDataController::create(SourceData &source_data) {
    source_data.id = UuidGenerator::generate_v4();
    auto res = m_repo.insert(source_data);
    if (!res) {
        return res;
    }
    auto created = m_repo.get(source_data.id);
    if (!created) {
        return tl::unexpected(created.error());
    }
    source_data = *created;
    return {};
}

tl::expected<SourceData, std::string> SourceDataController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<SourceData, std::string> SourceDataController::get_by_asset(const std::string &file_hash) {
    return m_repo.get_by_asset(file_hash);
}

tl::expected<std::vector<SourceData>, std::string> SourceDataController::list_by_asset(
    const std::string &file_hash) {
    return m_repo.list_by_asset(file_hash);
}

} // namespace lyra
