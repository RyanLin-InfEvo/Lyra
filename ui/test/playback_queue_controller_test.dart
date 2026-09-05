// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';

void main() {
  const track1 = Track(
    id: 't-1',
    title: 'First Track',
    artistName: 'Artist 1',
    albumTitle: 'Album 1',
    durationMs: 180000, // 3 minutes
  );

  const track2 = Track(
    id: 't-2',
    title: 'Second Track',
    artistName: 'Artist 2',
    albumTitle: 'Album 2',
    durationMs: 240000, // 4 minutes
  );

  const track3 = Track(
    id: 't-3',
    title: 'Third Track',
    artistName: 'Artist 3',
    albumTitle: 'Album 3',
    durationMs: 120000, // 2 minutes
  );

  group('PlaybackQueueController - Initial State', () {
    test('initializes with empty queue and default values', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      expect(controller.queue, isEmpty);
      expect(controller.currentIndex, equals(-1));
      expect(controller.currentTrack, isNull);
      expect(controller.isPlaying, isFalse);
      expect(controller.shuffleMode, isFalse);
      expect(controller.repeatMode, equals(RepeatMode.off));
      expect(controller.positionNotifier.value, equals(Duration.zero));
      expect(controller.duration, equals(Duration.zero));
    });
  });

  group('PlaybackQueueController - Play & Context Queue', () {
    test('play(track) sets queue with single track and starts playing', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1);

      expect(controller.queue, equals([track1]));
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.isPlaying, isTrue);
      expect(controller.duration, equals(const Duration(minutes: 3)));
    });

    test('play(track, contextQueue) sets entire queue and correct index', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track2, contextQueue: [track1, track2, track3]);

      expect(controller.queue, equals([track1, track2, track3]));
      expect(controller.currentIndex, equals(1));
      expect(controller.currentTrack, equals(track2));
      expect(controller.isPlaying, isTrue);
      expect(controller.duration, equals(const Duration(minutes: 4)));
    });

    test('play(track, contextQueue) inserts track if not in contextQueue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track2, track3]);

      expect(controller.queue.first, equals(track1));
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.queue.length, equals(3));
    });

    test('pause, resume, and togglePlay work properly', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1);
      expect(controller.isPlaying, isTrue);

      controller.pause();
      expect(controller.isPlaying, isFalse);

      controller.resume();
      expect(controller.isPlaying, isTrue);

      controller.togglePlay();
      expect(controller.isPlaying, isFalse);

      controller.togglePlay();
      expect(controller.isPlaying, isTrue);
    });

    test('togglePlay when no track active starts first track in queue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.addToQueue(track1);
      controller.addToQueue(track2);
      expect(controller.isPlaying, isFalse);

      controller.togglePlay();
      expect(controller.isPlaying, isTrue);
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
    });
  });

  group('PlaybackQueueController - Repeat Modes (next and previous)', () {
    test('RepeatMode.off: next advances, stops at end of queue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2]);
      expect(controller.repeatMode, equals(RepeatMode.off));
      expect(controller.currentIndex, equals(0));

      controller.next();
      expect(controller.currentIndex, equals(1));
      expect(controller.currentTrack, equals(track2));
      expect(controller.isPlaying, isTrue);

      // Next at the end of queue under RepeatMode.off
      controller.next();
      expect(controller.currentIndex, equals(1));
      expect(controller.isPlaying, isFalse);
      expect(controller.positionNotifier.value, equals(Duration.zero));
    });

    test(
      'RepeatMode.off: previous seeks to 0:00 or goes to previous track',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        controller.play(track2, contextQueue: [track1, track2]);
        expect(controller.currentIndex, equals(1));

        // > 3 seconds in: seeks to start of current track
        controller.seek(const Duration(seconds: 10));
        controller.previous();
        expect(controller.currentIndex, equals(1));
        expect(controller.positionNotifier.value, equals(Duration.zero));

        // <= 3 seconds in: plays previous track
        controller.seek(const Duration(seconds: 2));
        controller.previous();
        expect(controller.currentIndex, equals(0));
        expect(controller.currentTrack, equals(track1));

        // At start of queue (index 0) with <= 3s: seeks to start of track 1
        controller.seek(const Duration(seconds: 1));
        controller.previous();
        expect(controller.currentIndex, equals(0));
        expect(controller.positionNotifier.value, equals(Duration.zero));
      },
    );

    test('RepeatMode.all: next and previous wrap around queue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track2, contextQueue: [track1, track2]);
      controller.setRepeatMode(RepeatMode.all);
      expect(controller.repeatMode, equals(RepeatMode.all));

      // At last track: next wraps to first track
      controller.next();
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.isPlaying, isTrue);

      // At first track with <= 3s: previous wraps to last track
      controller.previous();
      expect(controller.currentIndex, equals(1));
      expect(controller.currentTrack, equals(track2));
      expect(controller.isPlaying, isTrue);
    });

    test('RepeatMode.one: next and previous replay current track', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2]);
      controller.setRepeat(RepeatMode.one);
      expect(controller.repeatMode, equals(RepeatMode.one));

      controller.seek(const Duration(seconds: 45));
      controller.next();
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.positionNotifier.value, equals(Duration.zero));
      expect(controller.isPlaying, isTrue);

      controller.seek(const Duration(seconds: 1));
      controller.previous();
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.positionNotifier.value, equals(Duration.zero));
      expect(controller.isPlaying, isTrue);
    });

    test('cycleRepeatMode cycles off -> all -> one -> off', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      expect(controller.repeatMode, equals(RepeatMode.off));

      controller.cycleRepeatMode();
      expect(controller.repeatMode, equals(RepeatMode.all));

      controller.cycleRepeatMode();
      expect(controller.repeatMode, equals(RepeatMode.one));

      controller.cycleRepeatMode();
      expect(controller.repeatMode, equals(RepeatMode.off));
    });
  });

  group('PlaybackQueueController - Seeking & Progress', () {
    test('seek updates positionNotifier within bounds', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1); // 180s duration
      expect(controller.positionNotifier.value, equals(Duration.zero));

      controller.seek(const Duration(seconds: 50));
      expect(
        controller.positionNotifier.value,
        equals(const Duration(seconds: 50)),
      );

      // Negative clamp
      controller.seek(const Duration(seconds: -10));
      expect(controller.positionNotifier.value, equals(Duration.zero));

      // Overflow clamp
      controller.seek(const Duration(seconds: 500));
      expect(
        controller.positionNotifier.value,
        equals(const Duration(seconds: 180)),
      );
    });

    test(
      'tick increments positionNotifier and auto-advances when track finishes',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        controller.play(
          track1,
          contextQueue: [track1, track2],
        ); // track1 is 180s

        controller.seek(const Duration(seconds: 179));
        controller.tick(
          const Duration(seconds: 1),
        ); // Reaches 180s -> auto-advance

        expect(controller.currentIndex, equals(1));
        expect(controller.currentTrack, equals(track2));
        expect(controller.positionNotifier.value, equals(Duration.zero));
      },
    );

    test('tick repeats track under RepeatMode.one when track finishes', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2]);
      controller.setRepeat(RepeatMode.one);

      controller.seek(const Duration(seconds: 179));
      controller.tick(const Duration(seconds: 2));

      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track1));
      expect(controller.positionNotifier.value, equals(Duration.zero));
      expect(controller.isPlaying, isTrue);
    });
  });

  group('PlaybackQueueController - Queue Mutations', () {
    test('addToQueue appends to the queue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1);
      controller.addToQueue(track2);
      controller.addToQueue(track3);

      expect(controller.queue, equals([track1, track2, track3]));
      expect(controller.currentIndex, equals(0));
    });

    test('playNext inserts immediately after currentIndex', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track3]);
      expect(controller.currentIndex, equals(0));

      controller.playNext(track2);
      expect(controller.queue, equals([track1, track2, track3]));
      expect(controller.currentIndex, equals(0));

      // Advancing plays the inserted track next
      controller.next();
      expect(controller.currentIndex, equals(1));
      expect(controller.currentTrack, equals(track2));
    });

    test('removeFromQueue adjusts currentIndex correctly', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track2, contextQueue: [track1, track2, track3]);
      expect(controller.currentIndex, equals(1));

      // Remove before current track: currentIndex drops by 1
      controller.removeFromQueue(0);
      expect(controller.queue, equals([track2, track3]));
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track2));

      // Remove after current track: currentIndex unaffected
      controller.removeFromQueue(1);
      expect(controller.queue, equals([track2]));
      expect(controller.currentIndex, equals(0));
      expect(controller.currentTrack, equals(track2));

      // Remove current track when it is the only one left
      controller.removeFromQueue(0);
      expect(controller.queue, isEmpty);
      expect(controller.currentIndex, equals(-1));
      expect(controller.currentTrack, isNull);
      expect(controller.isPlaying, isFalse);
    });

    test('reorderQueue moves items and preserves currentTrack reference', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track2, contextQueue: [track1, track2, track3]);
      expect(controller.currentIndex, equals(1));
      expect(controller.currentTrack, equals(track2));

      // Move track3 (index 2) to start (index 0)
      controller.reorderQueue(2, 0);
      expect(controller.queue, equals([track3, track1, track2]));
      expect(controller.currentIndex, equals(2));
      expect(controller.currentTrack, equals(track2));

      // Move track3 (index 0) to after track1 (newIndex 2 -> targetIndex 1)
      controller.reorderQueue(0, 2);
      expect(controller.queue, equals([track1, track3, track2]));
      expect(controller.currentIndex, equals(2));
      expect(controller.currentTrack, equals(track2));
    });

    test('clearQueue resets all playback state and queue', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2, track3]);
      controller.seek(const Duration(seconds: 40));
      expect(controller.queue.length, equals(3));
      expect(controller.isPlaying, isTrue);

      controller.clearQueue();

      expect(controller.queue, isEmpty);
      expect(controller.currentIndex, equals(-1));
      expect(controller.currentTrack, isNull);
      expect(controller.isPlaying, isFalse);
      expect(controller.positionNotifier.value, equals(Duration.zero));
    });
  });

  group('PlaybackQueueController - Shuffle Mode', () {
    test('setShuffle toggles shuffleMode and preserves current track', () {
      final controller = PlaybackQueueController(
        autoStartTimer: false,
        random: Random(42),
      );
      addTearDown(controller.dispose);

      controller.play(track2, contextQueue: [track1, track2, track3]);
      expect(controller.shuffleMode, isFalse);
      expect(controller.currentTrack, equals(track2));

      controller.setShuffle(true);
      expect(controller.shuffleMode, isTrue);
      expect(controller.currentTrack, equals(track2));

      controller.setShuffle(false);
      expect(controller.shuffleMode, isFalse);
      expect(controller.currentTrack, equals(track2));

      controller.toggleShuffle();
      expect(controller.shuffleMode, isTrue);
    });

    test('next and previous traverse all tracks in shuffle mode', () {
      final controller = PlaybackQueueController(
        autoStartTimer: false,
        random: Random(1),
      );
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2, track3]);
      controller.setShuffle(true);

      final playedTracks = <Track>{controller.currentTrack!};

      controller.next();
      playedTracks.add(controller.currentTrack!);

      controller.next();
      playedTracks.add(controller.currentTrack!);

      // All 3 tracks played
      expect(playedTracks, equals({track1, track2, track3}));

      // In RepeatMode.off, next at the end stops playback
      controller.next();
      expect(controller.isPlaying, isFalse);
    });

    test('shuffle mode with RepeatMode.all loops seamlessly', () {
      final controller = PlaybackQueueController(
        autoStartTimer: false,
        random: Random(1),
      );
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track2, track3]);
      controller.setShuffle(true);
      controller.setRepeatMode(RepeatMode.all);

      controller.next(); // 2nd track
      controller.next(); // 3rd track
      controller.next(); // Wraps around to 1st shuffled track
      expect(controller.isPlaying, isTrue);
      expect(controller.currentTrack, isNotNull);
    });
  });

  group('PlaybackQueueController - Disposal', () {
    test('dispose cancels timers and disposes positionNotifier', () {
      final controller = PlaybackQueueController(autoStartTimer: true);
      controller.play(track1);

      controller.dispose();

      // Trying to add listener to disposed positionNotifier should fail
      expect(
        () => controller.positionNotifier.addListener(() {}),
        throwsFlutterError,
      );
    });
  });
}
