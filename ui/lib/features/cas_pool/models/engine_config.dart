// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

int _parseInt(dynamic value, {required int defaultValue}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
    final parsedDouble = double.tryParse(value);
    if (parsedDouble != null) return parsedDouble.toInt();
  }
  return defaultValue;
}

bool _parseBool(dynamic value, {required bool defaultValue}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return defaultValue;
}

/// Volume control modes supported by the core audio engine.
enum AudioVolumeMode {
  linear('linear', 'Linear'),
  logarithmicDb('logarithmic_db', 'Logarithmic dB'),
  bitPerfectLock0dB('bit_perfect_lock_0db', 'Bit-Perfect Lock 0dB');

  final String value;
  final String label;

  const AudioVolumeMode(this.value, this.label);

  static AudioVolumeMode fromValue(String? value) {
    if (value == null) return AudioVolumeMode.bitPerfectLock0dB;
    switch (value) {
      case 'linear':
        return AudioVolumeMode.linear;
      case 'logarithmic_db':
        return AudioVolumeMode.logarithmicDb;
      case 'bit_perfect_lock_0db':
      case 'bitperfect_lock_0db':
        return AudioVolumeMode.bitPerfectLock0dB;
      default:
        return AudioVolumeMode.bitPerfectLock0dB;
    }
  }
}

/// Resampling engine quality profiles.
enum ResamplerQuality {
  native('native', 'Bit-Perfect Native'),
  sincMedium('sinc_medium', 'SWR Sinc Medium'),
  soxrHq('soxr_hq', 'SOXR High Quality');

  final String value;
  final String label;

  const ResamplerQuality(this.value, this.label);

  static ResamplerQuality fromValue(String? value) {
    if (value == null) return ResamplerQuality.soxrHq;
    switch (value) {
      case 'native':
        return ResamplerQuality.native;
      case 'sinc_medium':
        return ResamplerQuality.sincMedium;
      case 'soxr_hq':
      default:
        return ResamplerQuality.soxrHq;
    }
  }
}

/// DSD (Direct Stream Digital) decoding policy.
enum DsdMode {
  dop('dop', 'DoP (DSD over PCM)'),
  pcmTranscode('pcm_transcode', 'PCM Transcode');

  final String value;
  final String label;

  const DsdMode(this.value, this.label);

  static DsdMode fromValue(String? value) {
    if (value == null) return DsdMode.dop;
    switch (value) {
      case 'pcm_transcode':
        return DsdMode.pcmTranscode;
      case 'dop':
      default:
        return DsdMode.dop;
    }
  }
}

/// Ingestion pipeline depth strategy.
enum IngestionMode {
  fast('fast', 'Fast Ingest'),
  full('full', 'Full Analysis (Waveforms)');

  final String value;
  final String label;

  const IngestionMode(this.value, this.label);

  static IngestionMode fromValue(String? value) {
    if (value == null) return IngestionMode.full;
    switch (value) {
      case 'fast':
        return IngestionMode.fast;
      case 'full':
      default:
        return IngestionMode.full;
    }
  }
}

/// Configuration parameters for the CAS storage and database file locations.
@immutable
class StorageEngineConfig {
  final String storageRoot;
  final String databasePath;
  final String casObjectsDir;

  const StorageEngineConfig({
    required this.storageRoot,
    required this.databasePath,
    required this.casObjectsDir,
  });

  factory StorageEngineConfig.defaults({String storageRoot = ''}) {
    return StorageEngineConfig(
      storageRoot: storageRoot,
      databasePath: storageRoot.isNotEmpty ? '$storageRoot/lyra.db' : '',
      casObjectsDir: storageRoot.isNotEmpty ? '$storageRoot/objects' : '',
    );
  }

  factory StorageEngineConfig.fromJson(Map<String, dynamic> json) {
    final root = json['storage_root']?.toString() ?? '';
    return StorageEngineConfig(
      storageRoot: root,
      databasePath:
          json['database_path']?.toString() ??
          (root.isNotEmpty ? '$root/lyra.db' : ''),
      casObjectsDir:
          json['cas_objects_dir']?.toString() ??
          (root.isNotEmpty ? '$root/objects' : ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'storage_root': storageRoot,
    'database_path': databasePath,
    'cas_objects_dir': casObjectsDir,
  };

  StorageEngineConfig copyWith({
    String? storageRoot,
    String? databasePath,
    String? casObjectsDir,
  }) {
    return StorageEngineConfig(
      storageRoot: storageRoot ?? this.storageRoot,
      databasePath: databasePath ?? this.databasePath,
      casObjectsDir: casObjectsDir ?? this.casObjectsDir,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageEngineConfig &&
          runtimeType == other.runtimeType &&
          storageRoot == other.storageRoot &&
          databasePath == other.databasePath &&
          casObjectsDir == other.casObjectsDir;

  @override
  int get hashCode =>
      storageRoot.hashCode ^ databasePath.hashCode ^ casObjectsDir.hashCode;

  @override
  String toString() =>
      'StorageEngineConfig(storageRoot: $storageRoot, databasePath: $databasePath, casObjectsDir: $casObjectsDir)';
}

/// Configuration parameters for the SQLite core database engine.
@immutable
class DatabaseEngineConfig {
  final int cacheSizeKb;
  final int mmapSizeBytes;
  final int busyTimeoutMs;
  final int walAutocheckpoint;

  const DatabaseEngineConfig({
    required this.cacheSizeKb,
    required this.mmapSizeBytes,
    required this.busyTimeoutMs,
    required this.walAutocheckpoint,
  });

  factory DatabaseEngineConfig.defaults() {
    return const DatabaseEngineConfig(
      cacheSizeKb: 131072, // 128 MB
      mmapSizeBytes: 536870912, // 512 MB
      busyTimeoutMs: 30000, // 30,000 ms
      walAutocheckpoint: 1000, // 1000 pages
    );
  }

  factory DatabaseEngineConfig.fromJson(Map<String, dynamic> json) {
    return DatabaseEngineConfig(
      cacheSizeKb: _parseInt(json['cache_size_kb'], defaultValue: 131072),
      mmapSizeBytes: _parseInt(
        json['mmap_size_bytes'],
        defaultValue: 536870912,
      ),
      busyTimeoutMs: _parseInt(json['busy_timeout_ms'], defaultValue: 30000),
      walAutocheckpoint: _parseInt(
        json['wal_autocheckpoint'],
        defaultValue: 1000,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'cache_size_kb': cacheSizeKb,
    'mmap_size_bytes': mmapSizeBytes,
    'busy_timeout_ms': busyTimeoutMs,
    'wal_autocheckpoint': walAutocheckpoint,
  };

  DatabaseEngineConfig copyWith({
    int? cacheSizeKb,
    int? mmapSizeBytes,
    int? busyTimeoutMs,
    int? walAutocheckpoint,
  }) {
    return DatabaseEngineConfig(
      cacheSizeKb: cacheSizeKb ?? this.cacheSizeKb,
      mmapSizeBytes: mmapSizeBytes ?? this.mmapSizeBytes,
      busyTimeoutMs: busyTimeoutMs ?? this.busyTimeoutMs,
      walAutocheckpoint: walAutocheckpoint ?? this.walAutocheckpoint,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatabaseEngineConfig &&
          runtimeType == other.runtimeType &&
          cacheSizeKb == other.cacheSizeKb &&
          mmapSizeBytes == other.mmapSizeBytes &&
          busyTimeoutMs == other.busyTimeoutMs &&
          walAutocheckpoint == other.walAutocheckpoint;

  @override
  int get hashCode =>
      cacheSizeKb.hashCode ^
      mmapSizeBytes.hashCode ^
      busyTimeoutMs.hashCode ^
      walAutocheckpoint.hashCode;

  @override
  String toString() =>
      'DatabaseEngineConfig(cacheSizeKb: $cacheSizeKb, mmapSizeBytes: $mmapSizeBytes, busyTimeoutMs: $busyTimeoutMs, walAutocheckpoint: $walAutocheckpoint)';
}

/// Configuration parameters for the low-level audio hardware engine.
@immutable
class AudioEngineHardwareConfig {
  final String outputDeviceId;
  final int bufferSizeFrames;
  final bool exclusiveMode;
  final AudioVolumeMode volumeMode;
  final ResamplerQuality resamplerQuality;
  final DsdMode dsdMode;

  const AudioEngineHardwareConfig({
    required this.outputDeviceId,
    required this.bufferSizeFrames,
    required this.exclusiveMode,
    required this.volumeMode,
    required this.resamplerQuality,
    required this.dsdMode,
  });

  factory AudioEngineHardwareConfig.defaults() {
    return const AudioEngineHardwareConfig(
      outputDeviceId: 'default',
      bufferSizeFrames: 512,
      exclusiveMode: true,
      volumeMode: AudioVolumeMode.bitPerfectLock0dB,
      resamplerQuality: ResamplerQuality.soxrHq,
      dsdMode: DsdMode.dop,
    );
  }

  factory AudioEngineHardwareConfig.fromJson(Map<String, dynamic> json) {
    return AudioEngineHardwareConfig(
      outputDeviceId: json['output_device_id']?.toString() ?? 'default',
      bufferSizeFrames: _parseInt(
        json['buffer_size_frames'],
        defaultValue: 512,
      ),
      exclusiveMode: _parseBool(json['exclusive_mode'], defaultValue: true),
      volumeMode: AudioVolumeMode.fromValue(json['volume_mode']?.toString()),
      resamplerQuality: ResamplerQuality.fromValue(
        json['resampler_quality']?.toString(),
      ),
      dsdMode: DsdMode.fromValue(json['dsd_mode']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'output_device_id': outputDeviceId,
    'buffer_size_frames': bufferSizeFrames,
    'exclusive_mode': exclusiveMode,
    'volume_mode': volumeMode.value,
    'resampler_quality': resamplerQuality.value,
    'dsd_mode': dsdMode.value,
  };

  AudioEngineHardwareConfig copyWith({
    String? outputDeviceId,
    int? bufferSizeFrames,
    bool? exclusiveMode,
    AudioVolumeMode? volumeMode,
    ResamplerQuality? resamplerQuality,
    DsdMode? dsdMode,
  }) {
    return AudioEngineHardwareConfig(
      outputDeviceId: outputDeviceId ?? this.outputDeviceId,
      bufferSizeFrames: bufferSizeFrames ?? this.bufferSizeFrames,
      exclusiveMode: exclusiveMode ?? this.exclusiveMode,
      volumeMode: volumeMode ?? this.volumeMode,
      resamplerQuality: resamplerQuality ?? this.resamplerQuality,
      dsdMode: dsdMode ?? this.dsdMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioEngineHardwareConfig &&
          runtimeType == other.runtimeType &&
          outputDeviceId == other.outputDeviceId &&
          bufferSizeFrames == other.bufferSizeFrames &&
          exclusiveMode == other.exclusiveMode &&
          volumeMode == other.volumeMode &&
          resamplerQuality == other.resamplerQuality &&
          dsdMode == other.dsdMode;

  @override
  int get hashCode =>
      outputDeviceId.hashCode ^
      bufferSizeFrames.hashCode ^
      exclusiveMode.hashCode ^
      volumeMode.hashCode ^
      resamplerQuality.hashCode ^
      dsdMode.hashCode;

  @override
  String toString() =>
      'AudioEngineHardwareConfig(outputDeviceId: $outputDeviceId, bufferSizeFrames: $bufferSizeFrames, exclusiveMode: $exclusiveMode, volumeMode: $volumeMode, resamplerQuality: $resamplerQuality, dsdMode: $dsdMode)';
}

/// Configuration parameters for the multi-threaded ingestion pipeline.
@immutable
class IngestionPipelineConfig {
  final int parallelThreads;
  final int detectedCpuCores;
  final IngestionMode mode;

  const IngestionPipelineConfig({
    required this.parallelThreads,
    required this.detectedCpuCores,
    required this.mode,
  });

  factory IngestionPipelineConfig.defaults() {
    return const IngestionPipelineConfig(
      parallelThreads: 0, // 0 for Auto
      detectedCpuCores: 16,
      mode: IngestionMode.full,
    );
  }

  factory IngestionPipelineConfig.fromJson(Map<String, dynamic> json) {
    return IngestionPipelineConfig(
      parallelThreads: _parseInt(json['parallel_threads'], defaultValue: 0),
      detectedCpuCores: _parseInt(json['detected_cpu_cores'], defaultValue: 16),
      mode: IngestionMode.fromValue(json['mode']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'parallel_threads': parallelThreads,
    'detected_cpu_cores': detectedCpuCores,
    'mode': mode.value,
  };

  IngestionPipelineConfig copyWith({
    int? parallelThreads,
    int? detectedCpuCores,
    IngestionMode? mode,
  }) {
    return IngestionPipelineConfig(
      parallelThreads: parallelThreads ?? this.parallelThreads,
      detectedCpuCores: detectedCpuCores ?? this.detectedCpuCores,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngestionPipelineConfig &&
          runtimeType == other.runtimeType &&
          parallelThreads == other.parallelThreads &&
          detectedCpuCores == other.detectedCpuCores &&
          mode == other.mode;

  @override
  int get hashCode =>
      parallelThreads.hashCode ^ detectedCpuCores.hashCode ^ mode.hashCode;

  @override
  String toString() =>
      'IngestionPipelineConfig(parallelThreads: $parallelThreads, detectedCpuCores: $detectedCpuCores, mode: $mode)';
}

/// Root data model representing the backend engine configuration.
@immutable
class EngineConfig {
  final StorageEngineConfig storage;
  final DatabaseEngineConfig database;
  final AudioEngineHardwareConfig audio;
  final IngestionPipelineConfig ingestion;

  const EngineConfig({
    required this.storage,
    required this.database,
    required this.audio,
    required this.ingestion,
  });

  factory EngineConfig.defaults({String storageRoot = ''}) {
    return EngineConfig(
      storage: StorageEngineConfig.defaults(storageRoot: storageRoot),
      database: DatabaseEngineConfig.defaults(),
      audio: AudioEngineHardwareConfig.defaults(),
      ingestion: IngestionPipelineConfig.defaults(),
    );
  }

  factory EngineConfig.fromJson(Map<String, dynamic> json) {
    return EngineConfig(
      storage: json['storage'] is Map<String, dynamic>
          ? StorageEngineConfig.fromJson(
              json['storage'] as Map<String, dynamic>,
            )
          : (json['storage'] is Map
                ? StorageEngineConfig.fromJson(
                    (json['storage'] as Map).cast<String, dynamic>(),
                  )
                : StorageEngineConfig.defaults()),
      database: json['database'] is Map<String, dynamic>
          ? DatabaseEngineConfig.fromJson(
              json['database'] as Map<String, dynamic>,
            )
          : (json['database'] is Map
                ? DatabaseEngineConfig.fromJson(
                    (json['database'] as Map).cast<String, dynamic>(),
                  )
                : DatabaseEngineConfig.defaults()),
      audio: json['audio'] is Map<String, dynamic>
          ? AudioEngineHardwareConfig.fromJson(
              json['audio'] as Map<String, dynamic>,
            )
          : (json['audio'] is Map
                ? AudioEngineHardwareConfig.fromJson(
                    (json['audio'] as Map).cast<String, dynamic>(),
                  )
                : AudioEngineHardwareConfig.defaults()),
      ingestion: json['ingestion'] is Map<String, dynamic>
          ? IngestionPipelineConfig.fromJson(
              json['ingestion'] as Map<String, dynamic>,
            )
          : (json['ingestion'] is Map
                ? IngestionPipelineConfig.fromJson(
                    (json['ingestion'] as Map).cast<String, dynamic>(),
                  )
                : IngestionPipelineConfig.defaults()),
    );
  }

  Map<String, dynamic> toJson() => {
    'storage': storage.toJson(),
    'database': database.toJson(),
    'audio': audio.toJson(),
    'ingestion': ingestion.toJson(),
  };

  /// Serializes only mutable configuration fields for persistence.
  Map<String, dynamic> toSavePayload() => {
    'database': database.toJson(),
    'audio': audio.toJson(),
    'ingestion': {
      'parallel_threads': ingestion.parallelThreads,
      'mode': ingestion.mode.value,
    },
  };

  EngineConfig copyWith({
    StorageEngineConfig? storage,
    DatabaseEngineConfig? database,
    AudioEngineHardwareConfig? audio,
    IngestionPipelineConfig? ingestion,
  }) {
    return EngineConfig(
      storage: storage ?? this.storage,
      database: database ?? this.database,
      audio: audio ?? this.audio,
      ingestion: ingestion ?? this.ingestion,
    );
  }

  /// Whether this config has any difference from [other].
  bool isModifiedFrom(EngineConfig other) => this != other;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineConfig &&
          runtimeType == other.runtimeType &&
          storage == other.storage &&
          database == other.database &&
          audio == other.audio &&
          ingestion == other.ingestion;

  @override
  int get hashCode =>
      storage.hashCode ^
      database.hashCode ^
      audio.hashCode ^
      ingestion.hashCode;

  @override
  String toString() =>
      'EngineConfig(storage: $storage, database: $database, audio: $audio, ingestion: $ingestion)';
}
