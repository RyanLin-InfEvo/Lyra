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

  const Track({
    required this.id,
    this.pcmHash = '',
    this.workId,
    this.title,
    this.recordingYear,
    this.recordingMonth,
    this.recordingDay,
    this.recordingLocation,
    this.durationMs,
    this.isrc,
    this.musicbrainzId,
    this.spotifyId,
    this.ytmId,
    this.artistName,
    this.albumTitle,
    this.format,
    this.sampleRate,
    this.bitDepth,
    this.verified = true,
  });

  /// Factory constructor supporting legacy parameter names.
  factory Track.legacy({
    required String id,
    String? pcmHash,
    String? casHash,
    String? workId,
    String? title,
    int? recordingYear,
    int? recordingMonth,
    int? recordingDay,
    String? recordingLocation,
    int? durationMs,
    Duration? duration,
    String? isrc,
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
  }) {
    return Track(
      id: id,
      pcmHash: pcmHash ?? casHash ?? '',
      workId: workId,
      title: title,
      recordingYear: recordingYear,
      recordingMonth: recordingMonth,
      recordingDay: recordingDay,
      recordingLocation: recordingLocation,
      durationMs: durationMs ?? duration?.inMilliseconds,
      isrc: isrc,
      musicbrainzId: musicbrainzId,
      spotifyId: spotifyId,
      ytmId: ytmId,
      artistName: artistName ?? artist,
      albumTitle: albumTitle ?? album,
      format: format,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      verified: verified,
    );
  }

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

  /// Creates a [Track] instance from a JSON map.
  factory Track.fromJson(Map<String, dynamic> json) {
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
        json['duration_ms'] ?? json['durationMs'] ?? json['duration'];
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
      id: json['id']?.toString() ?? '',
      pcmHash:
          (json['pcm_hash'] ??
                  json['pcmHash'] ??
                  json['cas_hash'] ??
                  json['casHash'])
              ?.toString() ??
          '',
      workId: (json['work_id'] ?? json['workId'])?.toString(),
      title: json['title']?.toString(),
      recordingYear: parseInt(json['recording_year'] ?? json['recordingYear']),
      recordingMonth: parseInt(
        json['recording_month'] ?? json['recordingMonth'],
      ),
      recordingDay: parseInt(json['recording_day'] ?? json['recordingDay']),
      recordingLocation:
          (json['recording_location'] ?? json['recordingLocation'])?.toString(),
      durationMs: parsedDurationMs,
      isrc: json['isrc']?.toString(),
      musicbrainzId: (json['musicbrainz_id'] ?? json['musicbrainzId'])
          ?.toString(),
      spotifyId: (json['spotify_id'] ?? json['spotifyId'])?.toString(),
      ytmId: (json['ytm_id'] ?? json['ytmId'])?.toString(),
      artistName: (json['artist_name'] ?? json['artistName'] ?? json['artist'])
          ?.toString(),
      albumTitle: (json['album_title'] ?? json['albumTitle'] ?? json['album'])
          ?.toString(),
      format: json['format']?.toString(),
      sampleRate: parseInt(json['sample_rate'] ?? json['sampleRate']),
      bitDepth: parseInt(json['bit_depth'] ?? json['bitDepth']),
      verified: parseBool(json['verified'], defaultValue: true),
    );
  }

  /// Converts this [Track] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pcm_hash': pcmHash,
      if (workId != null) 'work_id': workId,
      if (title != null) 'title': title,
      if (recordingYear != null) 'recording_year': recordingYear,
      if (recordingMonth != null) 'recording_month': recordingMonth,
      if (recordingDay != null) 'recording_day': recordingDay,
      if (recordingLocation != null) 'recording_location': recordingLocation,
      if (durationMs != null) 'duration': durationMs,
      if (isrc != null) 'isrc': isrc,
      if (musicbrainzId != null) 'musicbrainz_id': musicbrainzId,
      if (spotifyId != null) 'spotify_id': spotifyId,
      if (ytmId != null) 'ytm_id': ytmId,
      if (artistName != null) 'artist_name': artistName,
      if (albumTitle != null) 'album_title': albumTitle,
      if (format != null) 'format': format,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      'verified': verified,
    };
  }

  /// Creates a copy of this [Track] with updated fields.
  Track copyWith({
    String? id,
    String? pcmHash,
    String? workId,
    String? title,
    int? recordingYear,
    int? recordingMonth,
    int? recordingDay,
    String? recordingLocation,
    int? durationMs,
    String? isrc,
    String? musicbrainzId,
    String? spotifyId,
    String? ytmId,
    String? artistName,
    String? albumTitle,
    String? format,
    int? sampleRate,
    int? bitDepth,
    bool? verified,
  }) {
    return Track(
      id: id ?? this.id,
      pcmHash: pcmHash ?? this.pcmHash,
      workId: workId ?? this.workId,
      title: title ?? this.title,
      recordingYear: recordingYear ?? this.recordingYear,
      recordingMonth: recordingMonth ?? this.recordingMonth,
      recordingDay: recordingDay ?? this.recordingDay,
      recordingLocation: recordingLocation ?? this.recordingLocation,
      durationMs: durationMs ?? this.durationMs,
      isrc: isrc ?? this.isrc,
      musicbrainzId: musicbrainzId ?? this.musicbrainzId,
      spotifyId: spotifyId ?? this.spotifyId,
      ytmId: ytmId ?? this.ytmId,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      verified: verified ?? this.verified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track &&
        other.id == id &&
        other.pcmHash == pcmHash &&
        other.workId == workId &&
        other.title == title &&
        other.recordingYear == recordingYear &&
        other.recordingMonth == recordingMonth &&
        other.recordingDay == recordingDay &&
        other.recordingLocation == recordingLocation &&
        other.durationMs == durationMs &&
        other.isrc == isrc &&
        other.musicbrainzId == musicbrainzId &&
        other.spotifyId == spotifyId &&
        other.ytmId == ytmId &&
        other.artistName == artistName &&
        other.albumTitle == albumTitle &&
        other.format == format &&
        other.sampleRate == sampleRate &&
        other.bitDepth == bitDepth &&
        other.verified == verified;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    pcmHash,
    workId,
    title,
    recordingYear,
    recordingMonth,
    recordingDay,
    recordingLocation,
    durationMs,
    isrc,
    musicbrainzId,
    spotifyId,
    ytmId,
    artistName,
    albumTitle,
    format,
    sampleRate,
    bitDepth,
    verified,
  ]);

  @override
  String toString() {
    return 'Track('
        'id: $id, '
        'pcmHash: $pcmHash, '
        'workId: $workId, '
        'title: $title, '
        'recordingYear: $recordingYear, '
        'recordingMonth: $recordingMonth, '
        'recordingDay: $recordingDay, '
        'recordingLocation: $recordingLocation, '
        'durationMs: $durationMs, '
        'isrc: $isrc, '
        'musicbrainzId: $musicbrainzId, '
        'spotifyId: $spotifyId, '
        'ytmId: $ytmId, '
        'artistName: $artistName, '
        'albumTitle: $albumTitle, '
        'format: $format, '
        'sampleRate: $sampleRate, '
        'bitDepth: $bitDepth, '
        'verified: $verified'
        ')';
  }
}
