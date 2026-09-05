// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../models/track.dart';
import '../controllers/playback_queue_controller.dart';
import 'components/media_viewport.dart';
import 'components/up_next_tab.dart';

/// YouTube Music-style full Now Playing view with split-view layout:
/// - Left: Media viewport (Song artwork vs Video theater surface).
/// - Right: Tabbed container (Up Next queue and Lyrics placeholder).
class NowPlayingView extends StatefulWidget {
  final Track? track;
  final PlaybackQueueController playbackController;
  final VoidCallback onCollapse;
  final String? queueSource;
  final double? videoAspectRatio;
  final Widget? customVideoPlayer;
  final String? videoTag;

  const NowPlayingView({
    super.key,
    required this.track,
    required this.playbackController,
    required this.onCollapse,
    this.queueSource,
    this.videoAspectRatio,
    this.customVideoPlayer,
    this.videoTag,
  });

  @override
  State<NowPlayingView> createState() => _NowPlayingViewState();
}

class _NowPlayingViewState extends State<NowPlayingView> {
  late final FocusNode _focusNode;
  int _selectedTabIndex = 0; // 0: Up Next, 1: Lyrics
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.playbackController.addListener(_onPlaybackChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant NowPlayingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController.removeListener(_onPlaybackChanged);
      widget.playbackController.addListener(_onPlaybackChanged);
    }
  }

  @override
  void dispose() {
    widget.playbackController.removeListener(_onPlaybackChanged);
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCollapse();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: RepaintBoundary(
        child: Container(
          color: tokens.background,
          child: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Collapse Button + View Title)
                Container(
                  height: 56.0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LyraSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    border: Border(
                      bottom: BorderSide(color: tokens.border, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Collapse Button
                      LyraButton.ghost(
                        size: LyraButtonSize.sm,
                        onPressed: widget.onCollapse,
                        leading: Icon(
                          LucideIcons.chevronDown,
                          size: 20.0,
                          color: tokens.text,
                        ),
                        child: Text(
                          'Collapse',
                          style: LyraTypography.small(
                            tokens,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),

                      const Spacer(),

                      // Title
                      Text(
                        'Now Playing',
                        style: LyraTypography.h4(
                          tokens,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),

                      const Spacer(),

                      // Right Spacer to balance collapse button width
                      const SizedBox(width: 80.0),
                    ],
                  ),
                ),

                // Split-View Body (Left: Media Viewport, Right: Up Next & Lyrics)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 780;

                      if (isStacked) {
                        // Narrow screen vertical stacked fallback
                        return Column(
                          children: [
                            Expanded(
                              flex: 2,
                              child: MediaViewport(
                                track: widget.track,
                                playbackController: widget.playbackController,
                                isFavorite: _isFavorite,
                                onToggleFavorite: () {
                                  setState(() => _isFavorite = !_isFavorite);
                                },
                                videoAspectRatio: widget.videoAspectRatio,
                                customVideoPlayer: widget.customVideoPlayer,
                                videoTag: widget.videoTag,
                              ),
                            ),
                            Container(height: 1.0, color: tokens.border),
                            Expanded(
                              flex: 1,
                              child: _buildRightTabContainer(tokens),
                            ),
                          ],
                        );
                      }

                      // Wide screen desktop split-view
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Pane: Media Viewport
                          Expanded(
                            flex: 2,
                            child: MediaViewport(
                              track: widget.track,
                              playbackController: widget.playbackController,
                              isFavorite: _isFavorite,
                              onToggleFavorite: () {
                                setState(() => _isFavorite = !_isFavorite);
                              },
                              videoAspectRatio: widget.videoAspectRatio,
                              customVideoPlayer: widget.customVideoPlayer,
                              videoTag: widget.videoTag,
                            ),
                          ),

                          // Vertical Divider
                          Container(width: 1.0, color: tokens.border),

                          // Right Pane: Tabbed Container (Up Next / Lyrics)
                          Expanded(
                            flex: 1,
                            child: _buildRightTabContainer(tokens),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightTabContainer(LyraThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs Header (Up Next vs Lyrics)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.md,
            vertical: LyraSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.border, width: 1.0),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabHeaderButton(
                  index: 0,
                  label: 'Up Next',
                  icon: LucideIcons.listMusic,
                  tokens: tokens,
                ),
                const SizedBox(width: LyraSpacing.sm),
                _buildTabHeaderButton(
                  index: 1,
                  label: 'Lyrics',
                  icon: LucideIcons.quote,
                  tokens: tokens,
                ),
              ],
            ),
          ),
        ),

        // Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedTabIndex == 0
                ? UpNextTab(
                    key: const ValueKey('up_next_tab'),
                    playbackController: widget.playbackController,
                    queueSource: widget.queueSource,
                  )
                : _buildLyricsPlaceholder(tokens),
          ),
        ),
      ],
    );
  }

  Widget _buildTabHeaderButton({
    required int index,
    required String label,
    required IconData icon,
    required LyraThemeTokens tokens,
  }) {
    final isSelected = _selectedTabIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_selectedTabIndex != index) {
            setState(() => _selectedTabIndex = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.md,
            vertical: 6.0,
          ),
          decoration: BoxDecoration(
            color: isSelected ? tokens.secondary : const Color(0x00000000),
            borderRadius: LyraRadius.mdRadius,
            border: isSelected
                ? Border.all(color: tokens.border, width: 1.0)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.0,
                color: isSelected ? tokens.text : tokens.textMuted,
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: LyraTypography.small(tokens).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? tokens.text : tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsPlaceholder(LyraThemeTokens tokens) {
    return Center(
      key: const ValueKey('lyrics_placeholder'),
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
                  LucideIcons.quote,
                  size: 28.0,
                  color: tokens.textMuted,
                ),
              ),
            ),
            const SizedBox(height: LyraSpacing.lg),
            Text(
              '歌詞功能將於下一階段推出',
              style: LyraTypography.h3(
                tokens,
              ).copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Lyrics will be available in Phase 3',
              style: LyraTypography.muted(
                tokens,
              ).copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LyraSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320.0),
              child: Text(
                '即時動態歌詞同步與時間軸對齊引擎正在開發中。',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
