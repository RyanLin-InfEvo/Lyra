// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Represents a single line of lyrics with an associated timestamp.
@immutable
class LyricsLine {
  final Duration timestamp;
  final String text;

  const LyricsLine({required this.timestamp, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text;

  @override
  int get hashCode => Object.hash(timestamp, text);

  @override
  String toString() => 'LyricsLine(timestamp: $timestamp, text: "$text")';
}

/// Container model for parsed lyrics data, supporting both synced LRC and unsynced plain text.
@immutable
class LyricsData {
  final List<LyricsLine> lines;
  final bool isSynced;
  final String? rawText;

  const LyricsData({required this.lines, required this.isSynced, this.rawText});

  const LyricsData.empty() : lines = const [], isSynced = false, rawText = '';

  /// Parses an LRC formatted string into [LyricsData].
  ///
  /// - Matches timestamps using `\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]`.
  /// - Handles multiple timestamps per line: `[00:12.30][00:45.00]Hello world`.
  /// - Strips metadata headers like `[ar: ...]`, `[ti: ...]`, etc.
  /// - Chronologically sorts parsed lines by [LyricsLine.timestamp].
  /// - Falls back to unsynced lines with [Duration.zero] if no timestamps are found.
  factory LyricsData.fromLrc(String lrcContent) {
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final metadataRegex = RegExp(r'^\s*\[[a-zA-Z_]+:.*\]\s*$');

    final rawLines = lrcContent.split(RegExp(r'\r?\n'));
    final List<LyricsLine> syncedLines = [];
    final List<String> plainLines = [];

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final matches = timestampRegex.allMatches(rawLine).toList();
      if (matches.isNotEmpty) {
        final text = rawLine.replaceAll(timestampRegex, '').trim();
        for (final match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final fractionStr = match.group(3);
          final milliseconds = fractionStr != null
              ? int.parse(fractionStr.padRight(3, '0'))
              : 0;

          syncedLines.add(
            LyricsLine(
              timestamp: Duration(
                minutes: minutes,
                seconds: seconds,
                milliseconds: milliseconds,
              ),
              text: text,
            ),
          );
        }
      } else if (!metadataRegex.hasMatch(trimmed)) {
        plainLines.add(trimmed);
      }
    }

    if (syncedLines.isNotEmpty) {
      syncedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return LyricsData(
        lines: List.unmodifiable(syncedLines),
        isSynced: true,
        rawText: lrcContent,
      );
    }

    if (plainLines.isNotEmpty) {
      final unsynced = plainLines
          .map((text) => LyricsLine(timestamp: Duration.zero, text: text))
          .toList(growable: false);
      return LyricsData(lines: unsynced, isSynced: false, rawText: lrcContent);
    }

    return LyricsData(lines: const [], isSynced: false, rawText: lrcContent);
  }

  /// Returns the 0-based index of the active lyrics line at [position].
  ///
  /// Returns -1 if [lines] is empty or if [position] is earlier than [lines.first.timestamp].
  int findActiveIndex(Duration position) {
    if (lines.isEmpty || position < lines.first.timestamp) {
      return -1;
    }

    int low = 0;
    int high = lines.length - 1;
    int result = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }
}
