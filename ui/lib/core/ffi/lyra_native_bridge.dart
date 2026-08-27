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
    // --- Works Mock Handlers ---
    _mockHandlers['ListWorks'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'wrk-001',
            'title': 'Symphony No. 5 in C minor, Op. 67',
            'composition_start_year': 1804,
            'composition_end_year': 1808,
            'composition_date_text': '1804-1808',
            'iswc': 'T-000.000.001-0',
            'musicbrainz_id': 'mb-wrk-001',
          },
          {
            'id': 'wrk-002',
            'title': 'Hotel California',
            'composition_start_year': 1976,
            'composition_end_year': 1976,
            'iswc': 'T-000.000.002-1',
            'musicbrainz_id': 'mb-wrk-002',
          },
        ],
        'total': 2,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 50,
      },
    };

    _mockHandlers['GetWork'] = (params) async {
      final id = params['id'] as String? ?? 'wrk-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': id,
          'title': id == 'wrk-002'
              ? 'Hotel California'
              : 'Symphony No. 5 in C minor, Op. 67',
          'composition_start_year': id == 'wrk-002' ? 1976 : 1804,
          'composition_end_year': id == 'wrk-002' ? 1976 : 1808,
          'composition_date_text': id == 'wrk-002' ? '1976' : '1804-1808',
          'iswc': id == 'wrk-002' ? 'T-000.000.002-1' : 'T-000.000.001-0',
          'musicbrainz_id': id == 'wrk-002' ? 'mb-wrk-002' : 'mb-wrk-001',
        },
      };
    };

    _mockHandlers['GetWorksByTitle'] = (params) async {
      final title = params['title'] as String? ?? '';
      return {
        'code': 200,
        'status': 'success',
        'data': [
          {
            'id': 'wrk-001',
            'title': title.isNotEmpty
                ? title
                : 'Symphony No. 5 in C minor, Op. 67',
            'composition_start_year': 1804,
            'composition_end_year': 1808,
          },
        ],
      };
    };

    _mockHandlers['CreateWork'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'wrk-created-${DateTime.now().millisecondsSinceEpoch}',
        'title': params['title'] ?? 'New Work',
        if (params.containsKey('composition_start_year'))
          'composition_start_year': params['composition_start_year'],
        if (params.containsKey('composition_end_year'))
          'composition_end_year': params['composition_end_year'],
        if (params.containsKey('composition_date_text'))
          'composition_date_text': params['composition_date_text'],
        if (params.containsKey('iswc')) 'iswc': params['iswc'],
        if (params.containsKey('musicbrainz_id'))
          'musicbrainz_id': params['musicbrainz_id'],
      },
    };

    _mockHandlers['UpdateWork'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'id': params['id'] ?? 'wrk-001',
        'title': params['title'] ?? 'Updated Work',
        ...params,
      },
    };

    // --- Tracks Mock Handlers ---
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
            'duration_ms': 432000,
            'artist': 'Eagles',
            'artist_name': 'Eagles',
            'album': 'Hell Freezes Over',
            'album_title': 'Hell Freezes Over',
            'format': 'FLAC',
            'sample_rate': 96000,
            'bit_depth': 24,
            'verified': true,
          },
          {
            'id': 'trk-002',
            'title': 'So What',
            'pcm_hash':
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            'duration': 562000,
            'duration_ms': 562000,
            'artist': 'Miles Davis',
            'artist_name': 'Miles Davis',
            'album': 'Kind of Blue',
            'album_title': 'Kind of Blue',
            'format': 'FLAC',
            'sample_rate': 44100,
            'bit_depth': 16,
            'verified': true,
          },
        ],
        'total': 2,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 20,
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
          'duration_ms': 432000,
          'artist_name': 'Eagles',
          'album_title': 'Hell Freezes Over',
          'format': 'FLAC',
          'sample_rate': 96000,
          'bit_depth': 24,
          'verified': true,
        },
      };
    };

    _mockHandlers['GetTracksByTitle'] = (params) async {
      final title = params['title'] as String? ?? '';
      return {
        'code': 200,
        'status': 'success',
        'data': [
          {
            'id': 'trk-001',
            'title': title.isNotEmpty
                ? title
                : 'Hotel California (Live on MTV 1994)',
            'pcm_hash':
                '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
            'duration_ms': 432000,
            'artist_name': 'Eagles',
            'album_title': 'Hell Freezes Over',
          },
        ],
      };
    };

    _mockHandlers['CreateTrack'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'trk-created-${DateTime.now().millisecondsSinceEpoch}',
        'pcm_hash': params['pcm_hash'] ?? 'mock_pcm_hash',
        'title': params['title'] ?? 'New Track',
        ...params,
      },
    };

    _mockHandlers['UpdateTrack'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'id': params['id'] ?? 'trk-001', ...params},
    };

    _mockHandlers['ImportTrack'] = (params) async {
      final sourcePath = params['source_path'] as String? ?? 'track.flac';
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'track_id': 'trk-imported-${DateTime.now().millisecondsSinceEpoch}',
          'id': 'trk-imported-${DateTime.now().millisecondsSinceEpoch}',
          'title': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          'pcm_hash':
              'mock_pcm_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
          'format': 'FLAC',
          'sample_rate': 44100,
          'bit_depth': 16,
        },
      };
    };

    // --- Albums Mock Handlers ---
    _mockHandlers['ListAlbums'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'alb-001',
            'title': 'Kind of Blue',
            'artist': 'Miles Davis',
            'artist_name': 'Miles Davis',
            'release_year': 1959,
            'cover_art_hash': 'img-cover-001',
            'total_tracks': 5,
            'format': 'FLAC',
          },
          {
            'id': 'alb-002',
            'title': 'Hell Freezes Over',
            'artist': 'Eagles',
            'artist_name': 'Eagles',
            'release_year': 1994,
            'cover_art_hash': 'img-cover-002',
            'total_tracks': 15,
            'format': 'FLAC',
          },
        ],
        'total': 2,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 20,
      },
    };

    _mockHandlers['GetAlbum'] = (params) async {
      final id = params['id'] as String? ?? 'alb-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': id,
          'title': id == 'alb-002' ? 'Hell Freezes Over' : 'Kind of Blue',
          'artist_name': id == 'alb-002' ? 'Eagles' : 'Miles Davis',
          'release_year': id == 'alb-002' ? 1994 : 1959,
          'cover_art_hash': 'img-cover-$id',
          'total_tracks': id == 'alb-002' ? 15 : 5,
          'format': 'FLAC',
        },
      };
    };

    _mockHandlers['GetAlbumsByTitle'] = (params) async {
      final title = params['title'] as String? ?? '';
      return {
        'code': 200,
        'status': 'success',
        'data': [
          {
            'id': 'alb-001',
            'title': title.isNotEmpty ? title : 'Kind of Blue',
            'artist_name': 'Miles Davis',
            'release_year': 1959,
          },
        ],
      };
    };

    _mockHandlers['GetAlbumCover'] = (params) async {
      final albumId = params['album_id'] as String? ?? 'alb-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'image_hash': 'img-cover-$albumId',
          'file_hash': 'file-cover-$albumId',
          'path': '/storage/covers/$albumId.jpg',
          'mime_type': 'image/jpeg',
          'width': 1000,
          'height': 1000,
          'dominant_color': '#1E293B',
          'role': 'front',
        },
      };
    };

    _mockHandlers['CreateAlbum'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'alb-created-${DateTime.now().millisecondsSinceEpoch}',
        'title': params['title'] ?? 'New Album',
        ...params,
      },
    };

    _mockHandlers['UpdateAlbum'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'id': params['id'] ?? 'alb-001', ...params},
    };

    // --- Artists Mock Handlers ---
    _mockHandlers['ListArtists'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'art-001',
            'name': 'Miles Davis',
            'musicbrainz_id': 'mb-art-001',
            'role': 'main',
          },
          {
            'id': 'art-002',
            'name': 'Eagles',
            'musicbrainz_id': 'mb-art-002',
            'role': 'main',
          },
        ],
        'total': 2,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 20,
      },
    };

    _mockHandlers['GetArtist'] = (params) async {
      final id = params['id'] as String? ?? 'art-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': id,
          'name': id == 'art-002' ? 'Eagles' : 'Miles Davis',
          'musicbrainz_id': 'mb-art-$id',
          'role': 'main',
        },
      };
    };

    _mockHandlers['GetArtistsByName'] = (params) async {
      final name = params['name'] as String? ?? '';
      return {
        'code': 200,
        'status': 'success',
        'data': [
          {'id': 'art-001', 'name': name.isNotEmpty ? name : 'Miles Davis'},
        ],
      };
    };

    _mockHandlers['GetArtistCover'] = (params) async {
      final artistId = params['artist_id'] as String? ?? 'art-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'image_hash': 'img-art-$artistId',
          'file_hash': 'file-art-$artistId',
          'path': '/storage/artists/$artistId.jpg',
          'mime_type': 'image/jpeg',
          'width': 800,
          'height': 800,
          'dominant_color': '#334155',
          'role': 'artist_avatar',
        },
      };
    };

    _mockHandlers['CreateArtist'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'art-created-${DateTime.now().millisecondsSinceEpoch}',
        'name': params['name'] ?? 'New Artist',
        ...params,
      },
    };

    _mockHandlers['UpdateArtist'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'id': params['id'] ?? 'art-001', ...params},
    };

    // --- Playlists Mock Handlers ---
    _mockHandlers['ListPlaylists'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'pl-001',
            'title': 'Audiophile Reference',
            'description': 'Master quality benchmark tracks',
            'track_ids': ['trk-001', 'trk-002'],
            'created_at': '2026-01-01T00:00:00.000Z',
            'updated_at': '2026-01-02T00:00:00.000Z',
          },
        ],
        'total': 1,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 20,
      },
    };

    _mockHandlers['GetPlaylist'] = (params) async {
      final id = params['id'] as String? ?? 'pl-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': id,
          'title': 'Audiophile Reference',
          'description': 'Master quality benchmark tracks',
          'track_ids': ['trk-001', 'trk-002'],
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-02T00:00:00.000Z',
        },
      };
    };

    _mockHandlers['GetPlaylistsByTitle'] = (params) async {
      final title = params['title'] as String? ?? '';
      return {
        'code': 200,
        'status': 'success',
        'data': [
          {
            'id': 'pl-001',
            'title': title.isNotEmpty ? title : 'Audiophile Reference',
            'track_ids': ['trk-001', 'trk-002'],
          },
        ],
      };
    };

    _mockHandlers['CreatePlaylist'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'pl-created-${DateTime.now().millisecondsSinceEpoch}',
        'title': params['title'] ?? 'New Playlist',
        'description': params['description'],
        'track_ids': params['track_ids'] ?? [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    };

    _mockHandlers['UpdatePlaylist'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'id': params['id'] ?? 'pl-001', ...params},
    };

    _mockHandlers['AddPlaylistTrack'] = (params) async => {
      'code': 201,
      'status': 'success',
      'message': 'Add PlaylistTrack success.',
    };

    _mockHandlers['RemovePlaylistTrack'] = (params) async => {
      'code': 200,
      'status': 'success',
      'message': 'Remove PlaylistTrack success.',
    };

    _mockHandlers['GetPlaylistTracks'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': ['trk-001', 'trk-002'],
    };

    _mockHandlers['GetPlaylistCover'] = (params) async {
      final playlistId = params['playlist_id'] as String? ?? 'pl-001';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'image_hash': 'img-pl-$playlistId',
          'file_hash': 'file-pl-$playlistId',
          'path': '/storage/playlists/$playlistId.jpg',
          'mime_type': 'image/jpeg',
          'width': 600,
          'height': 600,
          'dominant_color': '#475569',
          'role': 'front',
        },
      };
    };

    // --- Assets Mock Handlers ---
    _mockHandlers['ListAssets'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'file_hash':
                '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
            'mime_type': 'audio/flac',
            'asset_type': 'audio',
            'file_size': 45218900,
            'created_at': '2026-01-01T00:00:00.000Z',
            'verified': true,
          },
        ],
        'total': 1,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 50,
      },
    };

    _mockHandlers['GetAsset'] = (params) async {
      final hash =
          params['file_hash'] as String? ??
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'file_hash': hash,
          'mime_type': 'audio/flac',
          'asset_type': 'audio',
          'file_size': 45218900,
          'created_at': '2026-01-01T00:00:00.000Z',
          'verified': true,
        },
      };
    };

    _mockHandlers['CreateAsset'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'file_hash': params['file_hash'] ?? 'mock_asset_hash',
        ...params,
      },
    };

    _mockHandlers['UpdateAsset'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'file_hash': params['file_hash'] ?? 'mock_asset_hash',
        ...params,
      },
    };

    _mockHandlers['GetResourcePath'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'path':
            '/storage/cas/7f/83/7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069.flac',
        'mime_type': 'audio/flac',
      },
    };

    // --- Audio Mock Handlers ---
    _mockHandlers['ListAudio'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'pcm_hash':
                '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
            'parent_hash': 'parent_file_hash_001',
            'quality_score': 98,
            'bit_depth': 24,
            'sample_rate': 96000,
            'channels': 2,
            'duration_ms': 432000.0,
            'integrated_loudness': -14.2,
            'true_peak': -0.5,
          },
        ],
        'total': 1,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 50,
      },
    };

    _mockHandlers['GetAudio'] = (params) async {
      final hash =
          params['pcm_hash'] as String? ??
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'pcm_hash': hash,
          'parent_hash': 'parent_file_hash_001',
          'quality_score': 98,
          'bit_depth': 24,
          'sample_rate': 96000,
          'channels': 2,
          'duration_ms': 432000.0,
          'integrated_loudness': -14.2,
          'true_peak': -0.5,
        },
      };
    };

    _mockHandlers['CreateAudio'] = (params) async => {
      'code': 201,
      'status': 'success',
      'data': {'pcm_hash': params['pcm_hash'] ?? 'mock_pcm_hash', ...params},
    };

    _mockHandlers['UpdateAudio'] = (params) async => {
      'code': 200,
      'status': 'success',
      'data': {'pcm_hash': params['pcm_hash'] ?? 'mock_pcm_hash', ...params},
    };

    // --- Tag Mock Handlers ---
    Future<Map<String, dynamic>> tagListHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 200,
      'status': 'success',
      'data': {
        'items': [
          {
            'id': 'tag-001',
            'name': 'Audiophile Master',
            'category': 'quality',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': 'tag-002',
            'name': 'Jazz',
            'category': 'genre',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        ],
        'total': 2,
        'offset': params['offset'] ?? 0,
        'limit': params['limit'] ?? 50,
      },
    };
    _mockHandlers['tag.list'] = tagListHandler;
    _mockHandlers['ListTags'] = tagListHandler;

    Future<Map<String, dynamic>> tagCreateHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'tag-created-${DateTime.now().millisecondsSinceEpoch}',
        'name': params['name'] ?? 'New Tag',
        'category': params['category'] ?? 'general',
        'created_at': DateTime.now().toIso8601String(),
      },
    };
    _mockHandlers['tag.create'] = tagCreateHandler;
    _mockHandlers['CreateTag'] = tagCreateHandler;

    Future<Map<String, dynamic>> tagAssignHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 200,
      'status': 'success',
      'message': 'Tag assigned successfully.',
    };
    _mockHandlers['tag.assign'] = tagAssignHandler;
    _mockHandlers['AssignTag'] = tagAssignHandler;

    Future<Map<String, dynamic>> tagRemoveHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 200,
      'status': 'success',
      'message': 'Tag removed successfully.',
    };
    _mockHandlers['tag.remove'] = tagRemoveHandler;
    _mockHandlers['RemoveTag'] = tagRemoveHandler;

    Future<Map<String, dynamic>> tagGetEntityTagsHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 200,
      'status': 'success',
      'data': [
        {
          'id': 'tag-001',
          'name': 'Audiophile Master',
          'category': 'quality',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
      ],
    };
    _mockHandlers['tag.get_entity_tags'] = tagGetEntityTagsHandler;
    _mockHandlers['GetEntityTags'] = tagGetEntityTagsHandler;

    // --- Source Data Mock Handlers ---
    Future<Map<String, dynamic>> sourceDataGetHandler(
      Map<String, dynamic> params,
    ) async {
      final fileHash =
          (params['file_hash'] ??
                  params['fileHash'] ??
                  params['asset_hash'] ??
                  params['hash'])
              as String? ??
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069';
      return {
        'code': 200,
        'status': 'success',
        'data': {
          'id': 'src-001',
          'file_hash': fileHash,
          'source_type': 'cd_rip',
          'original_path': '/media/cdrom/track01.wav',
          'created_at': '2026-01-01T00:00:00.000Z',
          'note': 'EAC AccurateRip log: 100% confidence',
        },
      };
    }

    _mockHandlers['source_data.get_by_asset'] = sourceDataGetHandler;
    _mockHandlers['GetSourceDataByAssetHash'] = sourceDataGetHandler;
    _mockHandlers['GetSourceDataByAsset'] = sourceDataGetHandler;

    Future<Map<String, dynamic>> sourceDataCreateHandler(
      Map<String, dynamic> params,
    ) async => {
      'code': 201,
      'status': 'success',
      'data': {
        'id':
            params['id'] ??
            'src-created-${DateTime.now().millisecondsSinceEpoch}',
        'file_hash': params['file_hash'] ?? '',
        'source_type': params['source_type'] ?? 'digital_download',
        'original_path': params['original_path'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'note': params['note'] ?? '',
      },
    };
    _mockHandlers['source_data.create'] = sourceDataCreateHandler;
    _mockHandlers['CreateSourceData'] = sourceDataCreateHandler;

    // --- Audio Control Mock Handlers ---
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
