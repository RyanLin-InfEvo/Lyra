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
import '../../design_system/widgets/lyra_card.dart';
import '../common/batch_action_toolbar.dart';
import '../models/album.dart';

/// Responsive grid view of audiophile albums with desktop multi-selection.
class AlbumsView extends StatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onAlbumSelected;
  final ValueChanged<List<Album>>? onBatchPlayNext;
  final ValueChanged<List<Album>>? onBatchAddToQueue;
  final ValueChanged<List<Album>>? onBatchAddToPlaylist;
  final ValueChanged<List<Album>>? onBatchAddTag;

  const AlbumsView({
    super.key,
    required this.albums,
    this.onAlbumSelected,
    this.onBatchPlayNext,
    this.onBatchAddToQueue,
    this.onBatchAddToPlaylist,
    this.onBatchAddTag,
  });

  @override
  State<AlbumsView> createState() => _AlbumsViewState();
}

class _AlbumsViewState extends State<AlbumsView> {
  final Set<String> _selectedAlbumIds = {};
  String? _selectionAnchorId;
  bool _isModifierSelectionActive = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant AlbumsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedAlbumIds.removeWhere(
      (id) => !widget.albums.any((a) => a.id == id),
    );
    if (_selectionAnchorId != null &&
        !widget.albums.any((a) => a.id == _selectionAnchorId)) {
      _selectionAnchorId = null;
    }
    if (_selectedAlbumIds.isEmpty) {
      _isModifierSelectionActive = false;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool get _hasSelection => _selectedAlbumIds.isNotEmpty;

  void _clearSelection() {
    _selectedAlbumIds.clear();
    _selectionAnchorId = null;
    _isModifierSelectionActive = false;
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
      if (widget.albums.isNotEmpty) {
        setState(() {
          _selectedAlbumIds.clear();
          _selectedAlbumIds.addAll(widget.albums.map((a) => a.id));
          _selectionAnchorId ??= widget.albums.first.id;
          _isModifierSelectionActive = true;
        });
        return true;
      }
    }

    return false;
  }

  void _handleAlbumTap(Album album) {
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
      final clickedIndex = widget.albums.indexWhere((a) => a.id == album.id);
      if (clickedIndex != -1) {
        int anchorIndex = -1;
        if (_selectionAnchorId != null) {
          anchorIndex = widget.albums.indexWhere(
            (a) => a.id == _selectionAnchorId,
          );
        }
        if (anchorIndex == -1) {
          anchorIndex = 0;
          _selectionAnchorId = widget.albums.isNotEmpty
              ? widget.albums[0].id
              : album.id;
        }
        final start = math.min(anchorIndex, clickedIndex);
        final end = math.max(anchorIndex, clickedIndex);
        setState(() {
          _selectedAlbumIds.clear();
          for (int i = start; i <= end; i++) {
            _selectedAlbumIds.add(widget.albums[i].id);
          }
          _isModifierSelectionActive = true;
        });
      }
      return;
    }

    if (isControlOrMeta) {
      setState(() {
        if (_selectedAlbumIds.contains(album.id)) {
          _selectedAlbumIds.remove(album.id);
        } else {
          _selectedAlbumIds.add(album.id);
        }
        _selectionAnchorId = album.id;
        _isModifierSelectionActive = true;
      });
      return;
    }

    // Normal Click: calls widget.onAlbumSelected and single-selects (does not show toolbar).
    setState(() {
      _selectedAlbumIds.clear();
      _selectedAlbumIds.add(album.id);
      _selectionAnchorId = album.id;
      _isModifierSelectionActive = false;
    });

    widget.onAlbumSelected?.call(album);
  }

  Widget _buildBatchActionToolbar(
    List<Album> selectedAlbums,
    LyraThemeTokens tokens,
  ) {
    return BatchActionToolbar(
      selectedCount: selectedAlbums.length,
      onClearSelection: () {
        setState(() {
          _clearSelection();
        });
      },
      onPlayNext: widget.onBatchPlayNext != null
          ? () => widget.onBatchPlayNext!(selectedAlbums)
          : null,
      onAddToQueue: widget.onBatchAddToQueue != null
          ? () => widget.onBatchAddToQueue!(selectedAlbums)
          : null,
      onAddToPlaylist: widget.onBatchAddToPlaylist != null
          ? () => widget.onBatchAddToPlaylist!(selectedAlbums)
          : null,
      onAddTag: widget.onBatchAddTag != null
          ? () => widget.onBatchAddTag!(selectedAlbums)
          : null,
      tokens: tokens,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.disc, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No albums found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to populate your album library.',
              style: LyraTypography.muted(tokens),
            ),
          ],
        ),
      );
    }

    final selectedAlbums = widget.albums
        .where((a) => _selectedAlbumIds.contains(a.id))
        .toList();
    final bool showBatchToolbar =
        _selectedAlbumIds.isNotEmpty &&
        (_isModifierSelectionActive || _selectedAlbumIds.length > 1);

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
                      Text('Albums', style: LyraTypography.h2(tokens)),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${widget.albums.length} releases in master quality',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
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
                      crossAxisCount = 5;
                    } else if (width > 900) {
                      crossAxisCount = 4;
                    } else if (width > 600) {
                      crossAxisCount = 3;
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
                        childAspectRatio: 0.78,
                      ),
                      itemCount: widget.albums.length,
                      itemBuilder: (context, index) {
                        final album = widget.albums[index];
                        final isSelected = _selectedAlbumIds.contains(album.id);
                        return _AlbumCard(
                          album: album,
                          isSelected: isSelected,
                          onTap: () => _handleAlbumTap(album),
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
                      ? _buildBatchActionToolbar(selectedAlbums, tokens)
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

/// Single album card item.
class _AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;
  final bool isSelected;

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.tokens,
    this.isSelected = false,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final album = widget.album;
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
              padding: const EdgeInsets.all(LyraSpacing.md),
              border: isSelected
                  ? Border.all(color: tokens.primary, width: 2.0)
                  : null,
              backgroundColor: isSelected
                  ? tokens.primary.withValues(alpha: 0.12)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album Art Placeholder
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: album.coverColor,
                        borderRadius: LyraRadius.mdRadius,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              LucideIcons.disc,
                              size: 48.0,
                              color: const Color(0x66FFFFFF),
                            ),
                          ),
                          Positioned(
                            top: LyraSpacing.sm,
                            right: LyraSpacing.sm,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LyraBadge(
                                  variant: LyraBadgeVariant.secondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 2.0,
                                  ),
                                  child: Text(
                                    album.format ?? 'FLAC',
                                    style: LyraTypography.small(tokens)
                                        .copyWith(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4.0),
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
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: LyraSpacing.md),

                  // Title
                  Text(
                    album.title,
                    style: LyraTypography.h4(tokens),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2.0),

                  // Artist & Year
                  Text(
                    '${album.artist} • ${album.year}',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: LyraSpacing.xs),

                  // Track Count
                  Text(
                    '${album.trackCount} tracks',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted, fontSize: 11.0),
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
