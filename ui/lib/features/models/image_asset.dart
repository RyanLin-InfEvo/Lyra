// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Image asset entity representing cover art, booklet, or artist imagery stored in CAS.
///
/// Corresponds to the C++ [Image] entity in `core/src/models/image.h` and
/// [CoverResolutionResult] in `core/src/services/cover_art_service.h`.
@immutable
class ImageAsset {
  /// Cryptographic SHA-256 hash identifying the image metadata record.
  final String imageHash;

  /// Underlying file asset hash stored in CAS.
  final String fileHash;

  /// Width of the image in pixels.
  final int width;

  /// Height of the image in pixels.
  final int height;

  /// Primary dominant hex color string (e.g. "#1E3A8A").
  final String dominantColor;

  /// Role of the image relative to its parent entity (e.g. 'front', 'back', 'artist_avatar', 'leaflet').
  final String? role;

  /// MIME type of the image container (e.g. 'image/jpeg', 'image/png', 'image/webp').
  final String? mimeType;

  /// Size of the image file in bytes.
  final int? fileSize;

  /// Optional color depth / format string (e.g. '24-bit RGB', '32-bit RGBA').
  final String? colorFormat;

  const ImageAsset({
    required this.imageHash,
    required this.fileHash,
    this.width = 0,
    this.height = 0,
    this.dominantColor = '',
    this.role,
    this.mimeType,
    this.fileSize,
    this.colorFormat,
  });

  /// Formatted color depth or format (e.g. '24-bit RGB', '32-bit RGBA').
  String get displayColorFormat {
    if (colorFormat != null && colorFormat!.isNotEmpty) return colorFormat!;
    final lowerMime = mimeType?.toLowerCase();
    if (lowerMime == 'image/png' || lowerMime == 'image/webp') {
      return '32-bit RGBA';
    }
    return '24-bit RGB';
  }

  /// Human-readable megapixels (e.g. "9.0 MP").
  String get megapixels {
    if (width <= 0 || height <= 0) return '—';
    final mp = (width * height) / 1000000.0;
    return '${mp.toStringAsFixed(1)} MP';
  }

  /// Formatted aspect ratio string (e.g. "1:1 (Square)", "2:1", "4:5").
  String get formattedAspectRatio {
    if (width <= 0 || height <= 0) return '—';
    if (width == height) return '1:1 (Square)';
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final d = gcd(width, height);
    final w = width ~/ d;
    final h = height ~/ d;
    if (w <= 16 && h <= 16) {
      return '$w:$h';
    }
    final ratio = width / height;
    return '${ratio.toStringAsFixed(2)}:1';
  }

  /// Aspect ratio of the image (width / height).
  double get aspectRatio => (width > 0 && height > 0) ? width / height : 1.0;

  /// Whether the image is square (e.g., standard 1:1 cover art).
  bool get isSquare => width > 0 && width == height;

  /// Shortened image hash for UI display (e.g., "7f83b1...9069").
  String get shortImageHash {
    if (imageHash.length <= 12) return imageHash;
    return '${imageHash.substring(0, 6)}...${imageHash.substring(imageHash.length - 4)}';
  }

  /// Shortened file hash for UI display (e.g., "e3b0c4...52b855").
  String get shortFileHash {
    if (fileHash.length <= 12) return fileHash;
    return '${fileHash.substring(0, 6)}...${fileHash.substring(fileHash.length - 4)}';
  }

  /// Parsed Flutter [Color] from [dominantColor], or null if unparseable.
  Color? get parsedDominantColor {
    if (dominantColor.isEmpty) return null;
    final hex = dominantColor.replaceFirst('#', '').trim();
    if (hex.isEmpty) return null;
    final val = int.tryParse(
      hex.length == 6 ? 'FF$hex' : (hex.length == 8 ? hex : ''),
      radix: 16,
    );
    return val != null ? Color(val) : null;
  }

  /// Creates an [ImageAsset] instance from a JSON map.
  factory ImageAsset.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    int? parseNullableInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return ImageAsset(
      imageHash: (json['image_hash'] ?? json['imageHash'])?.toString() ?? '',
      fileHash: (json['file_hash'] ?? json['fileHash'])?.toString() ?? '',
      width: parseInt(json['width']),
      height: parseInt(json['height']),
      dominantColor:
          (json['dominant_color'] ?? json['dominantColor'])?.toString() ?? '',
      role: json['role']?.toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'])?.toString(),
      fileSize: parseNullableInt(json['file_size'] ?? json['fileSize']),
      colorFormat: (json['color_format'] ?? json['colorFormat'])?.toString(),
    );
  }

  /// Converts this [ImageAsset] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'image_hash': imageHash,
      'file_hash': fileHash,
      'width': width,
      'height': height,
      'dominant_color': dominantColor,
      if (role != null) 'role': role,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
      if (colorFormat != null) 'color_format': colorFormat,
    };
  }

  /// Creates a copy of this [ImageAsset] with updated fields.
  ImageAsset copyWith({
    String? imageHash,
    String? fileHash,
    int? width,
    int? height,
    String? dominantColor,
    String? role,
    String? mimeType,
    int? fileSize,
    String? colorFormat,
  }) {
    return ImageAsset(
      imageHash: imageHash ?? this.imageHash,
      fileHash: fileHash ?? this.fileHash,
      width: width ?? this.width,
      height: height ?? this.height,
      dominantColor: dominantColor ?? this.dominantColor,
      role: role ?? this.role,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      colorFormat: colorFormat ?? this.colorFormat,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageAsset &&
        other.imageHash == imageHash &&
        other.fileHash == fileHash &&
        other.width == width &&
        other.height == height &&
        other.dominantColor == dominantColor &&
        other.role == role &&
        other.mimeType == mimeType &&
        other.fileSize == fileSize &&
        other.colorFormat == colorFormat;
  }

  @override
  int get hashCode => Object.hash(
    imageHash,
    fileHash,
    width,
    height,
    dominantColor,
    role,
    mimeType,
    fileSize,
    colorFormat,
  );

  @override
  String toString() {
    return 'ImageAsset('
        'imageHash: $imageHash, '
        'fileHash: $fileHash, '
        'width: $width, '
        'height: $height, '
        'dominantColor: $dominantColor, '
        'role: $role, '
        'mimeType: $mimeType, '
        'fileSize: $fileSize, '
        'colorFormat: $colorFormat'
        ')';
  }
}
