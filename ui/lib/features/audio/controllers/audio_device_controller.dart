// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../../../core/bridge/lyra_bridge.dart';
import '../models/audio_device.dart';

/// Controller managing available audio output devices and active device selection.
class AudioDeviceController extends ChangeNotifier {
  final LyraBridge _bridge;

  static const List<AudioDevice> defaultInitialDevices = [
    AudioDevice(
      id: 'default',
      name: 'Default System Audio',
      isDefault: true,
      minChannels: 2,
      maxChannels: 2,
      minSampleRate: 44100,
      maxSampleRate: 48000,
    ),
    AudioDevice(
      id: 'usb-dac-01',
      name: 'USB Audio DAC (Hi-Res PCM 192kHz)',
      isDefault: false,
      minChannels: 2,
      maxChannels: 8,
      minSampleRate: 44100,
      maxSampleRate: 192000,
    ),
    AudioDevice(
      id: 'headphones-01',
      name: 'Headphones (3.5mm)',
      isDefault: false,
      minChannels: 2,
      maxChannels: 2,
      minSampleRate: 44100,
      maxSampleRate: 96000,
    ),
  ];

  List<AudioDevice> _devices;
  String _currentDeviceId;
  bool _isLoading = false;
  String? _errorMessage;

  AudioDeviceController({
    LyraBridge? bridge,
    List<AudioDevice>? initialDevices,
    String initialDeviceId = 'default',
    bool autoLoad = true,
  }) : _bridge = bridge ?? LyraBridge.instance,
       _devices = initialDevices ?? defaultInitialDevices,
       _currentDeviceId = initialDeviceId {
    if (autoLoad) {
      loadDevices();
    }
  }

  /// Available audio output devices.
  List<AudioDevice> get devices => List.unmodifiable(_devices);

  /// ID of the currently active audio output device.
  String get currentDeviceId => _currentDeviceId;

  /// Currently active [AudioDevice], or null if unknown.
  AudioDevice? get currentDevice {
    for (final device in _devices) {
      if (device.id == _currentDeviceId) {
        return device;
      }
    }
    return _devices.isNotEmpty ? _devices.first : null;
  }

  /// Whether device enumeration or switching is currently in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last operation, if any.
  String? get errorMessage => _errorMessage;

  /// Enumerate output devices from the backend audio engine.
  Future<void> loadDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _bridge.listAudioDevices();
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawDevices = data['devices'];
        if (rawDevices is List) {
          _devices = rawDevices
              .whereType<Map<String, dynamic>>()
              .map(AudioDevice.fromJson)
              .toList();
        }
        final currentId = data['current_device_id'] as String?;
        if (currentId != null && currentId.isNotEmpty) {
          _currentDeviceId = currentId;
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Set the active audio output device by [deviceId].
  Future<bool> selectDevice(String deviceId) async {
    if (_currentDeviceId == deviceId) return true;

    final previousId = _currentDeviceId;
    _currentDeviceId = deviceId;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _bridge.setAudioOutputDevice(deviceId);
      final status = response['status'];
      final data = response['data'];
      final bool success =
          status == 'success' || (data is Map && data['success'] == true);

      if (!success) {
        _currentDeviceId = previousId;
        _errorMessage =
            response['message']?.toString() ?? 'Failed to switch output device';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      _currentDeviceId = previousId;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
