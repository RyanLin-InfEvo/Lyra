// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Track recording entity (Tier 2 of Lyra 4-tier audio model).
///
/// Represents a specific audio recording release or track metadata instance.
/// Corresponds to the C++ [Track] entity in `core/src/models/track.h`.
@immutable
class Track {
  /// Unique identifier (UUID) of the track entity.
  final String id;

  /// Cryptographic SHA-256 hash of the decoded raw audio stream (PCM).
  final String pcmHash;

  /// Optional reference ID to the parent musical composition [Work].
  final String? workId;

  /// Title of the linked musical work composition.
  final String? workTitle;

  /// Display title of the track recording.
  final String? title;

  /// Year the recording was captured/created.
  final int? recordingYear;

  /// Month of recording (1-12).
  final int? recordingMonth;

  /// Day of recording (1-31).
  final int? recordingDay;

  /// Studio, venue, or geographic location where the recording occurred.
  final String? recordingLocation;

  /// Duration of the audio track in milliseconds.
  final int? durationMs;

  /// International Standard Recording Code (ISRC).
  final String? isrc;

  /// International Standard Musical Work Code (ISWC).
  final String? iswc;

  /// MusicBrainz Recording ID (UUID).
  final String? musicbrainzId;

  /// Spotify Track ID.
  final String? spotifyId;

  /// YouTube Music Track / Video ID.
  final String? ytmId;

  /// Primary artist or ensemble name.
  final String? artistName;

  /// Primary album or release container title.
  final String? albumTitle;

  /// Container/codec format (e.g. FLAC, WAV, AAC). Cached for UI convenience.
  final String? format;

  /// Audio sampling frequency in Hz (e.g. 44100, 96000, 192000). Cached for UI convenience.
  final int? sampleRate;

  /// Bit resolution depth (e.g. 16, 24, 32). Cached for UI convenience.
  final int? bitDepth;

  /// Whether the track's raw audio CAS integrity has been server-verified.
  final bool verified;

  /// Music genre classification (e.g. Rock, Jazz, Classical).
  final String? genre;

  /// Track position index within its disc/media.
  final int? trackNumber;

  /// Disc or media volume number in multi-disc sets.
  final int? discNumber;

  const Track({
    required this.id,
    this.pcmHash = '',
    this.workId,
    this.workTitle,
    this.title,
    this.recordingYear,
    this.recordingMonth,
    this.recordingDay,
    this.recordingLocation,
    this.durationMs,
    this.isrc,
    this.iswc,
    this.musicbrainzId,
    this.spotifyId,
    this.ytmId,
    this.artistName,
    this.albumTitle,
    this.format,
    this.sampleRate,
    this.bitDepth,
    this.verified = true,
    this.genre,
    this.trackNumber,
    this.discNumber,
  });

  /// Factory constructor supporting legacy parameter names.
  factory Track.legacy({
    required String id,
    String? pcmHash,
    String? casHash,
    String? workId,
    String? workTitle,
    String? title,
    int? recordingYear,
    int? recordingMonth,
    int? recordingDay,
    String? recordingLocation,
    int? durationMs,
    Duration? duration,
    String? isrc,
    String? iswc,
    String? musicbrainzId,
    String? spotifyId,
    String? ytmId,
    String? artistName,
    String? artist,
    String? albumTitle,
    String? album,
    String? format,
    int? sampleRate,
    int? bitDepth,
    bool verified = true,
    String? genre,
    int? trackNumber,
    int? discNumber,
  }) {
    return Track(
      id: id,
      pcmHash: pcmHash ?? casHash ?? '',
      workId: workId,
      workTitle: workTitle,
      title: title,
      recordingYear: recordingYear,
      recordingMonth: recordingMonth,
      recordingDay: recordingDay,
      recordingLocation: recordingLocation,
      durationMs: durationMs ?? duration?.inMilliseconds,
      isrc: isrc,
      iswc: iswc,
      musicbrainzId: musicbrainzId,
      spotifyId: spotifyId,
      ytmId: ytmId,
      artistName: artistName ?? artist,
      albumTitle: albumTitle ?? album,
      format: format,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      verified: verified,
      genre: genre,
      trackNumber: trackNumber,
      discNumber: discNumber,
    );
  }

  /// Backward-compatible year accessor.
  int? get year => recordingYear;

  /// Backward-compatible MusicBrainz ID accessor.
  String? get musicBrainzId => musicbrainzId;

  /// Safe display title with fallback.
  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : 'Untitled Track';

  /// Safe display format with fallback.
  String get displayFormat =>
      (format != null && format!.isNotEmpty) ? format! : 'Audio';

  /// Backward-compatible artist accessor.
  String get artist => artistName ?? '';

  /// Backward-compatible album accessor.
  String get album => albumTitle ?? '';

  /// Backward-compatible [Duration] accessor.
  Duration get duration => Duration(milliseconds: durationMs ?? 0);

  /// Backward-compatible CAS hash accessor.
  String get casHash => pcmHash;

  /// Formatted duration in mm:ss format.
  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Formatted audio resolution string (e.g., "24-bit/96kHz" or "16-bit/44.1kHz").
  String get formattedQuality {
    if (bitDepth == null || sampleRate == null) {
      return format ?? 'Audio';
    }
    final rate = sampleRate!;
    final khz = (rate / 1000).toStringAsFixed(rate % 1000 == 0 ? 0 : 1);
    return '$bitDepth-bit/${khz}kHz';
  }

  /// Shortened CAS hash for concise UI display (e.g., "e3b0...b855").
  String get shortCasHash {
    if (pcmHash.length <= 12) return pcmHash;
    return '${pcmHash.substring(0, 6)}...${pcmHash.substring(pcmHash.length - 4)}';
  }

  /// Creates a [Track] instance from a Map / JSON object.
  factory Track.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return defaultValue;
    }

    int? parsedDurationMs;
    final rawDuration =
        map['duration_ms'] ?? map['durationMs'] ?? map['duration'];
    if (rawDuration != null) {
      if (rawDuration is int) {
        parsedDurationMs = rawDuration;
      } else if (rawDuration is num) {
        final val = rawDuration.toDouble();
        parsedDurationMs = val > 10000 ? val.round() : (val * 1000).round();
      } else if (rawDuration is String) {
        final parsed = double.tryParse(rawDuration);
        if (parsed != null) {
          parsedDurationMs = parsed > 10000
              ? parsed.round()
              : (parsed * 1000).round();
        }
      }
    }

    return Track(
      id: map['id']?.toString() ?? '',
      pcmHash:
          (map['pcm_hash'] ??
                  map['pcmHash'] ??
                  map['cas_hash'] ??
                  map['casHash'])
              ?.toString() ??
          '',
      workId: (map['work_id'] ?? map['workId'])?.toString(),
      workTitle: (map['work_title'] ?? map['workTitle'])?.toString(),
      title: map['title']?.toString(),
      recordingYear: parseInt(
        map['recording_year'] ?? map['recordingYear'] ?? map['year'],
      ),
      recordingMonth: parseInt(map['recording_month'] ?? map['recordingMonth']),
      recordingDay: parseInt(map['recording_day'] ?? map['recordingDay']),
      recordingLocation: (map['recording_location'] ?? map['recordingLocation'])
          ?.toString(),
      durationMs: parsedDurationMs,
      isrc: map['isrc']?.toString(),
      iswc: map['iswc']?.toString(),
      musicbrainzId:
          (map['musicbrainz_id'] ??
                  map['musicbrainzId'] ??
                  map['musicBrainzId'])
              ?.toString(),
      spotifyId: (map['spotify_id'] ?? map['spotifyId'])?.toString(),
      ytmId: (map['ytm_id'] ?? map['ytmId'])?.toString(),
      artistName: (map['artist_name'] ?? map['artistName'] ?? map['artist'])
          ?.toString(),
      albumTitle: (map['album_title'] ?? map['albumTitle'] ?? map['album'])
          ?.toString(),
      format: map['format']?.toString(),
      sampleRate: parseInt(map['sample_rate'] ?? map['sampleRate']),
      bitDepth: parseInt(map['bit_depth'] ?? map['bitDepth']),
      verified: parseBool(map['verified'], defaultValue: true),
      genre: map['genre']?.toString(),
      trackNumber: parseInt(map['track_number'] ?? map['trackNumber']),
      discNumber: parseInt(map['disc_number'] ?? map['discNumber']),
    );
  }

  /// Creates a [Track] instance from a JSON map.
  factory Track.fromJson(Map<String, dynamic> json) => Track.fromMap(json);

  /// Converts this [Track] to a map compatible with storage and serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pcm_hash': pcmHash,
      if (workId != null) 'work_id': workId,
      if (workTitle != null) 'work_title': workTitle,
      if (title != null) 'title': title,
      if (recordingYear != null) 'recording_year': recordingYear,
      if (recordingMonth != null) 'recording_month': recordingMonth,
      if (recordingDay != null) 'recording_day': recordingDay,
      if (recordingLocation != null) 'recording_location': recordingLocation,
      if (durationMs != null) 'duration': durationMs,
      if (isrc != null) 'isrc': isrc,
      if (iswc != null) 'iswc': iswc,
      if (musicbrainzId != null) 'musicbrainz_id': musicbrainzId,
      if (spotifyId != null) 'spotify_id': spotifyId,
      if (ytmId != null) 'ytm_id': ytmId,
      if (artistName != null) 'artist_name': artistName,
      if (albumTitle != null) 'album_title': albumTitle,
      if (format != null) 'format': format,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      'verified': verified,
      if (genre != null) 'genre': genre,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
    };
  }

  /// Converts this [Track] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy of this [Track] with updated fields.
  Track copyWith({
    String? id,
    String? pcmHash,
    String? workId,
    String? workTitle,
    String? title,
    int? recordingYear,
    int? recordingMonth,
    int? recordingDay,
    String? recordingLocation,
    int? durationMs,
    String? isrc,
    String? iswc,
    String? musicbrainzId,
    String? spotifyId,
    String? ytmId,
    String? artistName,
    String? albumTitle,
    String? format,
    int? sampleRate,
    int? bitDepth,
    bool? verified,
    String? genre,
    int? trackNumber,
    int? discNumber,
  }) {
    return Track(
      id: id ?? this.id,
      pcmHash: pcmHash ?? this.pcmHash,
      workId: workId ?? this.workId,
      workTitle: workTitle ?? this.workTitle,
      title: title ?? this.title,
      recordingYear: recordingYear ?? this.recordingYear,
      recordingMonth: recordingMonth ?? this.recordingMonth,
      recordingDay: recordingDay ?? this.recordingDay,
      recordingLocation: recordingLocation ?? this.recordingLocation,
      durationMs: durationMs ?? this.durationMs,
      isrc: isrc ?? this.isrc,
      iswc: iswc ?? this.iswc,
      musicbrainzId: musicbrainzId ?? this.musicbrainzId,
      spotifyId: spotifyId ?? this.spotifyId,
      ytmId: ytmId ?? this.ytmId,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      verified: verified ?? this.verified,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track &&
        other.id == id &&
        other.pcmHash == pcmHash &&
        other.workId == workId &&
        other.workTitle == workTitle &&
        other.title == title &&
        other.recordingYear == recordingYear &&
        other.recordingMonth == recordingMonth &&
        other.recordingDay == recordingDay &&
        other.recordingLocation == recordingLocation &&
        other.durationMs == durationMs &&
        other.isrc == isrc &&
        other.iswc == iswc &&
        other.musicbrainzId == musicbrainzId &&
        other.spotifyId == spotifyId &&
        other.ytmId == ytmId &&
        other.artistName == artistName &&
        other.albumTitle == albumTitle &&
        other.format == format &&
        other.sampleRate == sampleRate &&
        other.bitDepth == bitDepth &&
        other.verified == verified &&
        other.genre == genre &&
        other.trackNumber == trackNumber &&
        other.discNumber == discNumber;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    pcmHash,
    workId,
    workTitle,
    title,
    recordingYear,
    recordingMonth,
    recordingDay,
    recordingLocation,
    durationMs,
    isrc,
    iswc,
    musicbrainzId,
    spotifyId,
    ytmId,
    artistName,
    albumTitle,
    format,
    sampleRate,
    bitDepth,
    verified,
    genre,
    trackNumber,
    discNumber,
  ]);

  @override
  String toString() {
    return 'Track('
        'id: $id, '
        'pcmHash: $pcmHash, '
        'workId: $workId, '
        'workTitle: $workTitle, '
        'title: $title, '
        'recordingYear: $recordingYear, '
        'recordingMonth: $recordingMonth, '
        'recordingDay: $recordingDay, '
        'recordingLocation: $recordingLocation, '
        'durationMs: $durationMs, '
        'isrc: $isrc, '
        'iswc: $iswc, '
        'musicbrainzId: $musicbrainzId, '
        'spotifyId: $spotifyId, '
        'ytmId: $ytmId, '
        'artistName: $artistName, '
        'albumTitle: $albumTitle, '
        'format: $format, '
        'sampleRate: $sampleRate, '
        'bitDepth: $bitDepth, '
        'verified: $verified, '
        'genre: $genre, '
        'trackNumber: $trackNumber, '
        'discNumber: $discNumber'
        ')';
  }
}
