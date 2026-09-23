// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Single discrete temporal bucket representation in an audio waveform.
@immutable
class WaveformPoint {
  /// Minimum negative audio sample value in bucket (normalized between -1.0 and 0.0).
  final double min;

  /// Maximum positive audio sample value in bucket (normalized between 0.0 and 1.0).
  final double max;

  /// Root Mean Square (RMS) energy in bucket (normalized between 0.0 and 1.0).
  final double rms;

  const WaveformPoint({
    required this.min,
    required this.max,
    required this.rms,
  });

  /// Peak amplitude magnitude for symmetric bar rendering.
  double get amplitude => math.max(min.abs(), max.abs());

  /// Deserializes a [WaveformPoint] from a JSON object map.
  factory WaveformPoint.fromJson(Map<String, dynamic> json) {
    return WaveformPoint(
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 0.0,
      rms: (json['rms'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Serializes this [WaveformPoint] to a JSON object map.
  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'rms': rms};

  WaveformPoint copyWith({double? min, double? max, double? rms}) {
    return WaveformPoint(
      min: min ?? this.min,
      max: max ?? this.max,
      rms: rms ?? this.rms,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveformPoint &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max &&
          rms == other.rms;

  @override
  int get hashCode => Object.hash(min, max, rms);

  @override
  String toString() => 'WaveformPoint(min: $min, max: $max, rms: $rms)';
}

/// Downsampled audio waveform representation for timeline visualization and scrubbing.
@immutable
class WaveformData {
  /// Unique PCM stream content hash identifying the audio data.
  final String pcmHash;

  /// Discrete downsampled points along the audio stream.
  final List<WaveformPoint> points;

  const WaveformData({required this.pcmHash, required this.points});

  /// Number of points in this waveform sequence.
  int get pointsCount => points.length;

  /// Alias for points count.
  int get pointCount => points.length;

  /// Deserializes [WaveformData] from backend command responses or storage maps.
  ///
  /// Supports:
  /// 1. Backend schema from `audio.get_waveform`:
  ///    `{ "pcm_hash": "...", "points": 300, "peaks": [[-0.5, 0.6], ...], "rms": [0.4, ...] }`
  /// 2. Direct points list:
  ///    `{ "pcm_hash": "...", "points": [ { "min": -0.5, "max": 0.6, "rms": 0.4 }, ... ] }`
  factory WaveformData.fromJson(Map<String, dynamic> json) {
    final pcmHash =
        json['pcm_hash']?.toString() ?? json['pcmHash']?.toString() ?? '';

    // Format 1: Backend peaks and rms arrays
    if (json['peaks'] is List && json['rms'] is List) {
      final peaksList = json['peaks'] as List;
      final rmsList = json['rms'] as List;
      final int count = peaksList.length < rmsList.length
          ? peaksList.length
          : rmsList.length;

      final pointsList = <WaveformPoint>[];
      for (int i = 0; i < count; i++) {
        final peak = peaksList[i];
        final rmsVal = rmsList[i];

        double minVal = 0.0;
        double maxVal = 0.0;
        if (peak is List && peak.isNotEmpty) {
          minVal = (peak[0] as num?)?.toDouble() ?? 0.0;
          if (peak.length > 1) {
            maxVal = (peak[1] as num?)?.toDouble() ?? 0.0;
          }
        }

        final double rms = (rmsVal as num?)?.toDouble() ?? 0.0;
        pointsList.add(WaveformPoint(min: minVal, max: maxVal, rms: rms));
      }
      return WaveformData(
        pcmHash: pcmHash,
        points: List.unmodifiable(pointsList),
      );
    }

    // Format 2: Direct list of points
    if (json['points'] is List) {
      final pointsList = (json['points'] as List).map((p) {
        if (p is WaveformPoint) return p;
        if (p is Map) {
          return WaveformPoint.fromJson(Map<String, dynamic>.from(p));
        }
        return const WaveformPoint(min: 0.0, max: 0.0, rms: 0.0);
      }).toList();
      return WaveformData(
        pcmHash: pcmHash,
        points: List.unmodifiable(pointsList),
      );
    }

    // Fallback: If only integer points count was passed or points are missing
    final int count = (json['points'] as num?)?.toInt() ?? 120;
    return WaveformData.mock(pcmHash: pcmHash, points: count);
  }

  /// Serializes [WaveformData] into the standard Lyra backend schema.
  Map<String, dynamic> toJson() => {
    'pcm_hash': pcmHash,
    'points': points.length,
    'peaks': points.map((p) => [p.min, p.max]).toList(),
    'rms': points.map((p) => p.rms).toList(),
  };

  /// Generates deterministic dynamic waveform data with realistic musical dynamics
  /// (intro, verse, chorus peaks, breakdown, and outro) based on a string seed.
  static List<WaveformPoint> generateMockPoints({
    int count = 120,
    String seedString = 'lyra-audio-seed',
  }) {
    if (count <= 0) return const [];

    // Stable 32-bit FNV-1a / DJB2 variant hash from seedString
    int seed = 5381;
    for (int i = 0; i < seedString.length; i++) {
      seed = ((seed << 5) + seed + seedString.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final rng = math.Random(seed);

    final points = <WaveformPoint>[];
    for (int i = 0; i < count; i++) {
      final double t = count > 1 ? i / (count - 1) : 0.0;

      // Realistic musical energy envelope curve:
      // Intro -> Verse 1 -> Chorus 1 -> Breakdown -> Climax / Chorus 2 -> Outro
      double energy;
      if (t < 0.12) {
        // Intro: gradual swelling buildup (0.15 ~ 0.40)
        energy = 0.15 + 0.25 * (t / 0.12);
      } else if (t < 0.35) {
        // Verse 1: steady rhythmic cadence (0.45 ~ 0.65)
        final subT = (t - 0.12) / (0.35 - 0.12);
        energy = 0.45 + 0.15 * math.sin(subT * math.pi * 3);
      } else if (t < 0.52) {
        // Chorus 1: high energy punchy peaks (0.75 ~ 0.92)
        final subT = (t - 0.35) / (0.52 - 0.35);
        energy = 0.75 + 0.18 * math.sin(subT * math.pi * 4);
      } else if (t < 0.68) {
        // Breakdown / Bridge: atmospheric drop (0.28 ~ 0.48)
        final subT = (t - 0.52) / (0.68 - 0.52);
        energy = 0.38 + 0.12 * math.cos(subT * math.pi * 2);
      } else if (t < 0.88) {
        // Chorus 2 / Climax: maximum wall of sound (0.85 ~ 0.98)
        final subT = (t - 0.68) / (0.88 - 0.68);
        energy = 0.85 + 0.14 * math.sin(subT * math.pi * 5);
      } else {
        // Outro: gradual fade out to silence (0.90 -> 0.05)
        final subT = (t - 0.88) / (1.0 - 0.88);
        energy = (1.0 - subT) * 0.85 + 0.05;
      }

      // Add pseudo-random rhythmic variations & micro-peaks
      final beatPulse = 0.85 + 0.15 * math.sin(t * count * 0.75);
      final noise = 0.90 + 0.20 * rng.nextDouble();

      final currentAmp = (energy * beatPulse * noise).clamp(0.05, 1.0);
      final rms = (currentAmp * 0.70 + 0.04).clamp(0.02, 0.95);

      // Asymmetric peak limits (min <= 0.0, max >= 0.0)
      final posSkew = 0.92 + 0.16 * rng.nextDouble();
      final negSkew = 0.92 + 0.16 * rng.nextDouble();
      final maxPeak = (currentAmp * posSkew).clamp(0.08, 1.0);
      final minPeak = (-currentAmp * negSkew).clamp(-1.0, -0.08);

      points.add(WaveformPoint(min: minPeak, max: maxPeak, rms: rms));
    }
    return List.unmodifiable(points);
  }

  /// Factory constructing deterministic mock waveform data.
  factory WaveformData.mock({
    String pcmHash = 'mock-waveform-hash',
    int points = 120,
    int? seed,
  }) {
    final seedStr = seed != null ? '$pcmHash-$seed' : pcmHash;
    final generated = generateMockPoints(count: points, seedString: seedStr);
    return WaveformData(pcmHash: pcmHash, points: generated);
  }

  /// Factory constructing fallback low-amplitude waveform data.
  factory WaveformData.fallback({
    String pcmHash = 'fallback-waveform',
    int points = 120,
  }) {
    return WaveformData.mock(pcmHash: pcmHash, points: points);
  }

  WaveformData copyWith({String? pcmHash, List<WaveformPoint>? points}) {
    return WaveformData(
      pcmHash: pcmHash ?? this.pcmHash,
      points: points ?? this.points,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveformData &&
          runtimeType == other.runtimeType &&
          pcmHash == other.pcmHash &&
          listEquals(points, other.points);

  @override
  int get hashCode => Object.hash(pcmHash, Object.hashAll(points));

  @override
  String toString() =>
      'WaveformData(pcmHash: $pcmHash, points: ${points.length})';
}
