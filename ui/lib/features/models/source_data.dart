// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Source provenance entity recording the origin and ingestion context of audio assets.
///
/// Corresponds to the C++ [SourceData] entity in `core/src/models/source_data.h`.
@immutable
class SourceData {
  /// Unique identifier (UUID) of the source data record.
  final String id;

  /// Cryptographic SHA-256 hash of the associated physical file asset.
  final String fileHash;

  /// Source media or acquisition type (e.g. 'cd_rip', 'vinyl_rip', 'digital_download', 'tape').
  final String sourceType;

  /// Original filesystem path from which the file was ingested.
  final String originalPath;

  /// Timestamp when this source record was created.
  final DateTime createdAt;

  /// Curator or ingestion notes (e.g. drive model, EAC log status, lineage).
  final String note;

  const SourceData({
    required this.id,
    required this.fileHash,
    this.sourceType = '',
    this.originalPath = '',
    required this.createdAt,
    this.note = '',
  });

  /// Shortened file hash for UI display (e.g., "7f83b165...b855").
  String get shortFileHash {
    if (fileHash.length <= 16) return fileHash;
    return '${fileHash.substring(0, 8)}...${fileHash.substring(fileHash.length - 6)}';
  }

  /// Whether any curator note is attached.
  bool get hasNote => note.isNotEmpty;

  /// Creates a [SourceData] instance from a JSON map.
  factory SourceData.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    final rawDate = json['created_at'] ?? json['createdAt'];
    if (rawDate is DateTime) {
      parsedCreatedAt = rawDate;
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return SourceData(
      id: json['id'] as String? ?? '',
      fileHash:
          (json['file_hash'] ?? json['fileHash'] ?? json['hash']) as String? ??
          '',
      sourceType: (json['source_type'] ?? json['sourceType']) as String? ?? '',
      originalPath:
          (json['original_path'] ?? json['originalPath']) as String? ?? '',
      createdAt: parsedCreatedAt,
      note: json['note'] as String? ?? '',
    );
  }

  /// Converts this [SourceData] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_hash': fileHash,
      'source_type': sourceType,
      'original_path': originalPath,
      'created_at': createdAt.toIso8601String(),
      'note': note,
    };
  }

  /// Creates a copy of this [SourceData] with updated fields.
  SourceData copyWith({
    String? id,
    String? fileHash,
    String? sourceType,
    String? originalPath,
    DateTime? createdAt,
    String? note,
  }) {
    return SourceData(
      id: id ?? this.id,
      fileHash: fileHash ?? this.fileHash,
      sourceType: sourceType ?? this.sourceType,
      originalPath: originalPath ?? this.originalPath,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SourceData &&
        other.id == id &&
        other.fileHash == fileHash &&
        other.sourceType == sourceType &&
        other.originalPath == originalPath &&
        other.createdAt == createdAt &&
        other.note == note;
  }

  @override
  int get hashCode =>
      Object.hash(id, fileHash, sourceType, originalPath, createdAt, note);

  @override
  String toString() {
    return 'SourceData('
        'id: $id, '
        'fileHash: $fileHash, '
        'sourceType: $sourceType, '
        'originalPath: $originalPath, '
        'createdAt: $createdAt, '
        'note: $note'
        ')';
  }
}
