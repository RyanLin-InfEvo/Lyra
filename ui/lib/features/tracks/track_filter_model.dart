// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../models/playlist.dart';
import '../models/tag.dart';
import '../models/track.dart';

/// Filterable track attributes supported by the Tracks boolean filter builder.
enum TrackFilterField { tag, playlist, artist, album, genre, format }

extension TrackFilterFieldX on TrackFilterField {
  /// Human-readable column/attribute label.
  String get label {
    switch (this) {
      case TrackFilterField.tag:
        return 'Tag';
      case TrackFilterField.playlist:
        return 'Playlist';
      case TrackFilterField.artist:
        return 'Artist';
      case TrackFilterField.album:
        return 'Album';
      case TrackFilterField.genre:
        return 'Genre';
      case TrackFilterField.format:
        return 'Format';
    }
  }

  /// Whether a track can hold multiple simultaneous values for this field.
  bool get isMultiValued =>
      this == TrackFilterField.tag || this == TrackFilterField.playlist;

  /// Operators valid for this field's cardinality.
  List<TrackFilterOperator> get availableOperators => isMultiValued
      ? const [
          TrackFilterOperator.isAnyOf,
          TrackFilterOperator.isAllOf,
          TrackFilterOperator.isNoneOf,
        ]
      : const [TrackFilterOperator.isAnyOf, TrackFilterOperator.isNoneOf];
}

/// Token comparison operator inside a single filter rule.
enum TrackFilterOperator { isAnyOf, isAllOf, isNoneOf }

extension TrackFilterOperatorX on TrackFilterOperator {
  /// Long human-readable label for rule operator dropdowns.
  String get label {
    switch (this) {
      case TrackFilterOperator.isAnyOf:
        return 'is any of';
      case TrackFilterOperator.isAllOf:
        return 'is all of';
      case TrackFilterOperator.isNoneOf:
        return 'is none of';
    }
  }

  /// Concise joiner label rendered between multi-select tokens inside a rule.
  String get tokenJoinLabel {
    switch (this) {
      case TrackFilterOperator.isAnyOf:
        return 'OR';
      case TrackFilterOperator.isAllOf:
        return 'AND';
      case TrackFilterOperator.isNoneOf:
        return 'NOR';
    }
  }
}

/// Boolean combinator joining rules inside a [TrackFilterGroup].
enum TrackFilterCombinator { and, or }

extension TrackFilterCombinatorX on TrackFilterCombinator {
  /// Human-readable label shown in the group combinator selector.
  String get label {
    switch (this) {
      case TrackFilterCombinator.and:
        return 'Match ALL (AND)';
      case TrackFilterCombinator.or:
        return 'Match ANY (OR)';
    }
  }

  /// Short infix connector used in filter summaries.
  String get shortLabel => this == TrackFilterCombinator.and ? 'AND' : 'OR';
}

/// Value option displayed in a filter rule's multi-select value picker.
@immutable
class TrackFilterOption {
  final String value;
  final String label;

  const TrackFilterOption({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackFilterOption &&
          other.value == value &&
          other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Pre-indexed library lookup context for fast [TrackFilterQuery] evaluation
/// and UI value-picker population.
@immutable
class TrackFilterContext {
  final List<Tag> tags;
  final List<Playlist> playlists;
  final Map<String, Set<String>> _tagIdsByTrackId;
  final Map<String, Set<String>> _playlistIdsByTrackId;
  final Map<String, String> _tagNamesById;
  final Map<String, String> _playlistTitlesById;
  final List<String> artists;
  final List<String> albums;
  final List<String> genres;
  final List<String> formats;

  const TrackFilterContext._({
    required this.tags,
    required this.playlists,
    required Map<String, Set<String>> tagIdsByTrackId,
    required Map<String, Set<String>> playlistIdsByTrackId,
    required Map<String, String> tagNamesById,
    required Map<String, String> playlistTitlesById,
    required this.artists,
    required this.albums,
    required this.genres,
    required this.formats,
  }) : _tagIdsByTrackId = tagIdsByTrackId,
       _playlistIdsByTrackId = playlistIdsByTrackId,
       _tagNamesById = tagNamesById,
       _playlistTitlesById = playlistTitlesById;

  /// Builds an empty context (useful as a safe default in standalone widgets).
  const TrackFilterContext.empty()
    : tags = const [],
      playlists = const [],
      _tagIdsByTrackId = const {},
      _playlistIdsByTrackId = const {},
      _tagNamesById = const {},
      _playlistTitlesById = const {},
      artists = const [],
      albums = const [],
      genres = const [],
      formats = const [];

  /// Constructs a lookup index from the current library catalog.
  factory TrackFilterContext.fromLibrary({
    required List<Track> tracks,
    required List<Tag> tags,
    required List<Playlist> playlists,
    required Map<String, Set<String>> taggedTrackIdsByTag,
  }) {
    final tagIdsByTrack = <String, Set<String>>{};
    for (final entry in taggedTrackIdsByTag.entries) {
      for (final trackId in entry.value) {
        (tagIdsByTrack[trackId] ??= <String>{}).add(entry.key);
      }
    }

    final playlistIdsByTrack = <String, Set<String>>{};
    for (final playlist in playlists) {
      for (final trackId in playlist.trackIds) {
        (playlistIdsByTrack[trackId] ??= <String>{}).add(playlist.id);
      }
    }

    final artistSet = <String>{};
    final albumSet = <String>{};
    final genreSet = <String>{};
    final formatSet = <String>{};
    for (final track in tracks) {
      final a = track.artist.trim();
      if (a.isNotEmpty) artistSet.add(a);
      final al = track.album.trim();
      if (al.isNotEmpty) albumSet.add(al);
      final g = track.genre?.trim() ?? '';
      if (g.isNotEmpty) genreSet.add(g);
      final f = track.format?.trim() ?? '';
      if (f.isNotEmpty) formatSet.add(f);
    }

    final sortedArtists = artistSet.toList()..sort();
    final sortedAlbums = albumSet.toList()..sort();
    final sortedGenres = genreSet.toList()..sort();
    final sortedFormats = formatSet.toList()..sort();

    return TrackFilterContext._(
      tags: List<Tag>.unmodifiable(tags),
      playlists: List<Playlist>.unmodifiable(playlists),
      tagIdsByTrackId: tagIdsByTrack,
      playlistIdsByTrackId: playlistIdsByTrack,
      tagNamesById: {for (final tag in tags) tag.id: tag.displayName},
      playlistTitlesById: {
        for (final playlist in playlists) playlist.id: playlist.displayTitle,
      },
      artists: List<String>.unmodifiable(sortedArtists),
      albums: List<String>.unmodifiable(sortedAlbums),
      genres: List<String>.unmodifiable(sortedGenres),
      formats: List<String>.unmodifiable(sortedFormats),
    );
  }

  /// Returns the tag IDs linked to [trackId].
  Set<String> tagIdsForTrack(String trackId) =>
      _tagIdsByTrackId[trackId] ?? const {};

  /// Returns the playlist IDs containing [trackId].
  Set<String> playlistIdsForTrack(String trackId) =>
      _playlistIdsByTrackId[trackId] ?? const {};

  /// Returns selectable options for [field] sorted for display.
  List<TrackFilterOption> optionsForField(TrackFilterField field) {
    switch (field) {
      case TrackFilterField.tag:
        return [
          for (final tag in tags)
            TrackFilterOption(value: tag.id, label: tag.displayName),
        ];
      case TrackFilterField.playlist:
        return [
          for (final playlist in playlists)
            TrackFilterOption(value: playlist.id, label: playlist.displayTitle),
        ];
      case TrackFilterField.artist:
        return [
          for (final artist in artists)
            TrackFilterOption(value: artist, label: artist),
        ];
      case TrackFilterField.album:
        return [
          for (final album in albums)
            TrackFilterOption(value: album, label: album),
        ];
      case TrackFilterField.genre:
        return [
          for (final genre in genres)
            TrackFilterOption(value: genre, label: genre),
        ];
      case TrackFilterField.format:
        return [
          for (final format in formats)
            TrackFilterOption(value: format, label: format),
        ];
    }
  }

  /// Resolves a user-facing label for a raw stored filter token [value].
  String displayLabelFor(TrackFilterField field, String value) {
    switch (field) {
      case TrackFilterField.tag:
        return _tagNamesById[value] ?? value;
      case TrackFilterField.playlist:
        return _playlistTitlesById[value] ?? value;
      case TrackFilterField.artist:
      case TrackFilterField.album:
      case TrackFilterField.genre:
      case TrackFilterField.format:
        return value;
    }
  }
}

/// Single condition rule: `[field] [operator] [values...]`.
///
/// An empty [values] list marks the rule as incomplete/inactive so adding a new
/// blank rule in the UI does not immediately clear the track table.
@immutable
class TrackFilterRule {
  final String id;
  final TrackFilterField field;
  final TrackFilterOperator operator;
  final List<String> values;

  const TrackFilterRule({
    required this.id,
    required this.field,
    this.operator = TrackFilterOperator.isAnyOf,
    this.values = const [],
  });

  List<String> get _effectiveValues => [
    for (final v in values)
      if (v.trim().isNotEmpty) v,
  ];

  /// Whether the rule has at least one non-whitespace selected token value.
  bool get isActive => values.any((v) => v.trim().isNotEmpty);

  /// Evaluates whether [track] satisfies this rule within [context].
  bool matches(Track track, TrackFilterContext context) {
    final effective = _effectiveValues;
    if (effective.isEmpty) return true;

    bool containsValue(String target) {
      switch (field) {
        case TrackFilterField.tag:
          return context.tagIdsForTrack(track.id).contains(target);
        case TrackFilterField.playlist:
          return context.playlistIdsForTrack(track.id).contains(target);
        case TrackFilterField.artist:
          return track.artist.trim().toLowerCase() ==
              target.trim().toLowerCase();
        case TrackFilterField.album:
          return track.album.trim().toLowerCase() ==
              target.trim().toLowerCase();
        case TrackFilterField.genre:
          return (track.genre?.trim().toLowerCase() ?? '') ==
              target.trim().toLowerCase();
        case TrackFilterField.format:
          return (track.format?.trim().toLowerCase() ?? '') ==
              target.trim().toLowerCase();
      }
    }

    switch (operator) {
      case TrackFilterOperator.isAnyOf:
        return effective.any(containsValue);
      case TrackFilterOperator.isAllOf:
        return effective.every(containsValue);
      case TrackFilterOperator.isNoneOf:
        return effective.every((v) => !containsValue(v));
    }
  }

  /// Creates an updated copy of this rule, normalizing unsupported operators
  /// when switching to a single-valued field.
  TrackFilterRule copyWith({
    String? id,
    TrackFilterField? field,
    TrackFilterOperator? operator,
    List<String>? values,
  }) {
    final nextField = field ?? this.field;
    var nextOp = operator ?? this.operator;
    if (!nextField.availableOperators.contains(nextOp)) {
      nextOp = nextField.availableOperators.first;
    }
    return TrackFilterRule(
      id: id ?? this.id,
      field: nextField,
      operator: nextOp,
      values: values ?? this.values,
    );
  }

  /// Formats this rule as a compact human-readable expression fragment.
  String formatSummary(TrackFilterContext context) {
    final labels = [
      for (final value in values) context.displayLabelFor(field, value),
    ];
    if (labels.isEmpty) return '${field.label}: (any)';
    final joined = labels.join(' ${operator.tokenJoinLabel} ');
    if (operator == TrackFilterOperator.isNoneOf) {
      return '${field.label} != ($joined)';
    }
    if (labels.length > 1) {
      return '${field.label}: ($joined)';
    }
    return '${field.label}: $joined';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackFilterRule &&
          other.id == id &&
          other.field == field &&
          other.operator == operator &&
          listEquals(other.values, values);

  @override
  int get hashCode => Object.hash(id, field, operator, Object.hashAll(values));
}

/// A group of [TrackFilterRule]s joined by [combinator] (`AND` or `OR`).
@immutable
class TrackFilterGroup {
  final String id;
  final TrackFilterCombinator combinator;
  final List<TrackFilterRule> rules;

  const TrackFilterGroup({
    required this.id,
    this.combinator = TrackFilterCombinator.and,
    this.rules = const [],
  });

  /// Whether at least one rule in this group has selected values.
  bool get isActive => rules.any((r) => r.isActive);

  /// Evaluates all active rules inside this group against [track].
  bool matches(Track track, TrackFilterContext context) {
    final activeRules = rules.where((r) => r.isActive).toList();
    if (activeRules.isEmpty) return true;
    if (combinator == TrackFilterCombinator.and) {
      return activeRules.every((r) => r.matches(track, context));
    }
    return activeRules.any((r) => r.matches(track, context));
  }

  /// Creates an updated copy of this group.
  TrackFilterGroup copyWith({
    String? id,
    TrackFilterCombinator? combinator,
    List<TrackFilterRule>? rules,
  }) {
    return TrackFilterGroup(
      id: id ?? this.id,
      combinator: combinator ?? this.combinator,
      rules: rules ?? this.rules,
    );
  }

  /// Formats active rules in this group into a readable clause.
  String formatSummary(TrackFilterContext context) {
    final activeRules = rules.where((r) => r.isActive).toList();
    if (activeRules.isEmpty) return '';
    return activeRules
        .map((r) => r.formatSummary(context))
        .join(' ${combinator.shortLabel} ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackFilterGroup &&
          other.id == id &&
          other.combinator == combinator &&
          listEquals(other.rules, rules);

  @override
  int get hashCode => Object.hash(id, combinator, Object.hashAll(rules));
}

/// Top-level Disjunctive Normal Query (`Group1 OR Group2 OR ...`) with
/// per-group `AND`/`OR` rules and per-rule multi-value OR/AND/NOR tokens.
@immutable
class TrackFilterQuery {
  final List<TrackFilterGroup> groups;

  const TrackFilterQuery({this.groups = const []});

  /// Convenience constructor representing a sidebar multi-tag filter.
  factory TrackFilterQuery.forTags(
    Iterable<String> tagIds, {
    TrackFilterOperator operator = TrackFilterOperator.isAnyOf,
  }) {
    final ordered = tagIds.toList();
    if (ordered.isEmpty) return const TrackFilterQuery();
    return TrackFilterQuery(
      groups: [
        TrackFilterGroup(
          id: 'group-tags',
          combinator: TrackFilterCombinator.and,
          rules: [
            TrackFilterRule(
              id: 'rule-tags',
              field: TrackFilterField.tag,
              operator: operator,
              values: ordered,
            ),
          ],
        ),
      ],
    );
  }

  /// Whether at least one group contains an active rule.
  bool get isActive => groups.any((g) => g.isActive);

  /// Total number of active rules across all groups.
  int get activeRuleCount => groups.fold<int>(
    0,
    (sum, group) => sum + group.rules.where((r) => r.isActive).length,
  );

  /// All tag IDs currently referenced by positive tag rules, useful for keeping
  /// sidebar tag selection highlights in sync.
  Set<String> get referencedTagIds {
    final ids = <String>{};
    for (final group in groups) {
      for (final rule in group.rules) {
        if (rule.field == TrackFilterField.tag &&
            rule.operator != TrackFilterOperator.isNoneOf) {
          for (final v in rule.values) {
            if (v.trim().isNotEmpty) {
              ids.add(v);
            }
          }
        }
      }
    }
    return ids;
  }

  /// Returns a copy with [tagId] pruned from any tag rules, dropping empty
  /// rules and groups so deleting a tag never leaves dangling filter tokens.
  TrackFilterQuery withoutTagId(String tagId) =>
      _filterTagValues((v) => v != tagId);

  /// Returns a copy retaining only tag IDs present in [validTagIds] across all
  /// tag rules (including `isNoneOf` exclusion rules).
  TrackFilterQuery retainValidTagIds(Set<String> validTagIds) =>
      _filterTagValues(validTagIds.contains);

  TrackFilterQuery _filterTagValues(bool Function(String value) keep) {
    final nextGroups = <TrackFilterGroup>[];
    for (final group in groups) {
      final nextRules = <TrackFilterRule>[];
      for (final rule in group.rules) {
        if (rule.field == TrackFilterField.tag) {
          final remaining = rule.values.where(keep).toList();
          if (remaining.isNotEmpty) {
            nextRules.add(rule.copyWith(values: remaining));
          }
        } else {
          nextRules.add(rule);
        }
      }
      if (nextRules.isNotEmpty) {
        nextGroups.add(group.copyWith(rules: nextRules));
      }
    }
    return TrackFilterQuery(groups: nextGroups);
  }

  /// Evaluates whether [track] matches any active group (`OR` across groups).
  bool matches(Track track, TrackFilterContext context) {
    final activeGroups = groups.where((g) => g.isActive).toList();
    if (activeGroups.isEmpty) return true;
    return activeGroups.any((group) => group.matches(track, context));
  }

  /// Filters [tracks] using [matches], returning the original list when inactive.
  List<Track> apply(List<Track> tracks, TrackFilterContext context) {
    if (!isActive) return tracks;
    return tracks.where((t) => matches(t, context)).toList();
  }

  /// Formats a concise summary label for headers/toolbars, or null if inactive.
  String? formatSummaryLabel(TrackFilterContext context) {
    final activeGroups = groups.where((g) => g.isActive).toList();
    if (activeGroups.isEmpty) return null;

    if (activeGroups.length == 1) {
      final onlyGroup = activeGroups.first;
      final activeRules = onlyGroup.rules.where((r) => r.isActive).toList();
      if (activeRules.length == 1) {
        final onlyRule = activeRules.first;
        if (onlyRule.field == TrackFilterField.tag &&
            onlyRule.operator == TrackFilterOperator.isAnyOf &&
            onlyRule.values.length == 1) {
          return 'Tag: ${context.displayLabelFor(TrackFilterField.tag, onlyRule.values.first)}';
        }
      }
      return onlyGroup.formatSummary(context);
    }

    return activeGroups
        .map((g) => '(${g.formatSummary(context)})')
        .join(' OR ');
  }

  /// Creates an updated copy of this query.
  TrackFilterQuery copyWith({List<TrackFilterGroup>? groups}) {
    return TrackFilterQuery(groups: groups ?? this.groups);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackFilterQuery && listEquals(other.groups, groups);

  @override
  int get hashCode => Object.hashAll(groups);
}
