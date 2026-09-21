// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_tooltip.dart';

/// Floating batch action toolbar displaying selected item count and batch operations.
class BatchActionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onAddTag;
  final VoidCallback? onDelete;
  final bool showAddToPlaylist;
  final LyraThemeTokens tokens;

  const BatchActionToolbar({
    super.key,
    required this.selectedCount,
    required this.onClearSelection,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onAddTag,
    this.onDelete,
    this.showAddToPlaylist = true,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('batch_action_toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: tokens.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? const Color(0x66000000)
                : const Color(0x22000000),
            blurRadius: 16.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LyraTooltip(
            message: 'Deselect (Esc)',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: const Key('batch_clear_selection_button'),
                behavior: HitTestBehavior.opaque,
                onTap: onClearSelection,
                child: Container(
                  width: 32.0,
                  height: 32.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.0),
                    color: tokens.muted.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    LucideIcons.x,
                    size: 16.0,
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          Text(
            '$selectedCount selected',
            key: const Key('batch_selected_count'),
            style: LyraTypography.small(tokens).copyWith(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: tokens.text,
            ),
          ),
          const SizedBox(width: 12.0),
          Container(height: 22.0, width: 1.0, color: tokens.border),
          const SizedBox(width: 12.0),
          LyraTooltip(
            message: 'Play Next',
            child: KeyedSubtree(
              key: const Key('batch_play_next_button'),
              child: LyraButton.outline(
                size: LyraButtonSize.md,
                width: 36.0,
                height: 36.0,
                padding: EdgeInsets.zero,
                onPressed: onPlayNext,
                child: const Icon(LucideIcons.listStart, size: 18.0),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          LyraTooltip(
            message: 'Add to Queue',
            child: KeyedSubtree(
              key: const Key('batch_add_to_queue_button'),
              child: LyraButton.outline(
                size: LyraButtonSize.md,
                width: 36.0,
                height: 36.0,
                padding: EdgeInsets.zero,
                onPressed: onAddToQueue,
                child: const Icon(LucideIcons.listEnd, size: 18.0),
              ),
            ),
          ),
          if (showAddToPlaylist) ...[
            const SizedBox(width: 10.0),
            LyraTooltip(
              message: 'Add to Playlist',
              child: KeyedSubtree(
                key: const Key('batch_add_to_playlist_button'),
                child: LyraButton.outline(
                  size: LyraButtonSize.md,
                  width: 36.0,
                  height: 36.0,
                  padding: EdgeInsets.zero,
                  onPressed: onAddToPlaylist,
                  child: const Icon(LucideIcons.folderPlus, size: 18.0),
                ),
              ),
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 10.0),
            LyraTooltip(
              message: 'Delete',
              child: KeyedSubtree(
                key: const Key('batch_delete_button'),
                child: LyraButton.outline(
                  size: LyraButtonSize.md,
                  width: 36.0,
                  height: 36.0,
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  child: const Icon(LucideIcons.trash2, size: 18.0),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10.0),
          LyraTooltip(
            message: 'Add Tags',
            child: KeyedSubtree(
              key: const Key('batch_add_tag_button'),
              child: LyraButton.outline(
                size: LyraButtonSize.md,
                width: 36.0,
                height: 36.0,
                padding: EdgeInsets.zero,
                onPressed: onAddTag,
                child: const Icon(LucideIcons.tag, size: 18.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
