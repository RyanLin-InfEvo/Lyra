// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final ValueListenable<Duration>? positionNotifier;
  final VoidCallback? onReloadLyrics;

  const LyricsTab({
    super.key,
    required this.playbackController,
    this.positionNotifier,
    this.lyrics,
    this.onReloadLyrics,
  });

  @override
  State<LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends State<LyricsTab> {
  late final ScrollController _scrollController;
  final ValueNotifier<int> _activeIndexNotifier = ValueNotifier<int>(-1);

  ValueListenable<Duration> get _positionNotifier =>
      widget.positionNotifier ?? widget.playbackController.positionNotifier;

  List<GlobalKey> _lineKeys = [];
  Timer? _userScrollTimer;
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initKeys();
    final initialIndex =
        widget.lyrics?.findActiveIndex(_positionNotifier.value) ?? -1;
    _activeIndexNotifier.value = initialIndex;
    _lastActiveIndex = initialIndex;
    _positionNotifier.addListener(_onPositionChanged);
    if (initialIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(initialIndex);
      });
    }
  }

  void _initKeys() {
    final count = widget.lyrics?.lines.length ?? 0;
    _lineKeys = List.generate(count, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant LyricsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier =
        oldWidget.positionNotifier ??
        oldWidget.playbackController.positionNotifier;
    if (oldNotifier != _positionNotifier) {
      oldNotifier.removeListener(_onPositionChanged);
      _positionNotifier.addListener(_onPositionChanged);
    }
    if (oldWidget.lyrics != widget.lyrics) {
      _initKeys();
      final newIndex =
          widget.lyrics?.findActiveIndex(_positionNotifier.value) ?? -1;
      _activeIndexNotifier.value = newIndex;
      _lastActiveIndex = newIndex;
      if (newIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActiveLine(newIndex);
        });
      }
    }
  }

  @override
  void dispose() {
    _positionNotifier.removeListener(_onPositionChanged);
    _activeIndexNotifier.dispose();
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    final lyrics = widget.lyrics;
    if (lyrics == null || !lyrics.isSynced) return;
    final newActiveIndex = lyrics.findActiveIndex(_positionNotifier.value);
    if (newActiveIndex != _activeIndexNotifier.value) {
      _activeIndexNotifier.value = newActiveIndex;
      _lastActiveIndex = newActiveIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(newActiveIndex);
      });
    }
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
        _isUserScrolling = false;
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
              return _SyncedLineItem(
                key: index < _lineKeys.length ? _lineKeys[index] : null,
                line: line,
                index: index,
                activeIndexNotifier: _activeIndexNotifier,
                tokens: tokens,
                onTap: () => _onLineTap(line),
              );
            },
          ),
        );
      },
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

/// Efficient synced lyric line item that listens to active index progression
/// and manages its own hover state without causing full-list rebuilds.
class _SyncedLineItem extends StatefulWidget {
  final LyricsLine line;
  final int index;
  final ValueListenable<int> activeIndexNotifier;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;

  const _SyncedLineItem({
    super.key,
    required this.line,
    required this.index,
    required this.activeIndexNotifier,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_SyncedLineItem> createState() => _SyncedLineItemState();
}

class _SyncedLineItemState extends State<_SyncedLineItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.activeIndexNotifier,
      builder: (context, activeIndex, _) {
        final isActive = widget.index == activeIndex;
        final textColor = isActive
            ? widget.tokens.text
            : _isHovered
            ? widget.tokens.text.withValues(alpha: 0.75)
            : widget.tokens.text.withValues(alpha: 0.4);

        final fontSize = isActive ? 22.0 : 17.0;
        final fontWeight = isActive ? FontWeight.bold : FontWeight.w500;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
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
                  widget.line.text.isEmpty ? '♪' : widget.line.text,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
