// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/core/bridge/lyra_bridge.dart';
import 'package:ui/core/bridge/mock_lyra_bridge.dart';

void main() {
  group('MockLyraBridge', () {
    late MockLyraBridge bridge;

    setUp(() async {
      bridge = MockLyraBridge();
      await bridge.initialize();
    });

    tearDown(() async {
      await bridge.dispose();
    });

    test('operates in mock mode and is initialized', () {
      expect(bridge.isMockMode, isTrue);
      expect(bridge.isInitialized, isTrue);
    });

    test('executes built-in mock commands for works, tracks, albums', () async {
      final worksRes = await bridge.executeCommand('ListWorks');
      expect(worksRes['code'], equals(200));
      expect(worksRes['data']['items'], isNotEmpty);

      final tracksRes = await bridge.executeCommand('ListTracks');
      expect(tracksRes['code'], equals(200));
      expect(tracksRes['data']['items'], isNotEmpty);

      final albumsRes = await bridge.executeCommand('ListAlbums');
      expect(albumsRes['code'], equals(200));
      expect(albumsRes['data']['items'], isNotEmpty);
    });

    test('executes audio device switcher commands', () async {
      final listRes = await bridge.listAudioDevices();
      expect(listRes['code'], equals(200));
      final devices = listRes['data']['devices'] as List;
      expect(devices, isNotEmpty);

      final setRes = await bridge.setAudioOutputDevice('usb-dac-01');
      expect(setRes['code'], equals(200));

      final updatedListRes = await bridge.listAudioDevices();
      expect(updatedListRes['data']['current_device_id'], equals('usb-dac-01'));
    });

    test('supports custom mock handlers and clearing', () async {
      bridge.registerMockHandler(
        'custom.ping',
        (params) async => {
          'code': 200,
          'status': 'pong',
          'echo': params['text'],
        },
      );

      final pingRes = await bridge.executeCommand('custom.ping', {
        'text': 'hello',
      });
      expect(pingRes['status'], equals('pong'));
      expect(pingRes['echo'], equals('hello'));

      bridge.removeMockHandler('custom.ping');
      final fallbackRes = await bridge.executeCommand('custom.ping');
      expect(fallbackRes['status'], equals('success'));
      expect(fallbackRes['echo'], isNull);

      bridge.registerMockHandler(
        'ListWorks',
        (params) async => {'code': 200, 'data': []},
      );
      final emptyRes = await bridge.executeCommand('ListWorks');
      expect(emptyRes['data'], isEmpty);

      bridge.clearMockHandlers();
      final restoredRes = await bridge.executeCommand('ListWorks');
      expect(restoredRes['data']['items'], isNotEmpty);
    });

    test('disposed bridge prevents execution and initialization', () async {
      await bridge.dispose();
      expect(bridge.isInitialized, isFalse);

      expect(
        bridge.executeCommand('ListTracks'),
        throwsA(isA<LyraBridgeException>()),
      );
      expect(bridge.initialize(), throwsA(isA<LyraBridgeException>()));
    });
  });

  group('LyraBridge Singleton & Factory', () {
    tearDown(() {
      LyraBridge.resetInstance();
    });

    test('LyraBridge.instance returns valid bridge instance', () {
      final instance = LyraBridge.instance;
      expect(instance, isNotNull);
      expect(instance.isMockMode, isNotNull);
    });

    test('setInstance and resetInstance update singleton', () {
      final custom = MockLyraBridge();
      LyraBridge.setInstance(custom);
      expect(identical(LyraBridge.instance, custom), isTrue);

      LyraBridge.resetInstance();
      final newInstance = LyraBridge.instance;
      expect(identical(newInstance, custom), isFalse);
    });
  });
}
