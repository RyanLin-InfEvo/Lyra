// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../models/track.dart';

/// Fixed bottom audio player bar with playback controls, progress slider, and audiophile badges.
class LyraPlayerBar extends StatelessWidget {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration currentPosition;
  final ValueListenable<Duration>? positionNotifier;
  final double volume;
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

  const LyraPlayerBar({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    this.currentPosition = Duration.zero,
    Duration? position,
    this.positionNotifier,
    required this.volume,
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

    return RepaintBoundary(
      child: Container(
        height: 84.0,
        padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.lg),
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border(top: BorderSide(color: tokens.border, width: 1.0)),
        ),
        child: Row(
          children: [
            // Left: Track Info & Format Metadata
            Expanded(
              flex: 3,
              child: currentTrack == null
                  ? Row(
                      children: [
                        Container(
                          width: 44.0,
                          height: 44.0,
                          decoration: BoxDecoration(
                            color: tokens.secondary,
                            borderRadius: LyraRadius.mdRadius,
                          ),
                          child: Icon(
                            LucideIcons.disc,
                            size: 22.0,
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
                      children: [
                        MouseRegion(
                          cursor: onExpandNowPlaying != null
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerUp: (_) => onExpandNowPlaying?.call(),
                            child: Container(
                              width: 44.0,
                              height: 44.0,
                              decoration: BoxDecoration(
                                color: tokens.primary,
                                borderRadius: LyraRadius.mdRadius,
                              ),
                              child: Center(
                                child: Icon(
                                  LucideIcons.music,
                                  size: 22.0,
                                  color: tokens.primaryForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: LyraSpacing.md),
                        Expanded(
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
                                        (onInspectAudio ?? onInspectTrack) !=
                                            null
                                        ? SystemMouseCursors.click
                                        : SystemMouseCursors.basic,
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerUp: (_) {
                                        final callback =
                                            onInspectAudio ?? onInspectTrack;
                                        callback?.call();
                                      },
                                      child: LyraBadge.secondary(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                          vertical: 1.0,
                                        ),
                                        child: Text(
                                          currentTrack!.displayFormat,
                                          style: LyraTypography.small(tokens)
                                              .copyWith(
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
                      ],
                    ),
            ),

            // Center: Playback Controls & Progress Bar
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Transport Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        onPressed: currentTrack == null ? null : onPrevious,
                        child: Icon(
                          LucideIcons.skipBack,
                          size: 18.0,
                          color: currentTrack == null
                              ? tokens.textMuted
                              : tokens.text,
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      MouseRegion(
                        cursor: currentTrack == null
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: currentTrack == null ? null : onTogglePlay,
                          child: Container(
                            width: 42.0,
                            height: 42.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentTrack == null
                                  ? tokens.secondary
                                  : tokens.primary,
                            ),
                            child: Center(
                              child: Icon(
                                isPlaying
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                size: 18.0,
                                color: currentTrack == null
                                    ? tokens.textMuted
                                    : tokens.primaryForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        onPressed: currentTrack == null ? null : onNext,
                        child: Icon(
                          LucideIcons.skipForward,
                          size: 18.0,
                          color: currentTrack == null
                              ? tokens.textMuted
                              : tokens.text,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4.0),

                  // Progress Scrubber
                  _buildProgressScrubber(tokens),
                ],
              ),
            ),

            // Right: Volume & Bit-Perfect Indicator
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    volume == 0
                        ? LucideIcons.volumeX
                        : volume < 0.5
                        ? LucideIcons.volume1
                        : LucideIcons.volume2,
                    size: 18.0,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: LyraSpacing.xs),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 100.0,
                        minWidth: 50.0,
                      ),
                      child: _VolumeSlider(
                        volume: volume,
                        onChanged: onVolumeChanged,
                        tokens: tokens,
                      ),
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.md),
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
    );
  }

  Widget _buildProgressScrubber(LyraThemeTokens tokens) {
    final totalDuration = currentTrack?.duration ?? Duration.zero;

    if (positionNotifier != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: positionNotifier!,
        builder: (context, pos, child) {
          return Row(
            children: [
              Text(
                _formatDuration(pos),
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted, fontSize: 11.0),
              ),
              const SizedBox(width: LyraSpacing.sm),
              Expanded(
                child: _ProgressSlider(
                  position: pos,
                  total: currentTrack?.duration ?? const Duration(seconds: 1),
                  onSeek: onSeek,
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: LyraSpacing.sm),
              child!,
            ],
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

    return Row(
      children: [
        Text(
          _formatDuration(effectivePosition),
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontSize: 11.0),
        ),
        const SizedBox(width: LyraSpacing.sm),
        Expanded(
          child: _ProgressSlider(
            position: effectivePosition,
            total: currentTrack?.duration ?? const Duration(seconds: 1),
            onSeek: onSeek,
            tokens: tokens,
          ),
        ),
        const SizedBox(width: LyraSpacing.sm),
        Text(
          _formatDuration(totalDuration),
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontSize: 11.0),
        ),
      ],
    );
  }
}

/// Custom lightweight progress scrubber bar with animated hover thumb and track expansion.
class _ProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration total;
  final ValueChanged<Duration> onSeek;
  final LyraThemeTokens tokens;

  const _ProgressSlider({
    required this.position,
    required this.total,
    required this.onSeek,
    required this.tokens,
  });

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  bool _isHovered = false;
  bool _isDragging = false;

  void _handleSeek(double localX, double maxWidth) {
    if (maxWidth <= 0) return;
    final double clampedX = localX.clamp(0.0, maxWidth);
    final double ratio = clampedX / maxWidth;
    final seekMs = (widget.total.inMilliseconds * ratio).round();
    widget.onSeek(Duration(milliseconds: seekMs));
  }

  @override
  Widget build(BuildContext context) {
    final factor = widget.total.inMilliseconds > 0
        ? (widget.position.inMilliseconds / widget.total.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final isActive = _isHovered || _isDragging;

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
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragUpdate: (details) {
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
              },
              onHorizontalDragCancel: () {
                setState(() => _isDragging = false);
              },
              onTapDown: (details) {
                setState(() => _isDragging = true);
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              },
              onTapUp: (_) {
                setState(() => _isDragging = false);
              },
              onTapCancel: () {
                setState(() => _isDragging = false);
              },
              child: Container(
                height: 16.0,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: isActive ? 6.0 : 4.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.tokens.secondary,
                        borderRadius: LyraRadius.fullRadius,
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: factor,
                      child: Container(
                        height: isActive ? 6.0 : 4.0,
                        decoration: BoxDecoration(
                          color: widget.tokens.primary,
                          borderRadius: LyraRadius.fullRadius,
                        ),
                      ),
                    ),
                    if (isActive)
                      Align(
                        alignment: Alignment(2 * factor - 1, 0.0),
                        child: Container(
                          width: 12.0,
                          height: 12.0,
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

  void _handleVolume(double localX, double maxWidth) {
    if (maxWidth <= 0) return;
    final double clampedX = localX.clamp(0.0, maxWidth);
    widget.onChanged(clampedX / maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final factor = widget.volume.clamp(0.0, 1.0);
    final isActive = _isHovered || _isDragging;

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
                setState(() => _isDragging = false);
              },
              onHorizontalDragCancel: () {
                setState(() => _isDragging = false);
              },
              onTapDown: (details) {
                setState(() => _isDragging = true);
                _handleVolume(details.localPosition.dx, constraints.maxWidth);
              },
              onTapUp: (_) {
                setState(() => _isDragging = false);
              },
              onTapCancel: () {
                setState(() => _isDragging = false);
              },
              child: Container(
                height: 16.0,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
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
                        duration: const Duration(milliseconds: 150),
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
                        duration: const Duration(milliseconds: 150),
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
