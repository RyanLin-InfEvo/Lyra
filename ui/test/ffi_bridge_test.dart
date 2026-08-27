// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/core/ffi/ffi.dart';

void main() {
  group('LyraFfiBindings', () {
    test('getLibraryFileNames returns correct platform library names', () {
      final names = LyraFfiBindings.getLibraryFileNames();
      expect(names, isNotEmpty);
      if (Platform.isLinux) {
        expect(names, contains('liblyra_core.so'));
      } else if (Platform.isMacOS) {
        expect(names, contains('liblyra_core.dylib'));
      } else if (Platform.isWindows) {
        expect(names, contains('lyra_core.dll'));
      }
    });

    test('getSearchPaths includes custom path, dev dirs, and lib names', () {
      final paths = LyraFfiBindings.getSearchPaths();
      expect(paths.length, greaterThan(1));
      final customPaths = LyraFfiBindings.getSearchPaths(
        customPath: '/custom/path/liblyra.so',
      );
      expect(customPaths, equals(['/custom/path/liblyra.so']));
    });

    test('tryLoadDynamicLibrary returns null on non-existent path', () {
      final dylib = LyraFfiBindings.tryLoadDynamicLibrary(
        customPath: '/invalid/path/that/does/not/exist.so',
      );
      expect(dylib, isNull);
    });

    test('loadDynamicLibrary throws LyraFfiException on non-existent path', () {
      expect(
        () => LyraFfiBindings.loadDynamicLibrary(
          customPath: '/invalid/path/that/does/not/exist.so',
        ),
        throwsA(isA<LyraFfiException>()),
      );
    });

    // Detect if compiled dynamic library is available in workspace
    final detectedDylib = LyraFfiBindings.tryLoadDynamicLibrary();
    if (detectedDylib != null) {
      group('Native C API Integration (Live liblyra_core)', () {
        late LyraFfiBindings bindings;
        late Directory tempDbDir;

        setUpAll(() {
          bindings = LyraFfiBindings(detectedDylib);
          tempDbDir = Directory.systemTemp.createTempSync('lyra_ffi_test_');
          final initRes = bindings.init(tempDbDir.path);
          expect(initRes, equals(0));
        });

        tearDownAll(() {
          if (tempDbDir.existsSync()) {
            tempDbDir.deleteSync(recursive: true);
          }
        });

        test('bindings.dispatch successfully routes valid command', () {
          final request = jsonEncode({
            'command': 'ListArtists',
            'params': {'offset': 0, 'limit': 10},
          });

          final responseStr = bindings.dispatch(request);
          final response = jsonDecode(responseStr) as Map<String, dynamic>;

          expect(response['code'], equals(200));
          final data = response['data'];
          final items = data is Map ? data['items'] : data;
          expect(items, isA<List>());
        });

        test('bindings.executeCommand handles creation and querying', () {
          final createReq = jsonEncode({
            'command': 'CreateArtist',
            'params': {'name': 'FFI Test Artist'},
          });

          final createResStr = bindings.executeCommand(createReq);
          final createRes = jsonDecode(createResStr) as Map<String, dynamic>;

          expect(createRes['code'], equals(201));
          expect(createRes['data']['name'], equals('FFI Test Artist'));
        });

        test('bindings.dispatch returns error code for unknown command', () {
          final badReq = jsonEncode({
            'command': 'NonExistentCommand',
            'params': {},
          });

          final resStr = bindings.dispatch(badReq);
          final res = jsonDecode(resStr) as Map<String, dynamic>;

          expect(res['code'], greaterThanOrEqualTo(400));
          expect(res['error'], isNotNull);
        });
      });
    }
  });

  group('LyraNativeBridge (Mock Mode)', () {
    late LyraNativeBridge bridge;

    setUp(() async {
      bridge = LyraNativeBridge();
      await bridge.initialize(forceMock: true);
    });

    tearDown(() async {
      await bridge.dispose();
    });

    test('initializes in mock mode correctly', () {
      expect(bridge.isInitialized, isTrue);
      expect(bridge.isMockMode, isTrue);
    });

    test('executeCommand ListTracks returns default mock tracks', () async {
      final res = await bridge.executeCommand('ListTracks');
      expect(res['code'], equals(200));
      final data = res['data'];
      final items = (data is Map ? data['items'] : data) as List;
      expect(items.length, greaterThanOrEqualTo(2));
      expect(items.first['title'], contains('Hotel California'));
    });

    test('executeCommand GetTrack returns single mock track', () async {
      final res = await bridge.executeCommand('GetTrack', {'id': 'trk-001'});
      expect(res['code'], equals(200));
      final data = res['data'] as Map<String, dynamic>;
      expect(data['id'], equals('trk-001'));
      expect(data['title'], contains('Hotel California'));
    });

    test('executeCommand ListAlbums returns mock albums', () async {
      final res = await bridge.executeCommand('ListAlbums');
      expect(res['code'], equals(200));
      final data = res['data'];
      final albums = (data is Map ? data['items'] : data) as List;
      expect(albums.first['title'], equals('Kind of Blue'));
    });

    test('executeCommand ListArtists returns mock artists', () async {
      final res = await bridge.executeCommand('ListArtists');
      expect(res['code'], equals(200));
      final data = res['data'];
      final artists = (data is Map ? data['items'] : data) as List;
      expect(artists.first['name'], equals('Miles Davis'));
    });

    test('executeCommand ListPlaylists returns mock playlists', () async {
      final res = await bridge.executeCommand('ListPlaylists');
      expect(res['code'], equals(200));
      final data = res['data'];
      final playlists = (data is Map ? data['items'] : data) as List;
      expect(playlists, isA<List>());
    });

    test(
      'executeCommand ImportTrack parses file path and returns mock track',
      () async {
        final res = await bridge.executeCommand('ImportTrack', {
          'source_path': '/music/flac/Symphony.flac',
        });
        expect(res['code'], equals(200));
        final data = res['data'] as Map<String, dynamic>;
        expect(data['track_id'], startsWith('trk-imported-'));
        expect(data['title'], equals('Symphony'));
      },
    );

    test('executeCommand audio control actions return valid states', () async {
      final playRes = await bridge.executeCommand('audio.play');
      expect(playRes['code'], equals(200));
      expect(playRes['data']['state'], equals('playing'));

      final pauseRes = await bridge.executeCommand('audio.pause');
      expect(pauseRes['code'], equals(200));
      expect(pauseRes['data']['state'], equals('paused'));

      final stateRes = await bridge.executeCommand('audio.get_state');
      expect(stateRes['code'], equals(200));
      expect(stateRes['data']['volume'], equals(1.0));
    });

    test('rawDispatch works with action or command parameter', () async {
      final resWithAction = await bridge.rawDispatch({
        'action': 'ListTracks',
        'params': <String, dynamic>{},
      });
      expect(resWithAction['code'], equals(200));

      final resWithCommand = await bridge.rawDispatch({
        'command': 'ListTracks',
        'params': {},
      });
      expect(resWithCommand['code'], equals(200));
    });

    test('custom mock handler registration, override, and removal', () async {
      bridge.registerMockHandler('CustomAction', (params) async {
        return {'code': 200, 'custom': true, 'echo_param': params['input']};
      });

      final customRes = await bridge.executeCommand('CustomAction', {
        'input': 'hello',
      });
      expect(customRes['code'], equals(200));
      expect(customRes['custom'], isTrue);
      expect(customRes['echo_param'], equals('hello'));

      bridge.removeMockHandler('CustomAction');
      final fallbackRes = await bridge.executeCommand('CustomAction');
      expect(fallbackRes['code'], equals(200));
      expect(fallbackRes['custom'], isNull);

      bridge.registerMockHandler('ListTracks', (params) async {
        return {'code': 200, 'data': []};
      });
      final emptyTracksRes = await bridge.executeCommand('ListTracks');
      expect(emptyTracksRes['data'], isEmpty);

      bridge.clearMockHandlers();
      final restoredTracksRes = await bridge.executeCommand('ListTracks');
      final restoredData = restoredTracksRes['data'];
      final restoredItems =
          (restoredData is Map ? restoredData['items'] : restoredData) as List;
      expect(restoredItems.isNotEmpty, isTrue);
    });

    test('disposing bridge prevents subsequent command execution', () async {
      await bridge.dispose();
      expect(bridge.isInitialized, isFalse);
      expect(
        bridge.executeCommand('ListTracks'),
        throwsA(isA<LyraBridgeException>()),
      );
      expect(bridge.initialize(), throwsA(isA<LyraBridgeException>()));
    });
  });

  group('LyraNativeBridge (Fallback & Lifecycle)', () {
    test(
      'initialization with invalid library path falls back to mock mode when enabled',
      () async {
        final bridge = LyraNativeBridge();
        await bridge.initialize(
          dynamicLibraryPath: '/non/existent/path/liblyra.so',
          enableMockFallback: true,
        );

        expect(bridge.isInitialized, isTrue);
        expect(bridge.isMockMode, isTrue);
        await bridge.dispose();
      },
    );

    test(
      'initialization with invalid library path throws when fallback disabled',
      () async {
        final bridge = LyraNativeBridge();
        expect(
          bridge.initialize(
            dynamicLibraryPath: '/non/existent/path/liblyra.so',
            enableMockFallback: false,
          ),
          throwsA(isA<LyraBridgeException>()),
        );
        await bridge.dispose();
      },
    );

    test('singleton instance management works correctly', () {
      final instance1 = LyraNativeBridge.instance;
      final instance2 = LyraNativeBridge.instance;
      expect(identical(instance1, instance2), isTrue);

      final customInstance = LyraNativeBridge();
      LyraNativeBridge.setInstance(customInstance);
      expect(identical(LyraNativeBridge.instance, customInstance), isTrue);

      LyraNativeBridge.resetInstance();
      final newInstance = LyraNativeBridge.instance;
      expect(identical(newInstance, customInstance), isFalse);
    });
  });

  final detectedDylib = LyraFfiBindings.tryLoadDynamicLibrary();
  if (detectedDylib != null) {
    group('LyraNativeBridge (Background Isolate Execution)', () {
      late LyraNativeBridge bridge;
      late Directory tempDbDir;

      setUp(() async {
        bridge = LyraNativeBridge();
        tempDbDir = Directory.systemTemp.createTempSync('lyra_isolate_test_');
        await bridge.initialize(
          storageRoot: tempDbDir.path,
          enableMockFallback: false,
        );
      });

      tearDown(() async {
        await bridge.dispose();
        if (tempDbDir.existsSync()) {
          tempDbDir.deleteSync(recursive: true);
        }
      });

      test('initializes in native mode with live isolate', () {
        expect(bridge.isInitialized, isTrue);
        expect(bridge.isMockMode, isFalse);
      });

      test('executes ListArtists across isolate boundary', () async {
        final res = await bridge.executeCommand('ListArtists', {
          'offset': 0,
          'limit': 10,
        });
        expect(res['code'], equals(200));
        final data = res['data'];
        final items = data is Map ? data['items'] : data;
        expect(items, isA<List>());
      });

      test(
        'executes CreateArtist and queries it via ListArtists in native backend',
        () async {
          final createRes = await bridge.executeCommand('CreateArtist', {
            'name': 'Isolate Test Artist',
          });
          expect(createRes['code'], equals(201));
          expect(createRes['data']['name'], equals('Isolate Test Artist'));

          final listRes = await bridge.executeCommand('ListArtists', {
            'search': 'Isolate Test Artist',
          });
          expect(listRes['code'], equals(200));
          final listData = listRes['data'];
          final list = (listData is Map ? listData['items'] : listData) as List;
          expect(list.any((a) => a['name'] == 'Isolate Test Artist'), isTrue);
        },
      );

      test(
        'handles unknown command rejection from native core gracefully',
        () async {
          expect(
            bridge.executeCommand('UnknownCommandThatDoesNotExist'),
            throwsA(isA<LyraBridgeException>()),
          );
        },
      );
    });
  }
}
