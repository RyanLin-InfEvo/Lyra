// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/inspector/asset_inspector_drawer.dart';
import 'package:ui/features/models/audio.dart';
import 'package:ui/features/models/cas_object.dart';
import 'package:ui/features/models/source_data.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/services/music_service.dart';

Widget _buildInspectorTestWidget({
  Track? track,
  Asset? asset,
  Audio? initialAudio,
  SourceData? initialSourceData,
  MusicService? musicService,
  VoidCallback? onClose,
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
                      AssetInspectorDrawer(
                        track: track,
                        asset: asset,
                        initialAudio: initialAudio,
                        initialSourceData: initialSourceData,
                        musicService: musicService,
                        onClose: onClose ?? () {},
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
  const sampleTrack = Track(
    id: 'trk-001',
    title: 'Hotel California (Live on MTV 1994)',
    artistName: 'Eagles',
    albumTitle: 'Hell Freezes Over',
    recordingYear: 1994,
    durationMs: 432000,
    format: 'FLAC',
    sampleRate: 96000,
    bitDepth: 24,
    pcmHash: '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
    verified: true,
  );

  const sampleAudio = Audio(
    pcmHash: '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
    parentHash:
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
    qualityScore: 99,
    bitDepth: 24,
    sampleRate: 96000,
    channels: 2,
    durationMs: 432000.0,
    integratedLoudness: -14.2,
    truePeak: -0.5,
  );

  final sampleSourceData = SourceData(
    id: 'src-001',
    fileHash:
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
    sourceType: 'cd_rip',
    originalPath:
        '/Volumes/MasterAudio/Eagles/HellFreezesOver/01_Hotel_California.flac',
    createdAt: DateTime(2026, 1, 15, 10, 30),
    note:
        'EAC Secure Mode (v1.6), AccurateRip confidence 28/28, Plextor Premium II',
  );

  final sampleAsset = Asset(
    fileHash:
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
    fileSize: 156824912,
    mimeType: 'audio/flac',
    assetType: 'audio',
    createdAt: DateTime(2026, 1, 15, 10, 30),
    verified: true,
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'AssetInspectorDrawer renders empty state when no entity is selected',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildInspectorTestWidget(track: null, asset: null),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Entity Selected'), findsOneWidget);
      expect(find.byIcon(LucideIcons.fileSearch), findsWidgets);
      expect(
        find.text(
          'Select a track or CAS storage object to inspect acoustic specifications and digital notarization records.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('AssetInspectorDrawer renders full acoustic specifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildInspectorTestWidget(
        track: sampleTrack,
        initialAudio: sampleAudio,
        initialSourceData: sampleSourceData,
        asset: sampleAsset,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Drawer Header & Track Banner
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.text('Asset & Notarization'), findsNothing);
    expect(find.text('Hotel California (Live on MTV 1994)'), findsOneWidget);
    expect(find.text('Eagles • Hell Freezes Over'), findsOneWidget);

    // Decorative marketing badge "CAS Verified" must NOT be in header
    expect(find.text('CAS Verified'), findsNothing);

    // 2. Audio Specifications Section
    expect(find.text('Audio Specifications'), findsOneWidget);
    expect(find.text('Acoustic Specifications'), findsNothing);
    expect(find.text('ACOUSTIC SPECIFICATIONS'), findsNothing);

    // Gamified marketing scores must be eliminated
    expect(find.text('Acoustic Fidelity Profile'), findsNothing);
    expect(find.text('99 / 100'), findsNothing);
    expect(find.text('Studio Reference Master'), findsNothing);

    // Real Acoustic Metrics
    expect(find.text('Integrated Loudness'), findsOneWidget);
    expect(find.text('-14.2 LUFS'), findsOneWidget);
    expect(find.text('ITU-R BS.1770'), findsNothing);

    expect(find.text('True Peak'), findsOneWidget);
    expect(find.text('-0.5 dBTP'), findsOneWidget);
    expect(find.text('Linear headroom'), findsNothing);

    expect(find.text('Sample Rate'), findsOneWidget);
    expect(find.text('96 kHz'), findsOneWidget);
    expect(find.text('96 kHz (96000 Hz)'), findsNothing);
    expect(find.text('High-Resolution'), findsNothing);

    expect(find.text('Bit Depth'), findsOneWidget);
    expect(find.text('24-bit PCM'), findsOneWidget);

    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('2.0 Stereo'), findsOneWidget);

    // Decoded PCM Hash
    expect(find.text('PCM Hash'), findsOneWidget);
    expect(find.text('Decoded PCM Stream Hash'), findsNothing);
    expect(find.text('DECODED PCM STREAM HASH (SHA-256)'), findsNothing);
    expect(
      find.text(
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'AssetInspectorDrawer renders digital provenance and notarization notes',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildInspectorTestWidget(
          track: sampleTrack,
          initialAudio: sampleAudio,
          initialSourceData: sampleSourceData,
          asset: sampleAsset,
        ),
      );
      await tester.pumpAndSettle();

      // Section 2: File Storage
      expect(find.text('File Storage'), findsOneWidget);
      expect(find.text('Storage & File Container'), findsNothing);
      expect(find.text('CONTENT ADDRESSABLE STORAGE (CAS)'), findsNothing);
      expect(find.text('File Size'), findsOneWidget);
      expect(find.text('PAYLOAD SIZE'), findsNothing);
      expect(find.text('149.6 MB'), findsOneWidget);
      expect(find.text('${sampleAsset.fileSize} bytes'), findsNothing);
      expect(find.text('MIME Type'), findsOneWidget);
      expect(find.text('Container MIME'), findsNothing);
      expect(find.text('CONTAINER MIME'), findsNothing);
      expect(find.text('audio/flac'), findsOneWidget);
      expect(find.text('Content-Type'), findsNothing);
      expect(find.text('File Hash'), findsOneWidget);
      expect(find.text('Physical File Digest'), findsNothing);
      expect(find.text('PHYSICAL BLOB DIGEST (SHA-256)'), findsNothing);

      // Section 3: Source Information
      expect(find.text('Source Information'), findsOneWidget);
      expect(find.text('Digital Provenance'), findsNothing);
      expect(find.text('DIGITAL PROVENANCE & NOTARIZATION'), findsNothing);
      expect(find.text('Source Type'), findsOneWidget);
      expect(find.text('SOURCE ACQUISITION'), findsNothing);
      expect(find.text('CD-Rip'), findsOneWidget);
      expect(find.text('CD-Rip (Redbook Audio)'), findsNothing);

      expect(find.text('Timestamp'), findsOneWidget);
      expect(find.text('Notarization Timestamp'), findsNothing);
      expect(find.text('NOTARIZATION TIMESTAMP'), findsNothing);
      expect(find.text('2026-01-15 10:30:00 UTC'), findsOneWidget);

      expect(find.text('Original File Path'), findsOneWidget);
      expect(find.text('ORIGINAL FILE PATH'), findsNothing);
      expect(
        find.text(
          '/Volumes/MasterAudio/Eagles/HellFreezesOver/01_Hotel_California.flac',
        ),
        findsOneWidget,
      );

      // Objective Cryptographic Integrity Status (Marketing buzzwords removed)
      expect(find.text('Integrity: Verified'), findsNothing);
      expect(find.text('Checksum Match'), findsNothing);
      expect(find.text('Re-verify'), findsNothing);
      expect(find.text('Cryptographically Notarized'), findsNothing);
      expect(find.text('SHA-256 CAS hash verified bit-perfect'), findsNothing);

      // Curator notes in monospace box
      expect(find.text('Ingestion Note'), findsOneWidget);
      expect(find.text('Curator & Ingestion Log'), findsNothing);
      expect(find.text('CURATOR LINEAGE & NOTES'), findsNothing);
      expect(
        find.text(
          'EAC Secure Mode (v1.6), AccurateRip confidence 28/28, Plextor Premium II',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AssetInspectorDrawer displays em-dash and unanalyzed state when acoustic, asset, and source data are absent',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const emptyTrack = Track(id: 'trk-empty', title: 'Unanalyzed Track');

      await tester.pumpWidget(_buildInspectorTestWidget(track: emptyTrack));
      await tester.pumpAndSettle();

      expect(find.text('Unanalyzed Track'), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);

      // Acoustic data must NOT fabricate fake defaults (-14.0 LUFS or -0.5 dBTP)
      expect(find.text('-14.0 LUFS'), findsNothing);
      expect(find.text('-0.5 dBTP'), findsNothing);
      expect(find.text('44.1 kHz'), findsNothing);
      expect(find.text('16-bit PCM'), findsNothing);
      expect(find.text('Not analyzed'), findsWidgets);

      // Asset data must NOT fabricate fake size or mime (149.6 MB or audio/flac)
      expect(find.text('149.6 MB'), findsNothing);
      expect(find.text('audio/flac'), findsNothing);

      // Provenance data must NOT fabricate fake cd_rip or fake file paths
      expect(find.text('CD-Rip'), findsNothing);
      expect(find.text('/library/audio/Unanalyzed Track.flac'), findsNothing);

      // Physical file is not registered in CAS: displays em-dash and subtitle
      expect(find.text('File Hash'), findsOneWidget);
      expect(find.text('Not registered in CAS'), findsOneWidget);
      expect(find.text('Integrity: Unregistered'), findsNothing);
      expect(find.text('Re-verify'), findsNothing);
    },
  );

  testWidgets(
    'AssetInspectorDrawer displays physical fileHash (not pcmHash) and clean technical metadata without placebo cards',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const customTrack = Track(
        id: 'trk-diff',
        title: 'Different Hashes Track',
        pcmHash: 'pcm-hash-value-1234567890abcdef',
      );
      final customAsset = Asset(
        fileHash: 'file-hash-value-0987654321fedcba',
        fileSize: 123456,
        mimeType: 'audio/flac',
        createdAt: DateTime(2026, 1, 1),
        verified: true,
      );

      await tester.pumpWidget(
        _buildInspectorTestWidget(track: customTrack, asset: customAsset),
      );
      await tester.pumpAndSettle();

      // Must display fileHash in CAS card, NEVER pcmHash as File Hash
      expect(find.text('file-hash-value-0987654321fedcba'), findsOneWidget);
      expect(find.text('File Size'), findsOneWidget);
      expect(find.text('MIME Type'), findsOneWidget);
      expect(find.text('audio/flac'), findsOneWidget);

      // Placebo integrity elements must NOT exist
      expect(find.text('Integrity: Verified'), findsNothing);
      expect(find.text('Checksum Match'), findsNothing);
      expect(find.text('Verification Failed'), findsNothing);
      expect(find.text('Checksum Mismatch'), findsNothing);
      expect(find.text('Re-verify'), findsNothing);
    },
  );

  testWidgets(
    'AssetInspectorDrawer copies hashes and file paths to clipboard',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.setData') {
              log.add(methodCall);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _buildInspectorTestWidget(
          track: sampleTrack,
          initialAudio: sampleAudio,
          initialSourceData: sampleSourceData,
          asset: sampleAsset,
        ),
      );
      await tester.pumpAndSettle();

      // Find copy buttons (LucideIcons.copy)
      final copyIcons = find.byIcon(LucideIcons.copy);
      expect(copyIcons, findsWidgets);

      // Tap first copy button (PCM hash)
      await tester.tap(copyIcons.first);
      await tester.pumpAndSettle();

      expect(log, isNotEmpty);
      expect(log.last.arguments['text'], equals(sampleTrack.pcmHash));
      expect(find.byIcon(LucideIcons.check), findsWidgets);
      expect(find.text('Copied'), findsNothing);
    },
  );

  testWidgets(
    'AssetInspectorDrawer loads audio specifications and provenance data via MusicService',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MockMusicService();

      await tester.pumpWidget(
        _buildInspectorTestWidget(track: sampleTrack, musicService: service),
      );
      await tester.pumpAndSettle();

      // Verify data was fetched asynchronously from MockMusicService
      expect(find.text('Audio Specifications'), findsOneWidget);
      expect(find.text('-14.2 LUFS'), findsOneWidget);
      expect(find.text('CD-Rip'), findsOneWidget);
      expect(
        find.text(
          'EAC Secure Mode (v1.6), AccurateRip confidence 28/28, Plextor Premium II',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AssetInspectorDrawer renders CAS asset mode when only Asset is supplied',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final casObject = CasObject(
        hash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        sizeBytes: 382910400,
        mimeType: 'audio/flac',
        createdAt: DateTime(2026, 1, 16, 14, 20),
        verified: true,
      );

      await tester.pumpWidget(_buildInspectorTestWidget(asset: casObject));
      await tester.pumpAndSettle();

      expect(find.text('Inspector'), findsOneWidget);
      expect(find.text('Asset & Notarization'), findsNothing);
      expect(find.text('CAS Asset'), findsOneWidget);
      expect(find.text('365.2 MB'), findsWidgets);
      expect(find.text('audio/flac'), findsWidgets);
    },
  );

  testWidgets('AssetInspectorDrawer triggers onClose callback', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool closeCalled = false;

    await tester.pumpWidget(
      _buildInspectorTestWidget(
        track: sampleTrack,
        onClose: () => closeCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    final closeBtn = find.byIcon(LucideIcons.x);
    expect(closeBtn, findsOneWidget);

    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    expect(closeCalled, isTrue);
  });

  testWidgets(
    'AssetInspectorDrawer adapts to Light and Dark Mode dynamically',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildInspectorTestWidget(
          track: sampleTrack,
          initialAudio: sampleAudio,
          initialSourceData: sampleSourceData,
          asset: sampleAsset,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Dark Mode check
      final headerElementDark = find
          .byType(AssetInspectorDrawer)
          .evaluate()
          .first;
      final themeDark = ShadTheme.of(headerElementDark);
      expect(themeDark.brightness, equals(Brightness.dark));

      // Switch to Light Mode
      themeNotifier.value = ThemeMode.light;
      await tester.pumpAndSettle();

      // 2. Light Mode check
      final headerElementLight = find
          .byType(AssetInspectorDrawer)
          .evaluate()
          .first;
      final themeLight = ShadTheme.of(headerElementLight);
      expect(themeLight.brightness, equals(Brightness.light));
    },
  );
}
