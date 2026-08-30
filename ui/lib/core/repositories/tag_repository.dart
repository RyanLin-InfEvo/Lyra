// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/tag.dart';
import 'base_repository.dart';

/// Domain repository for tag and categorization entities.
class TagRepository extends BaseRepository {
  TagRepository([super.bridge]);

  /// Lists tags with optional pagination, search query, and category filters.
  Future<List<Tag>> listTags({
    int offset = 0,
    int limit = 50,
    String? search,
    String? category,
  }) async {
    final response = await bridge.executeCommand('tag.list', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Creates a new tag entity.
  Future<Tag> createTag(Tag tag) async {
    final response = await bridge.executeCommand('tag.create', tag.toJson());
    final data = unpackMap(response);
    return Tag.fromJson(data);
  }

  /// Assigns a tag to an entity (e.g., track, album, artist, work).
  Future<void> assignTag({
    required String entityId,
    required String tagId,
    String? entityType,
  }) async {
    await bridge.executeCommand('tag.assign', {
      'entity_id': entityId,
      'tag_id': tagId,
      if (entityType != null && entityType.isNotEmpty)
        'entity_type': entityType,
    });
  }

  /// Removes a tag association from an entity.
  Future<void> removeTag({
    required String entityId,
    required String tagId,
    String? entityType,
  }) async {
    await bridge.executeCommand('tag.remove', {
      'entity_id': entityId,
      'tag_id': tagId,
      if (entityType != null && entityType.isNotEmpty)
        'entity_type': entityType,
    });
  }

  /// Retrieves all tags associated with the specified [entityId].
  Future<List<Tag>> getEntityTags(String entityId, {String? entityType}) async {
    final response = await bridge.executeCommand('tag.get_entity_tags', {
      'entity_id': entityId,
      if (entityType != null && entityType.isNotEmpty)
        'entity_type': entityType,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
