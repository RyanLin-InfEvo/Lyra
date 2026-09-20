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

    test(
      'playQueueItem(index) plays specific item without re-generating IDs or jumping on duplicate tracks',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        // Queue with duplicate track1 at index 0 and index 2: [track1, track2, track1, track3]
        controller.play(track1, contextQueue: [track1, track2, track1, track3]);
        expect(controller.currentIndex, equals(0));
        final originalIds = List<String>.from(controller.queueItemIds);

        // Play the duplicate track1 at index 2
        controller.playQueueItem(2);
        expect(controller.currentIndex, equals(2));
        expect(controller.currentTrack, equals(track1));
        expect(controller.isPlaying, isTrue);
        expect(controller.positionNotifier.value, equals(Duration.zero));
        // IDs must not churn / be regenerated
        expect(controller.queueItemIds, equals(originalIds));

        // Out-of-bounds index calls should be safely ignored
        controller.playQueueItem(-1);
        expect(controller.currentIndex, equals(2));
        controller.playQueueItem(999);
        expect(controller.currentIndex, equals(2));
      },
    );

    test(
      'playQueueItem(index) in shuffle mode synchronizes shuffledCurrentIndex without resetting shuffle order',
      () {
        final controller = PlaybackQueueController(
          autoStartTimer: false,
          random: Random(42),
        );
        addTearDown(controller.dispose);

        controller.play(track1, contextQueue: [track1, track2, track1, track3]);
        controller.setShuffle(true);

        final originalShuffleOrder = List<int>.from(controller.shuffledOrder);
        final originalIds = List<String>.from(controller.queueItemIds);

        // Select duplicate track at index 2
        controller.playQueueItem(2);
        expect(controller.currentIndex, equals(2));
        expect(controller.shuffledOrder, equals(originalShuffleOrder));
        expect(
          controller.shuffledCurrentIndex,
          equals(controller.shuffledOrder.indexOf(2)),
        );
        expect(
          controller.shuffledOrder[controller.shuffledCurrentIndex],
          equals(2),
        );
        expect(controller.queueItemIds, equals(originalIds));

        // Select track at index 3
        controller.playQueueItem(3);
        expect(controller.currentIndex, equals(3));
        expect(controller.shuffledOrder, equals(originalShuffleOrder));
        expect(
          controller.shuffledCurrentIndex,
          equals(controller.shuffledOrder.indexOf(3)),
        );
        expect(
          controller.shuffledOrder[controller.shuffledCurrentIndex],
          equals(3),
        );
      },
    );
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
      'seek updates positionNotifier without triggering notifyListeners to avoid stutter',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        controller.play(track1);

        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.seek(const Duration(seconds: 45));
        expect(
          controller.positionNotifier.value,
          equals(const Duration(seconds: 45)),
        );
        expect(notifyCount, equals(0));
      },
    );

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

    test(
      'addAllToQueue appends multiple tracks and notifies listeners once',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        int notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.addAllToQueue([track1, track2, track3]);

        expect(controller.queue, equals([track1, track2, track3]));
        expect(controller.currentIndex, equals(0));
        expect(notifyCount, equals(1));

        // Adding empty list does not notify
        controller.addAllToQueue([]);
        expect(notifyCount, equals(1));
      },
    );

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

    test(
      'playAllNext inserts multiple tracks immediately after currentIndex in order',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        controller.play(track1, contextQueue: [track1, track3]);
        expect(controller.currentIndex, equals(0));

        controller.playAllNext([track2, track1]);
        expect(controller.queue, equals([track1, track2, track1, track3]));
        expect(controller.currentIndex, equals(0));

        // Advancing plays the inserted tracks next in order
        controller.next();
        expect(controller.currentIndex, equals(1));
        expect(controller.currentTrack, equals(track2));

        controller.next();
        expect(controller.currentIndex, equals(2));
        expect(controller.currentTrack, equals(track1));
      },
    );

    test('playAllNext handles empty queue and empty list', () {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      // Empty list does nothing
      controller.playAllNext([]);
      expect(controller.queue, isEmpty);
      expect(controller.currentIndex, equals(-1));

      // Populates empty queue
      controller.playAllNext([track1, track2]);
      expect(controller.queue, equals([track1, track2]));
      expect(controller.currentIndex, equals(0));
      expect(controller.queueItemIds.length, equals(2));
    });

    test('playAllNext in shuffle mode orders new tracks immediately next', () {
      final controller = PlaybackQueueController(
        autoStartTimer: false,
        random: Random(42),
      );
      addTearDown(controller.dispose);

      controller.play(track1, contextQueue: [track1, track3]);
      controller.setShuffle(true);

      controller.playAllNext([track2]);
      expect(controller.queue, equals([track1, track2, track3]));

      // In shuffle mode, track2 should play next
      controller.next();
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

    test(
      'reorderQueue with duplicate tracks preserves correct currentIndex and item identity',
      () {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        // Queue with duplicate track1 at index 0 and index 2: [track1, track2, track1]
        controller.play(track1, contextQueue: [track1, track2, track1]);
        expect(controller.queue, equals([track1, track2, track1]));
        expect(controller.currentIndex, equals(0));

        // Advance to index 2 (the second track1)
        controller.next(); // index 1 (track2)
        controller.next(); // index 2 (second track1)
        expect(controller.currentIndex, equals(2));
        expect(controller.currentTrack, equals(track1));

        final stableIdsBefore = List<String>.from(controller.queueItemIds);
        expect(stableIdsBefore.length, equals(3));
        expect(stableIdsBefore[0], isNot(equals(stableIdsBefore[2])));

        // Reorder index 0 (first track1) to index 1 (Flutter ReorderCallback convention: newIndex 2 -> targetIndex 1)
        controller.reorderQueue(0, 2);
        expect(controller.queue, equals([track2, track1, track1]));

        // With pure index arithmetic, currentIndex must remain 2 (still pointing to the second track1),
        // NOT falsely jump to index 1 due to indexOf(current) returning first match!
        expect(controller.currentIndex, equals(2));
        expect(controller.currentTrack, equals(track1));
        expect(controller.queueItemIds[2], equals(stableIdsBefore[2]));
        expect(controller.queueItemIds[1], equals(stableIdsBefore[0]));

        // Move the currently playing item (index 2) to index 0: queue becomes [track1, track2, track1]
        controller.reorderQueue(2, 0);
        expect(controller.queue, equals([track1, track2, track1]));
        expect(controller.currentIndex, equals(0));
        expect(controller.currentTrack, equals(track1));
        expect(controller.queueItemIds[0], equals(stableIdsBefore[2]));
      },
    );

    test(
      'reorderQueue in shuffle mode preserves shuffle session and play order',
      () {
        final controller = PlaybackQueueController(
          autoStartTimer: false,
          random: Random(42),
        );
        addTearDown(controller.dispose);

        controller.play(track1, contextQueue: [track1, track2, track3]);
        controller.setShuffle(true);

        // Record the expected playback sequence from current shuffle session
        final initialShuffledOrder = List<int>.from(controller.shuffledOrder);
        final initialQueue = List<Track>.from(controller.queue);
        final plannedSequence = initialShuffledOrder
            .map((i) => initialQueue[i])
            .toList();

        // Reorder an item in the queue: move index 2 to index 0
        controller.reorderQueue(2, 0);

        // Queue order changed
        expect(controller.queue, equals([track3, track1, track2]));

        // In the new queue, mapped shuffled order should yield the exact same planned sequence
        final newShuffledOrder = List<int>.from(controller.shuffledOrder);
        final remappedSequence = newShuffledOrder
            .map((i) => controller.queue[i])
            .toList();

        expect(remappedSequence, equals(plannedSequence));

        // Stepping through next() plays the planned sequence seamlessly without re-randomization
        expect(controller.currentTrack, equals(plannedSequence[0]));
        controller.next();
        expect(controller.currentTrack, equals(plannedSequence[1]));
        controller.next();
        expect(controller.currentTrack, equals(plannedSequence[2]));
      },
    );

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

    test(
      'removeFromQueue for current track in shuffle mode synchronizes currentIndex with shuffledCurrentIndex',
      () {
        final controller = PlaybackQueueController(
          autoStartTimer: false,
          random: Random(42),
        );
        addTearDown(controller.dispose);

        controller.play(track1, contextQueue: [track1, track2, track3]);
        controller.setShuffle(true);

        // Verify initial synchronization
        expect(
          controller.currentIndex,
          equals(controller.shuffledOrder[controller.shuffledCurrentIndex]),
        );

        // Remove the currently playing track
        final currentIdx = controller.currentIndex;
        controller.removeFromQueue(currentIdx);

        // Verify queue length decreased
        expect(controller.queue.length, equals(2));

        // _currentIndex must match _shuffledOrder[_shuffledCurrentIndex]
        expect(
          controller.currentIndex,
          equals(controller.shuffledOrder[controller.shuffledCurrentIndex]),
        );
        expect(
          controller.currentTrack,
          equals(controller.queue[controller.currentIndex]),
        );

        // Remove the current track again
        controller.removeFromQueue(controller.currentIndex);
        expect(controller.queue.length, equals(1));
        expect(
          controller.currentIndex,
          equals(controller.shuffledOrder[controller.shuffledCurrentIndex]),
        );
        expect(
          controller.currentTrack,
          equals(controller.queue[controller.currentIndex]),
        );

        // Remove the final track
        controller.removeFromQueue(controller.currentIndex);
        expect(controller.queue, isEmpty);
        expect(controller.currentIndex, equals(-1));
        expect(controller.currentTrack, isNull);
        expect(controller.isPlaying, isFalse);
      },
    );
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
