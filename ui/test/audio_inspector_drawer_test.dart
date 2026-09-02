// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/asset.dart';
import 'package:ui/features/models/audio.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/services/music_service.dart';

Widget _buildAudioInspectorTestWidget({
  Track? track,
  Asset? asset,
  Audio? initialAudio,
  MusicService? musicService,
  VoidCallback? onClose,
  void Function(String newPcmHash)? onActiveAudioChanged,
  ValueNotifier<ThemeMode>? themeNotifier,
  double width = 420.0,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final tokens = isDark
            ? LyraThemeTokens.dark()
            : LyraThemeTokens.light();
        final shadTheme = ShadThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          colorScheme: isDark
              ? const ShadZincColorScheme.dark()
              : const ShadZincColorScheme.light(),
        );

        return ShadTheme(
          data: shadTheme,
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      AudioInspectorDrawer(
                        track: track,
                        asset: asset,
                        initialAudio: initialAudio,
                        musicService: musicService,
                        onClose: onClose ?? () {},
                        onActiveAudioChanged: onActiveAudioChanged,
                        width: width,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'AudioInspectorDrawer renders empty state when no entity is provided',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAudioInspectorTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No Entity Selected'), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
    },
  );

  testWidgets(
    'AudioInspectorDrawer renders audio versions and allows switching active audio',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MockMusicService();
      final tracks = await service.getTracks();
      final track = tracks.firstWhere((t) => t.id == 'trk-001');

      String? switchedHash;

      await tester.pumpWidget(
        _buildAudioInspectorTestWidget(
          track: track,
          musicService: service,
          onActiveAudioChanged: (newHash) {
            switchedHash = newHash;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify Track Metadata
      expect(find.text('Hotel California (Live on MTV 1994)'), findsOneWidget);
      expect(find.text('Eagles • Hell Freezes Over'), findsOneWidget);

      // Verify Audio Versions Section
      expect(find.text('Audio Versions'), findsOneWidget);
      expect(find.text('4 versions'), findsOneWidget);

      // Verify Badges and clean version labels (no duplicate 'Master · ...')
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Master'), findsOneWidget);
      expect(find.text('24-bit/96kHz'), findsOneWidget);
      expect(find.text('FLAC (Lossless) · 24-bit/96kHz'), findsOneWidget);
      expect(find.text('WAV (Lossless) · 16-bit/44.1kHz'), findsOneWidget);
      expect(find.text('FLAC (Lossless) · 24-bit/192kHz'), findsOneWidget);
      expect(find.text('MP3 (Lossy) · 16-bit/44.1kHz'), findsOneWidget);
      expect(
        find.text('Master · FLAC (Lossless) · 24-bit/96kHz'),
        findsNothing,
      );

      // Verify initially inspected version specs (Master: 24-bit/96kHz)
      expect(find.text('96 kHz'), findsWidgets);
      expect(find.text('24-bit PCM'), findsWidgets);

      // "Set as Active Audio" should not be visible while inspecting the active version
      expect(find.text('Set as Active Audio'), findsNothing);

      // Tap the second version (16-bit/44.1kHz CD WAV)
      final cdVersion = find.text('WAV (Lossless) · 16-bit/44.1kHz');
      expect(cdVersion, findsOneWidget);
      await tester.tap(cdVersion);
      await tester.pumpAndSettle();

      // Inspected specs should now update to 44.1 kHz / 16-bit PCM
      expect(find.text('44.1 kHz'), findsWidgets);
      expect(find.text('16-bit PCM'), findsWidgets);

      // "Set as Active Audio" button should now be visible
      final setActiveBtn = find.text('Set as Active Audio');
      expect(setActiveBtn, findsOneWidget);

      // Tap "Set as Active Audio"
      await tester.tap(setActiveBtn);
      await tester.pumpAndSettle();

      // Verify callback fired
      expect(
        switchedHash,
        equals(
          '7f83b16500000000000000000000000000000000000000000000000000004416',
        ),
      );

      // "Set as Active Audio" button should now disappear as it's now active
      expect(find.text('Set as Active Audio'), findsNothing);
    },
  );

  testWidgets('AudioInspectorDrawer adapts to Light and Dark modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = MockMusicService();
    final tracks = await service.getTracks();
    final track = tracks.first;
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

    // Dark mode
    await tester.pumpWidget(
      _buildAudioInspectorTestWidget(
        track: track,
        musicService: service,
        themeNotifier: themeNotifier,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);

    // Switch to Light mode
    themeNotifier.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
  });
}
