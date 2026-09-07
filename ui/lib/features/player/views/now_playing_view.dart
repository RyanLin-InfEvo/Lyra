// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../inspector/audio_inspector_drawer.dart';
import '../../models/track.dart';
import '../../services/music_service.dart';
import '../controllers/playback_queue_controller.dart';
import '../models/lyrics.dart';
import 'components/lyrics_tab.dart';
import 'components/media_viewport.dart';
import 'components/up_next_tab.dart';

/// YouTube Music-style full Now Playing view with split-view layout:
/// - Left: Media viewport (Song artwork vs Video theater surface).
/// - Right: Tabbed container (Up Next queue, Lyrics tab, and Audio Inspector tab).
class NowPlayingView extends StatefulWidget {
  final Track? track;
  final PlaybackQueueController playbackController;
  final VoidCallback onCollapse;
  final String? queueSource;
  final double? videoAspectRatio;
  final Widget? customVideoPlayer;
  final String? videoTag;
  final LyricsData? lyrics;
  final bool isExpanded;
  final MusicService? musicService;
  final ValueNotifier<int>? selectedTabNotifier;
  final int initialTabIndex;
  final ValueChanged<int>? onTabSelected;

  const NowPlayingView({
    super.key,
    required this.track,
    required this.playbackController,
    required this.onCollapse,
    this.queueSource,
    this.videoAspectRatio,
    this.customVideoPlayer,
    this.videoTag,
    this.lyrics,
    this.isExpanded = true,
    this.musicService,
    this.selectedTabNotifier,
    this.initialTabIndex = 0,
    this.onTabSelected,
  });

  @override
  State<NowPlayingView> createState() => _NowPlayingViewState();
}

class _NowPlayingViewState extends State<NowPlayingView> {
  late final FocusNode _focusNode;
  late int _selectedTabIndex;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _selectedTabIndex =
        widget.selectedTabNotifier?.value ?? widget.initialTabIndex;
    widget.playbackController.addListener(_onPlaybackChanged);
    widget.selectedTabNotifier?.addListener(_onTabNotifierChanged);
    if (widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTabNotifierChanged() {
    if (mounted && widget.selectedTabNotifier != null) {
      if (_selectedTabIndex != widget.selectedTabNotifier!.value) {
        setState(() {
          _selectedTabIndex = widget.selectedTabNotifier!.value;
        });
      }
    }
  }

  void _setTabIndex(int index) {
    if (_selectedTabIndex != index) {
      setState(() => _selectedTabIndex = index);
      if (widget.selectedTabNotifier != null &&
          widget.selectedTabNotifier!.value != index) {
        widget.selectedTabNotifier!.value = index;
      }
      widget.onTabSelected?.call(index);
    }
  }

  @override
  void didUpdateWidget(covariant NowPlayingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController.removeListener(_onPlaybackChanged);
      widget.playbackController.addListener(_onPlaybackChanged);
    }
    if (oldWidget.selectedTabNotifier != widget.selectedTabNotifier) {
      oldWidget.selectedTabNotifier?.removeListener(_onTabNotifierChanged);
      widget.selectedTabNotifier?.addListener(_onTabNotifierChanged);
      if (widget.selectedTabNotifier != null) {
        _selectedTabIndex = widget.selectedTabNotifier!.value;
      }
    }
    if (!oldWidget.isExpanded && widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    } else if (oldWidget.isExpanded && !widget.isExpanded) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    widget.selectedTabNotifier?.removeListener(_onTabNotifierChanged);
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

    return RepaintBoundary(
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.isExpanded,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          color: tokens.background,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Split-View Body (Left: Media Viewport, Right: Up Next & Lyrics)
                Positioned.fill(
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

                // Floating Collapse Button (Top-Left)
                Positioned(
                  top: LyraSpacing.md,
                  left: LyraSpacing.md,
                  child: LyraButton.ghost(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final Map<String, LyricsData> _sampleLyricsCache = {};

  LyricsData? _getSampleLyricsForTrack(Track? track) {
    if (track == null) return null;
    final cached = _sampleLyricsCache[track.id];
    if (cached != null) return cached;

    if (_sampleLyricsCache.length > 100) {
      _sampleLyricsCache.remove(_sampleLyricsCache.keys.first);
    }

    final parsed = LyricsData.fromLrc('''
[00:00.00]${track.title} - ${track.artist}
[00:04.00]Soundwaves drifting through the digital sea
[00:10.00]Every frequency aligning in place
[00:16.00]Melodies echoing across cyberspace
[00:22.00]Bit-perfect playback, crystal clear
[00:28.00]Feel the rhythm in your soul
[00:34.00]Let the music take control
[00:40.00]Lyra audio engine in harmony
''');
    _sampleLyricsCache[track.id] = parsed;
    return parsed;
  }

  Widget _buildRightTabContainer(LyraThemeTokens tokens) {
    final effectiveLyrics =
        widget.lyrics ?? _getSampleLyricsForTrack(widget.track);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs Header (Up Next vs Lyrics vs Inspector)
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
                const SizedBox(width: LyraSpacing.sm),
                _buildTabHeaderButton(
                  index: 2,
                  label: 'Details',
                  icon: LucideIcons.fileSearch,
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
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              key: ValueKey<Key?>(child.key),
              opacity: animation,
              child: child,
            ),
            child: _selectedTabIndex == 0
                ? UpNextTab(
                    key: const ValueKey('up_next_tab'),
                    playbackController: widget.playbackController,
                    queueSource: widget.queueSource,
                  )
                : _selectedTabIndex == 1
                ? LyricsTab(
                    key: const ValueKey('lyrics_tab'),
                    lyrics: effectiveLyrics,
                    playbackController: widget.playbackController,
                  )
                : AudioInspectorContent(
                    key: const ValueKey('inspector_tab'),
                    track: widget.track,
                    musicService: widget.musicService,
                  ),
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
        behavior: HitTestBehavior.opaque,
        onTap: () => _setTabIndex(index),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.sm,
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
}
