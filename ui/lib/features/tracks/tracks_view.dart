// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart'
    show
        ClampingScrollPhysics,
        Colors,
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

  static const TrackColumn cover = TrackColumn._(
    name: 'cover',
    headerLabel: 'Cover',
    label: 'Cover Art',
    width: 52.0,
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
    cover,
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
    cover,
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

/// Normalizes a column order list, ensuring all [TrackColumn.values] exist once.
List<TrackColumn> normalizeTrackColumnOrder(List<TrackColumn>? order) {
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

/// Normalizes visible column sets, falling back to [defaults] and keeping mandatory columns.
Set<TrackColumn> normalizeTrackVisibleColumns(
  Set<TrackColumn>? visible, {
  Set<TrackColumn>? defaults,
}) {
  final effectiveDefaults = defaults ?? TrackColumn.defaultVisibleColumns;
  if (visible == null || visible.isEmpty) {
    return Set<TrackColumn>.from(effectiveDefaults);
  }
  final normalized = Set<TrackColumn>.from(visible)
    ..retainWhere((col) => TrackColumn.values.contains(col));
  if (normalized.isEmpty) {
    return Set<TrackColumn>.from(effectiveDefaults);
  }
  for (final col in TrackColumn.values) {
    if (col.isMandatory) {
      normalized.add(col);
    }
  }
  return normalized;
}

/// Compact rounded album/track cover thumbnail used in track lists and tables.
///
/// Uses [LucideIcons.music] so [SongArtworkCard]'s [LucideIcons.disc] stays unique
/// when [UpNextTab] is visible alongside the artwork card.
class TrackCoverThumbnail extends StatelessWidget {
  final Track track;
  final bool isActive;
  final double size;
  final double borderRadius;
  final LyraThemeTokens? tokens;

  const TrackCoverThumbnail({
    super.key,
    required this.track,
    this.isActive = false,
    this.size = 38.0,
    this.borderRadius = 6.0,
    this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTokens =
        tokens ??
        LyraDesignSystemScope.maybeOf(context)?.tokens ??
        LyraThemeTokens.dark();
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: effectiveTokens.secondary,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isActive
                ? effectiveTokens.primary.withValues(alpha: 0.45)
                : effectiveTokens.border.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Icon(
            LucideIcons.music,
            size: math.max(12.0, size * 0.42),
            color: isActive
                ? effectiveTokens.primary
                : effectiveTokens.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Compact segmented icon toggle for switching between List and Detail view modes.
class TrackViewModeToggle extends StatelessWidget {
  final TrackListViewMode mode;
  final ValueChanged<TrackListViewMode> onModeChanged;
  final Key listButtonKey;
  final Key detailButtonKey;

  const TrackViewModeToggle({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.listButtonKey,
    required this.detailButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.isDark ? LyraColors.charcoal950 : LyraColors.zinc100,
        borderRadius: BorderRadius.circular(7.0),
        border: Border.all(color: tokens.border, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ViewModeSegmentButton(
              key: listButtonKey,
              tooltip: 'List View',
              icon: LucideIcons.list,
              isSelected: mode == TrackListViewMode.list,
              tokens: tokens,
              onTap: () => onModeChanged(TrackListViewMode.list),
            ),
            const SizedBox(width: 2.0),
            _ViewModeSegmentButton(
              key: detailButtonKey,
              tooltip: 'Detail View',
              icon: LucideIcons.table2,
              isSelected: mode == TrackListViewMode.detail,
              tokens: tokens,
              onTap: () => onModeChanged(TrackListViewMode.detail),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeSegmentButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final bool isSelected;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;

  const _ViewModeSegmentButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_ViewModeSegmentButton> createState() => _ViewModeSegmentButtonState();
}

class _ViewModeSegmentButtonState extends State<_ViewModeSegmentButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final bgColor = widget.isSelected
        ? (tokens.isDark ? LyraColors.charcoal750 : const Color(0xFFFFFFFF))
        : (_isHovered
              ? (tokens.isDark
                    ? LyraColors.charcoal850
                    : LyraColors.zinc200.withValues(alpha: 0.6))
              : (tokens.isDark
                    ? LyraColors.charcoal950.withValues(alpha: 0.0)
                    : const Color(0x00FFFFFF)));
    final borderColor = widget.isSelected
        ? (tokens.isDark ? LyraColors.charcoal700 : tokens.border)
        : const Color(0x00000000);
    final fgColor = widget.isSelected || _isHovered
        ? tokens.text
        : tokens.textMuted;

    return LyraTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 28.0,
            height: 24.0,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Icon(widget.icon, size: 14.0, color: fgColor),
          ),
        ),
      ),
    );
  }
}

/// Builds inline secondary metadata widgets for List view rows respecting [orderedVisibleColumns].
List<Widget> buildTrackListSubtitleChildren(
  Track track,
  List<TrackColumn> orderedVisibleColumns,
  TextStyle style,
) {
  final parts = <String>[];
  for (final col in orderedVisibleColumns) {
    switch (col.name) {
      case 'title':
        final artist = track.artist.trim();
        if (artist.isNotEmpty) {
          parts.add(artist);
        } else {
          parts.add('Unknown Artist');
        }
        break;
      case 'album':
        if (track.album.trim().isNotEmpty) {
          parts.add(track.album);
        }
        break;
      case 'work':
        if (track.workTitle != null && track.workTitle!.trim().isNotEmpty) {
          parts.add(track.workTitle!);
        }
        break;
      case 'year':
        if (track.year != null && track.year! > 0) {
          parts.add('${track.year}');
        }
        break;
      case 'genre':
        if (track.genre != null && track.genre!.trim().isNotEmpty) {
          parts.add(track.genre!);
        }
        break;
      case 'trackNumber':
        if (track.trackNumber != null && track.trackNumber! > 0) {
          parts.add('Trk ${track.trackNumber}');
        }
        break;
      case 'isrc':
        if (track.isrc != null && track.isrc!.trim().isNotEmpty) {
          parts.add(track.isrc!);
        }
        break;
      case 'iswc':
        if (track.iswc != null && track.iswc!.trim().isNotEmpty) {
          parts.add(track.iswc!);
        }
        break;
      case 'musicbrainzId':
        if (track.musicBrainzId != null &&
            track.musicBrainzId!.trim().isNotEmpty) {
          parts.add(track.musicBrainzId!);
        }
        break;
    }
  }

  if (parts.isEmpty) return const <Widget>[];
  return <Widget>[
    Expanded(
      child: Text(
        parts.join(' · '),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ];
}

/// Computed trailing column widths for List view rows and headers so that
/// resolution and duration remain right-aligned while shrinking cleanly on narrow screens.
class TrackListTrailingMetrics {
  final double maxBadgeWidth;
  final double durationWidth;

  const TrackListTrailingMetrics({
    required this.maxBadgeWidth,
    required this.durationWidth,
  });
}

const double kMinTrackListBadgeWidth = 28.0;
const double kMinTrackListDurationWidth = 14.0;

/// Computes trailing badge/duration budgets given available row width and left fixed width.
TrackListTrailingMetrics computeTrackListTrailingMetrics({
  required double availableRowWidth,
  required double leftFixedWidth,
  required bool hasResolution,
  required bool hasDuration,
  double gapBetweenTrailing = 10.0,
  double textScale = 1.0,
  double baseDurationWidth = 52.0,
  double baseMaxBadgeWidth = 160.0,
}) {
  if (!hasResolution && !hasDuration) {
    return const TrackListTrailingMetrics(
      maxBadgeWidth: 0.0,
      durationWidth: 0.0,
    );
  }
  final scale = math.max(1.0, textScale);
  final minBadgeWidth = kMinTrackListBadgeWidth * scale;
  final minDurationWidth = kMinTrackListDurationWidth * scale;
  final minTitleWidth = math.min(
    80.0,
    math.max(24.0, availableRowWidth * 0.25),
  );
  final maxTrailing = math.max(
    0.0,
    availableRowWidth - leftFixedWidth - minTitleWidth,
  );
  if (hasResolution && hasDuration) {
    final usable = math.max(0.0, maxTrailing - gapBetweenTrailing);
    final rawDurationW = math.min(baseDurationWidth * scale, usable * 0.42);
    final rawBadgeW = math.min(
      baseMaxBadgeWidth * scale,
      math.max(0.0, usable - rawDurationW),
    );
    if (rawBadgeW < minBadgeWidth) {
      final fallbackDurationW = math.min(
        baseDurationWidth * scale,
        maxTrailing,
      );
      return TrackListTrailingMetrics(
        maxBadgeWidth: 0.0,
        durationWidth: fallbackDurationW < minDurationWidth
            ? 0.0
            : fallbackDurationW,
      );
    }
    return TrackListTrailingMetrics(
      maxBadgeWidth: rawBadgeW,
      durationWidth: rawDurationW < minDurationWidth ? 0.0 : rawDurationW,
    );
  } else if (hasDuration) {
    final durationW = math.min(baseDurationWidth * scale, maxTrailing);
    return TrackListTrailingMetrics(
      maxBadgeWidth: 0.0,
      durationWidth: durationW < minDurationWidth ? 0.0 : durationW,
    );
  } else {
    final badgeW = math.min(baseMaxBadgeWidth * scale, maxTrailing);
    return TrackListTrailingMetrics(
      maxBadgeWidth: badgeW < minBadgeWidth ? 0.0 : badgeW,
      durationWidth: 0.0,
    );
  }
}

/// Builds trailing widgets (`resolution` badge and `duration`) for List view rows
/// in the exact relative order defined by [orderedVisibleColumns].
List<Widget> buildTrackListTrailingChildren({
  required Track track,
  required List<TrackColumn> orderedVisibleColumns,
  required LyraThemeTokens tokens,
  int versionCount = 1,
  VoidCallback? onInspectAudio,
  double maxBadgeWidth = 160.0,
  double? durationWidth,
}) {
  final children = <Widget>[];
  for (final col in orderedVisibleColumns) {
    if (col == TrackColumn.resolution && maxBadgeWidth > 0) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 10.0));
      }
      final badge = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBadgeWidth),
        child: LyraBadge.outline(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          child: Text(
            versionCount > 1
                ? '${track.formattedQuality} · $versionCount versions'
                : track.formattedQuality,
            style: LyraTypography.small(
              tokens,
            ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      children.add(
        onInspectAudio != null
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onInspectAudio,
                  child: badge,
                ),
              )
            : badge,
      );
    } else if (col == TrackColumn.duration &&
        (durationWidth == null || durationWidth > 0)) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 10.0));
      }
      final textWidget = Text(
        track.formattedDuration,
        textAlign: TextAlign.right,
        style: LyraTypography.small(tokens).copyWith(
          color: tokens.textMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      children.add(
        durationWidth != null
            ? SizedBox(
                width: durationWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: textWidget,
                ),
              )
            : textWidget,
      );
    }
  }
  return children;
}

/// Builds trailing header labels (`resolution` and `duration`) for List view
/// headers matching [buildTrackListTrailingChildren] visibility and width budgets.
List<Widget> buildTrackListTrailingHeaderLabels({
  required List<TrackColumn> orderedVisibleColumns,
  required TrackListTrailingMetrics metrics,
  required TextStyle style,
  Widget Function(TrackColumn col, bool alignRight)? labelBuilder,
}) {
  final labels = <Widget>[];
  for (final col in orderedVisibleColumns) {
    if (col == TrackColumn.resolution && metrics.maxBadgeWidth > 0) {
      if (labels.isNotEmpty) {
        labels.add(const SizedBox(width: 10.0));
      }
      labels.add(
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.maxBadgeWidth),
          child:
              labelBuilder?.call(col, false) ??
              Text(
                col.headerLabel,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        ),
      );
    } else if (col == TrackColumn.duration && metrics.durationWidth > 0) {
      if (labels.isNotEmpty) {
        labels.add(const SizedBox(width: 10.0));
      }
      labels.add(
        SizedBox(
          width: metrics.durationWidth,
          child:
              labelBuilder?.call(col, true) ??
              Text(
                col.headerLabel,
                style: style,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        ),
      );
    }
  }
  return labels;
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
  final ValueChanged<Track>? onTrackFocus;
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
  final TrackActivationMode? trackActivationMode;
  final bool isNowPlayingExpanded;
  final Map<String, double>? columnWidths;
  final ValueChanged<Map<String, double>>? onColumnWidthsChanged;
  final TrackListViewMode? viewMode;
  final bool? showHeader;

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
    this.onTrackFocus,
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
    this.trackActivationMode,
    this.isNowPlayingExpanded = false,
    this.columnWidths,
    this.onColumnWidthsChanged,
    this.viewMode,
    this.showHeader,
  });

  @override
  State<TracksView> createState() => _TracksViewState();
}

class _TracksViewState extends State<TracksView> {
  late List<TrackColumn> _internalColumnOrder;
  late Set<TrackColumn> _internalVisibleColumns;
  late Map<String, double> _columnWidths;
  late Map<String, double> _committedColumnWidths;
  late TrackListViewMode _localViewMode;
  late bool _localShowHeader;
  late final OverlayPortalController _columnsOverlayController;
  late final ValueNotifier<Offset> _columnsPositionNotifier;
  TrackColumn? _sortColumn;
  bool _sortAscending = true;

  final Set<String> _selectedTrackIds = {};
  String? _selectionAnchorId;
  bool _isModifierSelectionActive = false;

  TrackActivationMode get _effectiveActivationMode =>
      widget.trackActivationMode ??
      widget.preferencesService?.trackActivationMode ??
      TrackActivationMode.doubleClick;

  TrackListViewMode get _effectiveViewMode => widget.viewMode ?? _localViewMode;
  bool get _effectiveShowHeader => widget.showHeader ?? _localShowHeader;

  void _handleSort(TrackColumn col) {
    if (col == TrackColumn.index || col == TrackColumn.cover) return;
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

  void _syncColumnsFromPreferences() {
    final prefs = widget.preferencesService;
    if (prefs == null) return;
    final colMap = {for (final c in TrackColumn.values) c.name: c};
    if (widget.columnOrder == null) {
      final savedOrder = prefs.getTrackColumnOrder();
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
      final savedVisible = prefs.getTrackVisibleColumns();
      _internalVisibleColumns = savedVisible != null
          ? normalizeTrackVisibleColumns(
              savedVisible
                  .map((n) => colMap[n])
                  .whereType<TrackColumn>()
                  .toSet(),
            )
          : Set<TrackColumn>.from(TrackColumn.defaultVisibleColumns);
    }
    if (widget.columnWidths == null) {
      _columnWidths = Map<String, double>.from(prefs.trackColumnWidths);
      _committedColumnWidths = Map<String, double>.from(_columnWidths);
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
        widget.preferencesService?.trackViewMode ??
        TrackListViewMode.detail;
    _localShowHeader =
        widget.showHeader ?? widget.preferencesService?.showTrackHeader ?? true;
    _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    _syncColumnsFromPreferences();
    _columnWidths = Map<String, double>.from(
      widget.columnWidths ?? widget.preferencesService?.trackColumnWidths ?? {},
    );
    _committedColumnWidths = Map<String, double>.from(_columnWidths);
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.viewMode == null && widget.preferencesService != null) {
        _localViewMode = widget.preferencesService!.trackViewMode;
      }
      if (widget.showHeader == null && widget.preferencesService != null) {
        _localShowHeader = widget.preferencesService!.showTrackHeader;
      }
      _syncColumnsFromPreferences();
    });
  }

  @override
  void didUpdateWidget(covariant TracksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferencesService != oldWidget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      if (widget.viewMode == null && widget.preferencesService != null) {
        _localViewMode = widget.preferencesService!.trackViewMode;
      }
      if (widget.showHeader == null && widget.preferencesService != null) {
        _localShowHeader = widget.preferencesService!.showTrackHeader;
      }
      _syncColumnsFromPreferences();
    }
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
    }
    if (widget.columnWidths != null &&
        widget.columnWidths != oldWidget.columnWidths) {
      _columnWidths = Map<String, double>.from(widget.columnWidths!);
      _committedColumnWidths = Map<String, double>.from(_columnWidths);
    }
  }

  @override
  void dispose() {
    widget.preferencesService?.removeListener(_onPreferencesChanged);
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

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedTrackIds.isNotEmpty) {
        final displayTracks = _getDisplayTracks();
        Track? trackToPlay;
        if (_selectionAnchorId != null) {
          for (final t in displayTracks) {
            if (t.id == _selectionAnchorId) {
              trackToPlay = t;
              break;
            }
          }
        }
        if (trackToPlay == null) {
          for (final t in displayTracks) {
            if (_selectedTrackIds.contains(t.id)) {
              trackToPlay = t;
              break;
            }
          }
        }
        if (trackToPlay != null) {
          LyraContextMenuCoordinator.hideActive();
          widget.onTrackSelected(trackToPlay);
          return true;
        }
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

    if (_effectiveActivationMode == TrackActivationMode.singleClick) {
      final isCurrent = widget.currentTrack?.id == track.id;
      if (isCurrent) {
        widget.onTogglePlay();
      } else {
        widget.onTrackSelected(track);
      }
    } else {
      widget.onTrackFocus?.call(track);
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

  static List<TrackColumn> _normalizeColumnOrder(List<TrackColumn>? order) =>
      normalizeTrackColumnOrder(order);

  static Set<TrackColumn> _normalizeVisibleColumns(Set<TrackColumn>? visible) =>
      normalizeTrackVisibleColumns(visible);

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
    if (widget.onVisibleColumnsChanged == null) {
      widget.preferencesService?.setTrackVisibleColumns(
        current.map((c) => c.name).toSet(),
      );
    }
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
    if (widget.onColumnOrderChanged == null) {
      widget.preferencesService?.setTrackColumnOrder(
        newOrder.map((c) => c.name).toList(),
      );
    }
    setState(() {
      _internalColumnOrder = newOrder;
    });
  }

  void _updateColumnWidth(String colName, double newWidth) {
    setState(() {
      _columnWidths[colName] = newWidth;
    });
  }

  void _onColumnResizeEnd() {
    if (mapEquals(_columnWidths, _committedColumnWidths)) return;
    final snapshot = Map<String, double>.from(_columnWidths);
    _committedColumnWidths = snapshot;
    widget.preferencesService?.setTrackColumnWidths(snapshot);
    widget.onColumnWidthsChanged?.call(snapshot);
  }

  void _resetColumnWidth(String colName) {
    if (!_columnWidths.containsKey(colName)) return;
    setState(() {
      _columnWidths.remove(colName);
    });
    final snapshot = Map<String, double>.from(_columnWidths);
    _committedColumnWidths = snapshot;
    widget.preferencesService?.setTrackColumnWidths(snapshot);
    widget.onColumnWidthsChanged?.call(snapshot);
  }

  void _resetColumns() {
    final defaultOrder = List<TrackColumn>.from(TrackColumn.values);
    final defaultVisible = Set<TrackColumn>.from(
      TrackColumn.defaultVisibleColumns,
    );
    final hadCustomWidths = _columnWidths.isNotEmpty;
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    if (widget.onColumnOrderChanged == null) {
      widget.preferencesService?.setTrackColumnOrder(
        defaultOrder.map((c) => c.name).toList(),
      );
    }
    if (widget.onVisibleColumnsChanged == null) {
      widget.preferencesService?.setTrackVisibleColumns(
        defaultVisible.map((c) => c.name).toSet(),
      );
    }
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
      _columnWidths.clear();
    });
    if (hadCustomWidths) {
      final snapshot = Map<String, double>.from(_columnWidths);
      _committedColumnWidths = snapshot;
      widget.preferencesService?.setTrackColumnWidths(snapshot);
      widget.onColumnWidthsChanged?.call(snapshot);
    }
  }

  Widget _buildHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    Widget cellContent;
    final isSortable = col != TrackColumn.index && col != TrackColumn.cover;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  col.headerLabel,
                  style: headerTextStyle,
                  maxLines: 1,
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
                  maxLines: 1,
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

    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    final customWidth = _columnWidths[col.name];
    final defaultWidth = col.width != null
        ? (col == TrackColumn.cover ? col.width! : col.width! * scale)
        : null;
    final effectiveWidth = customWidth ?? defaultWidth;
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

  double _requiredDetailTableWidth(
    List<TrackColumn> visibleOrdered, {
    double textScale = 1.0,
  }) {
    if (visibleOrdered.isEmpty) return 0.0;
    final scale = math.max(1.0, textScale);
    var width = LyraSpacing.xl * 2;
    for (final col in visibleOrdered) {
      final customWidth = _columnWidths[col.name];
      if (customWidth != null) {
        width += customWidth;
      } else if (col.width != null) {
        width += col == TrackColumn.cover ? col.width! : col.width! * scale;
      } else {
        width += (col.flex ?? 1) * 32.0 * scale;
      }
    }
    return width;
  }

  Widget _buildSortableListHeaderLabel({
    required TrackColumn col,
    required String label,
    required LyraThemeTokens tokens,
    bool alignRight = false,
  }) {
    final isSorted = _sortColumn == col;
    final style = LyraTypography.small(tokens).copyWith(
      color: isSorted ? tokens.text : tokens.textMuted,
      fontWeight: FontWeight.bold,
    );
    final sortIcon = isSorted
        ? Icon(
            _sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
            size: 12.0,
            color: tokens.primary,
          )
        : null;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (sortIcon != null) ...[const SizedBox(width: 4.0), sortIcon],
      ],
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleSort(col),
        child: alignRight
            ? Align(alignment: Alignment.centerRight, child: row)
            : Align(alignment: Alignment.centerLeft, child: row),
      ),
    );
  }

  Widget _buildListHeaderRow(
    LyraThemeTokens tokens,
    List<TrackColumn> orderedVisible,
  ) {
    final headerTextStyle = LyraTypography.small(
      tokens,
    ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.bold);
    final showIndex = orderedVisible.contains(TrackColumn.index);
    final showCover = orderedVisible.contains(TrackColumn.cover);
    final hasResolution = orderedVisible.contains(TrackColumn.resolution);
    final hasDuration = orderedVisible.contains(TrackColumn.duration);
    final hasTrailing = hasResolution || hasDuration;

    return LayoutBuilder(
      builder: (context, rowConstraints) {
        final textScale = math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(1.0),
        );
        final rawIndexWidth =
            _columnWidths['index'] ??
            ((TrackColumn.index.width ?? 40.0) * textScale);
        final indexWidth = math.min(
          rawIndexWidth,
          rowConstraints.maxWidth * 0.2,
        );
        final leftFixedWidth =
            (showIndex ? indexWidth : 0.0) +
            (showCover ? 52.0 : 0.0) +
            (hasTrailing ? 12.0 : 0.0);
        final metrics = computeTrackListTrailingMetrics(
          availableRowWidth: rowConstraints.maxWidth,
          leftFixedWidth: leftFixedWidth,
          hasResolution: hasResolution,
          hasDuration: hasDuration,
          gapBetweenTrailing: 10.0,
          textScale: textScale,
        );

        final trailingLabels = buildTrackListTrailingHeaderLabels(
          orderedVisibleColumns: orderedVisible,
          metrics: metrics,
          style: headerTextStyle,
          labelBuilder: (col, alignRight) => _buildSortableListHeaderLabel(
            col: col,
            label: col.headerLabel,
            tokens: tokens,
            alignRight: alignRight,
          ),
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
              child: _buildSortableListHeaderLabel(
                col: TrackColumn.title,
                label: 'Title & Details',
                tokens: tokens,
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
            GestureDetector(
              key: const Key('tracks_view_header'),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tracks Library',
                                  style: LyraTypography.h2(tokens),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: LyraSpacing.xs),
                                Text(
                                  '${widget.tracks.length} tracks',
                                  style: LyraTypography.muted(tokens),
                                ),
                              ],
                            ),
                          ),
                          if (widget.filterLabel != null) ...[
                            const SizedBox(width: LyraSpacing.lg),
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 360.0,
                                ),
                                padding: EdgeInsets.only(
                                  left: 8.0,
                                  top: widget.onClearFilter != null ? 2.0 : 4.0,
                                  bottom: widget.onClearFilter != null
                                      ? 2.0
                                      : 4.0,
                                  right: widget.onClearFilter != null
                                      ? 3.0
                                      : 8.0,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.secondary.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(
                                    color: tokens.border,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.filterLabel!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: LyraTypography.small(tokens)
                                            .copyWith(
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
                  ],
                ),
              ),
            ),

            // Table Header + Rows with Horizontal Scroll Support in Detail Mode
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

                  final content = SizedBox(
                    width: effectiveWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DraggableColumnsOverlay(
                          key: const Key('tracks_table_header_context_menu'),
                          controller: _columnsOverlayController,
                          positionNotifier: _columnsPositionNotifier,
                          estimatedCardHeight:
                              60.0 + _effectiveColumnOrder.length * 36.0,
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
                                _proxyDecorator(
                                  child,
                                  index,
                                  animation,
                                  tokens,
                                ),
                            itemCount: _effectiveColumnOrder.length,
                            onReorder: _onReorder,
                            itemBuilder: (context, index) {
                              final col = _effectiveColumnOrder[index];
                              final isVisible = _effectiveVisibleColumns
                                  .contains(col);
                              final canToggle =
                                  !col.isMandatory &&
                                  (!isVisible ||
                                      _effectiveVisibleColumns.length > 1);
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
                          child: _effectiveShowHeader
                              ? Container(
                                  key: const Key('tracks_table_header'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: LyraSpacing.xl,
                                    vertical: LyraSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.background,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: tokens.border,
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  child: isDetail
                                      ? Row(
                                          children: [
                                            for (final col in orderedVisible)
                                              _buildHeaderCell(col, tokens),
                                          ],
                                        )
                                      : _buildListHeaderRow(
                                          tokens,
                                          orderedVisible,
                                        ),
                                )
                              : const SizedBox.shrink(),
                        ),
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
                            child:
                                NotificationListener<ScrollStartNotification>(
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
                                      _effectiveViewMode ==
                                              TrackListViewMode.list
                                          ? 64.0
                                          : 56.0,
                                      (_effectiveViewMode ==
                                                  TrackListViewMode.list
                                              ? 64.0
                                              : 56.0) *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1.0),
                                    ),
                                    itemBuilder: (context, index) {
                                      final track = displayTracks[index];
                                      final isCurrent =
                                          widget.currentTrack?.id == track.id;
                                      final isSelected = _selectedTrackIds
                                          .contains(track.id);
                                      final versionCount =
                                          widget.audioVersionCounts?[track
                                              .id] ??
                                          widget.audioVersionCounts?[track
                                              .pcmHash] ??
                                          1;

                                      final onInspectAudio =
                                          widget.onInspectAudio != null
                                          ? () => widget.onInspectAudio!(track)
                                          : (widget.onInspectTrack != null
                                                ? () => widget.onInspectTrack!(
                                                    track,
                                                  )
                                                : null);

                                      return _TrackRow(
                                        key: ValueKey(track.id),
                                        index: index + 1,
                                        track: track,
                                        viewMode: _effectiveViewMode,
                                        columnWidths: _columnWidths,
                                        isCurrent: isCurrent,
                                        isPlaying:
                                            isCurrent && widget.isPlaying,
                                        isSelected: isSelected,
                                        versionCount: versionCount,
                                        columnOrder: _effectiveColumnOrder,
                                        visibleColumns:
                                            _effectiveVisibleColumns,
                                        onTap: () => _handleTrackTap(
                                          track,
                                          displayTracks,
                                        ),
                                        onDoubleTap:
                                            _effectiveActivationMode ==
                                                TrackActivationMode.doubleClick
                                            ? () =>
                                                  widget.onTrackSelected(track)
                                            : null,
                                        onPlayNow: () =>
                                            widget.onTrackSelected(track),
                                        onPlayNext: widget.onPlayNext != null
                                            ? () => widget.onPlayNext!(track)
                                            : null,
                                        onAddToQueue:
                                            widget.onAddToQueue != null
                                            ? () => widget.onAddToQueue!(track)
                                            : null,
                                        onAddToPlaylist:
                                            widget.onAddToPlaylist != null
                                            ? () =>
                                                  widget.onAddToPlaylist!(track)
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
                  );

                  if (needsHorizontalScroll) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: content,
                    );
                  }
                  return content;
                },
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
                    LyraCheckbox(
                      key: Key('track_col_checkbox_${col.name}'),
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
  final GlobalKey _cellBodyKey = GlobalKey();
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragStartWidth = 0.0;
  double _accumulatedDelta = 0.0;

  double get _minWidth {
    if (widget.col == TrackColumn.index) return 40.0;
    if (widget.col == TrackColumn.cover) return 48.0;
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
                final wasDragging = _isDragging;
                setState(() => _isDragging = false);
                if (wasDragging) {
                  widget.onResizeEnd?.call();
                }
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

    final keyedCellBody = KeyedSubtree(key: _cellBodyKey, child: cellBody);

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: keyedCellBody);
    } else {
      return Expanded(flex: widget.flex ?? 1, child: keyedCellBody);
    }
  }
}

/// Single row item in the Tracks table.
class _TrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final TrackListViewMode viewMode;
  final bool isCurrent;
  final bool isPlaying;
  final bool isSelected;
  final int versionCount;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
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
    this.viewMode = TrackListViewMode.detail,
    required this.isCurrent,
    required this.isPlaying,
    this.isSelected = false,
    this.versionCount = 1,
    required this.onTap,
    this.onDoubleTap,
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

  Widget _wrapRowCell({required TrackColumn col, required Widget content}) {
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    final customWidth = widget.columnWidths?[col.name];
    final defaultWidth = col.width != null
        ? (col == TrackColumn.cover ? col.width! : col.width! * scale)
        : null;
    final effectiveWidth = customWidth ?? defaultWidth;
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      case 'cover':
        return _wrapRowCell(
          col: col,
          content: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TrackCoverThumbnail(
                track: widget.track,
                isActive: widget.isCurrent,
                size: 36.0,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
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
                  maxLines: 1,
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
              maxLines: 1,
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
              maxLines: 1,
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
                      maxLines: 1,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
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
                            maxLines: 1,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                            maxLines: 1,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                            maxLines: 1,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
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

  Widget _buildListRowContent(LyraThemeTokens tokens) {
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
    final subtitleChildren = buildTrackListSubtitleChildren(
      widget.track,
      orderedVisible,
      LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
    );

    return LayoutBuilder(
      builder: (context, rowConstraints) {
        final textScale = math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(1.0),
        );
        final rawIndexWidth =
            widget.columnWidths?['index'] ??
            ((TrackColumn.index.width ?? 40.0) * textScale);
        final indexWidth = math.min(
          rawIndexWidth,
          rowConstraints.maxWidth * 0.2,
        );
        final leftFixedWidth =
            (showIndex ? indexWidth : 0.0) +
            (showCover ? 52.0 : 0.0) +
            (hasTrailing ? 12.0 : 0.0);
        final metrics = computeTrackListTrailingMetrics(
          availableRowWidth: rowConstraints.maxWidth,
          leftFixedWidth: leftFixedWidth,
          hasResolution: hasResolution,
          hasDuration: hasDuration,
          gapBetweenTrailing: 10.0,
          textScale: textScale,
        );
        final trailingChildren = buildTrackListTrailingChildren(
          track: widget.track,
          orderedVisibleColumns: orderedVisible,
          tokens: tokens,
          versionCount: widget.versionCount,
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
                  child: _isHovered || widget.isPlaying
                      ? Icon(
                          widget.isPlaying
                              ? LucideIcons.volume2
                              : LucideIcons.play,
                          size: 16.0,
                          color: widget.isCurrent
                              ? tokens.primary
                              : tokens.text,
                        )
                      : Text(
                          '${widget.index}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              ),
            if (showCover)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TrackCoverThumbnail(
                  track: widget.track,
                  isActive: widget.isCurrent,
                  size: 40.0,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LyraTypography.p(tokens).copyWith(
                      fontWeight: widget.isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: widget.isCurrent ? tokens.primary : tokens.text,
                    ),
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
              Row(mainAxisSize: MainAxisSize.min, children: trailingChildren),
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
    final isSelected = widget.isSelected;
    final isHoverOrMenu = _isHovered || _contextMenuController.isOpen;

    Color? rowBackgroundColor;
    if (isSelected) {
      rowBackgroundColor = _isHovered
          ? tokens.surfaceElevatedHover
          : tokens.surfaceElevated;
    } else if (widget.isCurrent) {
      rowBackgroundColor = tokens.surfaceSecondary;
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
            onTap: _handleTap,
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
              child: widget.viewMode == TrackListViewMode.list
                  ? _buildListRowContent(tokens)
                  : Row(
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
