// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../bridge/lyra_bridge.dart';
import '../bridge/mock_lyra_bridge.dart';
import 'lyra_ffi_bindings.dart';

export '../bridge/lyra_bridge.dart';
export '../bridge/mock_lyra_bridge.dart';

/// Production asynchronous native bridge executing C++ operations via background [Isolate].
class LyraNativeBridge extends MockLyraBridge {
  /// Shared singleton instance for backward compatibility.
  static LyraNativeBridge get instance {
    final current = LyraBridge.instance;
    if (current is LyraNativeBridge) {
      return current;
    }
    final bridge = LyraNativeBridge();
    LyraBridge.setInstance(bridge);
    return bridge;
  }

  /// Sets or replaces the shared singleton instance.
  static void setInstance(LyraNativeBridge bridge) {
    LyraBridge.setInstance(bridge);
  }

  /// Resets the shared singleton instance.
  static void resetInstance() {
    LyraBridge.resetInstance();
  }

  bool _nativeInitialized = false;
  bool _mockMode = false;
  bool _nativeDisposed = false;

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _responseReceivePort;
  StreamSubscription<dynamic>? _responseSubscription;

  int _requestCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  LyraNativeBridge() : super();

  @override
  bool get isMockMode => _mockMode;

  @override
  bool get isInitialized => _nativeInitialized && !_nativeDisposed;

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
    if (_nativeDisposed) {
      throw const LyraBridgeException(
        'Cannot initialize a disposed LyraNativeBridge.',
      );
    }

    if (_nativeInitialized) {
      return;
    }

    if (forceMock) {
      _mockMode = true;
      _nativeInitialized = true;
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
          _nativeInitialized = true;
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
      _nativeInitialized = true;
    } catch (e) {
      if (enableMockFallback) {
        _mockMode = true;
        _nativeInitialized = true;
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
  Future<Map<String, dynamic>> rawDispatch(
    Map<dynamic, dynamic> requestPayload,
  ) async {
    if (_nativeDisposed) {
      throw const LyraBridgeException('Bridge has been disposed.');
    }

    if (!_nativeInitialized) {
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
      return dispatchMockCommand(command, params);
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

  @override
  Future<void> dispose() async {
    if (_nativeDisposed) return;
    _nativeDisposed = true;
    _nativeInitialized = false;

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

    await super.dispose();
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
