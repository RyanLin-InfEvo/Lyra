// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../audio/controllers/audio_device_controller.dart';
import '../audio/widgets/audio_device_button.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart' show RepeatMode;

/// Fixed bottom audio player bar with playback controls, progress slider, and audiophile badges.
class LyraPlayerBar extends StatelessWidget {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration currentPosition;
  final ValueListenable<Duration>? positionNotifier;
  final double volume;
  final ValueListenable<double>? volumeNotifier;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onInspectTrack;
  final VoidCallback? onInspectAudio;
  final bool isInspectorOpen;
  final bool isNowPlayingExpanded;
  final VoidCallback? onExpandNowPlaying;
  final bool isShuffle;
  final VoidCallback? onToggleShuffle;
  final RepeatMode repeatMode;
  final VoidCallback? onCycleRepeat;
  final VoidCallback? onAddToPlaylist;
  final AudioDeviceController? audioDeviceController;

  static AudioDeviceController? _fallbackDeviceController;
  AudioDeviceController get _effectiveAudioDeviceController =>
      audioDeviceController ??
      (_fallbackDeviceController ??= AudioDeviceController(autoLoad: false));

  const LyraPlayerBar({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    this.currentPosition = Duration.zero,
    Duration? position,
    this.positionNotifier,
    this.volume = 0.85,
    this.volumeNotifier,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.onVolumeChanged,
    this.onInspectTrack,
    this.onInspectAudio,
    this.isInspectorOpen = false,
    this.isNowPlayingExpanded = false,
    this.onExpandNowPlaying,
    this.isShuffle = false,
    this.onToggleShuffle,
    this.repeatMode = RepeatMode.off,
    this.onCycleRepeat,
    this.onAddToPlaylist,
    this.audioDeviceController,
  }) : _position = position;

  final Duration? _position;
  Duration get effectivePosition => _position ?? currentPosition;
  Duration get position => effectivePosition;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Container(
      height: 84.0,
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(top: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Top Full-Width Progress Scrubber (Flush with left & right edges, like YouTube Music)
          Positioned(
            top: -6.0,
            left: 0,
            right: 0,
            child: _buildTopProgressScrubber(tokens),
          ),

          // 2. Main Control Bar Content (Symmetric 7 : 8 : 7 flex ratio guarantees true horizontal center)
          Padding(
            padding: const EdgeInsets.only(
              top: 6.0,
              left: LyraSpacing.lg,
              right: LyraSpacing.lg,
            ),
            child: Row(
              children: [
                // Left: Transport Controls (Shuffle, Prev, Play/Pause, Next, Repeat) + Duration
                Expanded(
                  flex: 7,
                  child: Row(
                    children: [
                      // Shuffle Button (smaller, dimmer color)
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        width: 28.0,
                        height: 28.0,
                        padding: EdgeInsets.zero,
                        onPressed: currentTrack == null
                            ? null
                            : onToggleShuffle,
                        child: Icon(
                          LucideIcons.shuffle,
                          size: 15.0,
                          color: isShuffle
                              ? tokens.primary
                              : tokens.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // Previous Button
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        width: 32.0,
                        height: 32.0,
                        padding: EdgeInsets.zero,
                        onPressed: currentTrack == null ? null : onPrevious,
                        child: Icon(
                          LucideIcons.skipBack,
                          size: 18.0,
                          color: currentTrack == null
                              ? tokens.textMuted
                              : tokens.text,
                        ),
                      ),
                      const SizedBox(width: 6.0),

                      // Play/Pause Button with circular hover effect
                      _PlayerPlayPauseButton(
                        isPlaying: isPlaying,
                        isEnabled: currentTrack != null,
                        onTogglePlay: onTogglePlay,
                        tokens: tokens,
                      ),
                      const SizedBox(width: 6.0),

                      // Next Button
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        width: 32.0,
                        height: 32.0,
                        padding: EdgeInsets.zero,
                        onPressed: currentTrack == null ? null : onNext,
                        child: Icon(
                          LucideIcons.skipForward,
                          size: 18.0,
                          color: currentTrack == null
                              ? tokens.textMuted
                              : tokens.text,
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // Repeat Button (smaller, dimmer color)
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        width: 28.0,
                        height: 28.0,
                        padding: EdgeInsets.zero,
                        onPressed: currentTrack == null ? null : onCycleRepeat,
                        child: Icon(
                          repeatMode == RepeatMode.one
                              ? LucideIcons.repeat1
                              : LucideIcons.repeat,
                          size: 15.0,
                          color: repeatMode != RepeatMode.off
                              ? tokens.primary
                              : tokens.textMuted.withValues(alpha: 0.6),
                        ),
                      ),

                      const SizedBox(width: LyraSpacing.md),

                      // Duration Display (Elapsed / Total)
                      Flexible(child: _buildDurationDisplay(tokens)),
                    ],
                  ),
                ),

                // Center: Track Thumbnail & Info + Add to Playlist (Horizontally Centered)
                Expanded(
                  flex: 8,
                  child: currentTrack == null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 42.0,
                              height: 42.0,
                              decoration: BoxDecoration(
                                color: tokens.secondary,
                                borderRadius: LyraRadius.mdRadius,
                              ),
                              child: Icon(
                                LucideIcons.disc,
                                size: 20.0,
                                color: tokens.textMuted,
                              ),
                            ),
                            const SizedBox(width: LyraSpacing.md),
                            Flexible(
                              child: Text(
                                'No track selected',
                                style: LyraTypography.muted(tokens),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Small Thumbnail
                            MouseRegion(
                              cursor: onExpandNowPlaying != null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerUp: (_) => onExpandNowPlaying?.call(),
                                child: Container(
                                  width: 42.0,
                                  height: 42.0,
                                  decoration: BoxDecoration(
                                    color: tokens.primary,
                                    borderRadius: LyraRadius.mdRadius,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.music,
                                      size: 20.0,
                                      color: tokens.primaryForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: LyraSpacing.md),

                            // Song Title & Artist
                            Flexible(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MouseRegion(
                                    cursor: onExpandNowPlaying != null
                                        ? SystemMouseCursors.click
                                        : SystemMouseCursors.basic,
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerUp: (_) =>
                                          onExpandNowPlaying?.call(),
                                      child: Text(
                                        currentTrack!.displayTitle,
                                        style: LyraTypography.p(
                                          tokens,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${currentTrack!.artist} • ${currentTrack!.album}',
                                          style: LyraTypography.small(
                                            tokens,
                                          ).copyWith(color: tokens.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: LyraSpacing.xs),
                                      MouseRegion(
                                        cursor:
                                            (onInspectAudio ??
                                                    onInspectTrack) !=
                                                null
                                            ? SystemMouseCursors.click
                                            : SystemMouseCursors.basic,
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerUp: (_) {
                                            final callback =
                                                onInspectAudio ??
                                                onInspectTrack;
                                            callback?.call();
                                          },
                                          child: LyraBadge.secondary(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0,
                                              vertical: 1.0,
                                            ),
                                            child: Text(
                                              currentTrack!.displayFormat,
                                              style:
                                                  LyraTypography.small(
                                                    tokens,
                                                  ).copyWith(
                                                    fontSize: 9.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Add to Playlist Action Button
                            const SizedBox(width: LyraSpacing.xxl),
                            Tooltip(
                              message: 'Add to Playlist',
                              child: LyraButton.ghost(
                                size: LyraButtonSize.sm,
                                width: 28.0,
                                height: 28.0,
                                padding: EdgeInsets.zero,
                                onPressed: currentTrack == null
                                    ? null
                                    : onAddToPlaylist,
                                child: Icon(
                                  LucideIcons.listPlus,
                                  size: 16.0,
                                  color: currentTrack == null
                                      ? tokens.textMuted
                                      : tokens.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                // Right: Volume & Inspector Controls
                Expanded(
                  flex: 7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _VolumeControl(
                          volume: volume,
                          volumeNotifier: volumeNotifier,
                          onVolumeChanged: onVolumeChanged,
                          tokens: tokens,
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.xs),
                      AudioDeviceButton(
                        controller: _effectiveAudioDeviceController,
                      ),
                      const SizedBox(width: LyraSpacing.xs),
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        onPressed: currentTrack == null ? null : onInspectTrack,
                        child: Icon(
                          LucideIcons.fileSearch,
                          size: 18.0,
                          color: isInspectorOpen
                              ? tokens.primary
                              : currentTrack == null
                              ? tokens.textMuted
                              : tokens.text,
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.xs),
                      Tooltip(
                        message: isNowPlayingExpanded
                            ? 'Collapse Now Playing'
                            : 'Expand Now Playing',
                        child: LyraButton.ghost(
                          size: LyraButtonSize.sm,
                          onPressed: onExpandNowPlaying,
                          child: Icon(
                            isNowPlayingExpanded
                                ? LucideIcons.chevronDown
                                : LucideIcons.chevronUp,
                            size: 18.0,
                            color: onExpandNowPlaying == null
                                ? tokens.textMuted
                                : tokens.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProgressScrubber(LyraThemeTokens tokens) {
    if (positionNotifier != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: positionNotifier!,
        builder: (context, pos, _) {
          return RepaintBoundary(
            child: _ProgressSlider(
              position: pos,
              total: currentTrack?.duration ?? const Duration(seconds: 1),
              onSeek: onSeek,
              tokens: tokens,
              isTopScrubber: true,
            ),
          );
        },
      );
    }

    return RepaintBoundary(
      child: _ProgressSlider(
        position: effectivePosition,
        total: currentTrack?.duration ?? const Duration(seconds: 1),
        onSeek: onSeek,
        tokens: tokens,
        isTopScrubber: true,
      ),
    );
  }

  Widget _buildDurationDisplay(LyraThemeTokens tokens) {
    final totalDuration = currentTrack?.duration ?? Duration.zero;

    if (positionNotifier != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: positionNotifier!,
        builder: (context, pos, child) {
          return RepaintBoundary(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(pos),
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted, fontSize: 11.0),
                  ),
                  Text(
                    ' / ',
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.textMuted.withValues(alpha: 0.5),
                      fontSize: 11.0,
                    ),
                  ),
                  child!,
                ],
              ),
            ),
          );
        },
        child: Text(
          _formatDuration(totalDuration),
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontSize: 11.0),
        ),
      );
    }

    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(effectivePosition),
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted, fontSize: 11.0),
            ),
            Text(
              ' / ',
              style: LyraTypography.small(tokens).copyWith(
                color: tokens.textMuted.withValues(alpha: 0.5),
                fontSize: 11.0,
              ),
            ),
            Text(
              _formatDuration(totalDuration),
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted, fontSize: 11.0),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom lightweight progress scrubber bar with animated hover thumb and track expansion.
class _ProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final LyraThemeTokens tokens;
  final bool isTopScrubber;

  const _ProgressSlider({
    required this.position,
    required this.total,
    required this.onSeek,
    required this.tokens,
    this.isTopScrubber = false,
  });

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  bool _isHovered = false;
  bool _isDragging = false;
  final ValueNotifier<double?> _hoverXNotifier = ValueNotifier<double?>(null);
  double? _dragFactor;

  @override
  void dispose() {
    _hoverXNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSeek(double localX, double maxWidth) {
    if (maxWidth <= 0) return;
    final double clampedX = localX.clamp(0.0, maxWidth);
    final double ratio = clampedX / maxWidth;
    final seekMs = (widget.total.inMilliseconds * ratio).round();
    widget.onSeek(Duration(milliseconds: seekMs));
  }

  @override
  Widget build(BuildContext context) {
    final factor = _isDragging && _dragFactor != null
        ? _dragFactor!
        : (widget.total.inMilliseconds > 0
              ? (widget.position.inMilliseconds / widget.total.inMilliseconds)
                    .clamp(0.0, 1.0)
              : 0.0);
    final isActive = _isHovered || _isDragging;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) {
          _hoverXNotifier.value = event.localPosition.dx;
          if (!_isHovered) {
            setState(() {
              _isHovered = true;
            });
          }
        },
        onHover: (event) {
          _hoverXNotifier.value = event.localPosition.dx;
        },
        onExit: (_) {
          _hoverXNotifier.value = null;
          if (_isHovered) {
            setState(() {
              _isHovered = false;
            });
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                _hoverXNotifier.value = details.localPosition.dx;
                setState(() {
                  _isDragging = true;
                  _dragFactor =
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      );
                });
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragUpdate: (details) {
                _hoverXNotifier.value = details.localPosition.dx;
                setState(() {
                  _dragFactor =
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      );
                });
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                  _dragFactor = null;
                });
              },
              onHorizontalDragCancel: () {
                setState(() {
                  _isDragging = false;
                  _dragFactor = null;
                });
              },
              onTapDown: (details) {
                _hoverXNotifier.value = details.localPosition.dx;
                setState(() {
                  _isDragging = true;
                  _dragFactor =
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      );
                });
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onTapUp: (_) {
                setState(() {
                  _isDragging = false;
                  _dragFactor = null;
                });
              },
              onTapCancel: () {
                setState(() {
                  _isDragging = false;
                  _dragFactor = null;
                });
              },
              child: Container(
                height: widget.isTopScrubber ? 14.0 : 16.0,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background Track
                    Container(
                      height: widget.isTopScrubber
                          ? (isActive ? 4.0 : 2.0)
                          : (isActive ? 6.0 : 4.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.tokens.secondary,
                        borderRadius: widget.isTopScrubber
                            ? BorderRadius.zero
                            : LyraRadius.fullRadius,
                      ),
                    ),
                    // Active Progress Track
                    FractionallySizedBox(
                      widthFactor: factor,
                      child: Container(
                        height: widget.isTopScrubber
                            ? (isActive ? 4.0 : 2.0)
                            : (isActive ? 6.0 : 4.0),
                        decoration: BoxDecoration(
                          color: widget.tokens.primary,
                          borderRadius: widget.isTopScrubber
                              ? BorderRadius.zero
                              : LyraRadius.fullRadius,
                        ),
                      ),
                    ),
                    // Centered Circular Thumb Control Point
                    if (isActive)
                      Align(
                        alignment: Alignment(2 * factor - 1, 0.0),
                        child: Container(
                          width: widget.isTopScrubber ? 10.0 : 12.0,
                          height: widget.isTopScrubber ? 10.0 : 12.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.tokens.primary,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Hover Preview Timestamp Tooltip
                    if (_isHovered && widget.total.inMilliseconds > 0)
                      Positioned(
                        top: widget.isTopScrubber ? -26.0 : -28.0,
                        left: 0.0,
                        right: 0.0,
                        child: ValueListenableBuilder<double?>(
                          valueListenable: _hoverXNotifier,
                          builder: (context, hoverX, _) {
                            if (hoverX == null) return const SizedBox.shrink();
                            final leftOffset = (hoverX - 22.0)
                                .clamp(
                                  4.0,
                                  max(4.0, constraints.maxWidth - 48.0),
                                )
                                .toDouble();
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: Offset(leftOffset, 0.0),
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.tokens.card,
                                      borderRadius: LyraRadius.smRadius,
                                      border: Border.all(
                                        color: widget.tokens.border,
                                        width: 1.0,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x40000000),
                                          blurRadius: 6.0,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _formatDuration(
                                        Duration(
                                          milliseconds:
                                              (widget.total.inMilliseconds *
                                                      (hoverX /
                                                              constraints
                                                                  .maxWidth)
                                                          .clamp(0.0, 1.0))
                                                  .round(),
                                        ),
                                      ),
                                      style: LyraTypography.small(widget.tokens)
                                          .copyWith(
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.w600,
                                            color: widget.tokens.text,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Interactive volume control widget combining clickable mute toggle icon and smooth volume slider.
class _VolumeControl extends StatefulWidget {
  final double volume;
  final ValueListenable<double>? volumeNotifier;
  final ValueChanged<double> onVolumeChanged;
  final LyraThemeTokens tokens;

  const _VolumeControl({
    required this.volume,
    this.volumeNotifier,
    required this.onVolumeChanged,
    required this.tokens,
  });

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  late double _currentVolume;
  double _lastNonZeroVolume = 0.85;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volumeNotifier?.value ?? widget.volume;
    if (_currentVolume > 0) {
      _lastNonZeroVolume = _currentVolume;
    }
    widget.volumeNotifier?.addListener(_onNotifierChanged);
  }

  @override
  void didUpdateWidget(covariant _VolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeNotifier != widget.volumeNotifier) {
      oldWidget.volumeNotifier?.removeListener(_onNotifierChanged);
      widget.volumeNotifier?.addListener(_onNotifierChanged);
      if (widget.volumeNotifier != null) {
        _currentVolume = widget.volumeNotifier!.value;
        if (_currentVolume > 0) {
          _lastNonZeroVolume = _currentVolume;
        }
      }
    } else if (widget.volumeNotifier == null &&
        oldWidget.volume != widget.volume) {
      _currentVolume = widget.volume;
      if (_currentVolume > 0) {
        _lastNonZeroVolume = _currentVolume;
      }
    }
  }

  @override
  void dispose() {
    widget.volumeNotifier?.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    if (mounted && widget.volumeNotifier != null) {
      final newVol = widget.volumeNotifier!.value;
      if (newVol != _currentVolume) {
        setState(() {
          _currentVolume = newVol;
          if (newVol > 0) {
            _lastNonZeroVolume = newVol;
          }
        });
      }
    }
  }

  void _handleVolumeChanged(double vol) {
    final clamped = vol.clamp(0.0, 1.0);
    if (clamped > 0) {
      _lastNonZeroVolume = clamped;
    }
    setState(() {
      _currentVolume = clamped;
    });
    widget.onVolumeChanged(clamped);
  }

  void _toggleMute() {
    if (_currentVolume > 0) {
      _lastNonZeroVolume = _currentVolume;
      _handleVolumeChanged(0.0);
    } else {
      final restore = (_lastNonZeroVolume > 0) ? _lastNonZeroVolume : 0.85;
      _handleVolumeChanged(restore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconData volumeIcon = _currentVolume == 0
        ? LucideIcons.volumeX
        : _currentVolume < 0.5
        ? LucideIcons.volume1
        : LucideIcons.volume2;
    final String tooltip = _currentVolume == 0 ? 'Unmute' : 'Mute';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMute,
              child: SizedBox(
                width: 24.0,
                height: 24.0,
                child: Center(
                  child: Icon(
                    volumeIcon,
                    size: 18.0,
                    color: widget.tokens.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: LyraSpacing.xs),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90.0, minWidth: 30.0),
            child: _VolumeSlider(
              volume: _currentVolume,
              onChanged: _handleVolumeChanged,
              tokens: widget.tokens,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom volume slider with animated hover thumb and track expansion.
class _VolumeSlider extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  final LyraThemeTokens tokens;

  const _VolumeSlider({
    required this.volume,
    required this.onChanged,
    required this.tokens,
  });

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  bool _isHovered = false;
  bool _isDragging = false;
  double? _dragVolume;

  void _handleVolume(double localX, double maxWidth) {
    if (maxWidth <= 0) return;
    final double clampedX = localX.clamp(0.0, maxWidth);
    final double newVol = clampedX / maxWidth;
    setState(() {
      _dragVolume = newVol;
    });
    widget.onChanged(newVol);
  }

  @override
  Widget build(BuildContext context) {
    final factor = (_dragVolume ?? widget.volume).clamp(0.0, 1.0);
    final isActive = _isHovered || _isDragging;
    final animDuration = _isDragging
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                setState(() => _isDragging = true);
                _handleVolume(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragUpdate: (details) {
                _handleVolume(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                  _dragVolume = null;
                });
              },
              onHorizontalDragCancel: () {
                setState(() {
                  _isDragging = false;
                  _dragVolume = null;
                });
              },
              onTapDown: (details) {
                setState(() => _isDragging = true);
                _handleVolume(details.localPosition.dx, constraints.maxWidth);
              },
              onTapUp: (_) {
                setState(() {
                  _isDragging = false;
                  _dragVolume = null;
                });
              },
              onTapCancel: () {
                setState(() {
                  _isDragging = false;
                  _dragVolume = null;
                });
              },
              child: Container(
                height: 16.0,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: animDuration,
                      height: isActive ? 5.0 : 4.0,
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.tokens.secondary,
                          borderRadius: LyraRadius.fullRadius,
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: factor,
                      child: AnimatedContainer(
                        duration: animDuration,
                        height: isActive ? 5.0 : 4.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.tokens.primary,
                            borderRadius: LyraRadius.fullRadius,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(2 * factor - 1, 0.0),
                      child: AnimatedScale(
                        scale: isActive ? 1.0 : 0.0,
                        duration: animDuration,
                        child: Container(
                          width: 10.0,
                          height: 10.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.tokens.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Central circular play/pause button with hover feedback matching neighboring transport controls.
class _PlayerPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isEnabled;
  final VoidCallback? onTogglePlay;
  final LyraThemeTokens tokens;

  const _PlayerPlayPauseButton({
    required this.isPlaying,
    required this.isEnabled,
    required this.onTogglePlay,
    required this.tokens,
  });

  @override
  State<_PlayerPlayPauseButton> createState() => _PlayerPlayPauseButtonState();
}

class _PlayerPlayPauseButtonState extends State<_PlayerPlayPauseButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isEnabled = widget.isEnabled;
    final showHighlight = (_isHovered || _isPressed) && isEnabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: isEnabled ? widget.onTogglePlay : null,
        child: Container(
          width: 46.0,
          height: 46.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: showHighlight ? tokens.accent : const Color(0x00000000),
          ),
          child: Center(
            child: Icon(
              widget.isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 26.0,
              color: !isEnabled
                  ? tokens.textMuted
                  : (tokens.isDark ? const Color(0xFFFFFFFF) : tokens.text),
            ),
          ),
        ),
      ),
    );
  }
}
