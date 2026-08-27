// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Tag entity for categorizing and labeling entities across the music library.
///
/// Corresponds to the C++ [Tag] entity in `core/src/models/tag.h`.
@immutable
class Tag {
  /// Unique identifier (UUID) of the tag entity.
  final String id;

  /// Human-readable tag label (e.g., "Audiophile Remaster", "Post-Bop", "Live Recording").
  final String name;

  /// Logical grouping category (e.g., 'genre', 'mood', 'era', 'style', 'general').
  final String category;

  /// Optional timestamp when this tag was created.
  final DateTime? createdAt;

  const Tag({
    required this.id,
    required this.name,
    this.category = 'general',
    this.createdAt,
  });

  /// Safe display label with fallback.
  String get displayName => name.isNotEmpty ? name : 'Untitled Tag';

  /// Safe display category with fallback.
  String get displayCategory => category.isNotEmpty ? category : 'general';

  /// Creates a [Tag] instance from a JSON map.
  factory Tag.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Tag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Converts this [Tag] to a JSON map compatible with the core engine.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Creates a copy of this [Tag] with updated fields.
  Tag copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tag &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, category, createdAt);

  @override
  String toString() {
    return 'Tag('
        'id: $id, '
        'name: $name, '
        'category: $category, '
        'createdAt: $createdAt'
        ')';
  }
}
