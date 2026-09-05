// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/contracts/lyra_contracts.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../../design_system/widgets/lyra_button.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';

/// Large album artwork presentation card with metadata and secondary playback controls.
class SongArtworkCard extends StatelessWidget {
  final Track? track;
  final PlaybackQueueController playbackController;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const SongArtworkCard({
    super.key,
    required this.track,
    required this.playbackController,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxArtSize = min(
          constraints.maxWidth,
          min(constraints.maxHeight * 0.65, 380.0),
        );
        final artSize = max(maxArtSize, 180.0);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.lg,
              vertical: LyraSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Album Art Presentation Container
                Container(
                  width: artSize,
                  height: artSize,
                  decoration: BoxDecoration(
                    color: tokens.secondary,
                    borderRadius: LyraRadius.xlRadius,
                    border: Border.all(color: tokens.border, width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24.0,
                        offset: Offset(0, 10.0),
                        spreadRadius: -2.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: LyraRadius.xlRadius,
                    child: Center(
                      child: Icon(
                        LucideIcons.disc,
                        size: artSize * 0.35,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: LyraSpacing.xl),

                // Track Metadata Details
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: max(artSize, 280.0)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        track?.displayTitle ?? 'No track selected',
                        style: LyraTypography.h3(tokens).copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        track?.artist.isNotEmpty == true
                            ? track!.artist
                            : 'Unknown Artist',
                        style: LyraTypography.p(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (track?.album.isNotEmpty == true) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          track!.album,
                          style: LyraTypography.small(tokens).copyWith(
                            color: tokens.textMuted.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: LyraSpacing.lg),

                // Secondary Transport & Curation Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle Toggle
                    LyraButton.ghost(
                      size: LyraButtonSize.sm,
                      onPressed: playbackController.toggleShuffle,
                      child: Icon(
                        LucideIcons.shuffle,
                        size: 18.0,
                        color: playbackController.shuffleMode
                            ? tokens.primary
                            : tokens.textMuted,
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.md),

                    // Repeat Mode Cycler
                    LyraButton.ghost(
                      size: LyraButtonSize.sm,
                      onPressed: playbackController.cycleRepeatMode,
                      child: Icon(
                        playbackController.repeatMode == RepeatMode.one
                            ? LucideIcons.repeat1
                            : LucideIcons.repeat,
                        size: 18.0,
                        color: playbackController.repeatMode != RepeatMode.off
                            ? tokens.primary
                            : tokens.textMuted,
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.md),

                    // Favorite / Like Toggle
                    LyraButton.ghost(
                      size: LyraButtonSize.sm,
                      onPressed: onToggleFavorite,
                      child: Icon(
                        LucideIcons.heart,
                        size: 18.0,
                        color: isFavorite
                            ? tokens.destructive
                            : tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
