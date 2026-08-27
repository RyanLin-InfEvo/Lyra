// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/work.dart';
import 'base_repository.dart';

/// Domain repository for musical composition work entities (Tier 1).
class WorkRepository extends BaseRepository {
  WorkRepository([super.bridge]);

  /// Lists musical works with optional pagination and search filter.
  Future<List<Work>> listWorks({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListWorks', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Work.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Retrieves a specific musical work by its unique [id].
  Future<Work> getWork(String id) async {
    final response = await bridge.executeCommand('GetWork', {'id': id});
    final data = unpackMap(response);
    return Work.fromJson(data);
  }

  /// Queries musical works matching the specified [title].
  Future<List<Work>> getWorksByTitle(String title) async {
    final response = await bridge.executeCommand('GetWorksByTitle', {
      'title': title,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Work.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Creates a new musical work entity.
  Future<Work> createWork(Work work) async {
    final response = await bridge.executeCommand('CreateWork', work.toJson());
    final data = unpackMap(response);
    return Work.fromJson(data);
  }

  /// Updates an existing musical work entity.
  Future<Work> updateWork(Work work) async {
    final response = await bridge.executeCommand('UpdateWork', work.toJson());
    final data = unpackMap(response);
    return Work.fromJson(data);
  }
}
