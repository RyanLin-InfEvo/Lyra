// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'lyra_ffi_bindings.dart';

/// Exception thrown when a bridge request fails or is rejected by the backend.
class LyraBridgeException implements Exception {
  final String message;
  final int? code;
  final Map<String, dynamic>? details;

  const LyraBridgeException(this.message, {this.code, this.details});

  @override
  String toString() => 'LyraBridgeException(code: $code, message: $message)';
}

/// Abstract contract for interacting with the Lyra backend.
abstract class LyraBridge {
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

  /// Disposes of active background isolates and communication channels.
  Future<void> dispose();
}

/// Handler signature for mock command executions.
typedef MockCommandHandler =
    FutureOr<Map<String, dynamic>> Function(Map<String, dynamic> params);

/// Production asynchronous native bridge executing C++ operations via background [Isolate].
class LyraNativeBridge implements LyraBridge {
  static LyraNativeBridge? _instance;

  /// Shared singleton instance.
  static LyraNativeBridge get instance => _instance ??= LyraNativeBridge();

  /// Sets or replaces the shared singleton instance.
  static void setInstance(LyraNativeBridge bridge) {
    _instance = bridge;
  }

  /// Resets the shared singleton instance.
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  bool _initialized = false;
  bool _mockMode = false;
  bool _disposed = false;

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _responseReceivePort;
  StreamSubscription<dynamic>? _responseSubscription;

  int _requestCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final Map<String, MockCommandHandler> _mockHandlers = {};

  LyraNativeBridge() {
    _registerDefaultMockHandlers();
  }

  @override
  bool get isMockMode => _mockMode;

  @override
  bool get isInitialized => _initialized && !_disposed;

  /// Initializes the bridge.
  ///
  /// If [forceMock] is true or if dynamic library loading fails with [enableMockFallback] enabled,
  /// the bridge operates in mock fallback mode.
  @override
  Future<void> initialize({
    String? storageRoot,
    String? dynamicLibraryPath,
    bool enableMockFallback = true,
    bool forceMock = false,
  }) async {
    if (_disposed) {
      throw const LyraBridgeException(
        'Cannot initialize a disposed LyraNativeBridge.',
      );
    }

    if (_initialized) {
      return;
    }

    if (forceMock) {
      _mockMode = true;
      _initialized = true;
      return;
    }

    try {
      // Test dynamic library availability in current process first
      final dylib = LyraFfiBindings.tryLoadDynamicLibrary(
        customPath: dynamicLibraryPath,
      );

      if (dylib == null) {
        if (enableMockFallback) {
          _mockMode = true;
          _initialized = true;
          return;
        }
        throw const LyraBridgeException(
          'Lyra dynamic library not found and mock fallback is disabled.',
        );
      }

      await _spawnWorkerIsolate(
        storageRoot: storageRoot,
        dynamicLibraryPath: dynamicLibraryPath,
      );

      _mockMode = false;
      _initialized = true;
    } catch (e) {
      if (enableMockFallback) {
        _mockMode = true;
        _initialized = true;
      } else {
        if (e is LyraBridgeException) {
          rethrow;
        }
        throw LyraBridgeException(
          'Failed to initialize native bridge: $e',
          details: {'error': e.toString()},
        );
      }
    }
  }

  /// Spawns background worker isolate and establishes handshake.
  Future<void> _spawnWorkerIsolate({
    String? storageRoot,
    String? dynamicLibraryPath,
  }) async {
    final initReceivePort = ReceivePort();
    _responseReceivePort = ReceivePort();

    _workerIsolate = await Isolate.spawn(
      _isolateWorkerEntry,
      _IsolateInitConfig(
        handshakeSendPort: initReceivePort.sendPort,
        storageRoot: storageRoot,
        dynamicLibraryPath: dynamicLibraryPath,
      ),
    );

    final handshake = await initReceivePort.first as _IsolateHandshakeMessage;
    initReceivePort.close();

    if (!handshake.success) {
      throw LyraBridgeException(
        handshake.errorMessage ??
            'Isolate worker failed during startup initialization.',
      );
    }

    _workerSendPort = handshake.workerSendPort;

    _responseSubscription = _responseReceivePort!.listen(
      _handleWorkerResponse,
      onError: (error) {
        for (final completer in _pendingRequests.values) {
          if (!completer.isCompleted) {
            completer.completeError(
              LyraBridgeException('Worker isolate communication error: $error'),
            );
          }
        }
        _pendingRequests.clear();
      },
      onDone: () {
        for (final completer in _pendingRequests.values) {
          if (!completer.isCompleted) {
            completer.completeError(
              const LyraBridgeException(
                'Worker isolate terminated unexpectedly.',
              ),
            );
          }
        }
        _pendingRequests.clear();
      },
    );
  }

  /// Handles response messages delivered from the background isolate worker.
  void _handleWorkerResponse(dynamic message) {
    if (message is _IsolateResponseMessage) {
      final completer = _pendingRequests.remove(message.requestId);
      if (completer != null && !completer.isCompleted) {
        if (message.error != null) {
          completer.completeError(
            LyraBridgeException(
              message.error!,
              code: message.code ?? 500,
              details: message.data,
            ),
          );
        } else {
          completer.complete(message.data ?? <String, dynamic>{});
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>> executeCommand(
    String action, [
    Map<String, dynamic>? params,
  ]) async {
    return rawDispatch({
      'command': action,
      'params': params ?? <String, dynamic>{},
    });
  }

  @override
  Future<Map<String, dynamic>> rawDispatch(
    Map<dynamic, dynamic> requestPayload,
  ) async {
    if (_disposed) {
      throw const LyraBridgeException('Bridge has been disposed.');
    }

    if (!_initialized) {
      // Auto-initialize with default mock fallback if not yet initialized
      await initialize(enableMockFallback: true);
    }

    final command =
        requestPayload['command']?.toString() ??
        requestPayload['action']?.toString() ??
        '';

    final rawParams = requestPayload['params'];
    final Map<String, dynamic> params;
    if (rawParams is Map) {
      params = rawParams.map((k, v) => MapEntry(k.toString(), v));
    } else {
      params = <String, dynamic>{};
    }

    if (_mockMode) {
      return _dispatchMockCommand(command, params);
    }

    final requestId = ++_requestCounter;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    final request = _IsolateRequestMessage(
      requestId: requestId,
      commandPayload: {'command': command, 'params': params},
      responseSendPort: _responseReceivePort!.sendPort,
    );

    _workerSendPort!.send(request);

    return completer.future;
  }

  /// Registers a custom mock command handler for testing.
  void registerMockHandler(String action, MockCommandHandler handler) {
    _mockHandlers[action] = handler;
  }

  /// Removes a custom mock handler.
  void removeMockHandler(String action) {
    _mockHandlers.remove(action);
  }

  /// Clears all custom mock handlers and restores default handlers.
  void clearMockHandlers() {
    _mockHandlers.clear();
    _registerDefaultMockHandlers();
  }

  /// Executes a command against registered mock handlers or built-in defaults.
  Future<Map<String, dynamic>> _dispatchMockCommand(
    String action,
    Map<String, dynamic> params,
  ) async {
    // Delay slightly to simulate asynchronous isolate execution
    await Future<void>.delayed(const Duration(milliseconds: 1));

    if (_mockHandlers.containsKey(action)) {
      final handler = _mockHandlers[action]!;
      return await handler(params);
    }

    // Default mock response generator for unhandled actions
    return {
      'code': 200,
      'status': 'success',
      'action': action,
      'data': <String, dynamic>{},
      'message': 'Mock response for $action',
    };
  }

  /// Registers standard mock responses for built-in Lyra commands.
  void _registerDefaultMockHandlers() {
    _mockHandlers['ListTracks'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'trk-001',
            'title': 'Hotel California (Live on MTV 1994)',
            'pcm_hash':
                '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
            'duration': 432000,
            'artist': 'Eagles',
            'album': 'Hell Freezes Over',
          },
          {
            'id': 'trk-002',
            'title': 'So What',
            'pcm_hash':
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            'duration': 562000,
            'artist': 'Miles Davis',
            'album': 'Kind of Blue',
          },
        ],
        'total': 2,
        'offset': 0,
        'limit': 20,
      },
    };

    _mockHandlers['GetTrack'] = (params) async {
      final id = params['id'] as String?;
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': id ?? 'trk-001',
          'title': 'Hotel California (Live on MTV 1994)',
          'pcm_hash':
              '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
          'duration': 432000,
        },
      };
    };

    _mockHandlers['ListAlbums'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'alb-001',
            'title': 'Kind of Blue',
            'artist': 'Miles Davis',
            'release_year': 1959,
          },
          {
            'id': 'alb-002',
            'title': 'Hell Freezes Over',
            'artist': 'Eagles',
            'release_year': 1994,
          },
        ],
        'total': 2,
        'offset': 0,
        'limit': 20,
      },
    };

    _mockHandlers['ListArtists'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {'id': 'art-001', 'name': 'Miles Davis'},
          {'id': 'art-002', 'name': 'Eagles'},
        ],
        'total': 2,
        'offset': 0,
        'limit': 20,
      },
    };

    _mockHandlers['ListPlaylists'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {'id': 'pl-001', 'title': 'Audiophile Reference', 'track_count': 12},
        ],
        'total': 1,
        'offset': 0,
        'limit': 20,
      },
    };

    _mockHandlers['ImportTrack'] = (params) async {
      final sourcePath = params['source_path'] as String? ?? 'track.flac';
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'track_id': 'trk-imported-${DateTime.now().millisecondsSinceEpoch}',
          'title': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          'pcm_hash':
              'mock_pcm_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
        },
      };
    };

    _mockHandlers['audio.play'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'state': 'playing'},
    };

    _mockHandlers['audio.pause'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'state': 'paused'},
    };

    _mockHandlers['audio.resume'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'state': 'playing'},
    };

    _mockHandlers['audio.stop'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'state': 'stopped'},
    };

    _mockHandlers['audio.get_state'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'state': 'idle',
        'volume': 1.0,
        'position_ms': 0,
        'duration_ms': 0,
      },
    };
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const LyraBridgeException(
            'LyraNativeBridge disposed while request was pending.',
          ),
        );
      }
    }
    _pendingRequests.clear();

    await _responseSubscription?.cancel();
    _responseReceivePort?.close();

    _workerSendPort?.send(const _IsolateDisposeMessage());
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }
}

// ---------------------------------------------------------------------------
// Background Worker Isolate Implementation
// ---------------------------------------------------------------------------

class _IsolateInitConfig {
  final SendPort handshakeSendPort;
  final String? storageRoot;
  final String? dynamicLibraryPath;

  const _IsolateInitConfig({
    required this.handshakeSendPort,
    this.storageRoot,
    this.dynamicLibraryPath,
  });
}

class _IsolateHandshakeMessage {
  final bool success;
  final SendPort? workerSendPort;
  final String? errorMessage;

  const _IsolateHandshakeMessage({
    required this.success,
    this.workerSendPort,
    this.errorMessage,
  });
}

class _IsolateRequestMessage {
  final int requestId;
  final Map<String, dynamic> commandPayload;
  final SendPort responseSendPort;

  const _IsolateRequestMessage({
    required this.requestId,
    required this.commandPayload,
    required this.responseSendPort,
  });
}

class _IsolateResponseMessage {
  final int requestId;
  final Map<String, dynamic>? data;
  final int? code;
  final String? error;

  const _IsolateResponseMessage({
    required this.requestId,
    this.data,
    this.code,
    this.error,
  });
}

class _IsolateDisposeMessage {
  const _IsolateDisposeMessage();
}

/// Worker entry point executed inside background [Isolate].
void _isolateWorkerEntry(_IsolateInitConfig config) {
  final requestReceivePort = ReceivePort();
  LyraFfiBindings? bindings;

  try {
    bindings = LyraFfiBindings.load(customPath: config.dynamicLibraryPath);

    if (config.storageRoot != null && config.storageRoot!.isNotEmpty) {
      final initCode = bindings.init(config.storageRoot!);
      if (initCode != 0) {
        config.handshakeSendPort.send(
          _IsolateHandshakeMessage(
            success: false,
            errorMessage: 'lyra_init returned non-zero error code: $initCode',
          ),
        );
        requestReceivePort.close();
        return;
      }
    }

    config.handshakeSendPort.send(
      _IsolateHandshakeMessage(
        success: true,
        workerSendPort: requestReceivePort.sendPort,
      ),
    );
  } catch (e) {
    config.handshakeSendPort.send(
      _IsolateHandshakeMessage(
        success: false,
        errorMessage: 'Failed to load native bindings in isolate: $e',
      ),
    );
    requestReceivePort.close();
    return;
  }

  requestReceivePort.listen((message) {
    if (message is _IsolateDisposeMessage) {
      requestReceivePort.close();
      return;
    }

    if (message is _IsolateRequestMessage) {
      try {
        final jsonRequestStr = jsonEncode(message.commandPayload);
        final jsonResponseStr = bindings!.dispatch(jsonRequestStr);
        final dynamic decoded = jsonDecode(jsonResponseStr);

        if (decoded is Map<String, dynamic>) {
          final code = decoded['code'] as int?;
          if (code != null && code >= 400) {
            final errorMap = decoded['error'];
            final errorMsg = errorMap is Map
                ? errorMap['message']?.toString()
                : null;
            message.responseSendPort.send(
              _IsolateResponseMessage(
                requestId: message.requestId,
                data: decoded,
                code: code,
                error: errorMsg ?? 'Command failed with code $code',
              ),
            );
          } else {
            message.responseSendPort.send(
              _IsolateResponseMessage(
                requestId: message.requestId,
                data: decoded,
                code: code ?? 200,
              ),
            );
          }
        } else {
          message.responseSendPort.send(
            _IsolateResponseMessage(
              requestId: message.requestId,
              data: {'result': decoded},
              code: 200,
            ),
          );
        }
      } catch (e) {
        message.responseSendPort.send(
          _IsolateResponseMessage(
            requestId: message.requestId,
            error: e.toString(),
            code: 500,
          ),
        );
      }
    }
  });
}
