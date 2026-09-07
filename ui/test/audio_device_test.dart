// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/core/ffi/lyra_native_bridge.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/audio/controllers/audio_device_controller.dart';
import 'package:ui/features/audio/models/audio_device.dart';
import 'package:ui/features/audio/widgets/audio_device_button.dart';

class FakeAudioBridge implements LyraBridge {
  String currentDeviceId = 'default';
  bool simulateFailure = false;

  final List<Map<String, dynamic>> devices = [
    {
      'id': 'default',
      'name': 'Default System Audio',
      'is_default': true,
      'min_channels': 2,
      'max_channels': 2,
      'min_sample_rate': 44100,
      'max_sample_rate': 48000,
    },
    {
      'id': 'usb-dac-01',
      'name': 'USB Audio DAC (Hi-Res PCM 192kHz)',
      'is_default': false,
      'min_channels': 2,
      'max_channels': 8,
      'min_sample_rate': 44100,
      'max_sample_rate': 192000,
    },
    {
      'id': 'headphones-01',
      'name': 'Headphones (3.5mm)',
      'is_default': false,
      'min_channels': 2,
      'max_channels': 2,
      'min_sample_rate': 44100,
      'max_sample_rate': 96000,
    },
  ];

  @override
  Future<Map<String, dynamic>> listAudioDevices() async {
    return {
      'code': 200,
      'status': 'success',
      'data': {'devices': devices, 'current_device_id': currentDeviceId},
    };
  }

  @override
  Future<Map<String, dynamic>> setAudioOutputDevice(String deviceId) async {
    if (simulateFailure) {
      return {
        'code': 400,
        'status': 'error',
        'message': 'Failed to switch output device',
      };
    }
    currentDeviceId = deviceId;
    return {
      'code': 200,
      'status': 'success',
      'data': {'device_id': deviceId, 'success': true},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildDeviceButtonTest({required AudioDeviceController controller}) {
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final shadTheme = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark(),
  );

  return ShadApp(
    title: 'Lyra Device Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.dark),
        child: Scaffold(
          body: Center(child: AudioDeviceButton(controller: controller)),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioDevice Model', () {
    test('serializes and deserializes correctly', () {
      final map = {
        'id': 'test-dac',
        'name': 'FiiO K9 Pro ESS',
        'is_default': true,
        'min_channels': 2,
        'max_channels': 2,
        'min_sample_rate': 44100,
        'max_sample_rate': 768000,
      };

      final device = AudioDevice.fromJson(map);
      expect(device.id, equals('test-dac'));
      expect(device.name, equals('FiiO K9 Pro ESS'));
      expect(device.isDefault, isTrue);
      expect(device.minChannels, equals(2));
      expect(device.maxChannels, equals(2));
      expect(device.minSampleRate, equals(44100));
      expect(device.maxSampleRate, equals(768000));

      final serialized = device.toJson();
      expect(serialized['id'], equals('test-dac'));
      expect(serialized['name'], equals('FiiO K9 Pro ESS'));
      expect(serialized['is_default'], isTrue);
      expect(serialized['max_sample_rate'], equals(768000));
    });
  });

  group('AudioDeviceController', () {
    test('initializes with default devices and current device', () {
      final fakeBridge = FakeAudioBridge();
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      expect(controller.devices.length, equals(3));
      expect(controller.currentDeviceId, equals('default'));
      expect(controller.currentDevice?.name, equals('Default System Audio'));
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('loads devices from LyraBridge successfully', () async {
      final fakeBridge = FakeAudioBridge();
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      await controller.loadDevices();

      expect(controller.devices.length, equals(3));
      expect(controller.currentDeviceId, equals('default'));
      expect(controller.isLoading, isFalse);
    });

    test('selectDevice updates active device and notifies listeners', () async {
      final fakeBridge = FakeAudioBridge();
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final success = await controller.selectDevice('headphones-01');

      expect(success, isTrue);
      expect(controller.currentDeviceId, equals('headphones-01'));
      expect(controller.currentDevice?.name, equals('Headphones (3.5mm)'));
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('selectDevice rolls back on failure', () async {
      final fakeBridge = FakeAudioBridge()..simulateFailure = true;
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      final success = await controller.selectDevice('headphones-01');

      expect(success, isFalse);
      expect(controller.currentDeviceId, equals('default'));
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('AudioDeviceButton Widget', () {
    testWidgets('renders button with correct icon and tooltip', (tester) async {
      final fakeBridge = FakeAudioBridge();
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(AudioDeviceButton), findsOneWidget);
      expect(find.byIcon(LucideIcons.speaker), findsOneWidget);

      // Tooltip matches current device name
      expect(
        find.byTooltip('Audio Output: Default System Audio'),
        findsOneWidget,
      );
    });

    testWidgets(
      'toggles popover and displays all available devices with checkmark',
      (tester) async {
        final fakeBridge = FakeAudioBridge();
        final controller = AudioDeviceController(
          bridge: fakeBridge,
          autoLoad: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
        await tester.pumpAndSettle();

        // Click device button to open popover
        await tester.tap(find.byType(AudioDeviceButton));
        await tester.pumpAndSettle();

        // Verify popover header and device items
        expect(find.text('Audio Output'), findsOneWidget);
        expect(find.text('Default System Audio'), findsOneWidget);
        expect(find.text('USB Audio DAC (Hi-Res PCM 192kHz)'), findsOneWidget);
        expect(find.text('Headphones (3.5mm)'), findsOneWidget);

        // Verify checkmark is present on the selected default device
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
      },
    );

    testWidgets('switches output device and updates icon to headphones', (
      tester,
    ) async {
      final fakeBridge = FakeAudioBridge();
      final controller = AudioDeviceController(
        bridge: fakeBridge,
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
      await tester.pumpAndSettle();

      // Open popover
      await tester.tap(find.byType(AudioDeviceButton));
      await tester.pumpAndSettle();

      // Tap on headphones device item
      await tester.tap(find.text('Headphones (3.5mm)'));
      await tester.pumpAndSettle();

      // Controller updated
      expect(controller.currentDeviceId, equals('headphones-01'));

      // Main button icon should now be headphones icon
      expect(find.byIcon(LucideIcons.headphones), findsOneWidget);
      expect(
        find.byTooltip('Audio Output: Headphones (3.5mm)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ShadPopover has zero padding, empty shadows, and border-none decoration to avoid outer card wrapper',
      (tester) async {
        final fakeBridge = FakeAudioBridge();
        final controller = AudioDeviceController(
          bridge: fakeBridge,
          autoLoad: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
        await tester.pumpAndSettle();

        final popover = tester.widget<ShadPopover>(find.byType(ShadPopover));
        expect(popover.padding, equals(EdgeInsets.zero));
        expect(popover.shadows, isEmpty);
        expect(popover.decoration?.border, equals(ShadBorder.none));
        expect(popover.decoration?.disableSecondaryBorder, isTrue);
      },
    );

    testWidgets(
      'ShadPopover has floating card anchor configuration shifted leftwards and upwards',
      (tester) async {
        final fakeBridge = FakeAudioBridge();
        final controller = AudioDeviceController(
          bridge: fakeBridge,
          autoLoad: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
        await tester.pumpAndSettle();

        final popover = tester.widget<ShadPopover>(find.byType(ShadPopover));
        expect(popover.anchor, isA<ShadAnchorAuto>());
        final anchor = popover.anchor as ShadAnchorAuto;
        expect(anchor.offset.dx, equals(-8.0));
        expect(anchor.offset.dy, equals(-12.0));
        expect(anchor.followerAnchor, equals(Alignment.bottomLeft));
        expect(anchor.targetAnchor, equals(Alignment.topRight));
      },
    );

    testWidgets(
      'displays floating card popover with refined geometry, layered shadows, and typography',
      (tester) async {
        final fakeBridge = FakeAudioBridge();
        final controller = AudioDeviceController(
          bridge: fakeBridge,
          autoLoad: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildDeviceButtonTest(controller: controller));
        await tester.pumpAndSettle();

        // Tap to open popover
        await tester.tap(find.byType(AudioDeviceButton));
        await tester.pumpAndSettle();

        // Find popover card container by width 312.0
        final cardFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 312.0 &&
              widget.decoration is BoxDecoration,
        );
        expect(cardFinder, findsOneWidget);

        final card = tester.widget<Container>(cardFinder);
        final decoration = card.decoration as BoxDecoration;

        // Generous rounded corners (16px)
        expect(decoration.borderRadius, equals(BorderRadius.circular(16.0)));

        // Layered elevation shadows
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.length, equals(2));
        expect(decoration.boxShadow![0].blurRadius, equals(24.0));
        expect(decoration.boxShadow![0].offset, equals(const Offset(0, 10)));
        expect(decoration.boxShadow![1].blurRadius, equals(8.0));
        expect(decoration.boxShadow![1].offset, equals(const Offset(0, 2)));

        // Title typography (enlarged to 13.5px)
        final titleText = tester.widget<Text>(find.text('Audio Output'));
        expect(titleText.style?.fontSize, equals(13.5));
        expect(titleText.style?.fontWeight, equals(FontWeight.w600));

        // Device name typography (enlarged to 13.5px)
        final deviceText = tester.widget<Text>(
          find.text('Default System Audio'),
        );
        expect(deviceText.style?.fontSize, equals(13.5));

        // Details / spec typography (enlarged to 11.5px)
        final specFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('48kHz') ?? false) &&
              widget.style?.fontSize == 11.5,
        );
        expect(specFinder, findsOneWidget);
      },
    );
  });
}
