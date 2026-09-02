// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'asset.dart';

export 'asset.dart';

/// Backward-compatible wrapper/subclass for [Asset] representing a low-level CAS blob.
class CasObject extends Asset {
  const CasObject({
    required String hash,
    required int sizeBytes,
    required super.mimeType,
    required super.createdAt,
    super.verified = true,
    super.assetType = 'audio',
  }) : super(fileHash: hash, fileSize: sizeBytes);

  /// Factory constructor to create a [CasObject] from an [Asset].
  factory CasObject.fromAsset(Asset asset) {
    return CasObject(
      hash: asset.fileHash,
      sizeBytes: asset.fileSize,
      mimeType: asset.mimeType,
      createdAt: asset.createdAt,
      verified: asset.verified,
      assetType: asset.assetType,
    );
  }

  /// Creates a [CasObject] instance from a JSON map with safe fallbacks.
  factory CasObject.fromJson(Map<String, dynamic> json) {
    return CasObject.fromAsset(Asset.fromJson(json));
  }
}
