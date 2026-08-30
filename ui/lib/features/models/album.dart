// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Album model representing a collection of audio tracks or release container.
///
/// Corresponds to the C++ [Album] entity in `core/src/models/album.h` while maintaining
/// backward compatibility with UI presentation properties.
@immutable
class Album {
  /// Unique identifier (UUID) of the album entity.
  final String id;

  /// Title of the album release.
  final String title;

  /// Primary release year.
  final int? releaseYear;

  /// Release month (1-12).
  final int? releaseMonth;

  /// Release day (1-31).
  final int? releaseDay;

  /// Primary or credited artist name for this album release.
  final String? artistName;

  /// Hash of the album cover art image asset stored in CAS.
  final String? coverArtHash;

  /// Total number of tracks contained in this album.
  final int? totalTracks;

  /// Total number of discs or media volumes in this album release.
  final int? totalDiscs;

  /// UI presentation format description (e.g., 'FLAC 24/96', 'FLAC', 'WAV').
  final String? format;

  /// Optional custom placeholder or dominant color for UI rendering.
  final Color? _coverColor;

  const Album({
    required this.id,
    required this.title,
    int? releaseYear,
    int? year,
    this.releaseMonth,
    this.releaseDay,
    String? artistName,
    String? artist,
    this.coverArtHash,
    int? totalTracks,
    int? trackCount,
    this.totalDiscs,
    Color? coverColor,
    this.format = 'FLAC',
  }) : releaseYear = releaseYear ?? year,
       artistName = artistName ?? artist,
       totalTracks = totalTracks ?? trackCount,
       _coverColor = coverColor;

  /// Backward-compatible artist accessor.
  String get artist => artistName ?? '';

  /// Backward-compatible year accessor.
  int get year => releaseYear ?? 0;

  /// Backward-compatible track count accessor.
  int get trackCount => totalTracks ?? 0;

  /// Fallback-safe cover color accessor.
  Color get coverColor => _coverColor ?? const Color(0xFF1E293B);

  /// Safe display title with fallback.
  String get displayTitle => title.isNotEmpty ? title : 'Untitled Album';

  /// Safe display artist name with fallback.
  String get displayArtist => (artistName != null && artistName!.isNotEmpty)
      ? artistName!
      : 'Unknown Artist';

  /// Formatted release date string (e.g., "1973", "1973-03", "1973-03-01").
  String get formattedReleaseDate {
    if (releaseYear == null) return '';
    if (releaseMonth == null) return '$releaseYear';
    final m = releaseMonth.toString().padLeft(2, '0');
    if (releaseDay == null) return '$releaseYear-$m';
    final d = releaseDay.toString().padLeft(2, '0');
    return '$releaseYear-$m-$d';
  }

  /// Creates an [Album] instance from a JSON map.
  factory Album.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    Color? parsedColor;
    final rawColor = json['cover_color'] ?? json['coverColor'];
    if (rawColor is int) {
      parsedColor = Color(rawColor);
    } else if (rawColor is String && rawColor.isNotEmpty) {
      final hex = rawColor.replaceFirst('#', '');
      final val = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (val != null) {
        parsedColor = Color(val);
      }
    }

    return Album(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      releaseYear: parseInt(
        json['release_year'] ?? json['releaseYear'] ?? json['year'],
      ),
      releaseMonth: parseInt(json['release_month'] ?? json['releaseMonth']),
      releaseDay: parseInt(json['release_day'] ?? json['releaseDay']),
      artistName: (json['artist_name'] ?? json['artistName'] ?? json['artist'])
          ?.toString(),
      coverArtHash:
          (json['cover_art_hash'] ??
                  json['coverArtHash'] ??
                  json['cover_hash'] ??
                  json['coverHash'])
              ?.toString(),
      totalTracks: parseInt(
        json['total_tracks'] ??
            json['totalTracks'] ??
            json['track_count'] ??
            json['trackCount'],
      ),
      totalDiscs: parseInt(json['total_discs'] ?? json['totalDiscs']),
      coverColor: parsedColor,
      format: json['format']?.toString() ?? 'FLAC',
    );
  }

  /// Converts this [Album] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (releaseYear != null) 'release_year': releaseYear,
      if (releaseMonth != null) 'release_month': releaseMonth,
      if (releaseDay != null) 'release_day': releaseDay,
      if (artistName != null) 'artist_name': artistName,
      if (coverArtHash != null) 'cover_art_hash': coverArtHash,
      if (totalTracks != null) 'total_tracks': totalTracks,
      if (totalDiscs != null) 'total_discs': totalDiscs,
      if (format != null) 'format': format,
    };
  }

  /// Creates a copy of this [Album] with updated fields.
  Album copyWith({
    String? id,
    String? title,
    int? releaseYear,
    int? releaseMonth,
    int? releaseDay,
    String? artistName,
    String? coverArtHash,
    int? totalTracks,
    int? totalDiscs,
    Color? coverColor,
    String? format,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      releaseYear: releaseYear ?? this.releaseYear,
      releaseMonth: releaseMonth ?? this.releaseMonth,
      releaseDay: releaseDay ?? this.releaseDay,
      artistName: artistName ?? this.artistName,
      coverArtHash: coverArtHash ?? this.coverArtHash,
      totalTracks: totalTracks ?? this.totalTracks,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      coverColor: coverColor ?? _coverColor,
      format: format ?? this.format,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album &&
        other.id == id &&
        other.title == title &&
        other.releaseYear == releaseYear &&
        other.releaseMonth == releaseMonth &&
        other.releaseDay == releaseDay &&
        other.artistName == artistName &&
        other.coverArtHash == coverArtHash &&
        other.totalTracks == totalTracks &&
        other.totalDiscs == totalDiscs &&
        other.format == format &&
        other._coverColor == _coverColor;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    releaseYear,
    releaseMonth,
    releaseDay,
    artistName,
    coverArtHash,
    totalTracks,
    totalDiscs,
    format,
    _coverColor,
  );

  @override
  String toString() {
    return 'Album('
        'id: $id, '
        'title: $title, '
        'releaseYear: $releaseYear, '
        'releaseMonth: $releaseMonth, '
        'releaseDay: $releaseDay, '
        'artistName: $artistName, '
        'coverArtHash: $coverArtHash, '
        'totalTracks: $totalTracks, '
        'totalDiscs: $totalDiscs, '
        'format: $format'
        ')';
  }
}
