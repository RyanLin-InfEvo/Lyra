// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Musical composition work entity (Tier 1 of Lyra 4-tier audio model).
///
/// Corresponds to the C++ [Work] entity in `core/src/models/work.h`.
@immutable
class Work {
  /// Unique identifier (UUID) of the musical work entity.
  final String id;

  /// Canonical title of the musical composition.
  final String title;

  /// Starting year of composition (if known).
  final int? compositionStartYear;

  /// Ending year of composition (if known).
  final int? compositionEndYear;

  /// Freeform date text for historical or approximate dates (e.g., "circa 1808", "1972-1973").
  final String? compositionDateText;

  /// International Standard Musical Work Code (ISWC).
  final String? iswc;

  /// MusicBrainz Work ID (UUID).
  final String? musicbrainzId;

  /// Primary composer(s) or creator(s) of the composition.
  final String? composer;

  /// Lyricist(s) or text author(s) of the composition.
  final String? lyricist;

  /// Specific movement, section, or act name of the composition.
  final String? movement;

  const Work({
    required this.id,
    required this.title,
    this.compositionStartYear,
    this.compositionEndYear,
    this.compositionDateText,
    this.iswc,
    this.musicbrainzId,
    this.composer,
    this.lyricist,
    this.movement,
  });

  /// Formatted composition date text or year range for UI display.
  String get displayDate {
    if (compositionStartYear != null) {
      if (compositionEndYear != null &&
          compositionEndYear != compositionStartYear) {
        return '$compositionStartYear–$compositionEndYear';
      }
      return '$compositionStartYear';
    }
    if (compositionDateText != null && compositionDateText!.isNotEmpty) {
      return compositionDateText!;
    }
    if (compositionEndYear != null) {
      return '$compositionEndYear';
    }
    return '-';
  }

  /// Creates a [Work] instance from a Map / JSON object.
  factory Work.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return Work(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      compositionStartYear: parseInt(
        map['composition_start_year'] ?? map['compositionStartYear'],
      ),
      compositionEndYear: parseInt(
        map['composition_end_year'] ?? map['compositionEndYear'],
      ),
      compositionDateText:
          (map['composition_date_text'] ?? map['compositionDateText'])
              ?.toString(),
      iswc: map['iswc']?.toString(),
      musicbrainzId: (map['musicbrainz_id'] ?? map['musicbrainzId'])
          ?.toString(),
      composer: map['composer']?.toString(),
      lyricist: map['lyricist']?.toString(),
      movement: map['movement']?.toString(),
    );
  }

  /// Creates a [Work] instance from a JSON map.
  factory Work.fromJson(Map<String, dynamic> json) => Work.fromMap(json);

  /// Converts this [Work] to a map compatible with storage and serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (compositionStartYear != null)
        'composition_start_year': compositionStartYear,
      if (compositionEndYear != null)
        'composition_end_year': compositionEndYear,
      if (compositionDateText != null)
        'composition_date_text': compositionDateText,
      if (iswc != null) 'iswc': iswc,
      if (musicbrainzId != null) 'musicbrainz_id': musicbrainzId,
      if (composer != null) 'composer': composer,
      if (lyricist != null) 'lyricist': lyricist,
      if (movement != null) 'movement': movement,
    };
  }

  /// Converts this [Work] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy of this [Work] with updated fields.
  Work copyWith({
    String? id,
    String? title,
    int? compositionStartYear,
    int? compositionEndYear,
    String? compositionDateText,
    String? iswc,
    String? musicbrainzId,
    String? composer,
    String? lyricist,
    String? movement,
  }) {
    return Work(
      id: id ?? this.id,
      title: title ?? this.title,
      compositionStartYear: compositionStartYear ?? this.compositionStartYear,
      compositionEndYear: compositionEndYear ?? this.compositionEndYear,
      compositionDateText: compositionDateText ?? this.compositionDateText,
      iswc: iswc ?? this.iswc,
      musicbrainzId: musicbrainzId ?? this.musicbrainzId,
      composer: composer ?? this.composer,
      lyricist: lyricist ?? this.lyricist,
      movement: movement ?? this.movement,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Work &&
        other.id == id &&
        other.title == title &&
        other.compositionStartYear == compositionStartYear &&
        other.compositionEndYear == compositionEndYear &&
        other.compositionDateText == compositionDateText &&
        other.iswc == iswc &&
        other.musicbrainzId == musicbrainzId &&
        other.composer == composer &&
        other.lyricist == lyricist &&
        other.movement == movement;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    compositionStartYear,
    compositionEndYear,
    compositionDateText,
    iswc,
    musicbrainzId,
    composer,
    lyricist,
    movement,
  );

  @override
  String toString() {
    return 'Work('
        'id: $id, '
        'title: $title, '
        'compositionStartYear: $compositionStartYear, '
        'compositionEndYear: $compositionEndYear, '
        'compositionDateText: $compositionDateText, '
        'iswc: $iswc, '
        'musicbrainzId: $musicbrainzId, '
        'composer: $composer, '
        'lyricist: $lyricist, '
        'movement: $movement'
        ')';
  }
}
