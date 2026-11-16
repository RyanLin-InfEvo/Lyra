// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart'
    show
        ClampingScrollPhysics,
        Material,
        ReorderableDragStartListener,
        ReorderableListView;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_checkbox.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../widgets/draggable_columns_overlay.dart';
import '../../widgets/threshold_reorderable_drag_start_listener.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../settings/services/preferences_service.dart';
import '../tracks/tracks_view.dart';
import 'context_menu_coordinator.dart';

/// Formats a [DateTime] concisely in `YYYY-MM-DD` form for metadata summaries.
String formatMetadataDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Formats the summed duration of [tracks] into a human-readable summary string.
String formatCollectionDuration(List<Track> tracks) {
  final totalMs = tracks.fold<int>(
    0,
    (sum, track) => sum + (track.durationMs ?? 0),
  );
  if (totalMs <= 0) return '0 min';
  final totalSeconds = totalMs ~/ 1000;
  final totalMinutes = totalSeconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final remainingMinutes = totalMinutes % 60;

  if (hours > 0) {
    if (remainingMinutes > 0) {
      return '$hours hr $remainingMinutes min';
    }
    return '$hours hr';
  }
  if (totalMinutes > 0) {
    return '$totalMinutes min';
  }
  return '$totalSeconds sec';
}

/// Shared detail-page layout for playlists, artists, albums, and tags.
///
/// Renders a hero metadata header (back button, artwork, eyebrow label, title,
/// optional clickable subtitle/description, metadata summary line, Play/Shuffle
/// actions), an optional [middleSection] (such as an artist's album shelf),
/// and a customizable, keyboard-navigable track table with context menus.
class CollectionDetailView extends StatefulWidget {
  final String entityId;
  final String keyPrefix;
  final String backLabel;
  final String eyebrowLabel;
  final String title;
  final String? description;
  final String? subtitle;
  final VoidCallback? onSubtitleTap;
  final List<String> metadataItems;
  final IconData artworkIcon;
  final Color? artworkAccentColor;
  final WidgetBuilder? artworkBuilder;
  final List<Widget> extraHeaderActions;
  final Widget? middleSection;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool allowReorder;
  final bool usePlaylistColumnPreferences;
  final Set<TrackColumn> defaultVisibleColumns;

  final List<Track> tracks;
  final VoidCallback onBack;
  final PlaybackQueueController? playbackController;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffleAll;
  final ValueChanged<Track>? onTrackSelected;
  final ValueChanged<Track>? onPlayNext;
  final ValueChanged<Track>? onAddToQueue;
  final void Function(int index, Track track)? onRemoveTrack;
  final String removeTrackLabel;
  final void Function(int oldIndex, int newIndex)? onReorderTracks;
  final ValueChanged<Track>? onInspectAudio;
  final ValueChanged<Track>? onTrackFocus;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final Track? currentTrack;
  final bool isPlaying;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;
  final PreferencesService? preferencesService;
  final TrackActivationMode? trackActivationMode;
  final VoidCallback? onTogglePlay;
  final bool isNowPlayingExpanded;
  final TrackListViewMode? viewMode;
  final bool? showHeader;

  const CollectionDetailView({
    super.key,
    required this.entityId,
    required this.keyPrefix,
    required this.backLabel,
    required this.eyebrowLabel,
    required this.title,
    this.description,
    this.subtitle,
    this.onSubtitleTap,
    this.metadataItems = const [],
    required this.artworkIcon,
    this.artworkAccentColor,
    this.artworkBuilder,
    this.extraHeaderActions = const [],
    this.middleSection,
    this.emptyIcon = LucideIcons.music,
    this.emptyTitle = 'No tracks found',
    this.emptySubtitle = 'This collection does not contain any tracks yet.',
    this.allowReorder = false,
    this.usePlaylistColumnPreferences = false,
    required this.defaultVisibleColumns,
    required this.tracks,
    required this.onBack,
    this.playbackController,
    this.onPlayAll,
    this.onShuffleAll,
    this.onTrackSelected,
    this.onPlayNext,
    this.onAddToQueue,
    this.onRemoveTrack,
    this.removeTrackLabel = 'Remove from Playlist',
    this.onReorderTracks,
    this.onInspectAudio,
    this.onTrackFocus,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.currentTrack,
    this.isPlaying = false,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
    this.preferencesService,
    this.trackActivationMode,
    this.onTogglePlay,
    this.isNowPlayingExpanded = false,
    this.viewMode,
    this.showHeader,
  });

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  late List<TrackColumn> _internalColumnOrder;
  late Set<TrackColumn> _internalVisibleColumns;
  late TrackListViewMode _localViewMode;
  late bool _localShowHeader;
  late final OverlayPortalController _columnsOverlayController;
  late final ValueNotifier<Offset> _columnsPositionNotifier;
  String? _selectedTrackId;
  int? _selectedTrackIndex;

  TrackActivationMode get _effectiveActivationMode =>
      widget.trackActivationMode ??
      widget.preferencesService?.trackActivationMode ??
      TrackActivationMode.doubleClick;

  TrackListViewMode get _effectiveViewMode => widget.viewMode ?? _localViewMode;
  bool get _effectiveShowHeader => widget.showHeader ?? _localShowHeader;

  void _syncColumnsFromPreferences() {
    if (!widget.usePlaylistColumnPreferences) return;
    final prefs = widget.preferencesService;
    if (prefs == null) return;
    final colMap = {for (final c in TrackColumn.values) c.name: c};
    if (widget.columnOrder == null) {
      final savedOrder = prefs.getPlaylistColumnOrder();
      _internalColumnOrder = savedOrder != null
          ? normalizeTrackColumnOrder(
              savedOrder
                  .map((n) => colMap[n])
                  .whereType<TrackColumn>()
                  .toList(),
            )
          : List<TrackColumn>.from(TrackColumn.values);
    }
    if (widget.visibleColumns == null) {
      final savedVisible = prefs.getPlaylistVisibleColumns();
      _internalVisibleColumns = savedVisible != null
          ? normalizeTrackVisibleColumns(
              savedVisible
                  .map((n) => colMap[n])
                  .whereType<TrackColumn>()
                  .toSet(),
              defaults: widget.defaultVisibleColumns,
            )
          : Set<TrackColumn>.from(widget.defaultVisibleColumns);
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    widget.preferencesService?.addListener(_onPreferencesChanged);
    _columnsOverlayController = OverlayPortalController();
    _columnsPositionNotifier = ValueNotifier<Offset>(Offset.zero);
    _localViewMode =
        widget.viewMode ??
        widget.preferencesService?.playlistViewMode ??
        TrackListViewMode.detail;
    _localShowHeader =
        widget.showHeader ??
        widget.preferencesService?.showPlaylistHeader ??
        true;
    _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    _syncColumnsFromPreferences();
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.viewMode == null && widget.preferencesService != null) {
        _localViewMode = widget.preferencesService!.playlistViewMode;
      }
      if (widget.showHeader == null && widget.preferencesService != null) {
        _localShowHeader = widget.preferencesService!.showPlaylistHeader;
      }
      _syncColumnsFromPreferences();
    });
  }

  @override
  void didUpdateWidget(covariant CollectionDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferencesService != oldWidget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      if (widget.viewMode == null && widget.preferencesService != null) {
        _localViewMode = widget.preferencesService!.playlistViewMode;
      }
      if (widget.showHeader == null && widget.preferencesService != null) {
        _localShowHeader = widget.preferencesService!.showPlaylistHeader;
      }
      _syncColumnsFromPreferences();
    }
    if (widget.viewMode != null && widget.viewMode != oldWidget.viewMode) {
      _localViewMode = widget.viewMode!;
    }
    if (widget.showHeader != null &&
        widget.showHeader != oldWidget.showHeader) {
      _localShowHeader = widget.showHeader!;
    }
    if (widget.columnOrder != null &&
        widget.columnOrder != oldWidget.columnOrder) {
      _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    }
    if (widget.visibleColumns != null &&
        widget.visibleColumns != oldWidget.visibleColumns) {
      _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    } else if (oldWidget.defaultVisibleColumns !=
            widget.defaultVisibleColumns &&
        widget.visibleColumns == null &&
        !widget.usePlaylistColumnPreferences) {
      _internalVisibleColumns = _normalizeVisibleColumns(null);
    }
    if (oldWidget.entityId != widget.entityId) {
      _selectedTrackId = null;
      _selectedTrackIndex = null;
    } else if (_selectedTrackId != null) {
      final idx = widget.tracks.indexWhere((t) => t.id == _selectedTrackId);
      if (idx == -1) {
        _selectedTrackId = null;
        _selectedTrackIndex = null;
      } else {
        _selectedTrackIndex = idx;
      }
    } else if (_selectedTrackIndex != null &&
        _selectedTrackIndex! >= widget.tracks.length) {
      _selectedTrackIndex = null;
    }
  }

  @override
  void dispose() {
    widget.preferencesService?.removeListener(_onPreferencesChanged);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _columnsPositionNotifier.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        widget.isNowPlayingExpanded) {
      return false;
    }

    final primaryFocusContext = FocusManager.instance.primaryFocus?.context;
    if (primaryFocusContext != null) {
      final isEditingText =
          primaryFocusContext.findAncestorWidgetOfExactType<EditableText>() !=
          null;
      if (isEditingText) {
        return false;
      }
      final isActionableButton =
          primaryFocusContext.findAncestorWidgetOfExactType<LyraButton>() !=
              null ||
          primaryFocusContext.findAncestorWidgetOfExactType<ShadButton>() !=
              null;
      if (isActionableButton) {
        return false;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (LyraContextMenuCoordinator.hideActive()) {
        return true;
      }
      if (_selectedTrackId != null || _selectedTrackIndex != null) {
        setState(() {
          _selectedTrackId = null;
          _selectedTrackIndex = null;
        });
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      Track? trackToPlay;
      if (_selectedTrackId != null) {
        for (final t in widget.tracks) {
          if (t.id == _selectedTrackId) {
            trackToPlay = t;
            break;
          }
        }
      }
      if (trackToPlay == null &&
          _selectedTrackIndex != null &&
          _selectedTrackIndex! < widget.tracks.length) {
        trackToPlay = widget.tracks[_selectedTrackIndex!];
      }
      if (trackToPlay != null) {
        LyraContextMenuCoordinator.hideActive();
        _handlePlayTrack(trackToPlay);
        return true;
      }
    }

    return false;
  }

  void _handleTrackTap(int index, Track track) {
    setState(() {
      _selectedTrackId = track.id;
      _selectedTrackIndex = index;
    });

    if (_effectiveActivationMode == TrackActivationMode.singleClick) {
      final isCurrent = widget.currentTrack?.id == track.id;
      if (isCurrent) {
        if (widget.onTogglePlay != null) {
          widget.onTogglePlay!();
        } else {
          widget.playbackController?.togglePlay();
        }
      } else {
        _handlePlayTrack(track);
      }
    } else {
      widget.onTrackFocus?.call(track);
    }
  }

  List<TrackColumn> _normalizeColumnOrder(List<TrackColumn>? order) =>
      normalizeTrackColumnOrder(order);

  Set<TrackColumn> _normalizeVisibleColumns(Set<TrackColumn>? visible) =>
      normalizeTrackVisibleColumns(
        visible,
        defaults: widget.defaultVisibleColumns,
      );

  List<TrackColumn> get _effectiveColumnOrder => _internalColumnOrder;
  Set<TrackColumn> get _effectiveVisibleColumns => _internalVisibleColumns;

  void _toggleColumn(TrackColumn column) {
    if (column.isMandatory) return;
    final current = Set<TrackColumn>.from(_internalVisibleColumns);
    if (current.contains(column)) {
      if (current.length > 1) {
        current.remove(column);
      } else {
        return;
      }
    } else {
      current.add(column);
    }
    widget.onVisibleColumnsChanged?.call(current);
    if (widget.onVisibleColumnsChanged == null &&
        widget.usePlaylistColumnPreferences) {
      widget.preferencesService?.setPlaylistVisibleColumns(
        current.map((c) => c.name).toSet(),
      );
    }
    setState(() {
      _internalVisibleColumns = current;
    });
  }

  void _onReorderColumns(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final newOrder = List<TrackColumn>.from(_internalColumnOrder);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    widget.onColumnOrderChanged?.call(newOrder);
    if (widget.onColumnOrderChanged == null &&
        widget.usePlaylistColumnPreferences) {
      widget.preferencesService?.setPlaylistColumnOrder(
        newOrder.map((c) => c.name).toList(),
      );
    }
    setState(() {
      _internalColumnOrder = newOrder;
    });
  }

  void _resetColumns() {
    final defaultOrder = List<TrackColumn>.from(TrackColumn.values);
    final defaultVisible = Set<TrackColumn>.from(widget.defaultVisibleColumns);
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    if (widget.onColumnOrderChanged == null &&
        widget.usePlaylistColumnPreferences) {
      widget.preferencesService?.setPlaylistColumnOrder(
        defaultOrder.map((c) => c.name).toList(),
      );
    }
    if (widget.onVisibleColumnsChanged == null &&
        widget.usePlaylistColumnPreferences) {
      widget.preferencesService?.setPlaylistVisibleColumns(
        defaultVisible.map((c) => c.name).toSet(),
      );
    }
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
    });
  }

  void _handlePlayAll() {
    if (widget.onPlayAll != null) {
      widget.onPlayAll!();
    } else if (widget.playbackController != null && widget.tracks.isNotEmpty) {
      widget.playbackController!.play(
        widget.tracks.first,
        contextQueue: widget.tracks,
      );
    }
  }

  void _handleShuffleAll() {
    if (widget.onShuffleAll != null) {
      widget.onShuffleAll!();
    } else if (widget.playbackController != null && widget.tracks.isNotEmpty) {
      final shuffled = List<Track>.from(widget.tracks)..shuffle();
      widget.playbackController!.play(shuffled.first, contextQueue: shuffled);
    }
  }

  void _handlePlayTrack(Track track) {
    if (widget.onTrackSelected != null) {
      widget.onTrackSelected!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.play(track, contextQueue: widget.tracks);
    }
  }

  void _handlePlayNext(Track track) {
    if (widget.onPlayNext != null) {
      widget.onPlayNext!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.playNext(track);
    }
  }

  void _handleAddToQueue(Track track) {
    if (widget.onAddToQueue != null) {
      widget.onAddToQueue!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.addToQueue(track);
    }
  }

  Widget _proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
    LyraThemeTokens tokens,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        final t = Curves.easeInOut.transform(animation.value);
        return Material(
          color: const Color(0x00000000),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.mdRadius,
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.2 * t),
                  blurRadius: 4.0 + 8.0 * t,
                  offset: Offset(0, 2.0 + 2.0 * t),
                ),
              ],
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.grabbing,
              child: child,
            ),
          ),
        );
      },
    );
  }

  List<String> _resolvedMetadataItems() {
    if (widget.metadataItems.isNotEmpty) {
      return widget.metadataItems;
    }
    return [
      '${widget.tracks.length} ${widget.tracks.length == 1 ? 'track' : 'tracks'}',
      formatCollectionDuration(widget.tracks),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final topContent = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, tokens),
              if (widget.middleSection != null) widget.middleSection!,
            ],
          );

          final Widget boundedTop;
          if (outerConstraints.hasBoundedHeight) {
            final reservedForContent = math.min(
              180.0,
              outerConstraints.maxHeight * 0.45,
            );
            final maxTopHeight = math.max(
              0.0,
              outerConstraints.maxHeight - reservedForContent,
            );
            boundedTop = ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxTopHeight),
              child: SingleChildScrollView(child: topContent),
            );
          } else {
            boundedTop = topContent;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              boundedTop,
              if (widget.tracks.isEmpty)
                _buildEmptyState(tokens)
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final orderedVisible = [
                        for (final col in _effectiveColumnOrder)
                          if (_effectiveVisibleColumns.contains(col)) col,
                      ];
                      final isDetail =
                          _effectiveViewMode == TrackListViewMode.detail;
                      final textScale = math.max(
                        1.0,
                        MediaQuery.textScalerOf(context).scale(1.0),
                      );
                      final requiredWidth = isDetail
                          ? _requiredDetailTableWidth(
                              orderedVisible,
                              textScale: textScale,
                            )
                          : 0.0;
                      final effectiveWidth = isDetail
                          ? math.max(constraints.maxWidth, requiredWidth)
                          : constraints.maxWidth;
                      final needsHorizontalScroll =
                          isDetail && requiredWidth > constraints.maxWidth;

                      final inner = SizedBox(
                        width: effectiveWidth,
                        height: constraints.maxHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTableHeader(tokens, orderedVisible),
                            _buildTracksList(context, tokens),
                          ],
                        ),
                      );

                      if (needsHorizontalScroll) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: inner,
                        );
                      }
                      return inner;
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LyraThemeTokens tokens) {
    final prefix = widget.keyPrefix;
    final hasDescription =
        widget.description != null && widget.description!.trim().isNotEmpty;
    final hasSubtitle =
        widget.subtitle != null && widget.subtitle!.trim().isNotEmpty;
    final metadataItems = _resolvedMetadataItems();

    return GestureDetector(
      key: Key('${prefix}_view_header'),
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => DraggableColumnsOverlay.showAt(
        controller: _columnsOverlayController,
        positionNotifier: _columnsPositionNotifier,
        globalPosition: details.globalPosition,
        context: context,
        estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LyraSpacing.xl,
          vertical: LyraSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LyraButton.ghost(
              key: Key('${prefix}_detail_back_button'),
              size: LyraButtonSize.sm,
              onPressed: widget.onBack,
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.sm,
                vertical: LyraSpacing.xs,
              ),
              leading: const Icon(LucideIcons.arrowLeft, size: 16.0),
              child: Text(widget.backLabel),
            ),
            const SizedBox(height: LyraSpacing.md),
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isCompactHeader = headerConstraints.maxWidth < 420.0;
                final artworkSize = isCompactHeader ? 72.0 : 140.0;
                final artworkBox = Container(
                  width: artworkSize,
                  height: artworkSize,
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: LyraRadius.lgRadius,
                    border: Border.all(color: tokens.border, width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 12.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.artworkBuilder != null
                      ? widget.artworkBuilder!(context)
                      : Center(
                          child: Icon(
                            widget.artworkIcon,
                            size: isCompactHeader ? 32.0 : 56.0,
                            color: widget.artworkAccentColor ?? tokens.primary,
                          ),
                        ),
                );
                final metadataColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.eyebrowLabel,
                      style: LyraTypography.small(tokens).copyWith(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      widget.title,
                      style: LyraTypography.h2(tokens),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 4.0),
                      _buildSubtitle(tokens),
                    ],
                    if (hasDescription) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        widget.description!,
                        style: LyraTypography.muted(tokens),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8.0),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < metadataItems.length; i++) ...[
                          if (i > 0)
                            Text(
                              ' • ',
                              style: LyraTypography.small(
                                tokens,
                              ).copyWith(color: tokens.textMuted),
                            ),
                          Text(
                            metadataItems[i],
                            style: LyraTypography.small(tokens).copyWith(
                              color: tokens.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: LyraSpacing.md),
                    Wrap(
                      spacing: LyraSpacing.sm,
                      runSpacing: LyraSpacing.sm,
                      children: [
                        LyraButton(
                          key: Key('${prefix}_play_all_button'),
                          size: LyraButtonSize.sm,
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : _handlePlayAll,
                          leading: const Icon(LucideIcons.play, size: 16.0),
                          child: const Text('Play All'),
                        ),
                        LyraButton.outline(
                          key: Key('${prefix}_shuffle_all_button'),
                          size: LyraButtonSize.sm,
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : _handleShuffleAll,
                          leading: const Icon(LucideIcons.shuffle, size: 16.0),
                          child: const Text('Shuffle All'),
                        ),
                        ...widget.extraHeaderActions,
                      ],
                    ),
                  ],
                );
                if (isCompactHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      artworkBox,
                      const SizedBox(height: LyraSpacing.md),
                      metadataColumn,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    artworkBox,
                    const SizedBox(width: LyraSpacing.xl),
                    Expanded(child: metadataColumn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(LyraThemeTokens tokens) {
    final style = LyraTypography.p(tokens).copyWith(
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      color: widget.onSubtitleTap != null ? tokens.primary : tokens.textMuted,
    );
    final label = Text(
      widget.subtitle!,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (widget.onSubtitleTap == null) {
      return label;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: Key('${widget.keyPrefix}_detail_subtitle_link'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSubtitleTap,
        child: label,
      ),
    );
  }

  Widget _buildHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    Widget cellContent;
    final headerTextStyle = LyraTypography.small(
      tokens,
    ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.w600);

    if (col == TrackColumn.index) {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          col.headerLabel,
          style: headerTextStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (col == TrackColumn.cover) {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Text(
            col.headerLabel,
            style: headerTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (col == TrackColumn.duration ||
        col == TrackColumn.trackNumber ||
        col == TrackColumn.year) {
      cellContent = Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(
            col.headerLabel,
            style: headerTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(
            col.headerLabel,
            style: headerTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    if (col.width != null) {
      final width = col == TrackColumn.cover ? col.width! : col.width! * scale;
      return SizedBox(width: width, child: cellContent);
    } else {
      return Expanded(flex: col.flex ?? 1, child: cellContent);
    }
  }

  double _requiredDetailTableWidth(
    List<TrackColumn> visibleOrdered, {
    double textScale = 1.0,
  }) {
    if (visibleOrdered.isEmpty) return 0.0;
    final scale = math.max(1.0, textScale);
    var width = LyraSpacing.xl * 2;
    for (final col in visibleOrdered) {
      if (col.width != null) {
        width += col == TrackColumn.cover ? col.width! : col.width! * scale;
      } else {
        width += (col.flex ?? 1) * 32.0 * scale;
      }
    }
    return width;
  }

  Widget _buildListHeaderRow(
    LyraThemeTokens tokens,
    List<TrackColumn> orderedVisible,
  ) {
    final headerTextStyle = LyraTypography.small(
      tokens,
    ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.w600);
    final showIndex = orderedVisible.contains(TrackColumn.index);
    final showCover = orderedVisible.contains(TrackColumn.cover);
    final hasResolution = orderedVisible.contains(TrackColumn.resolution);
    final hasDuration = orderedVisible.contains(TrackColumn.duration);
    final hasTrailing = hasResolution || hasDuration;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final indexWidth = showIndex
            ? math.min(
                (TrackColumn.index.width ?? 40.0) * scale,
                constraints.maxWidth * 0.2,
              )
            : 0.0;
        final leftFixedWidth =
            indexWidth + (showCover ? 52.0 : 0.0) + (hasTrailing ? 12.0 : 0.0);
        final metrics = computeTrackListTrailingMetrics(
          availableRowWidth: constraints.maxWidth,
          leftFixedWidth: leftFixedWidth,
          hasResolution: hasResolution,
          hasDuration: hasDuration,
          textScale: scale,
        );
        final trailingLabels = buildTrackListTrailingHeaderLabels(
          orderedVisibleColumns: orderedVisible,
          metrics: metrics,
          style: headerTextStyle,
        );

        return Row(
          children: [
            if (showIndex)
              SizedBox(
                width: indexWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    TrackColumn.index.headerLabel,
                    style: headerTextStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (showCover)
              SizedBox(
                width: 52.0,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    TrackColumn.cover.headerLabel,
                    style: headerTextStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                'Title & Details',
                style: headerTextStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingLabels.isNotEmpty) ...[
              const SizedBox(width: 12.0),
              ...trailingLabels,
            ],
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(
    LyraThemeTokens tokens,
    List<TrackColumn> orderedVisible,
  ) {
    final prefix = widget.keyPrefix;
    final isDetail = _effectiveViewMode == TrackListViewMode.detail;
    return DraggableColumnsOverlay(
      key: Key('${prefix}_tracks_table_header_context_menu'),
      controller: _columnsOverlayController,
      positionNotifier: _columnsPositionNotifier,
      estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
      onReset: _resetColumns,
      cardKey: Key('${prefix}_tracks_columns_window'),
      headerKey: Key('${prefix}_tracks_columns_window_header'),
      resetKey: Key('${prefix}_tracks_columns_reset_button'),
      closeKey: Key('${prefix}_tracks_columns_close_button'),
      tokens: tokens,
      content: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) =>
            DraggableColumnsOverlay.proxyDecorator(
              child,
              index,
              animation,
              tokens,
            ),
        itemCount: _effectiveColumnOrder.length,
        onReorder: _onReorderColumns,
        itemBuilder: (context, index) {
          final col = _effectiveColumnOrder[index];
          final isVisible = _effectiveVisibleColumns.contains(col);
          final canToggle =
              !col.isMandatory &&
              (!isVisible || _effectiveVisibleColumns.length > 1);
          return _CollectionColumnMenuItem(
            key: Key('${prefix}_track_col_menu_${col.name}'),
            checkboxKey: Key('${prefix}_track_col_checkbox_${col.name}'),
            index: index,
            col: col,
            isVisible: isVisible,
            canToggle: canToggle,
            tokens: tokens,
            onToggle: () => _toggleColumn(col),
          );
        },
      ),
      child: _effectiveShowHeader
          ? Container(
              key: Key('${prefix}_tracks_table_header'),
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.xl,
                vertical: LyraSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: tokens.background,
                border: Border(
                  bottom: BorderSide(color: tokens.border, width: 1.0),
                ),
              ),
              child: isDetail
                  ? Row(
                      children: [
                        for (final col in orderedVisible)
                          _buildHeaderCell(col, tokens),
                      ],
                    )
                  : _buildListHeaderRow(tokens, orderedVisible),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(LyraThemeTokens tokens) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LyraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.emptyIcon, size: 48.0, color: tokens.textMuted),
              const SizedBox(height: LyraSpacing.md),
              Text(widget.emptyTitle, style: LyraTypography.h3(tokens)),
              const SizedBox(height: LyraSpacing.xs),
              Text(widget.emptySubtitle, style: LyraTypography.muted(tokens)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTracksList(BuildContext context, LyraThemeTokens tokens) {
    final prefix = widget.keyPrefix;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(1.0),
    );
    final itemExtent =
        (_effectiveViewMode == TrackListViewMode.list ? 64.0 : 56.0) *
        textScale;
    final itemKeys = <Key>[];
    final countMap = <String, int>{};
    for (var i = 0; i < widget.tracks.length; i++) {
      final id = widget.tracks[i].id;
      final count = countMap.update(id, (v) => v + 1, ifAbsent: () => 0);
      itemKeys.add(ValueKey('${prefix}_track_${id}_$count'));
    }

    Widget buildRow(BuildContext context, int index) {
      final track = widget.tracks[index];
      final isCurrent = widget.currentTrack?.id == track.id;
      final isPlaying = isCurrent && widget.isPlaying;

      return _CollectionTrackRow(
        key: itemKeys[index],
        index: index,
        track: track,
        viewMode: _effectiveViewMode,
        isCurrent: isCurrent,
        isPlaying: isPlaying,
        isSelected: _selectedTrackId != null
            ? track.id == _selectedTrackId
            : _selectedTrackIndex == index,
        columnOrder: _effectiveColumnOrder,
        visibleColumns: _effectiveVisibleColumns,
        tokens: tokens,
        canReorder: widget.allowReorder && widget.tracks.length > 1,
        useReorderListener: widget.allowReorder,
        removeLabel: widget.removeTrackLabel,
        onTap: () => _handleTrackTap(index, track),
        onDoubleTap: _effectiveActivationMode == TrackActivationMode.doubleClick
            ? () => _handlePlayTrack(track)
            : null,
        onPlayNow: () => _handlePlayTrack(track),
        onPlayNext: () => _handlePlayNext(track),
        onAddToQueue: () => _handleAddToQueue(track),
        onRemove: widget.onRemoveTrack != null
            ? () => widget.onRemoveTrack!(index, track)
            : null,
        onInspectAudio: widget.onInspectAudio != null
            ? () => widget.onInspectAudio!(track)
            : null,
        onGoToAlbum: widget.onGoToAlbum,
        onGoToArtist: widget.onGoToArtist,
      );
    }

    return Expanded(
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          LyraContextMenuCoordinator.hideActive();
          return false;
        },
        child: widget.allowReorder
            ? ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
                buildDefaultDragHandles: false,
                itemCount: widget.tracks.length,
                itemExtent: itemExtent,
                proxyDecorator: (child, index, animation) =>
                    _proxyDecorator(child, index, animation, tokens),
                onReorder: (oldIndex, newIndex) {
                  widget.onReorderTracks?.call(oldIndex, newIndex);
                },
                itemBuilder: buildRow,
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
                itemCount: widget.tracks.length,
                itemExtent: itemExtent,
                itemBuilder: buildRow,
              ),
      ),
    );
  }
}

class _CollectionTrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final TrackListViewMode viewMode;
  final bool isCurrent;
  final bool isPlaying;
  final bool isSelected;
  final List<TrackColumn> columnOrder;
  final Set<TrackColumn> visibleColumns;
  final LyraThemeTokens tokens;
  final bool canReorder;
  final bool useReorderListener;
  final String removeLabel;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onPlayNow;
  final VoidCallback onPlayNext;
  final VoidCallback onAddToQueue;
  final VoidCallback? onRemove;
  final VoidCallback? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;

  const _CollectionTrackRow({
    super.key,
    required this.index,
    required this.track,
    this.viewMode = TrackListViewMode.detail,
    required this.isCurrent,
    required this.isPlaying,
    this.isSelected = false,
    required this.columnOrder,
    required this.visibleColumns,
    required this.tokens,
    this.canReorder = true,
    this.useReorderListener = true,
    this.removeLabel = 'Remove from Playlist',
    required this.onTap,
    this.onDoubleTap,
    required this.onPlayNow,
    required this.onPlayNext,
    required this.onAddToQueue,
    this.onRemove,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  State<_CollectionTrackRow> createState() => _CollectionTrackRowState();
}

class _CollectionTrackRowState extends State<_CollectionTrackRow> {
  bool _isHovered = false;
  late final ShadContextMenuController _contextMenuController =
      ShadContextMenuController();
  DateTime? _lastTapTime;

  void _handleTap() {
    LyraContextMenuCoordinator.hideActive();
    final now = DateTime.now();
    if (widget.onDoubleTap != null &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350)) {
      _lastTapTime = null;
      widget.onDoubleTap!();
    } else {
      _lastTapTime = now;
      widget.onTap();
    }
  }

  @override
  void initState() {
    super.initState();
    _contextMenuController.addListener(_handleContextMenuChanged);
  }

  void _handleContextMenuChanged() {
    if (_contextMenuController.isOpen) {
      LyraContextMenuCoordinator.setActive(_contextMenuController);
    } else if (LyraContextMenuCoordinator.isActive(_contextMenuController)) {
      LyraContextMenuCoordinator.hideActive();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _contextMenuController.removeListener(_handleContextMenuChanged);
    LyraContextMenuCoordinator.onDisposed(_contextMenuController);
    _contextMenuController.dispose();
    super.dispose();
  }

  Widget _buildRowCell(TrackColumn col, LyraThemeTokens tokens) {
    final track = widget.track;
    final isCurrent = widget.isCurrent;
    final isPlaying = widget.isPlaying;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));

    switch (col.name) {
      case 'index':
        return SizedBox(
          width: (col.width ?? 40.0) * scale,
          child: Align(
            alignment: Alignment.centerLeft,
            child: isPlaying
                ? Icon(LucideIcons.volume2, size: 16.0, color: tokens.primary)
                : _isHovered
                ? Icon(
                    LucideIcons.play,
                    size: 16.0,
                    color: isCurrent ? tokens.primary : tokens.text,
                  )
                : Text(
                    '${widget.index + 1}',
                    style: LyraTypography.small(tokens).copyWith(
                      color: isCurrent ? tokens.primary : tokens.textMuted,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        );
      case 'cover':
        return SizedBox(
          width: col.width ?? 52.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TrackCoverThumbnail(
                track: track,
                isActive: isCurrent,
                size: 36.0,
              ),
            ),
          ),
        );
      case 'trackNumber':
        return SizedBox(
          width: (col.width ?? 66.0) * scale,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                track.trackNumber != null ? '${track.trackNumber}' : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'title':
        return Expanded(
          flex: col.flex ?? 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.displayTitle,
                  style: LyraTypography.p(tokens).copyWith(
                    fontSize: 13.0,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrent ? tokens.primary : tokens.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  track.artist.isNotEmpty ? track.artist : 'Unknown Artist',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontSize: 12.0, color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      case 'album':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                track.album.isNotEmpty ? track.album : 'Unknown Album',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'duration':
        return SizedBox(
          width: (col.width ?? 76.0) * scale,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                track.formattedDuration,
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'resolution':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: widget.onInspectAudio != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onInspectAudio,
                  child: LyraBadge.outline(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      track.formattedQuality,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'work':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              track.workTitle ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'year':
        return SizedBox(
          width: (col.width ?? 74.0) * scale,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                track.year != null ? '${track.year}' : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'genre':
        return Expanded(
          flex: col.flex ?? 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              track.genre ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'iswc':
        final val = track.iswc;
        return _buildMonospaceIdCell(val, 'Copy ISWC', 140.0 * scale, tokens);
      case 'isrc':
        final val = track.isrc;
        return _buildMonospaceIdCell(val, 'Copy ISRC', 130.0 * scale, tokens);
      case 'musicbrainzId':
        final val = track.musicbrainzId;
        return _buildMonospaceIdCell(
          val,
          'Copy MusicBrainz ID',
          260.0 * scale,
          tokens,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMonospaceIdCell(
    String? val,
    String tooltip,
    double width,
    LyraThemeTokens tokens,
  ) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: (val != null && val.isNotEmpty)
            ? Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        val,
                        style: LyraTypography.mono(
                          tokens,
                          fontSize: 11.0,
                        ).copyWith(color: tokens.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    LyraCopyButton(text: val, tooltip: tooltip),
                  ],
                ),
              )
            : Text(
                '-',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }

  Widget _buildListRowContent(LyraThemeTokens tokens) {
    final track = widget.track;
    final isCurrent = widget.isCurrent;
    final isPlaying = widget.isPlaying;
    final orderedVisible = [
      for (final col in widget.columnOrder)
        if (widget.visibleColumns.contains(col)) col,
    ];
    final showIndex = widget.visibleColumns.contains(TrackColumn.index);
    final showCover = widget.visibleColumns.contains(TrackColumn.cover);
    final hasResolution = widget.visibleColumns.contains(
      TrackColumn.resolution,
    );
    final hasDuration = widget.visibleColumns.contains(TrackColumn.duration);
    final hasTrailing = hasResolution || hasDuration;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    final subtitleChildren = buildTrackListSubtitleChildren(
      track,
      orderedVisible,
      LyraTypography.small(
        tokens,
      ).copyWith(fontSize: 12.0, color: tokens.textMuted),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final indexWidth = showIndex
            ? math.min(
                (TrackColumn.index.width ?? 40.0) * scale,
                constraints.maxWidth * 0.2,
              )
            : 0.0;
        final leftFixedWidth =
            indexWidth + (showCover ? 52.0 : 0.0) + (hasTrailing ? 12.0 : 0.0);
        final metrics = computeTrackListTrailingMetrics(
          availableRowWidth: constraints.maxWidth,
          leftFixedWidth: leftFixedWidth,
          hasResolution: hasResolution,
          hasDuration: hasDuration,
          textScale: scale,
        );
        final trailingChildren = buildTrackListTrailingChildren(
          track: track,
          orderedVisibleColumns: orderedVisible,
          tokens: tokens,
          onInspectAudio: widget.onInspectAudio,
          maxBadgeWidth: metrics.maxBadgeWidth,
          durationWidth: metrics.durationWidth,
        );

        return Row(
          children: [
            if (showIndex)
              SizedBox(
                width: indexWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isPlaying
                      ? Icon(
                          LucideIcons.volume2,
                          size: 16.0,
                          color: tokens.primary,
                        )
                      : _isHovered
                      ? Icon(
                          LucideIcons.play,
                          size: 16.0,
                          color: isCurrent ? tokens.primary : tokens.text,
                        )
                      : Text(
                          '${widget.index + 1}',
                          style: LyraTypography.small(tokens).copyWith(
                            color: isCurrent
                                ? tokens.primary
                                : tokens.textMuted,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            if (showCover)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TrackCoverThumbnail(
                  track: track,
                  isActive: isCurrent,
                  size: 40.0,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.displayTitle,
                    style: LyraTypography.p(tokens).copyWith(
                      fontSize: 13.0,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: isCurrent ? tokens.primary : tokens.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleChildren.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Row(children: subtitleChildren),
                  ],
                ],
              ),
            ),
            if (trailingChildren.isNotEmpty) ...[
              const SizedBox(width: 12.0),
              ...trailingChildren,
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final track = widget.track;
    final isCurrent = widget.isCurrent;
    final index = widget.index;

    final rowContent = ShadContextMenuRegion(
      controller: _contextMenuController,
      tapEnabled: false,
      constraints: const BoxConstraints(minWidth: 180),
      popoverReverseDuration: const Duration(milliseconds: 50),
      items: [
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.play, size: 16.0),
          onPressed: widget.onPlayNow,
          child: const Text('Play Now'),
        ),
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.listStart, size: 16.0),
          onPressed: widget.onPlayNext,
          child: const Text('Play Next'),
        ),
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.listEnd, size: 16.0),
          onPressed: widget.onAddToQueue,
          child: const Text('Add to Queue'),
        ),
        if (widget.onGoToAlbum != null && track.album.trim().isNotEmpty)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.disc, size: 16.0),
            onPressed: () => widget.onGoToAlbum!(track.album),
            child: const Text('Go to Album'),
          ),
        if (widget.onGoToArtist != null && track.artist.trim().isNotEmpty)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.mic2, size: 16.0),
            onPressed: () => widget.onGoToArtist!(track.artist),
            child: const Text('Go to Artist'),
          ),
        if (widget.onRemove != null)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.trash2, size: 16.0),
            onPressed: widget.onRemove,
            child: Text(widget.removeLabel),
          ),
        if (widget.onInspectAudio != null)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.info, size: 16.0),
            onPressed: widget.onInspectAudio,
            child: const Text('Inspect Audio'),
          ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.xl,
              vertical: LyraSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (_isHovered
                        ? tokens.surfaceElevatedHover
                        : tokens.surfaceElevated)
                  : isCurrent
                  ? tokens.surfaceSecondary
                  : tokens.itemBackground(
                      isHovered: _isHovered || _contextMenuController.isOpen,
                    ),
              border: Border(
                bottom: BorderSide(
                  color: widget.isSelected
                      ? tokens.primary.withValues(alpha: 0.3)
                      : tokens.borderSubtle,
                  width: 1.0,
                ),
              ),
            ),
            child: widget.viewMode == TrackListViewMode.list
                ? _buildListRowContent(tokens)
                : Row(
                    children: [
                      for (final col in widget.columnOrder)
                        if (widget.visibleColumns.contains(col))
                          _buildRowCell(col, tokens),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!widget.useReorderListener) {
      return rowContent;
    }

    return ThresholdReorderableDragStartListener(
      index: index,
      enabled: widget.canReorder,
      child: rowContent,
    );
  }
}

class _CollectionColumnMenuItem extends StatefulWidget {
  final int index;
  final TrackColumn col;
  final bool isVisible;
  final bool canToggle;
  final LyraThemeTokens tokens;
  final VoidCallback onToggle;
  final Key checkboxKey;

  const _CollectionColumnMenuItem({
    super.key,
    required this.checkboxKey,
    required this.index,
    required this.col,
    required this.isVisible,
    this.canToggle = true,
    required this.tokens,
    required this.onToggle,
  });

  @override
  State<_CollectionColumnMenuItem> createState() =>
      _CollectionColumnMenuItemState();
}

class _CollectionColumnMenuItemState extends State<_CollectionColumnMenuItem> {
  bool _isHovered = false;
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.isVisible;
  }

  @override
  void didUpdateWidget(covariant _CollectionColumnMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isChecked != widget.isVisible) {
      _isChecked = widget.isVisible;
    }
  }

  void _handleToggle() {
    if (!widget.canToggle) return;
    setState(() {
      _isChecked = !_isChecked;
    });
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final col = widget.col;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.canToggle
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        height: 36.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: _isHovered ? tokens.secondary.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 8.0,
                  ),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 14.0,
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: GestureDetector(
                key: Key('track_col_menu_${col.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.canToggle ? _handleToggle : null,
                child: Row(
                  children: [
                    LyraCheckbox(
                      key: widget.checkboxKey,
                      value: _isChecked,
                      enabled: widget.canToggle,
                      onChanged: widget.canToggle
                          ? (_) => _handleToggle()
                          : null,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        col.label,
                        style: LyraTypography.small(tokens).copyWith(
                          color: col.isMandatory
                              ? tokens.textMuted
                              : tokens.text,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (col.isMandatory) ...[
                      const SizedBox(width: 4.0),
                      Icon(
                        LucideIcons.lock,
                        size: 12.0,
                        color: tokens.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
