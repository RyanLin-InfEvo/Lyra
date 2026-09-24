// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/waveform_data.dart';
import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../inspector/audio_inspector_drawer.dart';
import '../../models/track.dart';
import '../../services/music_service.dart';
import '../../settings/services/preferences_service.dart';
import '../controllers/playback_queue_controller.dart';
import '../models/lyrics.dart';
import 'components/lyrics_tab.dart';
import 'components/media_viewport.dart';
import 'components/up_next_tab.dart';
import 'components/waveform_scrubber.dart';

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
  final PreferencesService? preferencesService;
  final ValueNotifier<int>? selectedTabNotifier;
  final int initialTabIndex;
  final ValueChanged<int>? onTabSelected;
  final void Function(Track track)? onAddToPlaylist;
  final void Function(Track track)? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;

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
    this.preferencesService,
    this.selectedTabNotifier,
    this.initialTabIndex = 0,
    this.onTabSelected,
    this.onAddToPlaylist,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  State<NowPlayingView> createState() => _NowPlayingViewState();
}

class _NowPlayingViewState extends State<NowPlayingView> {
  late final FocusNode _focusNode;
  late int _selectedTabIndex;
  bool _isFavorite = false;

  WaveformData? _waveform;
  String? _lastLoadedTrackKey;
  int _waveformCallId = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _selectedTabIndex =
        widget.selectedTabNotifier?.value ?? widget.initialTabIndex;
    widget.playbackController.addListener(_onPlaybackChanged);
    widget.selectedTabNotifier?.addListener(_onTabNotifierChanged);
    widget.preferencesService?.addListener(_onPreferencesChanged);
    _loadWaveformIfNeeded();
    if (widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _onPreferencesChanged() {
    if (mounted) {
      _loadWaveformIfNeeded();
      setState(() {});
    }
  }

  void _onPlaybackChanged() {
    if (mounted) {
      _loadWaveformIfNeeded();
      setState(() {});
    }
  }

  void _loadWaveformIfNeeded() {
    final showWaveform =
        widget.preferencesService?.showNowPlayingWaveform ?? true;
    if (!showWaveform) {
      if (_waveform != null) {
        setState(() {
          _waveform = null;
          _lastLoadedTrackKey = null;
        });
      }
      return;
    }

    final track = widget.track ?? widget.playbackController.currentTrack;
    if (track == null) {
      if (_waveform != null) {
        setState(() {
          _waveform = null;
          _lastLoadedTrackKey = null;
        });
      }
      return;
    }

    final key = track.pcmHash.isNotEmpty ? track.pcmHash : track.id;
    if (key.isEmpty) return;
    if (key == _lastLoadedTrackKey && _waveform != null) return;

    _lastLoadedTrackKey = key;
    final service = widget.musicService;
    if (service == null) {
      setState(() {
        _waveform = null;
      });
      return;
    }

    final points = widget.preferencesService?.nowPlayingWaveformPoints ?? 140;
    final callId = ++_waveformCallId;
    service
        .getWaveform(key, points: points)
        .then((wf) {
          if (!mounted || callId != _waveformCallId) return;
          setState(() {
            _waveform = wf;
          });
        })
        .catchError((_) {
          if (!mounted || callId != _waveformCallId) return;
          setState(() {
            _waveform = null;
          });
        });
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
    if (oldWidget.preferencesService != widget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      _loadWaveformIfNeeded();
    }
    if (oldWidget.track != widget.track ||
        oldWidget.playbackController != widget.playbackController ||
        oldWidget.musicService != widget.musicService) {
      _loadWaveformIfNeeded();
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
    widget.preferencesService?.removeListener(_onPreferencesChanged);
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
                          key: const ValueKey('now_playing_split_column'),
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildLeftMediaPane(tokens),
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
                          // Left Pane: Media Viewport & Waveform Scrubber
                          Expanded(flex: 2, child: _buildLeftMediaPane(tokens)),

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

  Widget _buildLeftMediaPane(LyraThemeTokens tokens) {
    final showWaveform =
        widget.preferencesService?.showNowPlayingWaveform ?? true;

    return Column(
      children: [
        Expanded(
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
        if (showWaveform)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LyraSpacing.lg,
              0,
              LyraSpacing.lg,
              LyraSpacing.md,
            ),
            child: _buildWaveformScrubber(tokens),
          ),
      ],
    );
  }

  Widget _buildWaveformScrubber(LyraThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.md,
        vertical: LyraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: LyraRadius.lgRadius,
        border: Border.all(color: tokens.border, width: 1.0),
      ),
      child: WaveformScrubber(
        waveform: _waveform,
        playbackController: widget.playbackController,
        height: 56.0,
        enablePulseAnimation:
            widget.preferencesService?.nowPlayingWaveformPulseAnimation ?? true,
        enableHoverTimeGuide:
            widget.preferencesService?.nowPlayingWaveformHoverTimeGuide ?? true,
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
              fit: StackFit.expand,
              alignment: Alignment.topCenter,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              key: ValueKey<Key?>(child.key),
              opacity: animation,
              child: child,
            ),
            child: _selectedTabIndex == 0
                ? SizedBox.expand(
                    key: const ValueKey('up_next_tab'),
                    child: UpNextTab(
                      playbackController: widget.playbackController,
                      queueSource: widget.queueSource,
                      onAddToPlaylist: widget.onAddToPlaylist,
                      onInspectAudio: widget.onInspectAudio,
                      onGoToAlbum: widget.onGoToAlbum,
                      onGoToArtist: widget.onGoToArtist,
                    ),
                  )
                : _selectedTabIndex == 1
                ? SizedBox.expand(
                    key: const ValueKey('lyrics_tab'),
                    child: LyricsTab(
                      lyrics: effectiveLyrics,
                      playbackController: widget.playbackController,
                    ),
                  )
                : SizedBox.expand(
                    key: const ValueKey('inspector_tab'),
                    child: AudioInspectorContent(
                      track: widget.track,
                      musicService: widget.musicService,
                      playbackController: widget.playbackController,
                      preferencesService: widget.preferencesService,
                    ),
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
