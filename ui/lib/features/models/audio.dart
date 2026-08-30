// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Decoded raw audio stream entity (Tier 3 of Lyra 4-tier audio model).
///
/// Represents bit-perfect decoded PCM audio stream properties.
/// Corresponds to the C++ [Audio] entity in `core/src/models/audio.h`.
@immutable
class Audio {
  /// Cryptographic SHA-256 hash of the decoded raw PCM stream.
  final String pcmHash;

  /// Parent file CAS hash from which this audio stream was decoded.
  final String parentHash;

  /// Quality score metric computed by the ingestion pipeline (0-100).
  final int qualityScore;

  /// Bit resolution depth (e.g. 16, 24, 32).
  final int bitDepth;

  /// Sampling frequency in Hz (e.g. 44100, 48000, 96000, 192000).
  final int sampleRate;

  /// Number of audio channels (e.g. 1 for mono, 2 for stereo, 6 for 5.1).
  final int channels;

  /// Duration of the audio stream in milliseconds.
  final double durationMs;

  /// Integrated loudness measured according to ITU-R BS.1770 (in LUFS).
  final double integratedLoudness;

  /// Maximum true peak level (in dBFS).
  final double truePeak;

  const Audio({
    required this.pcmHash,
    this.parentHash = '',
    this.qualityScore = 0,
    this.bitDepth = 0,
    this.sampleRate = 0,
    this.channels = 0,
    this.durationMs = 0.0,
    this.integratedLoudness = 0.0,
    this.truePeak = 0.0,
  });

  /// Backward-compatible [Duration] accessor.
  Duration get duration => Duration(milliseconds: durationMs.round());

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

  /// Shortened PCM hash for concise UI display (e.g., "e3b0...b855").
  String get shortPcmHash {
    if (pcmHash.length <= 12) return pcmHash;
    return '${pcmHash.substring(0, 6)}...${pcmHash.substring(pcmHash.length - 4)}';
  }

  /// Formatted duration in mm:ss format.
  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Creates an [Audio] instance from a JSON map.
  factory Audio.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    double parseDouble(dynamic val, {double defaultValue = 0.0}) {
      if (val is double) return val;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    double parsedDurationMs = 0.0;
    final rawDuration =
        json['duration_ms'] ?? json['durationMs'] ?? json['duration'];
    if (rawDuration != null) {
      if (rawDuration is num) {
        final val = rawDuration.toDouble();
        // If duration is passed as seconds (< 10000), convert to milliseconds
        parsedDurationMs =
            (val > 0 && val < 10000 && !json.containsKey('duration_ms'))
            ? val * 1000.0
            : val;
      } else if (rawDuration is String) {
        parsedDurationMs = double.tryParse(rawDuration) ?? 0.0;
      }
    }

    return Audio(
      pcmHash: (json['pcm_hash'] ?? json['pcmHash'])?.toString() ?? '',
      parentHash: (json['parent_hash'] ?? json['parentHash'])?.toString() ?? '',
      qualityScore: parseInt(json['quality_score'] ?? json['qualityScore']),
      bitDepth: parseInt(json['bit_depth'] ?? json['bitDepth']),
      sampleRate: parseInt(json['sample_rate'] ?? json['sampleRate']),
      channels: parseInt(json['channels']),
      durationMs: parsedDurationMs,
      integratedLoudness: parseDouble(
        json['integrated_loudness'] ?? json['integratedLoudness'],
      ),
      truePeak: parseDouble(json['true_peak'] ?? json['truePeak']),
    );
  }

  /// Converts this [Audio] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'pcm_hash': pcmHash,
      'parent_hash': parentHash,
      'quality_score': qualityScore,
      'bit_depth': bitDepth,
      'sample_rate': sampleRate,
      'channels': channels,
      'duration_ms': durationMs,
      'integrated_loudness': integratedLoudness,
      'true_peak': truePeak,
    };
  }

  /// Creates a copy of this [Audio] with updated fields.
  Audio copyWith({
    String? pcmHash,
    String? parentHash,
    int? qualityScore,
    int? bitDepth,
    int? sampleRate,
    int? channels,
    double? durationMs,
    double? integratedLoudness,
    double? truePeak,
  }) {
    return Audio(
      pcmHash: pcmHash ?? this.pcmHash,
      parentHash: parentHash ?? this.parentHash,
      qualityScore: qualityScore ?? this.qualityScore,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      durationMs: durationMs ?? this.durationMs,
      integratedLoudness: integratedLoudness ?? this.integratedLoudness,
      truePeak: truePeak ?? this.truePeak,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Audio &&
        other.pcmHash == pcmHash &&
        other.parentHash == parentHash &&
        other.qualityScore == qualityScore &&
        other.bitDepth == bitDepth &&
        other.sampleRate == sampleRate &&
        other.channels == channels &&
        other.durationMs == durationMs &&
        other.integratedLoudness == integratedLoudness &&
        other.truePeak == truePeak;
  }

  @override
  int get hashCode => Object.hash(
    pcmHash,
    parentHash,
    qualityScore,
    bitDepth,
    sampleRate,
    channels,
    durationMs,
    integratedLoudness,
    truePeak,
  );

  @override
  String toString() {
    return 'Audio('
        'pcmHash: $pcmHash, '
        'parentHash: $parentHash, '
        'qualityScore: $qualityScore, '
        'bitDepth: $bitDepth, '
        'sampleRate: $sampleRate, '
        'channels: $channels, '
        'durationMs: $durationMs, '
        'integratedLoudness: $integratedLoudness, '
        'truePeak: $truePeak'
        ')';
  }
}
