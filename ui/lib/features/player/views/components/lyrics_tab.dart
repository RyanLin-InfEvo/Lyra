// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/contracts/lyra_contracts.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../../design_system/widgets/lyra_button.dart';
import '../../controllers/playback_queue_controller.dart';
import '../../models/lyrics.dart';

/// Lyrics tab component displaying synced or plain lyrics with auto-scrolling,
/// active line highlighting, manual scroll detection, and empty state.
class LyricsTab extends StatefulWidget {
  final LyricsData? lyrics;
  final PlaybackQueueController playbackController;
  final VoidCallback? onReloadLyrics;

  const LyricsTab({
    super.key,
    required this.playbackController,
    this.lyrics,
    this.onReloadLyrics,
  });

  @override
  State<LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends State<LyricsTab> {
  late final ScrollController _scrollController;
  List<GlobalKey> _lineKeys = [];
  Timer? _userScrollTimer;
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;
  int _lastActiveIndex = -1;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initKeys();
  }

  void _initKeys() {
    final count = widget.lyrics?.lines.length ?? 0;
    _lineKeys = List.generate(count, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant LyricsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _initKeys();
      _lastActiveIndex = -1;
    }
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLineTap(LyricsLine line) {
    final current = widget.playbackController.currentTrack;
    if (!widget.playbackController.isPlaying && current != null) {
      widget.playbackController.play(current);
    }
    widget.playbackController.seek(line.timestamp);

    _isUserScrolling = false;
    _userScrollTimer?.cancel();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isAutoScrolling) {
      return false;
    }

    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _handleUserScroll();
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _handleUserScroll();
    }
    return false;
  }

  void _handleUserScroll() {
    _isUserScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
        _scrollToActiveLine(_lastActiveIndex);
      }
    });
  }

  void _scrollToActiveLine(int index) {
    if (!mounted ||
        _isUserScrolling ||
        index < 0 ||
        index >= _lineKeys.length) {
      return;
    }

    final keyContext = _lineKeys[index].currentContext;
    if (keyContext == null || !_scrollController.hasClients) {
      return;
    }

    final box = keyContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) {
      return;
    }

    final revealedOffset = viewport.getOffsetToReveal(box, 0.5).offset;
    final minScroll = _scrollController.position.minScrollExtent;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = revealedOffset.clamp(minScroll, maxScroll);

    if ((_scrollController.offset - targetOffset).abs() > 1.0) {
      _isAutoScrolling = true;
      _scrollController
          .animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            _isAutoScrolling = false;
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final lyrics = widget.lyrics;

    return RepaintBoundary(
      child: Container(
        color: tokens.background,
        child: lyrics == null || lyrics.lines.isEmpty
            ? _buildEmptyState(tokens)
            : lyrics.isSynced
            ? _buildSyncedLyrics(tokens, lyrics)
            : _buildUnsyncedLyrics(tokens, lyrics),
      ),
    );
  }

  Widget _buildEmptyState(LyraThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LyraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.secondary,
                border: Border.all(color: tokens.border, width: 1.0),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.mic,
                  size: 28.0,
                  color: tokens.textMuted,
                ),
              ),
            ),
            const SizedBox(height: LyraSpacing.lg),
            Text(
              'No lyrics available',
              style: LyraTypography.h4(
                tokens,
              ).copyWith(fontWeight: FontWeight.w600, color: tokens.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              '暫無歌詞',
              style: LyraTypography.muted(tokens),
              textAlign: TextAlign.center,
            ),
            if (widget.onReloadLyrics != null) ...[
              const SizedBox(height: LyraSpacing.lg),
              LyraButton.outline(
                size: LyraButtonSize.sm,
                onPressed: widget.onReloadLyrics,
                leading: Icon(
                  LucideIcons.refreshCw,
                  size: 14.0,
                  color: tokens.text,
                ),
                child: Text(
                  'Reload lyrics',
                  style: LyraTypography.small(tokens),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedLyrics(LyraThemeTokens tokens, LyricsData lyrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = (constraints.maxHeight / 2) - 40.0;
        final safeVerticalPadding = verticalPadding > 100.0
            ? verticalPadding
            : 100.0;

        return ValueListenableBuilder<Duration>(
          valueListenable: widget.playbackController.positionNotifier,
          builder: (context, currentPosition, _) {
            final activeIndex = lyrics.findActiveIndex(currentPosition);

            if (activeIndex != _lastActiveIndex) {
              _lastActiveIndex = activeIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToActiveLine(activeIndex);
              });
            }

            return NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  vertical: safeVerticalPadding,
                  horizontal: LyraSpacing.xl,
                ),
                itemCount: lyrics.lines.length,
                itemBuilder: (context, index) {
                  final line = lyrics.lines[index];
                  final isActive = index == activeIndex;
                  final isHovered = index == _hoveredIndex;

                  return _buildSyncedLineItem(
                    key: index < _lineKeys.length ? _lineKeys[index] : null,
                    line: line,
                    isActive: isActive,
                    isHovered: isHovered,
                    tokens: tokens,
                    onTap: () => _onLineTap(line),
                    onHover: (hovered) {
                      if (_hoveredIndex != (hovered ? index : null)) {
                        setState(() {
                          _hoveredIndex = hovered ? index : null;
                        });
                      }
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSyncedLineItem({
    Key? key,
    required LyricsLine line,
    required bool isActive,
    required bool isHovered,
    required LyraThemeTokens tokens,
    required VoidCallback onTap,
    required ValueChanged<bool> onHover,
  }) {
    final textColor = isActive
        ? tokens.text
        : isHovered
        ? tokens.text.withValues(alpha: 0.75)
        : tokens.text.withValues(alpha: 0.4);

    final fontSize = isActive ? 22.0 : 17.0;
    final fontWeight = isActive ? FontWeight.bold : FontWeight.w500;

    return MouseRegion(
      key: key,
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: LyraSpacing.md,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
              height: 1.4,
            ),
            child: Text(
              line.text.isEmpty ? '♪' : line.text,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsyncedLyrics(LyraThemeTokens tokens, LyricsData lyrics) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        vertical: LyraSpacing.xl,
        horizontal: LyraSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lyrics.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    line.text,
                    style: LyraTypography.p(tokens).copyWith(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: tokens.text,
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
