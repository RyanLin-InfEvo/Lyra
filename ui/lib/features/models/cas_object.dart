// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Model representing a low-level Content Addressable Storage (CAS) blob.
class CasObject {
  final String hash;
  final int sizeBytes;
  final String mimeType;
  final DateTime createdAt;
  final bool verified;

  const CasObject({
    required this.hash,
    required this.sizeBytes,
    required this.mimeType,
    required this.createdAt,
    this.verified = true,
  });

  /// Human-readable file size (e.g., "42.5 MB").
  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Shortened CAS hash for concise UI display (e.g., "e3b0c44298fc...").
  String get shortHash {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }
}
