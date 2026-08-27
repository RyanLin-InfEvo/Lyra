// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Artist entity representing a musical creator, performer, or ensemble.
///
/// Corresponds to the C++ [Artist] entity in `core/src/models/artist.h`.
@immutable
class Artist {
  /// Unique identifier (UUID) of the artist entity.
  final String id;

  /// Display name or moniker of the artist.
  final String name;

  /// MusicBrainz Artist ID (UUID).
  final String? musicbrainzId;

  /// Optional contribution or relationship role (e.g., 'main', 'featured', 'producer', 'conductor').
  final String? role;

  /// Spotify Artist ID.
  final String? spotifyId;

  /// YouTube Music Artist / Channel ID.
  final String? ytmId;

  const Artist({
    required this.id,
    required this.name,
    this.musicbrainzId,
    this.role,
    this.spotifyId,
    this.ytmId,
  });

  /// Safe display name with fallback.
  String get displayName => name.isNotEmpty ? name : 'Unknown Artist';

  /// Whether any external streaming or metadata provider IDs are attached.
  bool get hasExternalIds =>
      (musicbrainzId != null && musicbrainzId!.isNotEmpty) ||
      (spotifyId != null && spotifyId!.isNotEmpty) ||
      (ytmId != null && ytmId!.isNotEmpty);

  /// Creates an [Artist] instance from a JSON map.
  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String? ?? '',
      name:
          (json['name'] ?? json['artist_name'] ?? json['artistName'])
              as String? ??
          '',
      musicbrainzId:
          (json['musicbrainz_id'] ?? json['musicbrainzId']) as String?,
      role: json['role'] as String?,
      spotifyId: (json['spotify_id'] ?? json['spotifyId']) as String?,
      ytmId: (json['ytm_id'] ?? json['ytmId']) as String?,
    );
  }

  /// Converts this [Artist] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (musicbrainzId != null) 'musicbrainz_id': musicbrainzId,
      if (role != null) 'role': role,
      if (spotifyId != null) 'spotify_id': spotifyId,
      if (ytmId != null) 'ytm_id': ytmId,
    };
  }

  /// Creates a copy of this [Artist] with updated fields.
  Artist copyWith({
    String? id,
    String? name,
    String? musicbrainzId,
    String? role,
    String? spotifyId,
    String? ytmId,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      musicbrainzId: musicbrainzId ?? this.musicbrainzId,
      role: role ?? this.role,
      spotifyId: spotifyId ?? this.spotifyId,
      ytmId: ytmId ?? this.ytmId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artist &&
        other.id == id &&
        other.name == name &&
        other.musicbrainzId == musicbrainzId &&
        other.role == role &&
        other.spotifyId == spotifyId &&
        other.ytmId == ytmId;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, musicbrainzId, role, spotifyId, ytmId);

  @override
  String toString() {
    return 'Artist('
        'id: $id, '
        'name: $name, '
        'musicbrainzId: $musicbrainzId, '
        'role: $role, '
        'spotifyId: $spotifyId, '
        'ytmId: $ytmId'
        ')';
  }
}
