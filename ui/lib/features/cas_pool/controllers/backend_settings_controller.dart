// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/bridge/lyra_bridge.dart';
import '../../audio/controllers/audio_device_controller.dart';
import '../../audio/models/audio_device.dart';
import '../models/engine_config.dart';

/// Controller managing backend core engine tuning, audio hardware policies,
/// SQLite cache and MMAP parameters, and ingestion pipeline concurrency.
class BackendSettingsController extends ChangeNotifier {
  final LyraBridge _bridge;

  EngineConfig _config;
  EngineConfig _pendingConfig;
  List<AudioDevice> _audioDevices;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;
  String? _errorMessage;
  Timer? _statusTimer;
  bool _disposed = false;
  bool _isRestartPending = false;

  BackendSettingsController({
    LyraBridge? bridge,
    EngineConfig? initialConfig,
    List<AudioDevice>? initialDevices,
    bool autoLoad = true,
  }) : _bridge = bridge ?? LyraBridge.instance,
       _config = initialConfig ?? EngineConfig.defaults(),
       _pendingConfig = initialConfig ?? EngineConfig.defaults(),
       _audioDevices =
           initialDevices ?? AudioDeviceController.defaultInitialDevices {
    if (autoLoad) {
      loadConfig();
    }
  }

  /// The active, committed backend engine configuration.
  EngineConfig get config => _config;

  /// The working draft configuration with uncommitted edits.
  EngineConfig get pendingConfig => _pendingConfig;

  /// Available audio output devices enumerated from the backend engine.
  List<AudioDevice> get audioDevices => List.unmodifiable(_audioDevices);

  /// Whether configuration and audio devices are currently loading.
  bool get isLoading => _isLoading;

  /// Whether new configuration settings are currently being saved to the backend.
  bool get isSaving => _isSaving;

  /// Temporary success status message, if any.
  String? get statusMessage => _statusMessage;

  /// Error message from the last operation, if any.
  String? get errorMessage => _errorMessage;

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// Whether there are pending changes in the draft that differ from the committed config.
  bool get isDirty => _pendingConfig != _config;

  /// Whether an audio engine restart is pending on the backend.
  bool get isRestartPending => _isRestartPending;

  /// Acknowledges the pending restart notice.
  void acknowledgeRestart() {
    if (_isRestartPending) {
      _isRestartPending = false;
      notifyListeners();
    }
  }

  /// Whether the pending changes include modifications that require restarting the audio engine
  /// (such as buffer size frames or exclusive mode).
  bool get restartRequired =>
      _pendingConfig.audio.bufferSizeFrames != _config.audio.bufferSizeFrames ||
      _pendingConfig.audio.exclusiveMode != _config.audio.exclusiveMode;

  /// Asynchronously loads configuration and audio output devices from the backend.
  Future<void> loadConfig() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final configFuture = _bridge.executeCommand('system.get_config');
      final devicesFuture = _bridge.listAudioDevices();

      final results = await Future.wait([configFuture, devicesFuture]);
      if (_disposed) return;
      final configResp = results[0];
      final devicesResp = results[1];

      final isExplicitSuccess = configResp['success'] as bool?;
      final status = configResp['status'] as String?;
      final code = configResp['code'] as int?;

      final isConfigError =
          (isExplicitSuccess == false) ||
          (status == 'error') ||
          (code != null && (code < 200 || code >= 300));

      if (isConfigError) {
        _errorMessage =
            configResp['message']?.toString() ??
            'Failed to load engine configuration.';
        return;
      }

      final configData = configResp['data'];
      if (configData is Map) {
        final wasDirty = isDirty;
        _config = EngineConfig.fromJson(configData.cast<String, dynamic>());
        if (!wasDirty) {
          _pendingConfig = _config;
        }
      } else {
        _errorMessage = 'Invalid configuration payload received from engine.';
        return;
      }

      final devicesData = devicesResp['data'];
      if (devicesData is Map) {
        final rawDevices = devicesData['devices'];
        if (rawDevices is List) {
          _audioDevices = rawDevices
              .whereType<Map>()
              .map((d) => AudioDevice.fromJson(d.cast<String, dynamic>()))
              .toList();
        }
      }
    } catch (e) {
      if (_disposed) return;
      _errorMessage = 'Failed to load engine configuration: $e';
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Asynchronously commits pending configuration changes to the core backend engine.
  Future<bool> saveConfig() async {
    if (!isDirty || _isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final response = await _bridge.executeCommand(
        'system.set_config',
        _pendingConfig.toSavePayload(),
      );
      if (_disposed) return false;

      final isExplicitSuccess = response['success'] as bool?;
      final status = response['status'] as String?;
      final code = response['code'] as int?;

      final isOk =
          (isExplicitSuccess ?? (status != 'error')) &&
          (code == null || (code >= 200 && code < 300)) &&
          (isExplicitSuccess != null || status != null || code != null);

      if (isOk) {
        _config = _pendingConfig;
        final respData = response['data'];
        final bool restartRequiredByServer =
            (respData is Map && respData['restart_required'] == true) ||
            response['restart_required'] == true;
        if (restartRequiredByServer) {
          _isRestartPending = true;
        }

        _statusMessage = 'Engine settings saved successfully.';
        _statusTimer?.cancel();
        _statusTimer = Timer(const Duration(seconds: 3), () {
          if (!_disposed && _statusMessage != null) {
            _statusMessage = null;
            notifyListeners();
          }
        });
        return true;
      } else {
        _errorMessage =
            response['message']?.toString() ??
            'Failed to save engine settings.';
        return false;
      }
    } catch (e) {
      if (_disposed) return false;
      _errorMessage = 'Failed to save engine configuration: $e';
      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Discards all pending modifications and reverts the draft to the committed config.
  void resetDraft() {
    _pendingConfig = _config;
    _errorMessage = null;
    _statusMessage = null;
    _statusTimer?.cancel();
    notifyListeners();
  }

  /// Resets the pending draft to the system default configuration.
  void restoreDefaults() {
    _pendingConfig = EngineConfig.defaults();
    _errorMessage = null;
    _statusMessage = null;
    _statusTimer?.cancel();
    notifyListeners();
  }

  // --- Field Setters ---

  void setOutputDevice(String deviceId) {
    if (_pendingConfig.audio.outputDeviceId == deviceId) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(outputDeviceId: deviceId),
    );
    notifyListeners();
  }

  void setExclusiveMode(bool enabled) {
    if (_pendingConfig.audio.exclusiveMode == enabled) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(exclusiveMode: enabled),
    );
    notifyListeners();
  }

  void setBufferSize(int frames) {
    if (_pendingConfig.audio.bufferSizeFrames == frames) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(bufferSizeFrames: frames),
    );
    notifyListeners();
  }

  void setVolumeMode(AudioVolumeMode mode) {
    if (_pendingConfig.audio.volumeMode == mode) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(volumeMode: mode),
    );
    notifyListeners();
  }

  void setResamplerQuality(ResamplerQuality quality) {
    if (_pendingConfig.audio.resamplerQuality == quality) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(resamplerQuality: quality),
    );
    notifyListeners();
  }

  void setDsdMode(DsdMode mode) {
    if (_pendingConfig.audio.dsdMode == mode) return;
    _pendingConfig = _pendingConfig.copyWith(
      audio: _pendingConfig.audio.copyWith(dsdMode: mode),
    );
    notifyListeners();
  }

  void setDatabaseCacheSize(int kb) {
    if (_pendingConfig.database.cacheSizeKb == kb) return;
    _pendingConfig = _pendingConfig.copyWith(
      database: _pendingConfig.database.copyWith(cacheSizeKb: kb),
    );
    notifyListeners();
  }

  void setDatabaseMmapSize(int bytes) {
    if (_pendingConfig.database.mmapSizeBytes == bytes) return;
    _pendingConfig = _pendingConfig.copyWith(
      database: _pendingConfig.database.copyWith(mmapSizeBytes: bytes),
    );
    notifyListeners();
  }

  void setBusyTimeout(int ms) {
    if (_pendingConfig.database.busyTimeoutMs == ms) return;
    _pendingConfig = _pendingConfig.copyWith(
      database: _pendingConfig.database.copyWith(busyTimeoutMs: ms),
    );
    notifyListeners();
  }

  void setWalAutocheckpoint(int pages) {
    if (_pendingConfig.database.walAutocheckpoint == pages) return;
    _pendingConfig = _pendingConfig.copyWith(
      database: _pendingConfig.database.copyWith(walAutocheckpoint: pages),
    );
    notifyListeners();
  }

  void setParallelThreads(int threads) {
    if (_pendingConfig.ingestion.parallelThreads == threads) return;
    _pendingConfig = _pendingConfig.copyWith(
      ingestion: _pendingConfig.ingestion.copyWith(parallelThreads: threads),
    );
    notifyListeners();
  }

  void setIngestionMode(IngestionMode mode) {
    if (_pendingConfig.ingestion.mode == mode) return;
    _pendingConfig = _pendingConfig.copyWith(
      ingestion: _pendingConfig.ingestion.copyWith(mode: mode),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _statusTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
