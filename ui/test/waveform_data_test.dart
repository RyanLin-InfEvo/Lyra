// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/core/bridge/mock_lyra_bridge.dart';
import 'package:ui/core/models/waveform_data.dart';
import 'package:ui/core/repositories/audio_repository.dart';
import 'package:ui/features/services/mock_music_service.dart';

void main() {
  group('WaveformPoint Model', () {
    test('instantiates correctly and supports equality', () {
      const p1 = WaveformPoint(min: -0.65, max: 0.72, rms: 0.45);
      const p2 = WaveformPoint(min: -0.65, max: 0.72, rms: 0.45);
      const p3 = WaveformPoint(min: -0.10, max: 0.20, rms: 0.15);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1.amplitude, closeTo(0.72, 1e-4));
      expect(p1.toString(), contains('-0.65'));
    });

    test('serializes to and from JSON', () {
      final json = {'min': -0.80, 'max': 0.85, 'rms': 0.60};
      final point = WaveformPoint.fromJson(json);

      expect(point.min, closeTo(-0.80, 1e-4));
      expect(point.max, closeTo(0.85, 1e-4));
      expect(point.rms, closeTo(0.60, 1e-4));

      final serialized = point.toJson();
      expect(serialized['min'], point.min);
      expect(serialized['max'], point.max);
      expect(serialized['rms'], point.rms);
    });

    test('supports copyWith', () {
      const point = WaveformPoint(min: -0.5, max: 0.5, rms: 0.3);
      final updated = point.copyWith(max: 0.9, rms: 0.7);

      expect(updated.min, -0.5);
      expect(updated.max, 0.9);
      expect(updated.rms, 0.7);
    });
  });

  group('WaveformData Model', () {
    test('deserializes from backend schema (peaks and rms arrays)', () {
      final backendJson = {
        'pcm_hash':
            '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
        'points': 3,
        'peaks': [
          [-0.2, 0.3],
          [-0.8, 0.9],
          [-0.4, 0.5],
        ],
        'rms': [0.15, 0.70, 0.35],
      };

      final data = WaveformData.fromJson(backendJson);
      expect(
        data.pcmHash,
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      );
      expect(data.pointCount, 3);
      expect(data.pointsCount, 3);

      expect(data.points[0].min, closeTo(-0.2, 1e-4));
      expect(data.points[0].max, closeTo(0.3, 1e-4));
      expect(data.points[0].rms, closeTo(0.15, 1e-4));

      expect(data.points[1].min, closeTo(-0.8, 1e-4));
      expect(data.points[1].max, closeTo(0.9, 1e-4));
      expect(data.points[1].rms, closeTo(0.70, 1e-4));

      final serialized = data.toJson();
      expect(serialized['pcm_hash'], data.pcmHash);
      expect(serialized['points'], 3);
      expect(serialized['peaks'], hasLength(3));
      expect(serialized['rms'], hasLength(3));
    });

    test('deserializes from direct points map list', () {
      final directJson = {
        'pcmHash': 'custom-hash',
        'points': [
          {'min': -0.1, 'max': 0.1, 'rms': 0.05},
          {'min': -0.9, 'max': 0.9, 'rms': 0.85},
        ],
      };

      final data = WaveformData.fromJson(directJson);
      expect(data.pcmHash, 'custom-hash');
      expect(data.points.length, 2);
      expect(data.points[1].max, closeTo(0.9, 1e-4));
    });

    test('generates realistic deterministic musical dynamics envelope', () {
      final points = WaveformData.generateMockPoints(
        count: 120,
        seedString: 'test-track-seed',
      );
      expect(points.length, 120);

      // Verify all points have valid physical bounds
      for (final p in points) {
        expect(p.min, lessThanOrEqualTo(0.0));
        expect(p.min, greaterThanOrEqualTo(-1.0));
        expect(p.max, greaterThanOrEqualTo(0.0));
        expect(p.max, lessThanOrEqualTo(1.0));
        expect(p.rms, greaterThanOrEqualTo(0.0));
        expect(p.rms, lessThanOrEqualTo(1.0));
      }

      // Check musical progression:
      // Intro (index 5) should have lower energy than Chorus 1 (index 50)
      final introAmp = points[5].amplitude;
      final chorusAmp = points[50].amplitude;
      expect(chorusAmp, greaterThan(introAmp));

      // Outro (last point) should fade down
      final outroAmp = points.last.amplitude;
      expect(outroAmp, lessThan(chorusAmp));
    });

    test('mock factory is deterministic with same seed', () {
      final wf1 = WaveformData.mock(pcmHash: 'hotel-california', points: 60);
      final wf2 = WaveformData.mock(pcmHash: 'hotel-california', points: 60);
      final wfDiff = WaveformData.mock(pcmHash: 'so-what', points: 60);

      expect(wf1, equals(wf2));
      expect(wf1.hashCode, equals(wf2.hashCode));
      expect(wf1.points.first.max, equals(wf2.points.first.max));
      expect(wf1, isNot(equals(wfDiff)));
    });
  });

  group('MockMusicService Waveform Integration', () {
    test(
      'getWaveform returns deterministic dynamic waveform and caches results',
      () async {
        final service = MockMusicService();

        final wf1 = await service.getWaveform('trk-001', points: 100);
        expect(wf1.points.length, 100);

        final wf2 = await service.getWaveform('trk-001', points: 100);
        // Cache hit returns identical instance
        expect(identical(wf1, wf2), isTrue);

        final wfOther = await service.getWaveform('trk-002', points: 100);
        expect(wfOther.pcmHash, isNot(equals(wf1.pcmHash)));
      },
    );
  });

  group('AudioRepository Waveform Integration', () {
    test('queries audio.get_waveform with track_id or pcm_hash', () async {
      final bridge = MockLyraBridge();
      final repo = AudioRepository(bridge);

      // Register mock response for audio.get_waveform
      bridge.registerMockHandler('audio.get_waveform', (params) async {
        final pcmHash = params['pcm_hash'] ?? params['track_id'];
        final pts = params['points'] ?? 120;
        return {
          'code': 200,
          'status': 'success',
          'data': {
            'pcm_hash': pcmHash,
            'points': pts,
            'peaks': List.generate(pts as int, (_) => [-0.5, 0.5]),
            'rms': List.generate(pts, (_) => 0.35),
          },
        };
      });

      // 1. Query with track ID
      final wfTrack = await repo.getWaveform('trk-100', points: 80);
      expect(wfTrack.pcmHash, 'trk-100');
      expect(wfTrack.points.length, 80);

      // 2. Query with 64-char hex PCM hash
      const hexHash =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final wfHash = await repo.getWaveform(hexHash, points: 50);
      expect(wfHash.pcmHash, hexHash);
      expect(wfHash.points.length, 50);
    });
  });
}
