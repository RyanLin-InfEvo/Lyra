// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Audiophile music track model with Content Addressable Storage (CAS) integration.
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String format; // FLAC, WAV, AAC, etc.
  final int sampleRate; // in Hz, e.g. 96000, 192000, 44100
  final int bitDepth; // 16, 24, 32
  final String casHash; // SHA-256 Content Address
  final bool verified; // Server-verified CAS integrity

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.format,
    required this.sampleRate,
    required this.bitDepth,
    required this.casHash,
    this.verified = true,
  });

  /// Formatted duration in mm:ss format.
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Formatted audio resolution string (e.g., "Hi-Res 24-bit/96kHz" or "16-bit/44.1kHz").
  String get formattedQuality {
    final khz = (sampleRate / 1000).toStringAsFixed(
      sampleRate % 1000 == 0 ? 0 : 1,
    );
    if (bitDepth >= 24 || sampleRate > 48000) {
      return 'Hi-Res $bitDepth-bit/${khz}kHz';
    }
    return '$bitDepth-bit/${khz}kHz';
  }

  /// Shortened CAS hash for concise UI display (e.g., "e3b0...b855").
  String get shortCasHash {
    if (casHash.length <= 12) return casHash;
    return '${casHash.substring(0, 6)}...${casHash.substring(casHash.length - 4)}';
  }
}
