// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <string>

#include "../models/work.h"
#include "../services/database_manager.h"
#include "../utils/uuid_generator.h"
#include "work_controller.h"

namespace lyra {

std::optional<std::string> WorkController::create(Work &work) {
    work.id = UuidGenerator::generate_v4();
    return DatabaseManager::insert_work(work);
}

std::optional<Work> WorkController::get(const std::string &id) {
    return DatabaseManager::get_work(id);
}

std::optional<std::string> WorkController::update(const WorkUpdate &work_update) {
    return DatabaseManager::update_work(work_update);
}

} // namespace lyra
