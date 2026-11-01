// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/core/models/waveform_data.dart';

void main() {
  group('WaveformData.resample', () {
    test('returns empty points when targetCount <= 0 or points is empty', () {
      final wfEmpty = const WaveformData(pcmHash: 'hash-empty', points: []);
      expect(wfEmpty.resample(10).points, isEmpty);

      final wfWithData = WaveformData.mock(pcmHash: 'hash-1', points: 20);
      expect(wfWithData.resample(0).points, isEmpty);
      expect(wfWithData.resample(-5).points, isEmpty);
    });

    test('returns identical instance when targetCount == points.length', () {
      final wf = WaveformData.mock(pcmHash: 'hash-same', points: 30);
      final resampled = wf.resample(30);
      expect(identical(wf, resampled), isTrue);
    });

    test(
      'downsamples accurately preserving peak min/max and averaging RMS energy',
      () {
        const srcPoints = [
          WaveformPoint(min: -0.2, max: 0.4, rms: 0.3),
          WaveformPoint(min: -0.8, max: 0.6, rms: 0.5),
          WaveformPoint(min: -0.1, max: 0.9, rms: 0.4),
          WaveformPoint(min: -0.5, max: 0.2, rms: 0.2),
        ];
        const wf = WaveformData(pcmHash: 'hash-down', points: srcPoints);

        final resampled = wf.resample(2);
        expect(resampled.points.length, 2);

        // Bucket 0 combines indices 0 and 1
        expect(resampled.points[0].min, closeTo(-0.8, 1e-5));
        expect(resampled.points[0].max, closeTo(0.6, 1e-5));
        final expectedRms0 = math.sqrt((0.3 * 0.3 + 0.5 * 0.5) / 2);
        expect(resampled.points[0].rms, closeTo(expectedRms0, 1e-5));

        // Bucket 1 combines indices 2 and 3
        expect(resampled.points[1].min, closeTo(-0.5, 1e-5));
        expect(resampled.points[1].max, closeTo(0.9, 1e-5));
        final expectedRms1 = math.sqrt((0.4 * 0.4 + 0.2 * 0.2) / 2);
        expect(resampled.points[1].rms, closeTo(expectedRms1, 1e-5));
      },
    );

    test('upsamples smoothly to higher targetCount', () {
      const srcPoints = [
        WaveformPoint(min: -0.3, max: 0.5, rms: 0.35),
        WaveformPoint(min: -0.7, max: 0.8, rms: 0.65),
      ];
      const wf = WaveformData(pcmHash: 'hash-up', points: srcPoints);

      final resampled = wf.resample(4);
      expect(resampled.points.length, 4);
      for (final pt in resampled.points) {
        expect(pt.min, lessThanOrEqualTo(0.0));
        expect(pt.max, greaterThanOrEqualTo(0.0));
        expect(pt.rms, greaterThan(0.0));
      }
    });

    test(
      'resamples realistic mock data across canonical density boundaries',
      () {
        final wf1000 = WaveformData.mock(
          pcmHash: 'canonical-test',
          points: 1000,
        );

        // Downsample to Inspector 0% density: 24 points
        final wf24 = wf1000.resample(24);
        expect(wf24.points.length, 24);

        // Downsample to Now Playing 0% density: 49 points
        final wf49 = wf1000.resample(49);
        expect(wf49.points.length, 49);

        // Upsample to Now Playing 100% density: 1200 points
        final wf1200 = wf1000.resample(1200);
        expect(wf1200.points.length, 1200);

        // Verify points list is unmodifiable
        expect(
          () => (wf24.points as List).add(
            const WaveformPoint(min: 0, max: 0, rms: 0),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'preserves unipolar DC-offset envelope without distorting min/max to zero',
      () {
        // Positive unipolar signal (e.g. envelope follower or DC offset):
        // min is always positive, max is higher
        const positiveDcPoints = [
          WaveformPoint(min: 0.25, max: 0.75, rms: 0.5),
          WaveformPoint(min: 0.35, max: 0.85, rms: 0.6),
          WaveformPoint(min: 0.20, max: 0.70, rms: 0.45),
          WaveformPoint(min: 0.30, max: 0.80, rms: 0.55),
        ];
        const wfPos = WaveformData(pcmHash: 'pos-dc', points: positiveDcPoints);
        final resampledPos = wfPos.resample(2);
        expect(resampledPos.points.length, 2);
        // Bucket 0 combines indices 0 and 1 -> min should be 0.25, max 0.85, NOT min 0.0
        expect(resampledPos.points[0].min, closeTo(0.25, 1e-5));
        expect(resampledPos.points[0].max, closeTo(0.85, 1e-5));
        // Bucket 1 combines indices 2 and 3 -> min should be 0.20, max 0.80, NOT min 0.0
        expect(resampledPos.points[1].min, closeTo(0.20, 1e-5));
        expect(resampledPos.points[1].max, closeTo(0.80, 1e-5));

        // Negative unipolar signal (min is negative, max is also negative):
        const negativeDcPoints = [
          WaveformPoint(min: -0.75, max: -0.25, rms: 0.5),
          WaveformPoint(min: -0.85, max: -0.35, rms: 0.6),
          WaveformPoint(min: -0.70, max: -0.20, rms: 0.45),
          WaveformPoint(min: -0.80, max: -0.30, rms: 0.55),
        ];
        const wfNeg = WaveformData(pcmHash: 'neg-dc', points: negativeDcPoints);
        final resampledNeg = wfNeg.resample(2);
        expect(resampledNeg.points.length, 2);
        // Bucket 0 combines indices 0 and 1 -> min should be -0.85, max -0.25, NOT max 0.0
        expect(resampledNeg.points[0].min, closeTo(-0.85, 1e-5));
        expect(resampledNeg.points[0].max, closeTo(-0.25, 1e-5));
        // Bucket 1 combines indices 2 and 3 -> min should be -0.80, max -0.20, NOT max 0.0
        expect(resampledNeg.points[1].min, closeTo(-0.80, 1e-5));
        expect(resampledNeg.points[1].max, closeTo(-0.20, 1e-5));
      },
    );
  });
}
