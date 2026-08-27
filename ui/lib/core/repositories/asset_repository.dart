// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/asset.dart';
import 'base_repository.dart';

/// Domain repository for physical CAS file asset entities (Tier 4).
class AssetRepository extends BaseRepository {
  AssetRepository([super.bridge]);

  /// Lists file assets stored in CAS with optional pagination and search.
  Future<List<Asset>> listAssets({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListAssets', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Asset.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Retrieves a physical file asset by its cryptographic [fileHash].
  Future<Asset> getAsset(String fileHash) async {
    final response = await bridge.executeCommand('GetAsset', {
      'file_hash': fileHash,
    });
    final data = unpackMap(response);
    return Asset.fromJson(data);
  }

  /// Creates a new asset metadata entry in the CAS pool.
  Future<Asset> createAsset(Asset asset) async {
    final response = await bridge.executeCommand('CreateAsset', asset.toJson());
    final data = unpackMap(response);
    return Asset.fromJson(data);
  }

  /// Updates an existing asset metadata entry.
  Future<Asset> updateAsset(Asset asset) async {
    final response = await bridge.executeCommand('UpdateAsset', asset.toJson());
    final data = unpackMap(response);
    return Asset.fromJson(data);
  }

  /// Resolves the absolute filesystem path for a given resource.
  ///
  /// [resourceType] can be `'track'`, `'audio'`, or `'file'`.
  /// [identifier] represents the corresponding track ID, PCM hash, or file hash.
  Future<String> getResourcePath(String resourceType, String identifier) async {
    final Map<String, dynamic> params = {};
    final typeLower = resourceType.toLowerCase();

    if (typeLower == 'track' || typeLower == 'track_id') {
      params['track_id'] = identifier;
    } else if (typeLower == 'audio' ||
        typeLower == 'pcm' ||
        typeLower == 'pcm_hash') {
      params['pcm_hash'] = identifier;
    } else {
      params['file_hash'] = identifier;
    }

    final response = await bridge.executeCommand('GetResourcePath', params);
    final data = unpackMap(response);
    return (data['path'] as String?) ?? '';
  }
}
