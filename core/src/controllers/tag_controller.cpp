// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "tag_controller.h"
#include "../utils/uuid_generator.h"

namespace lyra {

TagController::TagController(ITagRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> TagController::create(Tag &tag) {
    tag.id = UuidGenerator::generate_v4();
    if (tag.category.empty()) {
        tag.category = "general";
    }
    auto res = m_repo.insert(tag);
    if (!res) {
        return res;
    }
    auto created = m_repo.get(tag.id);
    if (created) {
        tag = *created;
    }
    return {};
}

tl::expected<Tag, std::string> TagController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> TagController::delete_tag(const std::string &id) {
    return m_repo.delete_tag(id);
}

tl::expected<PaginatedResult<Tag>, std::string> TagController::list(
    int offset,
    int limit,
    const std::optional<std::string> &search,
    const std::optional<std::string> &category) {
    return m_repo.list(offset, limit, search, category);
}

tl::expected<void, std::string> TagController::assign_to_entity(
    const std::string &entity_id,
    const std::string &tag_id,
    const std::optional<std::string> &entity_type) {
    return m_repo.assign_to_entity(entity_id, tag_id, entity_type);
}

tl::expected<void, std::string> TagController::remove_from_entity(
    const std::string &entity_id,
    const std::string &tag_id,
    const std::optional<std::string> &entity_type) {
    return m_repo.remove_from_entity(entity_id, tag_id, entity_type);
}

tl::expected<std::vector<Tag>, std::string> TagController::get_entity_tags(
    const std::string &entity_id,
    const std::optional<std::string> &entity_type) {
    return m_repo.get_entity_tags(entity_id, entity_type);
}

} // namespace lyra
