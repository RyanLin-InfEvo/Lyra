// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';

/// Adaptive theater presentation card for music video playback, YouTube Music preview,
/// and custom video streams across various aspect ratios (e.g., 16:9, 4:3, 21:9, 9:16).
class VideoSurfaceCard extends StatelessWidget {
  final Track? track;
  final PlaybackQueueController playbackController;
  final Widget? customVideoPlayer;

  /// Target aspect ratio of the video surface (e.g., 16/9, 4/3, 21/9, 9/16).
  ///
  /// If specified, the theater viewport wraps in an [AspectRatio] matching this ratio.
  /// If omitted, defaults to an adaptive 16:9 fallback.
  final double? aspectRatio;

  /// Optional custom quality, format, or aspect ratio badge tag (e.g., "MV 4:3", "MV 1080p", "4K").
  ///
  /// If omitted, dynamically infers badge text based on [aspectRatio] or track metadata.
  final String? videoTag;

  const VideoSurfaceCard({
    super.key,
    required this.track,
    required this.playbackController,
    this.customVideoPlayer,
    this.aspectRatio,
    this.videoTag,
  });

  String _resolveTag(bool hasYtm) {
    if (videoTag != null && videoTag!.isNotEmpty) {
      return videoTag!;
    }
    final prefix = hasYtm ? 'MV' : 'Preview';
    if (aspectRatio != null) {
      final ratio = aspectRatio!;
      if ((ratio - 16 / 9).abs() < 0.02) return '$prefix 16:9';
      if ((ratio - 4 / 3).abs() < 0.02) return '$prefix 4:3';
      if ((ratio - 21 / 9).abs() < 0.02 ||
          (ratio - 2.35).abs() < 0.05 ||
          (ratio - 2.39).abs() < 0.05) {
        return '$prefix 21:9';
      }
      if ((ratio - 9 / 16).abs() < 0.02) return '$prefix 9:16';
      if ((ratio - 1.0).abs() < 0.02) return '$prefix 1:1';
      return '$prefix ${ratio.toStringAsFixed(2)}:1';
    }
    return hasYtm ? 'MV 1080p' : 'Preview';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final hasYtm = track?.ytmId != null && track!.ytmId!.isNotEmpty;

    return RepaintBoundary(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.lg,
            vertical: LyraSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Flexible Theater Viewport Container with responsive max constraints
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620.0,
                  maxHeight: 460.0,
                ),
                child: AspectRatio(
                  aspectRatio: aspectRatio ?? (16 / 9),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.isDark
                          ? LyraColors.zinc950
                          : const Color(0xFF0F0F12),
                      borderRadius: LyraRadius.xlRadius,
                      border: Border.all(color: tokens.border, width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24.0,
                          offset: Offset(0, 10.0),
                          spreadRadius: -2.0,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: customVideoPlayer != null
                        ? Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: customVideoPlayer!,
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              // Backdrop Ambient Gradient
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF23232A),
                                      Color(0xFF141418),
                                      Color(0xFF09090B),
                                    ],
                                  ),
                                ),
                              ),

                              // Video Surface Decorative Watermark
                              Center(
                                child: Icon(
                                  LucideIcons.video,
                                  size: 72.0,
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),

                              // Center Play / Pause Interactive Transport Overlay
                              Center(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: playbackController.togglePlay,
                                    child: Container(
                                      width: 56.0,
                                      height: 56.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: tokens.primary,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x4D000000),
                                            blurRadius: 16.0,
                                            offset: Offset(0, 4.0),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          playbackController.isPlaying
                                              ? LucideIcons.pause
                                              : LucideIcons.play,
                                          size: 24.0,
                                          color: tokens.primaryForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom Gradient Scrim Overlay with Video Metadata
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: LyraSpacing.lg,
                                    vertical: LyraSpacing.md,
                                  ),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xE609090B),
                                        Color(0x9909090B),
                                        Color(0x0009090B),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              track?.displayTitle ??
                                                  'No track selected',
                                              style: const TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFFAFAFA),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2.0),
                                            Text(
                                              track?.artist.isNotEmpty == true
                                                  ? track!.artist
                                                  : 'Unknown Artist',
                                              style: const TextStyle(
                                                fontSize: 12.0,
                                                color: Color(0xFFA1A1AA),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0,
                                          vertical: 2.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33FFFFFF),
                                          borderRadius: LyraRadius.smRadius,
                                        ),
                                        child: Text(
                                          _resolveTag(hasYtm),
                                          style: const TextStyle(
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFAFAFA),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: LyraSpacing.lg),

              // Sub-Theater Source & Extensibility Information
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620.0),
                child: Container(
                  padding: const EdgeInsets.all(LyraSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.secondary.withValues(alpha: 0.5),
                    borderRadius: LyraRadius.mdRadius,
                    border: Border.all(color: tokens.border, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasYtm ? LucideIcons.tv : LucideIcons.info,
                        size: 18.0,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      Expanded(
                        child: Text(
                          hasYtm
                              ? 'YouTube Music ID: ${track!.ytmId}'
                              : 'No music video linked to this track. Showing preview theater surface.',
                          style: LyraTypography.small(
                            tokens,
                          ).copyWith(color: tokens.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
