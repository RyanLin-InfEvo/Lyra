// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../common/batch_action_toolbar.dart';
import '../models/artist.dart';

/// Responsive grid view of musical artists and ensembles with desktop multi-selection.
class ArtistsView extends StatefulWidget {
  final List<Artist> artists;
  final ValueChanged<Artist>? onArtistSelected;
  final ValueChanged<List<Artist>>? onBatchPlayNext;
  final ValueChanged<List<Artist>>? onBatchAddToQueue;
  final ValueChanged<List<Artist>>? onBatchAddToPlaylist;
  final ValueChanged<List<Artist>>? onBatchAddTag;

  const ArtistsView({
    super.key,
    required this.artists,
    this.onArtistSelected,
    this.onBatchPlayNext,
    this.onBatchAddToQueue,
    this.onBatchAddToPlaylist,
    this.onBatchAddTag,
  });

  @override
  State<ArtistsView> createState() => _ArtistsViewState();
}

class _ArtistsViewState extends State<ArtistsView> {
  final Set<String> _selectedArtistIds = {};
  String? _selectionAnchorId;
  bool _isModifierSelectionActive = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant ArtistsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedArtistIds.removeWhere(
      (id) => !widget.artists.any((a) => a.id == id),
    );
    if (_selectionAnchorId != null &&
        !widget.artists.any((a) => a.id == _selectionAnchorId)) {
      _selectionAnchorId = null;
    }
    if (_selectedArtistIds.isEmpty) {
      _isModifierSelectionActive = false;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool get _hasSelection => _selectedArtistIds.isNotEmpty;

  void _clearSelection() {
    _selectedArtistIds.clear();
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
      if (widget.artists.isNotEmpty) {
        setState(() {
          _selectedArtistIds.clear();
          _selectedArtistIds.addAll(widget.artists.map((a) => a.id));
          _selectionAnchorId ??= widget.artists.first.id;
          _isModifierSelectionActive = true;
        });
        return true;
      }
    }

    return false;
  }

  void _handleArtistTap(Artist artist) {
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
      final clickedIndex = widget.artists.indexWhere((a) => a.id == artist.id);
      if (clickedIndex != -1) {
        int anchorIndex = -1;
        if (_selectionAnchorId != null) {
          anchorIndex = widget.artists.indexWhere(
            (a) => a.id == _selectionAnchorId,
          );
        }
        if (anchorIndex == -1) {
          anchorIndex = 0;
          _selectionAnchorId = widget.artists.isNotEmpty
              ? widget.artists[0].id
              : artist.id;
        }
        final start = math.min(anchorIndex, clickedIndex);
        final end = math.max(anchorIndex, clickedIndex);
        setState(() {
          _selectedArtistIds.clear();
          for (int i = start; i <= end; i++) {
            _selectedArtistIds.add(widget.artists[i].id);
          }
          _isModifierSelectionActive = true;
        });
      }
      return;
    }

    if (isControlOrMeta) {
      setState(() {
        if (_selectedArtistIds.contains(artist.id)) {
          _selectedArtistIds.remove(artist.id);
        } else {
          _selectedArtistIds.add(artist.id);
        }
        _selectionAnchorId = artist.id;
        _isModifierSelectionActive = true;
      });
      return;
    }

    // Normal Click: calls widget.onArtistSelected and single-selects (does not show toolbar).
    setState(() {
      _selectedArtistIds.clear();
      _selectedArtistIds.add(artist.id);
      _selectionAnchorId = artist.id;
      _isModifierSelectionActive = false;
    });

    widget.onArtistSelected?.call(artist);
  }

  Widget _buildBatchActionToolbar(
    List<Artist> selectedArtists,
    LyraThemeTokens tokens,
  ) {
    return BatchActionToolbar(
      selectedCount: selectedArtists.length,
      onClearSelection: () {
        setState(() {
          _clearSelection();
        });
      },
      onPlayNext: widget.onBatchPlayNext != null
          ? () => widget.onBatchPlayNext!(selectedArtists)
          : null,
      onAddToQueue: widget.onBatchAddToQueue != null
          ? () => widget.onBatchAddToQueue!(selectedArtists)
          : null,
      onAddToPlaylist: widget.onBatchAddToPlaylist != null
          ? () => widget.onBatchAddToPlaylist!(selectedArtists)
          : null,
      onAddTag: widget.onBatchAddTag != null
          ? () => widget.onBatchAddTag!(selectedArtists)
          : null,
      tokens: tokens,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.mic, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No artists found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to populate your artist directory.',
              style: LyraTypography.muted(tokens),
            ),
          ],
        ),
      );
    }

    final selectedArtists = widget.artists
        .where((a) => _selectedArtistIds.contains(a.id))
        .toList();
    final bool showBatchToolbar =
        _selectedArtistIds.isNotEmpty &&
        (_isModifierSelectionActive || _selectedArtistIds.length > 1);

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
                      Text('Artists', style: LyraTypography.h2(tokens)),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${widget.artists.length} performers, composers, and ensembles',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
                  ),
                  const Spacer(),
                  LyraBadge.secondary(
                    child: Text('${widget.artists.length} Artists'),
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
                        childAspectRatio: 0.85,
                      ),
                      itemCount: widget.artists.length,
                      itemBuilder: (context, index) {
                        final artist = widget.artists[index];
                        final isSelected = _selectedArtistIds.contains(
                          artist.id,
                        );
                        return _ArtistCard(
                          artist: artist,
                          isSelected: isSelected,
                          onTap: () => _handleArtistTap(artist),
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
                      ? _buildBatchActionToolbar(selectedArtists, tokens)
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

class _ArtistCard extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;
  final bool isSelected;

  const _ArtistCard({
    required this.artist,
    required this.onTap,
    required this.tokens,
    this.isSelected = false,
  });

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final artist = widget.artist;
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
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
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
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72.0,
                          height: 72.0,
                          decoration: BoxDecoration(
                            color: tokens.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.border,
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.mic,
                              size: 32.0,
                              color: tokens.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: LyraSpacing.md),
                        Text(
                          artist.displayName,
                          style: LyraTypography.h4(tokens),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        if (artist.role != null)
                          LyraBadge.secondary(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            child: Text(
                              artist.role!,
                              style: LyraTypography.small(tokens).copyWith(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Artist',
                            style: LyraTypography.small(
                              tokens,
                            ).copyWith(color: tokens.textMuted),
                          ),
                      ],
                    ),
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
