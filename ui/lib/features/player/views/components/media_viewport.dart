// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';
import 'song_artwork_card.dart';
import 'video_surface_card.dart';

/// Available display viewport presentation modes.
enum MediaViewportMode {
  /// Standard high-resolution audio cover art view.
  song,

  /// Theater MV video or visualizer surface view across adaptive aspect ratios.
  video,
}

/// Responsive media viewport with top segmented capsule toggle between Song and Video modes.
class MediaViewport extends StatefulWidget {
  final Track? track;
  final PlaybackQueueController playbackController;
  final MediaViewportMode initialMode;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<MediaViewportMode>? onModeChanged;
  final double? videoAspectRatio;
  final Widget? customVideoPlayer;
  final String? videoTag;

  const MediaViewport({
    super.key,
    required this.track,
    required this.playbackController,
    this.initialMode = MediaViewportMode.song,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onModeChanged,
    this.videoAspectRatio,
    this.customVideoPlayer,
    this.videoTag,
  });

  @override
  State<MediaViewport> createState() => _MediaViewportState();
}

class _MediaViewportState extends State<MediaViewport> {
  late MediaViewportMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  void _switchMode(MediaViewportMode mode) {
    if (_currentMode == mode) return;
    setState(() {
      _currentMode = mode;
    });
    widget.onModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final hasYtm =
        widget.track?.ytmId != null && widget.track!.ytmId!.isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: LyraSpacing.sm),

        // Top Pill/Capsule Segmented Toggle (Song vs Video)
        Container(
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            color: tokens.secondary,
            borderRadius: LyraRadius.fullRadius,
            border: Border.all(color: tokens.border, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Song Option
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _switchMode(MediaViewportMode.song),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: LyraSpacing.md,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: _currentMode == MediaViewportMode.song
                          ? tokens.card
                          : const Color(0x00000000),
                      borderRadius: LyraRadius.fullRadius,
                      boxShadow: _currentMode == MediaViewportMode.song
                          ? const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 4.0,
                                offset: Offset(0, 1.0),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.music,
                          size: 14.0,
                          color: _currentMode == MediaViewportMode.song
                              ? tokens.text
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          'Song',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: _currentMode == MediaViewportMode.song
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _currentMode == MediaViewportMode.song
                                ? tokens.text
                                : tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 2.0),

              // Video Option
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _switchMode(MediaViewportMode.video),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: LyraSpacing.md,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: _currentMode == MediaViewportMode.video
                          ? tokens.card
                          : const Color(0x00000000),
                      borderRadius: LyraRadius.fullRadius,
                      boxShadow: _currentMode == MediaViewportMode.video
                          ? const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 4.0,
                                offset: Offset(0, 1.0),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.video,
                          size: 14.0,
                          color: _currentMode == MediaViewportMode.video
                              ? tokens.text
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          hasYtm ? 'Video' : 'Video (Preview)',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: _currentMode == MediaViewportMode.video
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _currentMode == MediaViewportMode.video
                                ? tokens.text
                                : tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: LyraSpacing.sm),

        // Switchable Viewport Body
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _currentMode == MediaViewportMode.song
                ? SongArtworkCard(
                    key: const ValueKey('song_artwork_mode'),
                    track: widget.track,
                    playbackController: widget.playbackController,
                    isFavorite: widget.isFavorite,
                    onToggleFavorite: widget.onToggleFavorite,
                  )
                : VideoSurfaceCard(
                    key: const ValueKey('video_surface_mode'),
                    track: widget.track,
                    playbackController: widget.playbackController,
                    customVideoPlayer: widget.customVideoPlayer,
                    aspectRatio: widget.videoAspectRatio,
                    videoTag: widget.videoTag,
                  ),
          ),
        ),
      ],
    );
  }
}
