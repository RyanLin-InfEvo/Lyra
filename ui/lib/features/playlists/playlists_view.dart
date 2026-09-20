// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../common/batch_action_toolbar.dart';
import '../models/playlist.dart';

/// Responsive grid view of curated and user playlists with multi-selection support.
class PlaylistsView extends StatefulWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist>? onPlaylistSelected;
  final VoidCallback? onNewPlaylist;
  final ValueChanged<List<Playlist>>? onBatchPlayNext;
  final ValueChanged<List<Playlist>>? onBatchAddToQueue;
  final ValueChanged<List<Playlist>>? onBatchDelete;
  final ValueChanged<List<Playlist>>? onBatchAddTag;

  const PlaylistsView({
    super.key,
    required this.playlists,
    this.onPlaylistSelected,
    this.onNewPlaylist,
    this.onBatchPlayNext,
    this.onBatchAddToQueue,
    this.onBatchDelete,
    this.onBatchAddTag,
  });

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  final Set<String> _selectedPlaylistIds = {};
  String? _selectionAnchorId;
  bool _isModifierSelectionActive = false;

  bool get _hasSelection => _selectedPlaylistIds.isNotEmpty;

  void _clearSelection() {
    _selectedPlaylistIds.clear();
    _selectionAnchorId = null;
    _isModifierSelectionActive = false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant PlaylistsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedPlaylistIds.removeWhere(
      (id) => !widget.playlists.any((p) => p.id == id),
    );
    if (_selectionAnchorId != null &&
        !widget.playlists.any((p) => p.id == _selectionAnchorId)) {
      _selectionAnchorId = null;
    }
    if (_selectedPlaylistIds.isEmpty) {
      _isModifierSelectionActive = false;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final isEditingText =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    if (isEditingText) {
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_hasSelection) {
        setState(() {
          _clearSelection();
        });
        return true;
      }
      return false;
    }

    final isControl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.control,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlRight,
        );

    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.meta,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaRight,
        );

    final isControlOrMeta = isControl || isMeta;

    if (isControlOrMeta && event.logicalKey == LogicalKeyboardKey.keyA) {
      if (widget.playlists.isNotEmpty) {
        setState(() {
          _selectedPlaylistIds.clear();
          _selectedPlaylistIds.addAll(widget.playlists.map((p) => p.id));
          _selectionAnchorId ??= widget.playlists.first.id;
          _isModifierSelectionActive = true;
        });
        return true;
      }
    }

    return false;
  }

  void _handlePlaylistTap(Playlist playlist) {
    final isShift =
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shift,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftRight,
        );

    final isControl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.control,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.controlRight,
        );

    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.meta,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaRight,
        );

    final isControlOrMeta = isControl || isMeta;

    if (isShift) {
      final clickedIndex = widget.playlists.indexWhere(
        (p) => p.id == playlist.id,
      );
      if (clickedIndex != -1) {
        int anchorIndex = -1;
        if (_selectionAnchorId != null) {
          anchorIndex = widget.playlists.indexWhere(
            (p) => p.id == _selectionAnchorId,
          );
        }
        if (anchorIndex == -1) {
          anchorIndex = 0;
          _selectionAnchorId = widget.playlists.isNotEmpty
              ? widget.playlists[0].id
              : playlist.id;
        }
        final start = math.min(anchorIndex, clickedIndex);
        final end = math.max(anchorIndex, clickedIndex);
        setState(() {
          _selectedPlaylistIds.clear();
          for (int i = start; i <= end; i++) {
            _selectedPlaylistIds.add(widget.playlists[i].id);
          }
          _isModifierSelectionActive = true;
        });
      }
      return;
    }

    if (isControlOrMeta) {
      setState(() {
        if (_selectedPlaylistIds.contains(playlist.id)) {
          _selectedPlaylistIds.remove(playlist.id);
        } else {
          _selectedPlaylistIds.add(playlist.id);
        }
        _selectionAnchorId = playlist.id;
        _isModifierSelectionActive = true;
      });
      return;
    }

    // Normal Click: Single select and invoke widget.onPlaylistSelected
    setState(() {
      _selectedPlaylistIds.clear();
      _selectedPlaylistIds.add(playlist.id);
      _selectionAnchorId = playlist.id;
      _isModifierSelectionActive = false;
    });

    widget.onPlaylistSelected?.call(playlist);
  }

  Widget _buildBatchActionToolbar(
    List<Playlist> selectedPlaylists,
    LyraThemeTokens tokens,
  ) {
    return BatchActionToolbar(
      selectedCount: selectedPlaylists.length,
      onClearSelection: () {
        setState(() {
          _clearSelection();
        });
      },
      onPlayNext: widget.onBatchPlayNext != null
          ? () => widget.onBatchPlayNext!(selectedPlaylists)
          : null,
      onAddToQueue: widget.onBatchAddToQueue != null
          ? () => widget.onBatchAddToQueue!(selectedPlaylists)
          : null,
      showAddToPlaylist: false,
      onDelete: widget.onBatchDelete != null
          ? () => widget.onBatchDelete!(selectedPlaylists)
          : null,
      onAddTag: widget.onBatchAddTag != null
          ? () => widget.onBatchAddTag!(selectedPlaylists)
          : null,
      tokens: tokens,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.listPlus, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No playlists created yet', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Create a playlist to organize your favorite master tracks.',
              style: LyraTypography.muted(tokens),
            ),
            const SizedBox(height: LyraSpacing.lg),
            if (widget.onNewPlaylist != null)
              LyraButton(
                onPressed: widget.onNewPlaylist,
                leading: const Icon(LucideIcons.plus, size: 16.0),
                child: const Text('Create Playlist'),
              ),
          ],
        ),
      );
    }

    final showBatchToolbar =
        _selectedPlaylistIds.isNotEmpty &&
        (_isModifierSelectionActive || _selectedPlaylistIds.length > 1);

    final selectedPlaylists = widget.playlists
        .where((p) => _selectedPlaylistIds.contains(p.id))
        .toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.xl,
                vertical: LyraSpacing.lg,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playlists', style: LyraTypography.h2(tokens)),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${widget.playlists.length} curated collections',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (widget.onNewPlaylist != null)
                    LyraButton(
                      size: LyraButtonSize.sm,
                      onPressed: widget.onNewPlaylist,
                      leading: const Icon(LucideIcons.plus, size: 16.0),
                      child: const Text('New Playlist'),
                    ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_hasSelection) {
                    setState(() {
                      _clearSelection();
                    });
                  }
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    int crossAxisCount = 2;
                    if (width > 1200) {
                      crossAxisCount = 4;
                    } else if (width > 900) {
                      crossAxisCount = 3;
                    } else if (width > 600) {
                      crossAxisCount = 2;
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LyraSpacing.xl,
                        vertical: LyraSpacing.sm,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: LyraSpacing.lg,
                        mainAxisSpacing: LyraSpacing.lg,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: widget.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = widget.playlists[index];
                        final isSelected = _selectedPlaylistIds.contains(
                          playlist.id,
                        );
                        return _PlaylistCard(
                          playlist: playlist,
                          isSelected: isSelected,
                          onTap: () => _handlePlaylistTap(playlist),
                          tokens: tokens,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // Floating Batch Action Toolbar
        Positioned(
          left: 0,
          right: 0,
          bottom: 24.0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              ignoring: !showBatchToolbar,
              child: AnimatedSlide(
                offset: showBatchToolbar ? Offset.zero : const Offset(0.0, 1.5),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showBatchToolbar ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: showBatchToolbar
                      ? _buildBatchActionToolbar(selectedPlaylists, tokens)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;
  final bool isSelected;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.tokens,
    this.isSelected = false,
  });

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final playlist = widget.playlist;
    final isSelected = widget.isSelected;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: LyraCard(
              padding: const EdgeInsets.all(LyraSpacing.lg),
              border: isSelected
                  ? Border.all(color: tokens.primary, width: 2.0)
                  : null,
              backgroundColor: isSelected
                  ? tokens.primary.withValues(alpha: 0.12)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: tokens.secondary,
                          borderRadius: LyraRadius.mdRadius,
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.listMusic,
                            size: 22.0,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      LyraBadge.secondary(
                        child: Text('${playlist.trackCount} tracks'),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.all(3.0),
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 12.0,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    playlist.displayTitle,
                    style: LyraTypography.h4(tokens),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    playlist.description ?? 'Curated Playlist',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
