// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Physical file asset entity (Tier 4 of Lyra 4-tier audio model).
///
/// Represents an immutable file blob stored in Content Addressable Storage (CAS).
/// Corresponds to the C++ [Asset] entity in `core/src/models/asset.h`.
@immutable
class Asset {
  /// Cryptographic SHA-256 hash of the physical file content.
  final String fileHash;

  /// MIME type of the file container (e.g. "audio/flac", "audio/wav", "image/jpeg").
  final String mimeType;

  /// Logical asset category (e.g. "audio", "image", "lyrics", "cover").
  final String assetType;

  /// Physical file size in bytes.
  final int fileSize;

  /// Timestamp when the asset was ingested into the CAS pool.
  final DateTime createdAt;

  /// Server-verified CAS integrity flag.
  final bool verified;

  const Asset({
    required this.fileHash,
    this.mimeType = '',
    this.assetType = 'audio',
    this.fileSize = 0,
    required this.createdAt,
    this.verified = true,
  });

  /// Alias for backward compatibility with [CasObject].
  String get hash => fileHash;

  /// Alias for backward compatibility with [CasObject].
  int get sizeBytes => fileSize;

  /// Human-readable file size (e.g., "42.5 MB").
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Shortened CAS hash for concise UI display (e.g., "e3b0c442...b855").
  String get shortHash {
    if (fileHash.length <= 16) return fileHash;
    return '${fileHash.substring(0, 8)}...${fileHash.substring(fileHash.length - 6)}';
  }

  /// Alias for short hash.
  String get shortFileHash => shortHash;

  /// Creates an [Asset] instance from a JSON map.
  factory Asset.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    final rawDate = json['created_at'] ?? json['createdAt'];
    if (rawDate is DateTime) {
      parsedCreatedAt = rawDate;
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return defaultValue;
    }

    return Asset(
      fileHash:
          (json['file_hash'] ?? json['fileHash'] ?? json['hash'])?.toString() ??
          '',
      mimeType: (json['mime_type'] ?? json['mimeType'])?.toString() ?? '',
      assetType:
          (json['asset_type'] ?? json['assetType'])?.toString() ?? 'audio',
      fileSize: parseInt(
        json['file_size'] ??
            json['fileSize'] ??
            json['size_bytes'] ??
            json['sizeBytes'],
      ),
      createdAt: parsedCreatedAt,
      verified: parseBool(json['verified'], defaultValue: true),
    );
  }

  /// Converts this [Asset] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'file_hash': fileHash,
      'mime_type': mimeType,
      'asset_type': assetType,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
      'verified': verified,
    };
  }

  /// Creates a copy of this [Asset] with updated fields.
  Asset copyWith({
    String? fileHash,
    String? mimeType,
    String? assetType,
    int? fileSize,
    DateTime? createdAt,
    bool? verified,
  }) {
    return Asset(
      fileHash: fileHash ?? this.fileHash,
      mimeType: mimeType ?? this.mimeType,
      assetType: assetType ?? this.assetType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      verified: verified ?? this.verified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Asset &&
        other.fileHash == fileHash &&
        other.mimeType == mimeType &&
        other.assetType == assetType &&
        other.fileSize == fileSize &&
        other.createdAt == createdAt &&
        other.verified == verified;
  }

  @override
  int get hashCode =>
      Object.hash(fileHash, mimeType, assetType, fileSize, createdAt, verified);

  @override
  String toString() {
    return 'Asset('
        'fileHash: $fileHash, '
        'mimeType: $mimeType, '
        'assetType: $assetType, '
        'fileSize: $fileSize, '
        'createdAt: $createdAt, '
        'verified: $verified'
        ')';
  }
}
