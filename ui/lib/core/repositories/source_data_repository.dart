// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/source_data.dart';
import 'base_repository.dart';

/// Domain repository for source provenance records.
class SourceDataRepository extends BaseRepository {
  SourceDataRepository([super.bridge]);

  /// Retrieves source provenance data for a physical file asset identified by [fileHash].
  Future<SourceData?> getSourceDataByAssetHash(String fileHash) async {
    try {
      final response = await bridge.executeCommand('source_data.get_by_asset', {
        'file_hash': fileHash,
      });
      final data = unpackMap(response);
      if (data.isEmpty) return null;
      return SourceData.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new source provenance data record.
  Future<SourceData> createSourceData(SourceData sourceData) async {
    final response = await bridge.executeCommand(
      'source_data.create',
      sourceData.toJson(),
    );
    final data = unpackMap(response);
    return SourceData.fromJson(data);
  }
}
