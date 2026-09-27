// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'asset.dart';

export 'asset.dart';

/// Backward-compatible wrapper/subclass for [Asset] representing a low-level CAS blob.
class CasObject extends Asset {
  /// Number of catalog references (tracks, albums, playlists) referencing this CAS blob.
  final int references;

  const CasObject({
    required String hash,
    required int sizeBytes,
    required super.mimeType,
    required super.createdAt,
    super.verified = true,
    super.assetType = 'audio',
    this.references = 1,
  }) : super(fileHash: hash, fileSize: sizeBytes);

  /// Factory constructor to create a [CasObject] from an [Asset].
  factory CasObject.fromAsset(Asset asset, {int references = 1}) {
    return CasObject(
      hash: asset.fileHash,
      sizeBytes: asset.fileSize,
      mimeType: asset.mimeType,
      createdAt: asset.createdAt,
      verified: asset.verified,
      assetType: asset.assetType,
      references: references,
    );
  }

  /// Creates a [CasObject] instance from a JSON map with safe fallbacks.
  factory CasObject.fromJson(Map<String, dynamic> json) {
    final asset = Asset.fromJson(json);
    final rawRefs =
        json['references'] ??
        json['reference_count'] ??
        json['referencesCount'] ??
        1;
    final refs = rawRefs is int
        ? rawRefs
        : (int.tryParse(rawRefs.toString()) ?? 1);
    return CasObject(
      hash: asset.fileHash,
      sizeBytes: asset.fileSize,
      mimeType: asset.mimeType,
      createdAt: asset.createdAt,
      verified: asset.verified,
      assetType: asset.assetType,
      references: refs,
    );
  }
}
