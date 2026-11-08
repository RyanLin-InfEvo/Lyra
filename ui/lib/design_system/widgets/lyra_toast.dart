// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/settings/services/preferences_service.dart';
import '../factory/lyra_design_system_scope.dart';
import '../tokens/lyra_tokens.dart';

/// Semantic variants for floating toast notifications.
enum LyraToastVariant { info, success, warning, destructive }

/// A notification item displayed within the [LyraToastStack].
class LyraToast {
  final String id;
  final String title;
  final String? message;
  final String? tag;
  final LyraToastVariant variant;
  final IconData? icon;
  final Duration? duration;
  final bool autoDismiss;
  final DateTime createdAt;
  final VoidCallback? onDismiss;
  bool isDismissing;

  LyraToast({
    String? id,
    required this.title,
    this.message,
    this.tag,
    this.variant = LyraToastVariant.info,
    this.icon,
    this.duration,
    this.autoDismiss = true,
    DateTime? createdAt,
    this.onDismiss,
    this.isDismissing = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();
}

/// State controller that manages the queue, auto-dismiss timers, and expanded/collapsed
/// state of TradingView-styled toast notifications.
class LyraToastController extends ChangeNotifier {
  final PreferencesService? preferencesService;
  final List<LyraToast> _toasts = [];
  final Map<String, Timer> _timers = {};
  final Map<String, Duration> _totalDurations = {};
  final Map<String, Duration> _remainingDurations = {};
  final Map<String, DateTime> _timerStartedAt = {};
  final Set<String> _pausedToastIds = {};
  Timer? _dismissAllTimer;
  bool _autoDismiss;
  Duration _defaultDuration;
  bool _showProgressBar;
  bool _isExpanded = false;

  LyraToastController({
    this.preferencesService,
    bool? autoDismiss,
    Duration? defaultDuration,
    bool? showProgressBar,
  }) : _autoDismiss =
           autoDismiss ?? preferencesService?.toastAutoDismiss ?? true,
       _defaultDuration =
           defaultDuration ??
           Duration(seconds: preferencesService?.toastDurationSeconds ?? 10),
       _showProgressBar =
           showProgressBar ?? preferencesService?.toastShowProgressBar ?? true {
    preferencesService?.addListener(_onPreferencesChanged);
  }

  List<LyraToast> get toasts => List.unmodifiable(_toasts);
  bool get isExpanded => _isExpanded;
  bool get isPaused => _pausedToastIds.isNotEmpty;
  bool get autoDismiss => _autoDismiss;
  Duration get defaultDuration => _defaultDuration;
  bool get showProgressBar => _showProgressBar;

  void setShowProgressBar(bool value) {
    if (_showProgressBar == value) return;
    _showProgressBar = value;
    notifyListeners();
  }

  void _onPreferencesChanged() {
    final prefs = preferencesService;
    if (prefs == null) return;

    final newAutoDismiss = prefs.toastAutoDismiss;
    final newDuration = Duration(seconds: prefs.toastDurationSeconds);
    final newShowProgressBar = prefs.toastShowProgressBar;

    if (_autoDismiss != newAutoDismiss ||
        _defaultDuration != newDuration ||
        _showProgressBar != newShowProgressBar) {
      _autoDismiss = newAutoDismiss;
      _defaultDuration = newDuration;
      _showProgressBar = newShowProgressBar;

      if (!_autoDismiss) {
        _cancelAllTimers();
      } else {
        // Restart countdown on active toasts that allow autoDismiss
        for (final toast in _toasts) {
          if (!toast.isDismissing && toast.autoDismiss) {
            final dur =
                _remainingDurations[toast.id] ??
                toast.duration ??
                _defaultDuration;
            _startTimer(toast.id, dur);
          }
        }
      }
      notifyListeners();
    }
  }

  /// Display a new toast notification. Prepend to queue (newest on top).
  void show(LyraToast toast) {
    _toasts.removeWhere((t) => t.id == toast.id);
    _cancelTimer(toast.id);
    _pausedToastIds.remove(toast.id);

    _toasts.insert(0, toast);

    final dur = toast.duration ?? _defaultDuration;
    _totalDurations[toast.id] = dur;
    _remainingDurations[toast.id] = dur;

    if (_autoDismiss && toast.autoDismiss) {
      _startTimer(toast.id, dur);
    }

    notifyListeners();
  }

  /// Convenience method to create and show a toast.
  void showMessage({
    required String title,
    String? message,
    String? tag,
    LyraToastVariant variant = LyraToastVariant.info,
    IconData? icon,
    Duration? duration,
    bool autoDismiss = true,
    VoidCallback? onDismiss,
  }) {
    show(
      LyraToast(
        title: title,
        message: message,
        tag: tag,
        variant: variant,
        icon: icon,
        duration: duration,
        autoDismiss: autoDismiss,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Get total duration for a toast item.
  Duration getTotalDuration(String id) {
    return _totalDurations[id] ?? _defaultDuration;
  }

  /// Get current remaining countdown duration for a toast item.
  Duration getRemainingDuration(String id) {
    if (_pausedToastIds.contains(id)) {
      return _remainingDurations[id] ?? _defaultDuration;
    }
    final started = _timerStartedAt[id];
    final remaining = _remainingDurations[id];
    if (started != null && remaining != null) {
      final elapsed = DateTime.now().difference(started);
      final current = remaining - elapsed;
      return current.isNegative ? Duration.zero : current;
    }
    return _remainingDurations[id] ?? _defaultDuration;
  }

  /// Check whether an individual toast is paused on hover.
  bool isToastPaused(String id) => _pausedToastIds.contains(id);

  /// Pause an individual toast's countdown while hovered.
  void pauseToast(String id) {
    if (_pausedToastIds.contains(id)) return;
    _pausedToastIds.add(id);

    final started = _timerStartedAt[id];
    final remaining = _remainingDurations[id];
    if (started != null && remaining != null) {
      final elapsed = DateTime.now().difference(started);
      final current = remaining - elapsed;
      _remainingDurations[id] = current.isNegative ? Duration.zero : current;
    }
    _cancelTimer(id);
    notifyListeners();
  }

  /// Resume an individual toast's countdown when hover exits.
  void resumeToast(String id) {
    if (!_pausedToastIds.remove(id)) return;
    if (!_autoDismiss) return;

    final remaining = _remainingDurations[id] ?? _defaultDuration;
    if (remaining > const Duration(milliseconds: 50)) {
      _startTimer(id, remaining);
    } else {
      dismiss(id);
    }
    notifyListeners();
  }

  /// Pause all active timers.
  void pauseTimers() {
    for (final toast in _toasts) {
      pauseToast(toast.id);
    }
  }

  /// Resume all active timers with each toast's remaining duration.
  void resumeTimers() {
    for (final toast in _toasts) {
      resumeToast(toast.id);
    }
  }

  /// Dismiss an individual toast by ID.
  /// If [immediate] is true, deletes synchronously from queue without exit animation.
  void dismiss(String id, {bool immediate = false}) {
    _cancelTimer(id);
    _totalDurations.remove(id);
    _remainingDurations.remove(id);
    _timerStartedAt.remove(id);
    _pausedToastIds.remove(id);

    final idx = _toasts.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    if (immediate || !hasListeners) {
      final toast = _toasts.removeAt(idx);
      toast.onDismiss?.call();
      if (_toasts.length <= 1) {
        _isExpanded = false;
      }
      notifyListeners();
      return;
    }

    final toast = _toasts[idx];
    if (toast.isDismissing) return;
    toast.isDismissing = true;
    notifyListeners();

    // Fallback timer in case the widget unmounted before finishing reverse animation
    _timers['exit_$id'] = Timer(const Duration(milliseconds: 250), () {
      _timers.remove('exit_$id');
      final removeIdx = _toasts.indexWhere((t) => t.id == id);
      if (removeIdx != -1) {
        final removed = _toasts.removeAt(removeIdx);
        removed.onDismiss?.call();
      }
      if (_toasts.length <= 1) {
        _isExpanded = false;
      }
      notifyListeners();
    });
  }

  /// Dismiss all active notifications at once.
  void dismissAll({bool immediate = false}) {
    _cancelAllTimers();
    _totalDurations.clear();
    _remainingDurations.clear();
    _timerStartedAt.clear();
    _pausedToastIds.clear();

    if (_toasts.isEmpty) return;

    if (immediate || !hasListeners) {
      for (final toast in _toasts) {
        toast.onDismiss?.call();
      }
      _toasts.clear();
      _isExpanded = false;
      notifyListeners();
      return;
    }

    for (final toast in _toasts) {
      toast.isDismissing = true;
    }
    notifyListeners();

    _dismissAllTimer = Timer(const Duration(milliseconds: 250), () {
      _dismissAllTimer = null;
      for (final toast in _toasts) {
        toast.onDismiss?.call();
      }
      _toasts.clear();
      _isExpanded = false;
      notifyListeners();
    });
  }

  /// Toggle between collapsed stacked-deck and expanded list views.
  void toggleExpanded() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  /// Explicitly set the expanded state.
  void setExpanded(bool expanded) {
    if (_isExpanded != expanded) {
      _isExpanded = expanded;
      notifyListeners();
    }
  }

  void _startTimer(String id, Duration duration) {
    _cancelTimer(id);
    _timerStartedAt[id] = DateTime.now();
    _remainingDurations[id] = duration;

    _timers[id] = Timer(duration, () {
      dismiss(id);
    });
  }

  void _cancelTimer(String id) {
    _timers.remove(id)?.cancel();
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _dismissAllTimer?.cancel();
    _dismissAllTimer = null;
  }

  @override
  void dispose() {
    preferencesService?.removeListener(_onPreferencesChanged);
    _cancelAllTimers();
    super.dispose();
  }
}

/// Scope inherited widget exposing [LyraToastController] to ancestor widgets.
class LyraToastScope extends InheritedNotifier<LyraToastController> {
  const LyraToastScope({
    super.key,
    required LyraToastController controller,
    required super.child,
  }) : super(notifier: controller);

  static LyraToastController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LyraToastScope>();
    assert(scope != null, 'No LyraToastScope found in context');
    return scope!.notifier!;
  }

  static LyraToastController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LyraToastScope>();
    return scope?.notifier;
  }
}

/// Convenience facade for triggering Lyra toast notifications.
class LyraToaster {
  const LyraToaster._();

  static LyraToastController of(BuildContext context) =>
      LyraToastScope.of(context);

  static LyraToastController? maybeOf(BuildContext context) =>
      LyraToastScope.maybeOf(context);

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    String? tag,
    LyraToastVariant variant = LyraToastVariant.info,
    IconData? icon,
    Duration? duration,
    bool autoDismiss = true,
    VoidCallback? onDismiss,
  }) {
    final controller = maybeOf(context);
    controller?.showMessage(
      title: title,
      message: message,
      tag: tag,
      variant: variant,
      icon: icon,
      duration: duration,
      autoDismiss: autoDismiss,
      onDismiss: onDismiss,
    );
  }
}

/// TradingView-style stacked / expandable toast notification overlay.
class LyraToastStack extends StatelessWidget {
  final double width;

  const LyraToastStack({super.key, this.width = 340.0});

  @override
  Widget build(BuildContext context) {
    final controller = LyraToastScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    final toasts = controller.toasts;
    if (toasts.isEmpty) return const SizedBox.shrink();

    final tokens = LyraDesignSystemScope.of(context).tokens;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (Show more/less & Dismiss All) if multiple toasts exist
          if (toasts.length > 1) ...[
            _buildHeaderBar(context, controller, tokens, toasts.length),
            const SizedBox(height: 6.0),
          ],

          // Content: Either collapsed deck of cards or expanded vertical list
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: controller.isExpanded
                ? _buildExpandedList(context, controller, tokens, toasts)
                : _buildCollapsedDeck(context, controller, tokens, toasts),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    LyraToastController controller,
    LyraThemeTokens tokens,
    int count,
  ) {
    final isExpanded = controller.isExpanded;
    final label = isExpanded ? 'Show less' : 'Show more';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expand / Collapse toggle button with badge
          GestureDetector(
            key: const Key('toast_stack_toggle_button'),
            onTap: controller.toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 3.0,
              ),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: tokens.border, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: LyraTypography.small(tokens).copyWith(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Container(
                    width: 16.0,
                    height: 16.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.primary.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: LyraTypography.small(tokens).copyWith(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        color: tokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6.0),
          // Dismiss All button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const Key('toast_stack_dismiss_all_button'),
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.dismissAll(),
              child: Container(
                width: 24.0,
                height: 24.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: Colors.transparent,
                ),
                child: Icon(LucideIcons.x, size: 13.0, color: tokens.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedDeck(
    BuildContext context,
    LyraToastController controller,
    LyraThemeTokens tokens,
    List<LyraToast> toasts,
  ) {
    final frontToast = toasts.first;
    final hasSecond = toasts.length > 1;
    final hasThird = toasts.length > 2;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Layer 3 (deepest deck card)
        if (hasThird)
          Positioned(
            left: 12.0,
            right: 12.0,
            bottom: -8.0,
            child: _buildDummyDeckCard(tokens),
          ),

        // Layer 2 (middle deck card)
        if (hasSecond)
          Positioned(
            left: 6.0,
            right: 6.0,
            bottom: -4.0,
            child: _buildDummyDeckCard(tokens),
          ),

        // Layer 1 (frontmost card with entrance/exit animation & dismissible)
        _AnimatedToastCard(
          key: ValueKey('deck_${frontToast.id}'),
          toast: frontToast,
          controller: controller,
          onDismiss: ({bool immediate = false}) =>
              controller.dismiss(frontToast.id, immediate: immediate),
        ),
      ],
    );
  }

  Widget _buildDummyDeckCard(LyraThemeTokens tokens) {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: tokens.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: tokens.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedList(
    BuildContext context,
    LyraToastController controller,
    LyraThemeTokens tokens,
    List<LyraToast> toasts,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 380.0),
      child: SingleChildScrollView(
        reverse: true, // Newest on top or bottom
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = toasts.length - 1; i >= 0; i--) ...[
              _AnimatedToastCard(
                key: ValueKey('list_${toasts[i].id}'),
                toast: toasts[i],
                controller: controller,
                onDismiss: ({bool immediate = false}) =>
                    controller.dismiss(toasts[i].id, immediate: immediate),
              ),
              if (i > 0) const SizedBox(height: 8.0),
            ],
          ],
        ),
      ),
    );
  }
}

typedef ToastDismissCallback = void Function({bool immediate});

/// Animated wrapper delivering smooth slide & fade entrance and exit transitions,
/// horizontal swipe-to-dismiss, and per-toast countdown progress visualization.
class _AnimatedToastCard extends StatefulWidget {
  final LyraToast toast;
  final LyraToastController controller;
  final ToastDismissCallback onDismiss;

  const _AnimatedToastCard({
    required super.key,
    required this.toast,
    required this.controller,
    required this.onDismiss,
  });

  @override
  State<_AnimatedToastCard> createState() => _AnimatedToastCardState();
}

class _AnimatedToastCardState extends State<_AnimatedToastCard>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _progressController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  bool _dismissTriggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(curved);
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(curved);

    _animController.forward();

    // Progress line countdown animation
    final total = widget.controller.getTotalDuration(widget.toast.id);
    _progressController = AnimationController(vsync: this, duration: total);

    _syncProgressAnimation();
  }

  void _syncProgressAnimation() {
    if (!widget.controller.autoDismiss ||
        !widget.toast.autoDismiss ||
        !widget.controller.showProgressBar) {
      _progressController.stop();
      return;
    }

    final total = widget.controller.getTotalDuration(widget.toast.id);
    final remaining = widget.controller.getRemainingDuration(widget.toast.id);
    final totalMs = math.max(total.inMilliseconds, 1);
    final remainingMs = math.max(remaining.inMilliseconds, 0);

    final currentProgress = (1.0 - (remainingMs / totalMs)).clamp(0.0, 1.0);
    _progressController.value = currentProgress;

    if (!widget.controller.isToastPaused(widget.toast.id) && remainingMs > 0) {
      _progressController.animateTo(
        1.0,
        duration: Duration(milliseconds: remainingMs),
        curve: Curves.linear,
      );
    } else {
      _progressController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toast.isDismissing && !_dismissTriggered) {
      _dismissTriggered = true;
      _animController.reverse().then((_) {
        if (mounted) {
          widget.onDismiss(immediate: true);
        }
      });
    } else {
      _syncProgressAnimation();
    }
  }

  void _handleManualDismiss() {
    if (_dismissTriggered) return;
    _dismissTriggered = true;
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss(immediate: true);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showProgress =
        widget.controller.autoDismiss &&
        widget.toast.autoDismiss &&
        widget.controller.showProgressBar;

    return MouseRegion(
      onEnter: (_) {
        widget.controller.pauseToast(widget.toast.id);
        _progressController.stop();
      },
      onExit: (_) {
        widget.controller.resumeToast(widget.toast.id);
        _syncProgressAnimation();
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dismissible(
              key: ValueKey('dismissible_${widget.toast.id}'),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                _dismissTriggered = true;
                widget.onDismiss(immediate: true);
              },
              child: LyraToastCard(
                toast: widget.toast,
                onDismiss: _handleManualDismiss,
                progressAnimation: showProgress ? _progressController : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An individual toast notification card styled after TradingView notifications.
class LyraToastCard extends StatefulWidget {
  final LyraToast toast;
  final VoidCallback onDismiss;
  final Animation<double>? progressAnimation;

  const LyraToastCard({
    super.key,
    required this.toast,
    required this.onDismiss,
    this.progressAnimation,
  });

  @override
  State<LyraToastCard> createState() => _LyraToastCardState();
}

class _LyraToastCardState extends State<LyraToastCard> {
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final (icon, iconColor, iconBg) = _resolveVariantStyle(tokens);

    return Container(
      key: Key('toast_card_${widget.toast.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: tokens.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Status Icon Pill / Badge
                Container(
                  width: 28.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.toast.icon ?? icon,
                    size: 15.0,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 10.0),

                // Middle Column: Title & Message / Tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.toast.title,
                        style: LyraTypography.small(tokens).copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.text,
                          fontSize: 12.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.toast.tag != null ||
                          widget.toast.message != null) ...[
                        const SizedBox(height: 4.0),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6.0,
                          children: [
                            if (widget.toast.tag != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.secondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(
                                    color: tokens.border.withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  widget.toast.tag!,
                                  style:
                                      LyraTypography.mono(
                                        tokens,
                                        fontSize: 10.5,
                                      ).copyWith(
                                        color: tokens.text,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            if (widget.toast.message != null)
                              Text(
                                widget.toast.message!,
                                style: LyraTypography.muted(
                                  tokens,
                                ).copyWith(fontSize: 11.0),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),

                // Right Close Button (✕) with dedicated hover & tap detection
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isCloseHovered = true),
                  onExit: (_) => setState(() => _isCloseHovered = false),
                  child: GestureDetector(
                    key: Key('toast_dismiss_${widget.toast.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 24.0,
                      height: 24.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.0),
                        color: _isCloseHovered
                            ? tokens.text.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        size: 13.0,
                        color: _isCloseHovered ? tokens.text : tokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Countdown Progress Line
          if (widget.progressAnimation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: widget.progressAnimation!,
                builder: (context, _) {
                  final remainingFactor =
                      (1.0 - widget.progressAnimation!.value).clamp(0.0, 1.0);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: remainingFactor,
                      child: Container(
                        height: 1.4,
                        color: tokens.text.withValues(alpha: 0.75),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _resolveVariantStyle(LyraThemeTokens tokens) {
    switch (widget.toast.variant) {
      case LyraToastVariant.success:
        return (
          LucideIcons.check,
          tokens.success,
          tokens.success.withValues(alpha: 0.15),
        );
      case LyraToastVariant.destructive:
        return (
          LucideIcons.alertCircle,
          tokens.destructive,
          tokens.destructive.withValues(alpha: 0.15),
        );
      case LyraToastVariant.warning:
        return (
          LucideIcons.triangleAlert,
          tokens.warning,
          tokens.warning.withValues(alpha: 0.15),
        );
      case LyraToastVariant.info:
        return (
          LucideIcons.info,
          tokens.primary,
          tokens.primary.withValues(alpha: 0.15),
        );
    }
  }
}
