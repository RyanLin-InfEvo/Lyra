// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Album model representing a collection of audio tracks.
class Album {
  final String id;
  final String title;
  final String artist;
  final int year;
  final int trackCount;
  final Color coverColor;
  final String? format;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.trackCount,
    required this.coverColor,
    this.format = 'FLAC',
  });
}
