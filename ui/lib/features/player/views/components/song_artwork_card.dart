// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'package:flutter/widgets.dart' hide RepeatMode;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';

/// Large album artwork presentation card with metadata and secondary playback controls.
class SongArtworkCard extends StatelessWidget {
  final Track? track;
  final PlaybackQueueController? playbackController;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const SongArtworkCard({
    super.key,
    required this.track,
    this.playbackController,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artSize =
              min(constraints.maxWidth, constraints.maxHeight) * 0.8;

          return Center(
            child: Container(
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
          );
        },
      ),
    );
  }
}
