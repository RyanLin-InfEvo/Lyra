// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/work.h"
#include "../utils/uuid_generator.h"
#include "work_controller.h"

namespace lyra {

using json = nlohmann::json;

WorkController::WorkController(IWorkRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> WorkController::create(Work &work) {
    work.id = UuidGenerator::generate_v4();
    return m_repo.insert(work);
}

tl::expected<Work, std::string> WorkController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> WorkController::update(const WorkUpdate &work_update) {
    return m_repo.update(work_update);
}

} // namespace lyra
