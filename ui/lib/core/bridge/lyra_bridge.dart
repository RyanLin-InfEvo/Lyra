// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'bridge_factory_web.dart'
    if (dart.library.ffi) 'bridge_factory_native.dart'
    as bridge_factory;

/// Exception thrown when a bridge request fails or is rejected by the backend.
class LyraBridgeException implements Exception {
  final String message;
  final int? code;
  final Map<String, dynamic>? details;

  const LyraBridgeException(this.message, {this.code, this.details});

  @override
  String toString() => 'LyraBridgeException(code: $code, message: $message)';
}

/// Handler signature for mock command executions.
typedef MockCommandHandler =
    FutureOr<Map<String, dynamic>> Function(Map<String, dynamic> params);

/// Abstract contract for interacting with the Lyra backend.
abstract class LyraBridge {
  static LyraBridge? _instance;

  /// Shared singleton instance.
  static LyraBridge get instance => _instance ??= bridge_factory.createBridge();

  /// Sets or replaces the shared singleton instance.
  static void setInstance(LyraBridge bridge) {
    _instance = bridge;
  }

  /// Resets the shared singleton instance.
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// Whether the bridge is currently operating in mock fallback mode.
  bool get isMockMode;

  /// Whether the bridge has been initialized and is ready to process requests.
  bool get isInitialized;

  /// Initializes the bridge with optional [storageRoot] and [dynamicLibraryPath].
  Future<void> initialize({
    String? storageRoot,
    String? dynamicLibraryPath,
    bool enableMockFallback = true,
    bool forceMock = false,
  });

  /// Executes a named backend command with optional parameters off the UI thread.
  Future<Map<String, dynamic>> executeCommand(
    String action, [
    Map<String, dynamic>? params,
  ]);

  /// Dispatches a raw request map (containing `command` or `action` and `params`).
  Future<Map<String, dynamic>> rawDispatch(
    Map<dynamic, dynamic> requestPayload,
  );

  /// Retrieves detected audio output devices and currently active device.
  Future<Map<String, dynamic>> listAudioDevices();

  /// Switches active audio output device by [deviceId].
  Future<Map<String, dynamic>> setAudioOutputDevice(String deviceId);

  /// Disposes of active background isolates and communication channels.
  Future<void> dispose();
}
