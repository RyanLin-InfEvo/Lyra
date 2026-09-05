// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/track.dart';

/// Playback repeat modes for the audio queue.
enum RepeatMode {
  /// Playback stops when the queue reaches the end.
  off,

  /// The entire queue repeats from the beginning when it reaches the end.
  all,

  /// The current track repeats indefinitely.
  one,
}

/// Controller managing audio playback queue state, transport controls, and position progression.
class PlaybackQueueController extends ChangeNotifier {
  final Duration timerInterval;
  final Random _random;
  final bool autoStartTimer;

  final List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _shuffleMode = false;
  RepeatMode _repeatMode = RepeatMode.off;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  Timer? _playbackTimer;
  bool _isDisposed = false;

  List<int> _shuffledOrder = [];
  int _shuffledCurrentIndex = 0;

  PlaybackQueueController({
    this.timerInterval = const Duration(milliseconds: 200),
    Random? random,
    this.autoStartTimer = true,
  }) : _random = random ?? Random();

  /// Unmodifiable view of the current playback queue.
  List<Track> get queue => List.unmodifiable(_queue);

  /// Index of the currently active track in [queue], or -1 if none.
  int get currentIndex => _currentIndex;

  /// The currently active [Track], or null if none is selected.
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
      ? _queue[_currentIndex]
      : null;

  /// Whether audio is currently actively playing.
  bool get isPlaying => _isPlaying;

  /// Whether shuffle playback order is active.
  bool get shuffleMode => _shuffleMode;

  /// Current repeat mode.
  RepeatMode get repeatMode => _repeatMode;

  /// High-frequency position notifier for audio scrubbers.
  ValueNotifier<Duration> get positionNotifier => _positionNotifier;

  /// Total duration of the current track, or [Duration.zero] if none.
  Duration get duration => currentTrack?.duration ?? Duration.zero;

  /// Plays [track], optionally populating the queue with [contextQueue].
  void play(Track track, {List<Track>? contextQueue}) {
    if (contextQueue != null && contextQueue.isNotEmpty) {
      _queue
        ..clear()
        ..addAll(contextQueue);
      final idx = _queue.indexOf(track);
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        final idIdx = _queue.indexWhere((t) => t.id == track.id);
        if (idIdx != -1) {
          _currentIndex = idIdx;
        } else {
          _queue.insert(0, track);
          _currentIndex = 0;
        }
      }
    } else {
      final idx = _queue.indexOf(track);
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        final idIdx = _queue.indexWhere((t) => t.id == track.id);
        if (idIdx != -1) {
          _currentIndex = idIdx;
        } else {
          _queue
            ..clear()
            ..add(track);
          _currentIndex = 0;
        }
      }
    }

    _positionNotifier.value = Duration.zero;
    _isPlaying = true;
    if (_shuffleMode) {
      _initShuffleOrder();
    }
    _startPlaybackTimer();
    notifyListeners();
  }

  /// Toggles between play and pause states.
  void togglePlay() {
    if (currentTrack == null) {
      if (_queue.isNotEmpty) {
        _currentIndex = 0;
        _positionNotifier.value = Duration.zero;
        _isPlaying = true;
        if (_shuffleMode) {
          _initShuffleOrder();
        }
        _startPlaybackTimer();
        notifyListeners();
      }
      return;
    }

    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  /// Pauses audio playback and stops the progress timer.
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _stopPlaybackTimer();
    notifyListeners();
  }

  /// Resumes playback if a track is selected.
  void resume() {
    if (_isPlaying || currentTrack == null) return;
    _isPlaying = true;
    _startPlaybackTimer();
    notifyListeners();
  }

  /// Advances to the next track according to repeat and shuffle configurations.
  void next() {
    if (_queue.isEmpty) return;

    if (_currentIndex < 0) {
      _currentIndex = 0;
      if (_shuffleMode) {
        _initShuffleOrder();
      }
      _positionNotifier.value = Duration.zero;
      _isPlaying = true;
      _startPlaybackTimer();
      notifyListeners();
      return;
    }

    if (_repeatMode == RepeatMode.one) {
      _positionNotifier.value = Duration.zero;
      _isPlaying = true;
      _startPlaybackTimer();
      notifyListeners();
      return;
    }

    if (_shuffleMode) {
      if (_shuffledOrder.isEmpty) {
        _initShuffleOrder();
      }
      if (_shuffledCurrentIndex < _shuffledOrder.length - 1) {
        _shuffledCurrentIndex++;
        _currentIndex = _shuffledOrder[_shuffledCurrentIndex];
        _positionNotifier.value = Duration.zero;
        _isPlaying = true;
        _startPlaybackTimer();
        notifyListeners();
      } else {
        if (_repeatMode == RepeatMode.all) {
          _shuffledCurrentIndex = 0;
          _currentIndex = _shuffledOrder[_shuffledCurrentIndex];
          _positionNotifier.value = Duration.zero;
          _isPlaying = true;
          _startPlaybackTimer();
          notifyListeners();
        } else {
          _isPlaying = false;
          _stopPlaybackTimer();
          _positionNotifier.value = Duration.zero;
          notifyListeners();
        }
      }
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _positionNotifier.value = Duration.zero;
      _isPlaying = true;
      _startPlaybackTimer();
      notifyListeners();
    } else {
      if (_repeatMode == RepeatMode.all) {
        _currentIndex = 0;
        _positionNotifier.value = Duration.zero;
        _isPlaying = true;
        _startPlaybackTimer();
        notifyListeners();
      } else {
        _isPlaying = false;
        _stopPlaybackTimer();
        _positionNotifier.value = Duration.zero;
        notifyListeners();
      }
    }
  }

  /// Skips to the previous track, or seeks to start if > 3 seconds in.
  void previous() {
    if (_queue.isEmpty || _currentIndex < 0) return;

    if (_positionNotifier.value > const Duration(seconds: 3)) {
      _positionNotifier.value = Duration.zero;
      notifyListeners();
      return;
    }

    if (_repeatMode == RepeatMode.one) {
      _positionNotifier.value = Duration.zero;
      _isPlaying = true;
      _startPlaybackTimer();
      notifyListeners();
      return;
    }

    if (_shuffleMode) {
      if (_shuffledOrder.isEmpty) {
        _initShuffleOrder();
      }
      if (_shuffledCurrentIndex > 0) {
        _shuffledCurrentIndex--;
        _currentIndex = _shuffledOrder[_shuffledCurrentIndex];
        _positionNotifier.value = Duration.zero;
        _isPlaying = true;
        _startPlaybackTimer();
        notifyListeners();
      } else {
        if (_repeatMode == RepeatMode.all) {
          _shuffledCurrentIndex = _shuffledOrder.length - 1;
          _currentIndex = _shuffledOrder[_shuffledCurrentIndex];
          _positionNotifier.value = Duration.zero;
          _isPlaying = true;
          _startPlaybackTimer();
          notifyListeners();
        } else {
          _positionNotifier.value = Duration.zero;
          notifyListeners();
        }
      }
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      _positionNotifier.value = Duration.zero;
      _isPlaying = true;
      _startPlaybackTimer();
      notifyListeners();
    } else {
      if (_repeatMode == RepeatMode.all) {
        _currentIndex = _queue.length - 1;
        _positionNotifier.value = Duration.zero;
        _isPlaying = true;
        _startPlaybackTimer();
        notifyListeners();
      } else {
        _positionNotifier.value = Duration.zero;
        notifyListeners();
      }
    }
  }

  /// Seeks to [position] within the bounds of the current track's duration.
  void seek(Duration position) {
    if (currentTrack == null) return;
    final trackDuration = duration;
    Duration target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (trackDuration > Duration.zero && target > trackDuration) {
      target = trackDuration;
    }
    _positionNotifier.value = target;
    notifyListeners();
  }

  /// Appends [track] to the end of the queue.
  void addToQueue(Track track) {
    _queue.add(track);
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
    if (_shuffleMode) {
      _shuffledOrder.add(_queue.length - 1);
    }
    notifyListeners();
  }

  /// Inserts [track] immediately after [currentIndex].
  void playNext(Track track) {
    if (_queue.isEmpty || _currentIndex < 0) {
      _queue.add(track);
      _currentIndex = 0;
      if (_shuffleMode) {
        _shuffledOrder = [0];
        _shuffledCurrentIndex = 0;
      }
    } else {
      final insertIndex = _currentIndex + 1;
      _queue.insert(insertIndex, track);
      if (_shuffleMode) {
        for (var i = 0; i < _shuffledOrder.length; i++) {
          if (_shuffledOrder[i] >= insertIndex) {
            _shuffledOrder[i]++;
          }
        }
        _shuffledOrder.insert(_shuffledCurrentIndex + 1, insertIndex);
      }
    }
    notifyListeners();
  }

  /// Removes the track at [index] from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    if (_shuffleMode) {
      final shuffledPos = _shuffledOrder.indexOf(index);
      if (shuffledPos != -1) {
        _shuffledOrder.removeAt(shuffledPos);
        if (shuffledPos < _shuffledCurrentIndex) {
          _shuffledCurrentIndex--;
        } else if (_shuffledCurrentIndex >= _shuffledOrder.length) {
          _shuffledCurrentIndex = _shuffledOrder.isNotEmpty
              ? _shuffledOrder.length - 1
              : 0;
        }
      }
      for (var i = 0; i < _shuffledOrder.length; i++) {
        if (_shuffledOrder[i] > index) {
          _shuffledOrder[i]--;
        }
      }
    }

    if (index == _currentIndex) {
      _queue.removeAt(index);
      if (_queue.isEmpty) {
        _currentIndex = -1;
        _isPlaying = false;
        _stopPlaybackTimer();
        _positionNotifier.value = Duration.zero;
      } else {
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.length - 1;
        }
        _positionNotifier.value = Duration.zero;
      }
    } else if (index < _currentIndex) {
      _queue.removeAt(index);
      _currentIndex--;
    } else {
      _queue.removeAt(index);
    }

    notifyListeners();
  }

  /// Reorders items in the queue compatible with Flutter's [ReorderCallback].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0) return;
    if (newIndex > _queue.length) newIndex = _queue.length;

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex == targetIndex) return;

    final current = currentTrack;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(targetIndex, track);

    if (current != null) {
      _currentIndex = _queue.indexOf(current);
    }

    if (_shuffleMode) {
      _initShuffleOrder();
    }
    notifyListeners();
  }

  /// Clears the queue and resets all playback state.
  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _isPlaying = false;
    _stopPlaybackTimer();
    _positionNotifier.value = Duration.zero;
    _shuffledOrder.clear();
    _shuffledCurrentIndex = 0;
    notifyListeners();
  }

  /// Sets whether shuffle playback mode is enabled.
  void setShuffle(bool enabled) {
    if (_shuffleMode == enabled) return;
    _shuffleMode = enabled;
    if (_shuffleMode) {
      _initShuffleOrder();
    } else {
      _shuffledOrder.clear();
      _shuffledCurrentIndex = 0;
    }
    notifyListeners();
  }

  /// Toggles shuffle mode on or off.
  void toggleShuffle() => setShuffle(!_shuffleMode);

  /// Sets the repeat mode.
  void setRepeat(RepeatMode mode) => setRepeatMode(mode);

  /// Sets the repeat mode.
  void setRepeatMode(RepeatMode mode) {
    if (_repeatMode == mode) return;
    _repeatMode = mode;
    notifyListeners();
  }

  /// Cycles repeat mode: off -> all -> one -> off.
  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        setRepeatMode(RepeatMode.all);
        break;
      case RepeatMode.all:
        setRepeatMode(RepeatMode.one);
        break;
      case RepeatMode.one:
        setRepeatMode(RepeatMode.off);
        break;
    }
  }

  /// Advances playback position by [elapsed], advancing to next track if complete.
  @visibleForTesting
  void tick([Duration? elapsed]) {
    if (!_isPlaying || currentTrack == null) return;
    final step = elapsed ?? timerInterval;
    final trackDuration = duration;
    final newPosition = _positionNotifier.value + step;
    if (trackDuration > Duration.zero && newPosition >= trackDuration) {
      next();
    } else {
      _positionNotifier.value = newPosition;
    }
  }

  void _startPlaybackTimer() {
    _stopPlaybackTimer();
    if (!autoStartTimer || _isDisposed || !_isPlaying || currentTrack == null) {
      return;
    }
    _playbackTimer = Timer.periodic(timerInterval, (_) {
      _onPlaybackTick();
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void _onPlaybackTick() {
    if (_isDisposed || !_isPlaying || currentTrack == null) {
      _stopPlaybackTimer();
      return;
    }
    tick(timerInterval);
  }

  void _initShuffleOrder() {
    _shuffledOrder.clear();
    if (_queue.isEmpty) {
      _shuffledCurrentIndex = 0;
      return;
    }
    final indices = List<int>.generate(_queue.length, (i) => i);
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      indices.remove(_currentIndex);
      indices.shuffle(_random);
      _shuffledOrder = [_currentIndex, ...indices];
      _shuffledCurrentIndex = 0;
    } else {
      indices.shuffle(_random);
      _shuffledOrder = indices;
      _shuffledCurrentIndex = 0;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPlaybackTimer();
    _positionNotifier.dispose();
    super.dispose();
  }
}
