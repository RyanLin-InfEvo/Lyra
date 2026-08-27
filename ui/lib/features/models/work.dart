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

  const Work({
    required this.id,
    required this.title,
    this.compositionStartYear,
    this.compositionEndYear,
    this.compositionDateText,
    this.iswc,
    this.musicbrainzId,
  });

  /// Creates a [Work] instance from a JSON map.
  factory Work.fromJson(Map<String, dynamic> json) {
    return Work(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      compositionStartYear:
          (json['composition_start_year'] ?? json['compositionStartYear'])
              as int?,
      compositionEndYear:
          (json['composition_end_year'] ?? json['compositionEndYear']) as int?,
      compositionDateText:
          (json['composition_date_text'] ?? json['compositionDateText'])
              as String?,
      iswc: json['iswc'] as String?,
      musicbrainzId:
          (json['musicbrainz_id'] ?? json['musicbrainzId']) as String?,
    );
  }

  /// Converts this [Work] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
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
    };
  }

  /// Creates a copy of this [Work] with updated fields.
  Work copyWith({
    String? id,
    String? title,
    int? compositionStartYear,
    int? compositionEndYear,
    String? compositionDateText,
    String? iswc,
    String? musicbrainzId,
  }) {
    return Work(
      id: id ?? this.id,
      title: title ?? this.title,
      compositionStartYear: compositionStartYear ?? this.compositionStartYear,
      compositionEndYear: compositionEndYear ?? this.compositionEndYear,
      compositionDateText: compositionDateText ?? this.compositionDateText,
      iswc: iswc ?? this.iswc,
      musicbrainzId: musicbrainzId ?? this.musicbrainzId,
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
        other.musicbrainzId == musicbrainzId;
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
        'musicbrainzId: $musicbrainzId'
        ')';
  }
}
