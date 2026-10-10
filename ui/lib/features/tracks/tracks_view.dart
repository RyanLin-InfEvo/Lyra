// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart'
    show
        ClampingScrollPhysics,
        Colors,
        Material,
        ReorderableDragStartListener,
        ReorderableListView;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_checkbox.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../design_system/widgets/lyra_tooltip.dart';
import '../../widgets/draggable_columns_overlay.dart';
import '../common/batch_action_toolbar.dart';
import '../common/context_menu_coordinator.dart';
import '../models/track.dart';
import '../settings/services/preferences_service.dart';

/// Columns available in the Tracks table.
class TrackColumn {
  final String name;
  final String headerLabel;
  final String label;
  final double? width;
  final int? flex;
  final bool isMandatory;
  final bool defaultVisible;

  const TrackColumn._({
    required this.name,
    required this.headerLabel,
    required this.label,
    this.width,
    this.flex,
    this.isMandatory = false,
    this.defaultVisible = true,
  });

  static const TrackColumn index = TrackColumn._(
    name: 'index',
    headerLabel: '#',
    label: 'Track Number',
    width: 40.0,
  );

  static const TrackColumn title = TrackColumn._(
    name: 'title',
    headerLabel: 'Title & Artist',
    label: 'Title & Artist',
    flex: 5,
    isMandatory: true,
  );

  static const TrackColumn album = TrackColumn._(
    name: 'album',
    headerLabel: 'Album',
    label: 'Album',
    flex: 4,
  );

  /// Best resolution format badge (e.g. 24-bit/96kHz) and audio version count.
  static const TrackColumn resolution = TrackColumn._(
    name: 'resolution',
    headerLabel: 'Resolution',
    label: 'Resolution',
    flex: 3,
  );

  static const TrackColumn duration = TrackColumn._(
    name: 'duration',
    headerLabel: 'Time',
    label: 'Time',
    width: 76.0,
  );

  static const TrackColumn work = TrackColumn._(
    name: 'work',
    headerLabel: 'Work',
    label: 'Work / Composition',
    flex: 4,
    defaultVisible: false,
  );

  static const TrackColumn iswc = TrackColumn._(
    name: 'iswc',
    headerLabel: 'ISWC',
    label: 'ISWC',
    width: 140.0,
    defaultVisible: false,
  );

  static const TrackColumn year = TrackColumn._(
    name: 'year',
    headerLabel: 'Year',
    label: 'Year Date',
    width: 74.0,
    defaultVisible: false,
  );

  static const TrackColumn musicbrainzId = TrackColumn._(
    name: 'musicbrainzId',
    headerLabel: 'MusicBrainz ID',
    label: 'MusicBrainz ID',
    width: 260.0,
    defaultVisible: false,
  );

  static const TrackColumn isrc = TrackColumn._(
    name: 'isrc',
    headerLabel: 'ISRC',
    label: 'ISRC',
    width: 130.0,
    defaultVisible: false,
  );

  static const TrackColumn genre = TrackColumn._(
    name: 'genre',
    headerLabel: 'Genre',
    label: 'Genre',
    flex: 2,
    defaultVisible: false,
  );

  static const TrackColumn trackNumber = TrackColumn._(
    name: 'trackNumber',
    headerLabel: 'Trk#',
    label: 'Track #',
    width: 66.0,
    defaultVisible: false,
  );

  static const List<TrackColumn> values = [
    index,
    title,
    album,
    resolution,
    work,
    year,
    genre,
    iswc,
    isrc,
    musicbrainzId,
    trackNumber,
    duration,
  ];

  static final Set<TrackColumn> defaultVisibleColumns = {
    index,
    title,
    album,
    resolution,
    duration,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackColumn &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'TrackColumn.$name';
}

/// High-density tracks table view with audiophile format badges.
class TracksView extends StatefulWidget {
  final List<Track> tracks;
  final Track? currentTrack;
  final bool isPlaying;
  final ValueChanged<Track> onTrackSelected;
  final VoidCallback onTogglePlay;
  final ValueChanged<Track>? onPlayNext;
  final ValueChanged<Track>? onAddToQueue;
  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<List<Track>>? onBatchAddToPlaylist;
  final ValueChanged<List<Track>>? onBatchAddTag;
  final ValueChanged<List<Track>>? onBatchAddToQueue;
  final ValueChanged<List<Track>>? onBatchPlayNext;
  final ValueChanged<Track>? onInspectTrack;
  final ValueChanged<Track>? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final Map<String, int>? audioVersionCounts;
  final String? filterLabel;
  final VoidCallback? onClearFilter;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;
  final VoidCallback? onImport;
  final PreferencesService? preferencesService;
  final Map<String, double>? columnWidths;
  final ValueChanged<Map<String, double>>? onColumnWidthsChanged;

  const TracksView({
    super.key,
    required this.tracks,
    required this.currentTrack,
    required this.isPlaying,
    required this.onTrackSelected,
    required this.onTogglePlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onBatchAddToPlaylist,
    this.onBatchAddTag,
    this.onBatchAddToQueue,
    this.onBatchPlayNext,
    this.onInspectTrack,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.audioVersionCounts,
    this.filterLabel,
    this.onClearFilter,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
    this.onImport,
    this.preferencesService,
    this.columnWidths,
    this.onColumnWidthsChanged,
  });

  @override
  State<TracksView> createState() => _TracksViewState();
}

class _TracksViewState extends State<TracksView> {
  late List<TrackColumn> _internalColumnOrder;
  late Set<TrackColumn> _internalVisibleColumns;
  late Map<String, double> _columnWidths;
  late final OverlayPortalController _columnsOverlayController;
  late final ValueNotifier<Offset> _columnsPositionNotifier;
  TrackColumn? _sortColumn;
  bool _sortAscending = true;

  final Set<String> _selectedTrackIds = {};
  String? _selectionAnchorId;
  bool _isModifierSelectionActive = false;

  void _handleSort(TrackColumn col) {
    if (col == TrackColumn.index) return;
    setState(() {
      if (_sortColumn == col) {
        if (_sortAscending) {
          _sortAscending = false;
        } else {
          _sortColumn = null;
          _sortAscending = true;
        }
      } else {
        _sortColumn = col;
        _sortAscending = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _columnsOverlayController = OverlayPortalController();
    _columnsPositionNotifier = ValueNotifier<Offset>(Offset.zero);
    _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    _columnWidths = Map<String, double>.from(
      widget.columnWidths ?? widget.preferencesService?.trackColumnWidths ?? {},
    );
  }

  @override
  void didUpdateWidget(covariant TracksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedTrackIds.removeWhere(
      (id) => !widget.tracks.any((t) => t.id == id),
    );
    if (_selectionAnchorId != null &&
        !widget.tracks.any((t) => t.id == _selectionAnchorId)) {
      _selectionAnchorId = null;
    }
    if (_selectedTrackIds.isEmpty) {
      _isModifierSelectionActive = false;
    }
    if (widget.columnOrder != null &&
        widget.columnOrder != oldWidget.columnOrder) {
      _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    }
    if (widget.visibleColumns != null &&
        widget.visibleColumns != oldWidget.visibleColumns) {
      _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    }
    if (widget.columnWidths != null &&
        widget.columnWidths != oldWidget.columnWidths) {
      _columnWidths = Map<String, double>.from(widget.columnWidths!);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _columnsPositionNotifier.dispose();
    super.dispose();
  }

  bool get _hasSelection => _selectedTrackIds.isNotEmpty;

  void _clearSelection() {
    _selectedTrackIds.clear();
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
      final displayTracks = _getDisplayTracks();
      if (displayTracks.isNotEmpty) {
        setState(() {
          _selectedTrackIds.clear();
          _selectedTrackIds.addAll(displayTracks.map((t) => t.id));
          _selectionAnchorId ??= displayTracks.first.id;
          _isModifierSelectionActive = true;
        });
        return true;
      }
    }

    return false;
  }

  List<Track> _getDisplayTracks() {
    final displayTracks = List<Track>.of(widget.tracks);
    if (_sortColumn != null) {
      displayTracks.sort((a, b) {
        int cmp = switch (_sortColumn!.name) {
          'title' => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
          'album' => (a.album).toLowerCase().compareTo((b.album).toLowerCase()),
          'duration' => (a.durationMs ?? 0).compareTo(b.durationMs ?? 0),
          'year' => (a.year ?? 0).compareTo(b.year ?? 0),
          'trackNumber' => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0),
          'work' => (a.workTitle ?? '').toLowerCase().compareTo(
            (b.workTitle ?? '').toLowerCase(),
          ),
          'genre' => (a.genre ?? '').toLowerCase().compareTo(
            (b.genre ?? '').toLowerCase(),
          ),
          'resolution' => a.formattedQuality.toLowerCase().compareTo(
            b.formattedQuality.toLowerCase(),
          ),
          'iswc' => (a.iswc ?? '').toLowerCase().compareTo(
            (b.iswc ?? '').toLowerCase(),
          ),
          'isrc' => (a.isrc ?? '').toLowerCase().compareTo(
            (b.isrc ?? '').toLowerCase(),
          ),
          'musicbrainzId' => (a.musicbrainzId ?? '').toLowerCase().compareTo(
            (b.musicbrainzId ?? '').toLowerCase(),
          ),
          _ => 0,
        };
        return _sortAscending ? cmp : -cmp;
      });
    }
    return displayTracks;
  }

  void _handleTrackTap(Track track, List<Track> displayTracks) {
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
      final clickedIndex = displayTracks.indexWhere((t) => t.id == track.id);
      if (clickedIndex != -1) {
        int anchorIndex = -1;
        if (_selectionAnchorId != null) {
          anchorIndex = displayTracks.indexWhere(
            (t) => t.id == _selectionAnchorId,
          );
        }
        if (anchorIndex == -1) {
          anchorIndex = 0;
          _selectionAnchorId = displayTracks.isNotEmpty
              ? displayTracks[0].id
              : track.id;
        }
        final start = math.min(anchorIndex, clickedIndex);
        final end = math.max(anchorIndex, clickedIndex);
        setState(() {
          _selectedTrackIds.clear();
          for (int i = start; i <= end; i++) {
            _selectedTrackIds.add(displayTracks[i].id);
          }
          _isModifierSelectionActive = true;
        });
      }
      return;
    }

    if (isControlOrMeta) {
      setState(() {
        if (_selectedTrackIds.contains(track.id)) {
          _selectedTrackIds.remove(track.id);
        } else {
          _selectedTrackIds.add(track.id);
        }
        _selectionAnchorId = track.id;
        _isModifierSelectionActive = true;
      });
      return;
    }

    // Normal click: selects single track, clears others.
    setState(() {
      _selectedTrackIds.clear();
      _selectedTrackIds.add(track.id);
      _selectionAnchorId = track.id;
      _isModifierSelectionActive = false;
    });

    final isCurrent = widget.currentTrack?.id == track.id;
    if (isCurrent) {
      widget.onTogglePlay();
    } else {
      widget.onTrackSelected(track);
    }
  }

  Widget _buildBatchActionToolbar(
    List<Track> selectedTracks,
    LyraThemeTokens tokens,
  ) {
    return BatchActionToolbar(
      selectedCount: selectedTracks.length,
      onClearSelection: () {
        setState(() {
          _clearSelection();
        });
      },
      onPlayNext: widget.onBatchPlayNext != null
          ? () => widget.onBatchPlayNext!(selectedTracks)
          : null,
      onAddToQueue: widget.onBatchAddToQueue != null
          ? () => widget.onBatchAddToQueue!(selectedTracks)
          : null,
      onAddToPlaylist: widget.onBatchAddToPlaylist != null
          ? () => widget.onBatchAddToPlaylist!(selectedTracks)
          : null,
      onAddTag: widget.onBatchAddTag != null
          ? () => widget.onBatchAddTag!(selectedTracks)
          : null,
      tokens: tokens,
    );
  }

  static List<TrackColumn> _normalizeColumnOrder(List<TrackColumn>? order) {
    if (order == null || order.isEmpty) {
      return List<TrackColumn>.from(TrackColumn.values);
    }
    final normalized = <TrackColumn>[];
    for (final col in order) {
      if (TrackColumn.values.contains(col) && !normalized.contains(col)) {
        normalized.add(col);
      }
    }
    for (final col in TrackColumn.values) {
      if (!normalized.contains(col)) {
        normalized.add(col);
      }
    }
    return normalized;
  }

  static Set<TrackColumn> _normalizeVisibleColumns(Set<TrackColumn>? visible) {
    if (visible == null || visible.isEmpty) {
      return Set<TrackColumn>.from(TrackColumn.defaultVisibleColumns);
    }
    final normalized = Set<TrackColumn>.from(visible);
    for (final col in TrackColumn.values) {
      if (col.isMandatory) {
        normalized.add(col);
      }
    }
    return normalized;
  }

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
    setState(() {
      _internalVisibleColumns = current;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final newOrder = List<TrackColumn>.from(_internalColumnOrder);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    widget.onColumnOrderChanged?.call(newOrder);
    setState(() {
      _internalColumnOrder = newOrder;
    });
  }

  void _updateColumnWidth(String colName, double newWidth) {
    setState(() {
      _columnWidths[colName] = newWidth;
    });
    widget.onColumnWidthsChanged?.call(_columnWidths);
  }

  void _onColumnResizeEnd() {
    widget.preferencesService?.setTrackColumnWidths(_columnWidths);
  }

  void _resetColumnWidth(String colName) {
    setState(() {
      _columnWidths.remove(colName);
    });
    widget.preferencesService?.setTrackColumnWidths(_columnWidths);
    widget.onColumnWidthsChanged?.call(_columnWidths);
  }

  void _resetColumns() {
    final defaultOrder = List<TrackColumn>.from(TrackColumn.values);
    final defaultVisible = Set<TrackColumn>.from(
      TrackColumn.defaultVisibleColumns,
    );
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
      _columnWidths.clear();
    });
    widget.preferencesService?.setTrackColumnWidths(_columnWidths);
    widget.onColumnWidthsChanged?.call(_columnWidths);
  }

  Widget _buildHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    Widget cellContent;
    final isSortable = col != TrackColumn.index;
    final isSorted = _sortColumn == col;
    final sortIcon = isSorted
        ? Icon(
            _sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
            size: 12.0,
            color: tokens.primary,
          )
        : null;

    final headerTextStyle = LyraTypography.small(tokens).copyWith(
      color: isSorted ? tokens.text : tokens.textMuted,
      fontWeight: FontWeight.bold,
    );

    if (col == TrackColumn.index) {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Text(col.headerLabel, style: headerTextStyle),
      );
    } else if (col == TrackColumn.duration ||
        col == TrackColumn.trackNumber ||
        col == TrackColumn.year) {
      cellContent = Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  col.headerLabel,
                  style: headerTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sortIcon != null) ...[const SizedBox(width: 4.0), sortIcon],
            ],
          ),
        ),
      );
    } else {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  col.headerLabel,
                  style: headerTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sortIcon != null) ...[const SizedBox(width: 4.0), sortIcon],
            ],
          ),
        ),
      );
    }

    final interactiveChild = MouseRegion(
      cursor: isSortable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSortable ? () => _handleSort(col) : null,
        child: cellContent,
      ),
    );

    final customWidth = _columnWidths[col.name];
    final effectiveWidth = customWidth ?? col.width;
    final effectiveFlex = customWidth == null ? col.flex : null;

    return _ResizableTrackHeaderCell(
      key: ValueKey('header_cell_${col.name}'),
      col: col,
      width: effectiveWidth,
      flex: effectiveFlex,
      tokens: tokens,
      onWidthChanged: (w) => _updateColumnWidth(col.name, w),
      onResizeEnd: _onColumnResizeEnd,
      onResetWidth: () => _resetColumnWidth(col.name),
      child: interactiveChild,
    );
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
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: tokens.border, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.searchX, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text(
              widget.filterLabel != null
                  ? 'No matching tracks found'
                  : 'No tracks found',
              style: LyraTypography.h3(tokens),
            ),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              widget.filterLabel != null
                  ? 'No tracks found matching "${widget.filterLabel}".'
                  : 'Try adjusting your search query or import new audio files.',
              style: LyraTypography.muted(tokens),
            ),
            if (widget.filterLabel == null && widget.onImport != null) ...[
              const SizedBox(height: LyraSpacing.md),
              LyraButton.primary(
                onPressed: widget.onImport,
                leading: const Icon(LucideIcons.plus, size: 16.0),
                child: const Text('Import Audio'),
              ),
            ],
            if (widget.filterLabel != null && widget.onClearFilter != null) ...[
              const SizedBox(height: LyraSpacing.md),
              LyraButton.outline(
                size: LyraButtonSize.sm,
                onPressed: widget.onClearFilter,
                leading: const Icon(LucideIcons.x, size: 14.0),
                child: const Text('Clear filter'),
              ),
            ],
          ],
        ),
      );
    }

    final displayTracks = _getDisplayTracks();
    final selectedTracks = widget.tracks
        .where((t) => _selectedTrackIds.contains(t.id))
        .toList();
    final bool showBatchToolbar =
        selectedTracks.isNotEmpty &&
        (_isModifierSelectionActive || selectedTracks.length > 1);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View Header
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
                      Text('Tracks Library', style: LyraTypography.h2(tokens)),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${widget.tracks.length} tracks',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
                  ),
                  if (widget.filterLabel != null) ...[
                    const SizedBox(width: LyraSpacing.lg),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360.0),
                        padding: EdgeInsets.only(
                          left: 8.0,
                          top: widget.onClearFilter != null ? 2.0 : 4.0,
                          bottom: widget.onClearFilter != null ? 2.0 : 4.0,
                          right: widget.onClearFilter != null ? 3.0 : 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.secondary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: tokens.border, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.filterLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LyraTypography.small(tokens).copyWith(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.text,
                                ),
                              ),
                            ),
                            if (widget.onClearFilter != null) ...[
                              const SizedBox(width: 4.0),
                              _FilterCloseButton(
                                onTap: widget.onClearFilter,
                                tokens: tokens,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Table Header with Draggable Floating Columns Window
            DraggableColumnsOverlay(
              key: const Key('tracks_table_header_context_menu'),
              controller: _columnsOverlayController,
              positionNotifier: _columnsPositionNotifier,
              estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
              onReset: _resetColumns,
              cardKey: const Key('tracks_columns_window'),
              headerKey: const Key('tracks_columns_window_header'),
              resetKey: const Key('tracks_columns_reset_button'),
              closeKey: const Key('tracks_columns_close_button'),
              tokens: tokens,
              content: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) =>
                    _proxyDecorator(child, index, animation, tokens),
                itemCount: _effectiveColumnOrder.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final col = _effectiveColumnOrder[index];
                  final isVisible = _effectiveVisibleColumns.contains(col);
                  final canToggle =
                      !col.isMandatory &&
                      (!isVisible || _effectiveVisibleColumns.length > 1);
                  return _TrackColumnMenuItem(
                    key: Key('track_col_menu_${col.name}'),
                    index: index,
                    col: col,
                    isVisible: isVisible,
                    canToggle: canToggle,
                    tokens: tokens,
                    onToggle: () => _toggleColumn(col),
                  );
                },
              ),
              child: Container(
                key: const Key('tracks_table_header'),
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
                child: Row(
                  children: [
                    for (final col in _effectiveColumnOrder)
                      if (_effectiveVisibleColumns.contains(col))
                        _buildHeaderCell(col, tokens),
                  ],
                ),
              ),
            ),

            // Table Rows
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
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    LyraContextMenuCoordinator.hideActive();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: LyraSpacing.xs,
                    ),
                    itemCount: displayTracks.length,
                    itemExtent: math.max(
                      56.0,
                      56.0 * MediaQuery.textScalerOf(context).scale(1.0),
                    ),
                    itemBuilder: (context, index) {
                      final track = displayTracks[index];
                      final isCurrent = widget.currentTrack?.id == track.id;
                      final isSelected = _selectedTrackIds.contains(track.id);
                      final versionCount =
                          widget.audioVersionCounts?[track.id] ??
                          widget.audioVersionCounts?[track.pcmHash] ??
                          1;

                      final onInspectAudio = widget.onInspectAudio != null
                          ? () => widget.onInspectAudio!(track)
                          : (widget.onInspectTrack != null
                                ? () => widget.onInspectTrack!(track)
                                : null);

                      return _TrackRow(
                        key: ValueKey(track.id),
                        index: index + 1,
                        track: track,
                        columnWidths: _columnWidths,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && widget.isPlaying,
                        isSelected: isSelected,
                        versionCount: versionCount,
                        columnOrder: _effectiveColumnOrder,
                        visibleColumns: _effectiveVisibleColumns,
                        onTap: () => _handleTrackTap(track, displayTracks),
                        onPlayNow: () => widget.onTrackSelected(track),
                        onPlayNext: widget.onPlayNext != null
                            ? () => widget.onPlayNext!(track)
                            : null,
                        onAddToQueue: widget.onAddToQueue != null
                            ? () => widget.onAddToQueue!(track)
                            : null,
                        onAddToPlaylist: widget.onAddToPlaylist != null
                            ? () => widget.onAddToPlaylist!(track)
                            : null,
                        onInspectAudio: onInspectAudio,
                        onGoToAlbum: widget.onGoToAlbum,
                        onGoToArtist: widget.onGoToArtist,
                        tokens: tokens,
                      );
                    },
                  ),
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
                      ? _buildBatchActionToolbar(selectedTracks, tokens)
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

class _TrackColumnMenuItem extends StatefulWidget {
  final int index;
  final TrackColumn col;
  final bool isVisible;
  final bool canToggle;
  final LyraThemeTokens tokens;
  final VoidCallback onToggle;

  const _TrackColumnMenuItem({
    super.key,
    required this.index,
    required this.col,
    required this.isVisible,
    this.canToggle = true,
    required this.tokens,
    required this.onToggle,
  });

  @override
  State<_TrackColumnMenuItem> createState() => _TrackColumnMenuItemState();
}

class _TrackColumnMenuItemState extends State<_TrackColumnMenuItem> {
  bool _isHovered = false;
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.isVisible;
  }

  @override
  void didUpdateWidget(covariant _TrackColumnMenuItem oldWidget) {
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
                behavior: HitTestBehavior.opaque,
                onTap: widget.canToggle ? _handleToggle : null,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: LyraCheckbox(
                        key: Key('track_col_checkbox_${col.name}'),
                        value: _isChecked,
                        enabled: widget.canToggle,
                      ),
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

class _ResizableTrackHeaderCell extends StatefulWidget {
  final TrackColumn col;
  final Widget child;
  final double? width;
  final int? flex;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onResetWidth;
  final VoidCallback? onResizeEnd;
  final LyraThemeTokens tokens;

  const _ResizableTrackHeaderCell({
    super.key,
    required this.col,
    required this.child,
    this.width,
    this.flex,
    required this.onWidthChanged,
    required this.onResetWidth,
    this.onResizeEnd,
    required this.tokens,
  });

  @override
  State<_ResizableTrackHeaderCell> createState() =>
      _ResizableTrackHeaderCellState();
}

class _ResizableTrackHeaderCellState extends State<_ResizableTrackHeaderCell> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragStartWidth = 0.0;
  double _accumulatedDelta = 0.0;

  double get _minWidth {
    if (widget.col == TrackColumn.index) return 40.0;
    if (widget.col == TrackColumn.duration ||
        widget.col == TrackColumn.year ||
        widget.col == TrackColumn.trackNumber) {
      return 50.0;
    }
    return 70.0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isHandleActive = _isHovered || _isDragging;

    final cellBody = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: double.infinity, child: widget.child),
        Positioned(
          right: 0.0,
          top: 0,
          bottom: 0,
          width: 8.0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              key: Key('column_resize_handle_${widget.col.name}'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _dragStartWidth = context.size?.width ?? widget.width ?? 100.0;
                _accumulatedDelta = 0.0;
                setState(() => _isDragging = true);
              },
              onHorizontalDragUpdate: (details) {
                _accumulatedDelta += details.delta.dx;
                final newWidth = math.max(
                  _minWidth,
                  _dragStartWidth + _accumulatedDelta,
                );
                widget.onWidthChanged(newWidth);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
                widget.onResizeEnd?.call();
              },
              onHorizontalDragCancel: () {
                setState(() => _isDragging = false);
                widget.onResizeEnd?.call();
              },
              onDoubleTap: widget.onResetWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: isHandleActive ? 2.0 : 1.0,
                  height: double.infinity,
                  color: isHandleActive ? tokens.primary : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: cellBody);
    } else {
      return Expanded(flex: widget.flex ?? 1, child: cellBody);
    }
  }
}

/// Single row item in the Tracks table.
class _TrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isSelected;
  final int versionCount;
  final VoidCallback onTap;
  final VoidCallback? onPlayNow;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final LyraThemeTokens tokens;
  final List<TrackColumn> columnOrder;
  final Set<TrackColumn> visibleColumns;
  final Map<String, double>? columnWidths;

  const _TrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    this.isSelected = false,
    this.versionCount = 1,
    required this.onTap,
    this.onPlayNow,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
    required this.tokens,
    required this.columnOrder,
    required this.visibleColumns,
    this.columnWidths,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _isHovered = false;
  late final ShadContextMenuController _contextMenuController =
      ShadContextMenuController();

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

  Widget _wrapRowCell({required TrackColumn col, required Widget content}) {
    final customWidth = widget.columnWidths?[col.name];
    final effectiveWidth = customWidth ?? col.width;
    final effectiveFlex = customWidth == null ? col.flex : null;

    if (effectiveWidth != null) {
      return SizedBox(width: effectiveWidth, child: content);
    } else {
      return Expanded(flex: effectiveFlex ?? 1, child: content);
    }
  }

  Widget _buildRowCell(TrackColumn col, LyraThemeTokens tokens) {
    switch (col.name) {
      case 'index':
        return _wrapRowCell(
          col: col,
          content: Align(
            alignment: Alignment.centerLeft,
            child: _isHovered || widget.isPlaying
                ? Icon(
                    widget.isPlaying ? LucideIcons.volume2 : LucideIcons.play,
                    size: 16.0,
                    color: widget.isCurrent ? tokens.primary : tokens.text,
                  )
                : Text(
                    '${widget.index}',
                    style: LyraTypography.small(tokens).copyWith(
                      color: widget.isCurrent
                          ? tokens.primary
                          : tokens.textMuted,
                      fontWeight: widget.isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        );
      case 'trackNumber':
        return _wrapRowCell(
          col: col,
          content: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.track.trackNumber != null
                    ? '${widget.track.trackNumber}'
                    : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        );
      case 'title':
        return _wrapRowCell(
          col: col,
          content: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.track.displayTitle,
                  style: LyraTypography.p(tokens).copyWith(
                    fontWeight: widget.isCurrent
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.isCurrent ? tokens.primary : tokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.track.artist,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      case 'work':
        return _wrapRowCell(
          col: col,
          content: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.workTitle ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'album':
        return _wrapRowCell(
          col: col,
          content: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.album,
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'resolution':
        return _wrapRowCell(
          col: col,
          content: Padding(
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
                      widget.versionCount > 1
                          ? '${widget.track.formattedQuality} · ${widget.versionCount} versions'
                          : widget.track.formattedQuality,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'duration':
        return _wrapRowCell(
          col: col,
          content: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.track.formattedDuration,
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        );
      case 'year':
        return _wrapRowCell(
          col: col,
          content: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.track.year != null ? '${widget.track.year}' : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'iswc':
        final val = widget.track.iswc;
        return _wrapRowCell(
          col: col,
          content: Padding(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(text: val, tooltip: 'Copy ISWC'),
                      ],
                    ),
                  )
                : Text(
                    '-',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
          ),
        );
      case 'isrc':
        final val = widget.track.isrc;
        return _wrapRowCell(
          col: col,
          content: Padding(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(text: val, tooltip: 'Copy ISRC'),
                      ],
                    ),
                  )
                : Text(
                    '-',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
          ),
        );
      case 'musicbrainzId':
        final val = widget.track.musicbrainzId;
        return _wrapRowCell(
          col: col,
          content: Padding(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(
                          text: val,
                          tooltip: 'Copy MusicBrainz ID',
                        ),
                      ],
                    ),
                  )
                : Text(
                    '-',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
          ),
        );
      case 'genre':
        return _wrapRowCell(
          col: col,
          content: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.genre ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCell(TrackColumn col, LyraThemeTokens tokens) =>
      _buildRowCell(col, tokens);

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final track = widget.track;
    final isSelected = widget.isSelected;
    final isHoverOrMenu = _isHovered || _contextMenuController.isOpen;

    Color? rowBackgroundColor;
    if (isSelected) {
      rowBackgroundColor = tokens.isDark
          ? (_isHovered ? const Color(0xFF52525B) : const Color(0xFF3F3F46))
          : (_isHovered ? const Color(0xFFE4E4E7) : const Color(0xFFF4F4F5));
    } else if (widget.isCurrent) {
      rowBackgroundColor = tokens.isDark
          ? const Color(0xFF27272A)
          : const Color(0xFFE4E4E7);
    } else if (isHoverOrMenu) {
      rowBackgroundColor = tokens.secondary.withValues(alpha: 0.5);
    }

    return RepaintBoundary(
      child: ShadContextMenuRegion(
        controller: _contextMenuController,
        tapEnabled: false,
        constraints: const BoxConstraints(minWidth: 180),
        popoverReverseDuration: const Duration(milliseconds: 50),
        items: [
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.play, size: 16.0),
            onPressed: widget.onPlayNow ?? widget.onTap,
            child: const Text('Play Now'),
          ),
          if (widget.onPlayNext != null)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.listStart, size: 16.0),
              onPressed: widget.onPlayNext,
              child: const Text('Play Next'),
            ),
          if (widget.onAddToQueue != null)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.listEnd, size: 16.0),
              onPressed: widget.onAddToQueue,
              child: const Text('Add to Queue'),
            ),
          if (widget.onAddToPlaylist != null)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.folderPlus, size: 16.0),
              onPressed: widget.onAddToPlaylist,
              child: const Text('Add to Playlist...'),
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
            onTap: () {
              LyraContextMenuCoordinator.hideActive();
              widget.onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.xl,
                vertical: LyraSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: rowBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? tokens.primary.withValues(alpha: 0.3)
                        : tokens.border.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  for (final col in widget.columnOrder)
                    if (widget.visibleColumns.contains(col))
                      _buildCell(col, tokens),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterCloseButton extends StatefulWidget {
  final VoidCallback? onTap;
  final LyraThemeTokens tokens;

  const _FilterCloseButton({required this.onTap, required this.tokens});

  @override
  State<_FilterCloseButton> createState() => _FilterCloseButtonState();
}

class _FilterCloseButtonState extends State<_FilterCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: 'Clear filter',
      onTap: widget.onTap,
      child: LyraTooltip(
        message: 'Clear filter',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0),
                color: _isHovered
                    ? tokens.muted.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
              child: Icon(
                LucideIcons.x,
                size: 13.0,
                color: _isHovered ? tokens.text : tokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
