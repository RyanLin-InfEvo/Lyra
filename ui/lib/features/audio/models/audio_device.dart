// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Represents a hardware or virtual audio output device enumerated by the audio engine.
class AudioDevice {
  final String id;
  final String name;
  final bool isDefault;
  final int minChannels;
  final int maxChannels;
  final int minSampleRate;
  final int maxSampleRate;

  const AudioDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.minChannels = 2,
    this.maxChannels = 2,
    this.minSampleRate = 44100,
    this.maxSampleRate = 48000,
  });

  factory AudioDevice.fromJson(Map<String, dynamic> json) {
    return AudioDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      minChannels: (json['min_channels'] as num?)?.toInt() ?? 2,
      maxChannels: (json['max_channels'] as num?)?.toInt() ?? 2,
      minSampleRate: (json['min_sample_rate'] as num?)?.toInt() ?? 44100,
      maxSampleRate: (json['max_sample_rate'] as num?)?.toInt() ?? 48000,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'is_default': isDefault,
    'min_channels': minChannels,
    'max_channels': maxChannels,
    'min_sample_rate': minSampleRate,
    'max_sample_rate': maxSampleRate,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isDefault == other.isDefault &&
          minChannels == other.minChannels &&
          maxChannels == other.maxChannels &&
          minSampleRate == other.minSampleRate &&
          maxSampleRate == other.maxSampleRate;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      isDefault.hashCode ^
      minChannels.hashCode ^
      maxChannels.hashCode ^
      minSampleRate.hashCode ^
      maxSampleRate.hashCode;

  @override
  String toString() =>
      'AudioDevice(id: $id, name: $name, isDefault: $isDefault)';
}
