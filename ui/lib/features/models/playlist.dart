// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Playlist entity representing a user-curated or smart collection of tracks.
///
/// Corresponds to the C++ [Playlist] entity in `core/src/models/playlist.h`.
@immutable
class Playlist {
  /// Unique identifier (UUID) of the playlist entity.
  final String id;

  /// Display title of the playlist.
  final String title;

  /// Optional description or curator notes.
  final String? description;

  /// Ordered list of track UUIDs contained in this playlist.
  final List<String> trackIds;

  /// Timestamp when the playlist was created.
  final DateTime? createdAt;

  /// Timestamp when the playlist was last updated.
  final DateTime? updatedAt;

  /// Optional cover art image hash stored in CAS.
  final String? coverArtHash;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.trackIds = const [],
    this.createdAt,
    this.updatedAt,
    this.coverArtHash,
  });

  /// Total number of tracks in this playlist.
  int get trackCount => trackIds.length;

  /// Safe display title with fallback.
  String get displayTitle => title.isNotEmpty ? title : 'Untitled Playlist';

  /// Whether the playlist contains any tracks.
  bool get isEmpty => trackIds.isEmpty;

  /// Whether the playlist has at least one track.
  bool get isNotEmpty => trackIds.isNotEmpty;

  /// Creates a [Playlist] instance from a JSON map.
  factory Playlist.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<String> parseTrackIds(dynamic val) {
      if (val is List) {
        return val
            .where((item) => item != null)
            .map((item) {
              if (item is String) return item;
              if (item is Map) {
                final trackId = item['id'] ?? item['track_id'];
                return trackId?.toString() ?? '';
              }
              return item.toString();
            })
            .where((id) => id.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      trackIds: parseTrackIds(
        json['track_ids'] ?? json['trackIds'] ?? json['tracks'],
      ),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      coverArtHash:
          (json['cover_art_hash'] ??
                  json['coverArtHash'] ??
                  json['cover_hash'] ??
                  json['coverHash'])
              ?.toString(),
    );
  }

  /// Converts this [Playlist] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'track_ids': trackIds,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (coverArtHash != null) 'cover_art_hash': coverArtHash,
    };
  }

  /// Creates a copy of this [Playlist] with updated fields.
  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverArtHash,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverArtHash: coverArtHash ?? this.coverArtHash,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        listEquals(other.trackIds, trackIds) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.coverArtHash == coverArtHash;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    Object.hashAll(trackIds),
    createdAt,
    updatedAt,
    coverArtHash,
  );

  @override
  String toString() {
    return 'Playlist('
        'id: $id, '
        'title: $title, '
        'description: $description, '
        'trackIds: $trackIds, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'coverArtHash: $coverArtHash'
        ')';
  }
}
