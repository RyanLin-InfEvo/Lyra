// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A custom [ReorderableDragStartListener] with a slop threshold before initiating
/// a drag to prevent accidental drags during normal click/tap actions.
class ThresholdReorderableDragStartListener
    extends ReorderableDragStartListener {
  final double slopThreshold;
  final Duration touchDelay;

  const ThresholdReorderableDragStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled = true,
    this.slopThreshold = 10.0,
    this.touchDelay = kLongPressTimeout,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled
          ? (PointerDownEvent event) {
              if (event.kind == PointerDeviceKind.mouse &&
                  event.buttons != kPrimaryButton) {
                return;
              }
              _startDragging(context, event);
            }
          : null,
      child: child,
    );
  }

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return ThresholdMultiDragGestureRecognizer(
      slopThreshold: slopThreshold,
      touchDelay: touchDelay,
      debugOwner: this,
    );
  }

  void _startDragging(BuildContext context, PointerDownEvent event) {
    final DeviceGestureSettings? gestureSettings =
        MediaQuery.maybeGestureSettingsOf(context);
    final SliverReorderableListState? list = SliverReorderableList.maybeOf(
      context,
    );
    list?.startItemDragReorder(
      index: index,
      event: event,
      recognizer: createRecognizer()..gestureSettings = gestureSettings,
    );
  }
}

/// A custom [MultiDragGestureRecognizer] that enforces a configurable slop threshold
/// (default 10.0 logical pixels) for mouse pointers before resolving as accepted.
/// This prevents pointer jitter from misfiring clicks as drag-to-reorder events.
///
/// On touch devices (`PointerDeviceKind.touch`), immediate vertical drags are NOT
/// accepted to prevent hijacking normal list scrolling. Instead, a delay ([touchDelay],
/// default [kLongPressTimeout]) is used so normal swiping scrolls the list while
/// a press-and-hold initiates reordering.
class ThresholdMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  final double slopThreshold;
  final Duration touchDelay;

  ThresholdMultiDragGestureRecognizer({
    this.slopThreshold = 10.0,
    this.touchDelay = kLongPressTimeout,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      return _ThresholdMousePointerState(
        event.position,
        event.kind,
        gestureSettings,
        slopThreshold: slopThreshold,
      );
    }
    return _ThresholdTouchPointerState(
      event.position,
      event.kind,
      gestureSettings,
      delay: touchDelay,
    );
  }

  @override
  String get debugDescription => 'threshold multidrag';
}

class _ThresholdMousePointerState extends MultiDragPointerState {
  final double slopThreshold;

  _ThresholdMousePointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings, {
    required this.slopThreshold,
  });

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.distance > slopThreshold) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class _ThresholdTouchPointerState extends MultiDragPointerState {
  final Duration delay;
  Timer? _timer;

  _ThresholdTouchPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings, {
    required this.delay,
  }) {
    _timer = Timer(delay, _delayPassed);
  }

  void _delayPassed() {
    assert(_timer != null);
    assert(pendingDelta != null);
    _timer = null;
    resolve(GestureDisposition.accepted);
  }

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (_timer != null) {
      final double touchSlop = gestureSettings?.touchSlop ?? kTouchSlop;
      if (pendingDelta!.distance > touchSlop) {
        resolve(GestureDisposition.rejected);
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
