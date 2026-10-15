// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_badge.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_copy_button.dart';
import 'package:ui/design_system/widgets/lyra_input.dart';
import 'package:ui/design_system/widgets/lyra_skeleton.dart';
import 'package:ui/design_system/widgets/lyra_spinner.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/asset.dart';
import 'package:ui/features/models/audio.dart';
import 'package:ui/features/models/source_data.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/player/views/components/waveform_scrubber.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/services/music_service.dart';

Widget _buildAudioInspectorTestWidget({
  Track? track,
  Asset? asset,
  Audio? initialAudio,
  MusicService? musicService,
  PlaybackQueueController? playbackController,
  VoidCallback? onClose,
  void Function(String newPcmHash)? onActiveAudioChanged,
  void Function(Track updatedTrack)? onTrackUpdated,
  ValueNotifier<ThemeMode>? themeNotifier,
  double? width,
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
                        playbackController: playbackController,
                        onClose: onClose ?? () {},
                        onActiveAudioChanged: onActiveAudioChanged,
                        onTrackUpdated: onTrackUpdated,
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
      expect(find.text('4 versions'), findsNothing);

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

  testWidgets(
    'AudioInspectorDrawer copy button maintains stable container and text size when clicked',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MockMusicService();
      final tracks = await service.getTracks();
      final track = tracks.firstWhere((t) => t.id == 'trk-001');

      await tester.pumpWidget(
        _buildAudioInspectorTestWidget(track: track, musicService: service),
      );
      await tester.pumpAndSettle();

      final copyButtonFinder = find.byType(LyraCopyButton).first;
      expect(copyButtonFinder, findsOneWidget);

      final rowFinder = find
          .ancestor(of: copyButtonFinder, matching: find.byType(Row))
          .first;

      final initialRowSize = tester.getSize(rowFinder);
      final initialButtonSize = tester.getSize(copyButtonFinder);

      expect(initialButtonSize.width, equals(28.0));
      expect(initialButtonSize.height, equals(28.0));

      final containerFinder = find.descendant(
        of: copyButtonFinder,
        matching: find.byType(AnimatedContainer),
      );
      final visualSize = tester.getSize(containerFinder);
      expect(visualSize.width, equals(24.0));
      expect(visualSize.height, equals(24.0));

      // Tap copy button
      await tester.tap(copyButtonFinder);
      await tester.pump();

      // Verify sizes remain 100% identical during animation and in copied state
      expect(tester.getSize(copyButtonFinder), equals(initialButtonSize));
      expect(tester.getSize(rowFinder), equals(initialRowSize));

      await tester.pumpAndSettle();
      expect(tester.getSize(copyButtonFinder), equals(initialButtonSize));
      expect(tester.getSize(rowFinder), equals(initialRowSize));
    },
  );

  testWidgets(
    'AudioInspectorDrawer adapts width dynamically according to screen constraints',
    (tester) async {
      final drawerFinder = find.byType(AudioInspectorDrawer);

      // 1. Wide desktop (1400px >= 1200px) -> 420px
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAudioInspectorTestWidget());
      await tester.pumpAndSettle();
      expect(tester.getSize(drawerFinder).width, equals(420.0));

      // 2. Compact desktop (1000px < 1200px) -> 1000 * 0.35 = 350px
      tester.view.physicalSize = const Size(1000, 900);
      await tester.pumpWidget(_buildAudioInspectorTestWidget());
      await tester.pumpAndSettle();
      expect(tester.getSize(drawerFinder).width, equals(350.0));

      // 3. Small screen (800px < 1200px) -> clamped to min 320px (800 * 0.35 = 280 -> 320)
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpWidget(_buildAudioInspectorTestWidget());
      await tester.pumpAndSettle();
      expect(tester.getSize(drawerFinder).width, equals(320.0));
    },
  );

  group('Audio Metadata Tag Editor', () {
    testWidgets(
      'AudioInspectorDrawer shows Edit button for track, toggles edit mode, and populates form fields',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // 1. Verify Edit button is visible when inspecting a track
        final editButton = find.widgetWithText(LyraButton, 'Edit');
        expect(editButton, findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);

        // Edit form should NOT be visible initially
        expect(find.text('Edit Metadata'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Save'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Cancel'), findsNothing);

        // 2. Click Edit button
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // 3. Verify Edit mode toggled
        expect(find.text('Edit Metadata'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Save'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Cancel'), findsOneWidget);

        // 4. Verify form fields are pre-populated with current values
        expect(
          find.byKey(const Key('inspector_edit_title_input')),
          findsWidgets,
        );
        expect(
          find.text('Hotel California (Live on MTV 1994)'),
          findsOneWidget,
        );
        expect(find.text('Eagles'), findsOneWidget);
        expect(find.text('Hell Freezes Over'), findsOneWidget);
        expect(find.text('1994'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Classic Rock'), findsOneWidget);
        expect(find.text('T-070.789.012-3'), findsOneWidget);
        expect(find.text('USPR37600010'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer does not show Edit button when inspecting CAS Asset only',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final casObjects = await service.getCasObjects();
        final asset = casObjects.first;

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(asset: asset, musicService: service),
        );
        await tester.pumpAndSettle();

        expect(find.text('CAS Asset'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsNothing);
        expect(find.text('Edit'), findsNothing);
      },
    );

    testWidgets(
      'AudioInspectorDrawer editing fields and clicking Save updates track via service and callback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        Track? updatedCallbackTrack;

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Change Title, Artist, Album, Year, Track Number, ISWC
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Hotel California (2026 Master)',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_artist_input')).first,
          'The Eagles Remastered',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_album_input')).first,
          'Hell Freezes Over (Deluxe Edition)',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_year_input')).first,
          '2026',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_track_number_input')).first,
          '12',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_iswc_input')).first,
          'T-999.888.777-1',
        );
        await tester.pumpAndSettle();

        // Tap Save button to open diff confirmation dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Diff confirmation dialog appeared
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);
        expect(find.text('Confirm Metadata Changes'), findsOneWidget);

        // Tap Confirm & Save in dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // 1. Verify edit mode exited
        expect(find.text('Edit Metadata'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);

        // 2. Verify callback was invoked with updated track data
        expect(updatedCallbackTrack, isNotNull);
        expect(
          updatedCallbackTrack!.title,
          equals('Hotel California (2026 Master)'),
        );
        expect(
          updatedCallbackTrack!.artistName,
          equals('The Eagles Remastered'),
        );
        expect(
          updatedCallbackTrack!.albumTitle,
          equals('Hell Freezes Over (Deluxe Edition)'),
        );
        expect(updatedCallbackTrack!.recordingYear, equals(2026));
        expect(updatedCallbackTrack!.trackNumber, equals(12));
        expect(updatedCallbackTrack!.iswc, equals('T-999.888.777-1'));

        // 3. Verify service was updated
        final updatedInService = (await service.getTracks()).firstWhere(
          (t) => t.id == 'trk-001',
        );
        expect(
          updatedInService.title,
          equals('Hotel California (2026 Master)'),
        );
        expect(updatedInService.artistName, equals('The Eagles Remastered'));
        expect(
          updatedInService.albumTitle,
          equals('Hell Freezes Over (Deluxe Edition)'),
        );
        expect(updatedInService.recordingYear, equals(2026));
        expect(updatedInService.trackNumber, equals(12));
        expect(updatedInService.iswc, equals('T-999.888.777-1'));

        // 4. Verify drawer summary updated to new values
        expect(find.text('Hotel California (2026 Master)'), findsOneWidget);
        expect(
          find.text(
            'The Eagles Remastered • Hell Freezes Over (Deluxe Edition)',
          ),
          findsOneWidget,
        );
        expect(find.text('2026'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer clicking Cancel reverts form changes without updating track',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        Track? updatedCallbackTrack;

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Change text in title input
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Cancelled Title Change',
        );
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel'));
        await tester.pumpAndSettle();

        // 1. Verify edit mode exited
        expect(find.text('Edit Metadata'), findsNothing);

        // 2. Verify callback was NOT called
        expect(updatedCallbackTrack, isNull);

        // 3. Verify original title is retained
        expect(
          find.text('Hotel California (Live on MTV 1994)'),
          findsOneWidget,
        );
        expect(find.text('Cancelled Title Change'), findsNothing);

        // 4. Verify service still has original data
        final inService = (await service.getTracks()).firstWhere(
          (t) => t.id == 'trk-001',
        );
        expect(inService.title, equals('Hotel California (Live on MTV 1994)'));

        // 5. Re-entering edit mode shows original data
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();
        expect(
          find.text('Hotel California (Live on MTV 1994)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AudioInspectorDrawer autocomplete suggests existing artists and allows selection',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Type 'Miles' in Artist field
        final artistInput = find
            .byKey(const Key('inspector_edit_artist_input'))
            .first;
        await tester.enterText(artistInput, 'Miles');
        await tester.pumpAndSettle();

        // Autocomplete option for Miles Davis should be visible in dropdown
        final milesOption = find.text('Miles Davis');
        expect(milesOption, findsWidgets);

        // Tap 'Miles Davis' in dropdown
        await tester.tap(milesOption.first);
        await tester.pumpAndSettle();

        // Verify the input has updated to 'Miles Davis'
        expect(find.widgetWithText(LyraInput, 'Miles Davis'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer autocomplete allows creating custom non-existing artist',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Type custom artist name not in mock database
        final artistInput = find
            .byKey(const Key('inspector_edit_artist_input'))
            .first;
        await tester.enterText(artistInput, 'Radiohead');
        await tester.pumpAndSettle();

        // Dropdown option 'Create "Radiohead"' should appear
        final createOption = find.byKey(
          const Key('autocomplete_option_create_Radiohead'),
        );
        expect(createOption, findsOneWidget);

        // Tap the create option
        await tester.tap(createOption);
        await tester.pumpAndSettle();

        // Verify the input retains 'Radiohead'
        expect(find.widgetWithText(LyraInput, 'Radiohead'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer autocomplete suggests existing albums and allows custom creation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Type 'Kind' in Album field
        final albumInput = find
            .byKey(const Key('inspector_edit_album_input'))
            .first;
        await tester.enterText(albumInput, 'Kind');
        await tester.pumpAndSettle();

        // Verify existing album 'Kind of Blue' is shown
        final kindOption = find.text('Kind of Blue');
        expect(kindOption, findsWidgets);

        // Tap 'Kind of Blue' option
        await tester.tap(kindOption.first);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(LyraInput, 'Kind of Blue'), findsOneWidget);

        // Now enter custom album name
        await tester.enterText(albumInput, 'In Rainbows');
        await tester.pumpAndSettle();

        // Create option appears
        final createAlbumOption = find.byKey(
          const Key('autocomplete_option_create_In Rainbows'),
        );
        expect(createAlbumOption, findsOneWidget);

        await tester.tap(createAlbumOption);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(LyraInput, 'In Rainbows'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer validates ISWC, ISRC, Year, and Track Number fields and prevents saving on error',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Enter invalid values
        await tester.enterText(
          find.byKey(const Key('inspector_edit_iswc_input')).first,
          'invalid-iswc-code',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_isrc_input')).first,
          '12345',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_year_input')).first,
          '3000',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_track_number_input')).first,
          '0',
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pumpAndSettle();

        // 1. Verify diff dialog was NOT opened
        expect(find.byKey(const Key('metadata_diff_dialog')), findsNothing);

        // 2. Verify all 4 validation error messages are displayed
        expect(
          find.byKey(const Key('inspector_edit_iswc_error')),
          findsOneWidget,
        );
        expect(
          find.text('Invalid ISWC format (e.g. T-123.456.789-0)'),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('inspector_edit_isrc_error')),
          findsOneWidget,
        );
        expect(
          find.text('Invalid ISRC format (e.g. US-SM1-59-00001)'),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('inspector_edit_year_error')),
          findsOneWidget,
        );
        expect(find.text('Year must be between 1000 and 2100'), findsOneWidget);

        expect(
          find.byKey(const Key('inspector_edit_track_number_error')),
          findsOneWidget,
        );
        expect(find.text('Track number must be 1 or greater'), findsOneWidget);

        // 3. Fix values to valid standard formats
        await tester.enterText(
          find.byKey(const Key('inspector_edit_iswc_input')).first,
          'T-070.123.456-7',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_isrc_input')).first,
          'US-SM1-59-00001',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_year_input')).first,
          '1994',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_track_number_input')).first,
          '6',
        );
        await tester.pumpAndSettle();

        // 4. Tap Save again
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 5. Diff confirmation dialog opens now that validation passes
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel').last);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'AudioInspectorDrawer diff confirmation dialog shows side-by-side comparisons and dismisses on Cancel',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Modify title
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Hotel California (Acoustic 2026)',
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Diff confirmation dialog
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);
        expect(find.text('ORIGINAL (BEFORE)'), findsOneWidget);
        expect(find.text('MODIFIED (AFTER)'), findsOneWidget);
        expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);
        expect(find.text('Hotel California (Acoustic 2026)'), findsWidgets);

        // Tap Cancel on diff dialog
        await tester.tap(
          find.byKey(const Key('diff_dialog_cancel_button')).first,
        );
        await tester.pumpAndSettle();

        // Verify dialog is closed and still in edit mode
        expect(find.byKey(const Key('metadata_diff_dialog')), findsNothing);
        expect(find.text('Edit Metadata'), findsOneWidget);
        expect(
          find.widgetWithText(LyraInput, 'Hotel California (Acoustic 2026)'),
          findsOneWidget,
        );

        // Verify track in service has NOT changed
        final inService = (await service.getTracks()).firstWhere(
          (t) => t.id == 'trk-001',
        );
        expect(inService.title, equals('Hotel California (Live on MTV 1994)'));
      },
    );

    testWidgets(
      'AudioInspectorDrawer exits edit mode cleanly and displays new track when track changes while editing',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final trackA = tracks.firstWhere((t) => t.id == 'trk-001');
        final trackB = tracks.firstWhere((t) => t.id == 'trk-002');

        // Step 1: Pump widget with Track A
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: trackA, musicService: service),
        );
        await tester.pumpAndSettle();

        // Step 2: Tap "Edit" to enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Metadata'), findsOneWidget);

        // Focus the artist field and enter text
        await tester.tap(
          find.byKey(const Key('inspector_edit_artist_input')).first,
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_artist_input')).first,
          'Eag',
        );
        await tester.pumpAndSettle();

        // Step 3: Pump widget with Track B
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: trackB, musicService: service),
        );
        await tester.pumpAndSettle();

        // Step 4: Verify Track B is displayed and not hanging
        expect(find.text(trackB.displayTitle), findsOneWidget);
        expect(find.text('Edit Metadata'), findsNothing);
      },
    );

    testWidgets(
      'Inspector edit mode is wrapped in AnimatedSize and AnimatedSwitcher with normal duration and easeInOutCubic curve',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // 1. Verify AnimatedSize configuration
        final animatedSizeFinder = find.byKey(
          const Key('inspector_edit_mode_animated_size'),
        );
        expect(animatedSizeFinder, findsOneWidget);
        final animatedSize = tester.widget<AnimatedSize>(animatedSizeFinder);
        expect(animatedSize.duration, equals(LyraAnimation.normal));
        expect(animatedSize.curve, equals(Curves.easeInOutCubic));
        expect(animatedSize.clipBehavior, equals(Clip.hardEdge));
        expect(animatedSize.alignment, equals(Alignment.topCenter));

        // 2. Verify AnimatedSwitcher configuration
        final switcherFinder = find.byKey(
          const Key('inspector_edit_mode_animated_switcher'),
        );
        expect(switcherFinder, findsOneWidget);
        final switcher = tester.widget<AnimatedSwitcher>(switcherFinder);
        expect(switcher.duration, equals(LyraAnimation.normal));
        expect(switcher.switchInCurve, equals(Curves.easeInOutCubic));
        expect(switcher.switchOutCurve, equals(Curves.easeInOutCubic));
      },
    );

    testWidgets(
      'Toggling edit mode initiates smooth in-flight transition with fade and slide without layout breaks',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Initially in summary view
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);
        expect(find.text('Edit Metadata'), findsNothing);

        // Tap Edit to initiate enter transition
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pump();

        // Mid-flight: advance by 100ms (less than 250ms duration)
        await tester.pump(const Duration(milliseconds: 100));

        // Both outgoing summary and incoming form should coexist during cross-fade transition
        expect(
          find.byKey(const Key('inspector_edit_mode_animated_switcher')),
          findsOneWidget,
        );
        expect(find.text('Edit Metadata'), findsOneWidget);
        expect(find.text(track.displayTitle), findsWidgets);

        // Complete animation
        await tester.pumpAndSettle();

        // Settled: only edit form is present
        expect(find.text('Edit Metadata'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Cancel'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Save'), findsOneWidget);

        // Tap Cancel to initiate exit transition
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel'));
        await tester.pump();

        // Mid-flight exit: advance by 100ms
        await tester.pump(const Duration(milliseconds: 100));

        // Verify transition handles reverse smoothly without exceptions
        expect(tester.takeException(), isNull);

        // Complete animation
        await tester.pumpAndSettle();

        // Settled: only summary is present
        expect(find.text('Edit Metadata'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Cancel'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Save'), findsNothing);
      },
    );

    testWidgets(
      'AnimatedSwitcher layoutBuilder uses Clip.none and guards against null currentChild',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Verify live Stack clipBehavior is Clip.none to let parent AnimatedSize govern clipping
        final stackFinder = find.descendant(
          of: find.byKey(const Key('inspector_edit_mode_animated_switcher')),
          matching: find.byType(Stack),
        );
        expect(stackFinder, findsOneWidget);
        final stack = tester.widget<Stack>(stackFinder);
        expect(stack.clipBehavior, equals(Clip.none));

        // Verify layoutBuilder safely supplies non-positioned anchor child when currentChild is null
        final switcher = tester.widget<AnimatedSwitcher>(
          find.byKey(const Key('inspector_edit_mode_animated_switcher')),
        );
        final renderedStack = switcher.layoutBuilder(null, <Widget>[]) as Stack;
        expect(renderedStack.clipBehavior, equals(Clip.none));
        expect(
          renderedStack.children.any((w) => w is SizedBox && w is! Positioned),
          isTrue,
        );
      },
    );

    testWidgets(
      'Clicking Save immediately disables Save button before dialog settles preventing double-click stacking',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Enter new title to create a diff
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Hotel California (Re-entrancy Test)',
        );
        await tester.pumpAndSettle();

        // Tap Save twice in rapid succession (simulating double click before route transitions)
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.tap(
          find.byKey(const Key('inspector_save_button')).first,
          warnIfMissed: false,
        );
        // Pump 1 frame to trigger immediate submission state without settling dialog
        await tester.pump();

        // Save button must be disabled immediately to prevent double-click re-entrancy and display LyraSpinner
        final saveButton = tester.widget<LyraButton>(
          find.byKey(const Key('inspector_save_button')).first,
        );
        expect(saveButton.onPressed, isNull);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Exactly one confirmation dialog must be present
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);
      },
    );

    testWidgets(
      'Navigating to new track while not editing synchronizes controller text',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track1 = tracks.firstWhere((t) => t.id == 'trk-001');
        final track2 = tracks.firstWhere((t) => t.id == 'trk-002');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track1, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode on track1 to inspect controller instance
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        final titleInput = tester.widget<LyraInput>(
          find.byKey(const Key('inspector_edit_title_input')).first,
        );
        final titleController = titleInput.controller!;
        expect(titleController.text, equals(track1.title));

        // Cancel edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel'));
        await tester.pumpAndSettle();

        // Navigate to track2 while not editing
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track2, musicService: service),
        );
        await tester.pump();

        // Controllers must be synchronized to track2
        expect(titleController.text, equals(track2.title));
      },
    );

    testWidgets(
      'Cancelling edit mode unfocuses active input cleanly via FocusScope',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Focus title input field
        final titleEditable = find.byType(EditableText).first;
        await tester.tap(titleEditable);
        await tester.pumpAndSettle();

        expect(
          tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
          isTrue,
        );

        // Tap Cancel
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel'));
        await tester.pump(); // Frame 1 of exit transition

        // Keyboard focus must be released from text input fields immediately
        expect(
          tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
          isFalse,
        );
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNull,
        );
      },
    );

    testWidgets(
      'Saving metadata preserves fresh live track attributes updated during dialog confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final initialTrack = tracks.firstWhere((t) => t.id == 'trk-001');

        Track? savedResultTrack;
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: initialTrack,
            musicService: service,
            onTrackUpdated: (saved) {
              savedResultTrack = saved;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Tap Save to open diff dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        // While dialog is open, track receives fresh attributes (updated non-PCM metadata: duration and recording location)
        final liveTrack = initialTrack.copyWith(
          durationMs: 315000,
          recordingLocation: 'Live Soundstage',
        );
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: liveTrack,
            musicService: service,
            onTrackUpdated: (saved) {
              savedResultTrack = saved;
            },
          ),
        );
        await tester.pump();

        // Confirm save
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // Fresh live track attributes must be preserved rather than overwritten by stale initial snapshot
        expect(savedResultTrack, isNotNull);
        expect(savedResultTrack!.pcmHash, equals(initialTrack.pcmHash));
        expect(savedResultTrack!.durationMs, equals(315000));
        expect(savedResultTrack!.recordingLocation, equals('Live Soundstage'));
      },
    );

    testWidgets(
      'Image asset inspection displays preview surface, dimensions, megapixels, and dominant color swatch',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final imageAsset = Asset(
          fileHash: 'img-hash-001',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: imageAsset,
            musicService: service,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Image Preview Surface is present
        expect(find.byKey(const Key('image_preview_surface')), findsOneWidget);

        // 2. Verify Image Specifications section
        expect(find.text('Image Specifications'), findsOneWidget);
        expect(find.textContaining('3000 × 3000 px'), findsOneWidget);
        expect(find.textContaining('9.0 MP'), findsOneWidget);
        expect(find.text('1:1 (Square)'), findsOneWidget);
        expect(find.text('24-bit RGB'), findsOneWidget);

        // 3. Verify dominant color text and swatch
        expect(find.text('#1E3A8A'), findsOneWidget);
        expect(find.byKey(const Key('dominant_color_swatch')), findsOneWidget);

        // 4. Verify role badge
        expect(find.text('Front Cover'), findsWidgets);
      },
    );

    testWidgets(
      'Image asset inspection suppresses acoustic specifications and waveform scrubber',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final imageAsset = Asset(
          fileHash: 'img-hash-001',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: imageAsset,
            musicService: service,
          ),
        );
        await tester.pumpAndSettle();

        // Acoustic specifications and scrubber must be suppressed
        expect(find.text('Audio Specifications'), findsNothing);
        expect(find.byType(WaveformScrubber), findsNothing);
        expect(find.text('Audio Versions'), findsNothing);

        // General file storage and provenance sections should still be present
        expect(find.text('File Storage'), findsOneWidget);
        expect(find.text('Source Information'), findsOneWidget);
      },
    );

    testWidgets(
      'Lightbox zoom dialog opens with dedicated zoom toolbar and top-right close button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final imageAsset = Asset(
          fileHash: 'img-hash-001',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: imageAsset,
            musicService: service,
          ),
        );
        await tester.pumpAndSettle();

        // Tap the preview surface to open lightbox
        await tester.tap(find.byKey(const Key('image_preview_surface')));
        await tester.pumpAndSettle();

        // 1. Verify lightbox is open
        expect(find.byKey(const Key('image_lightbox_dialog')), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);

        // 2. Old scale toggle removed from header
        expect(find.byKey(const Key('lightbox_scale_toggle')), findsNothing);

        // 3. Top-right close button exists and is symmetrically positioned (8px from top and right of header)
        final closeBtnFinder = find
            .byKey(const Key('lightbox_close_button'))
            .first;
        expect(closeBtnFinder, findsOneWidget);
        final closeBtnRect = tester.getRect(closeBtnFinder);
        final headerContainerFinder = find
            .ancestor(of: closeBtnFinder, matching: find.byType(Container))
            .first;
        final headerRect = tester.getRect(headerContainerFinder);
        expect(headerRect.right - closeBtnRect.right, closeTo(8.0, 0.5));
        expect(closeBtnRect.top - headerRect.top, closeTo(8.0, 0.5));
        expect(closeBtnRect.width, equals(32.0));
        expect(closeBtnRect.height, equals(32.0));

        // 4. Verify dedicated zoom toolbar components exist
        expect(find.byKey(const Key('lightbox_fit_button')), findsWidgets);
        expect(find.byKey(const Key('lightbox_zoom_out')), findsWidgets);
        expect(find.byKey(const Key('lightbox_zoom_slider')), findsOneWidget);
        expect(find.byKey(const Key('lightbox_zoom_in')), findsWidgets);
        expect(
          find.byKey(const Key('lightbox_zoom_percentage_button')),
          findsOneWidget,
        );

        // Initial percentage is 100%
        expect(find.text('100%'), findsOneWidget);

        // 5. Tap zoom-in button increases scale
        await tester.tap(find.byKey(const Key('lightbox_zoom_in')).first);
        await tester.pumpAndSettle();
        expect(find.text('125%'), findsOneWidget);

        // 6. Tap zoom-out button decreases scale
        await tester.tap(find.byKey(const Key('lightbox_zoom_out')).first);
        await tester.pumpAndSettle();
        expect(find.text('100%'), findsOneWidget);

        // 7. Test slider interaction
        final sliderFinder = find.byKey(const Key('lightbox_zoom_slider'));
        expect(sliderFinder, findsOneWidget);
        final sliderWidget = tester.widget<Slider>(sliderFinder);
        expect(sliderWidget.min, equals(0.25));
        expect(sliderWidget.max, equals(8.0));

        // 8. Test percentage selector popup menu
        await tester.tap(
          find.byKey(const Key('lightbox_zoom_percentage_button')),
        );
        await tester.pumpAndSettle();

        // Check preset options in menu
        expect(find.text('Fit'), findsWidgets);
        expect(find.text('25%'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(find.text('100% (1×)'), findsOneWidget);
        expect(find.text('200% (2×)'), findsOneWidget);
        expect(find.text('400% (4×)'), findsOneWidget);
        expect(find.text('800% (8×)'), findsOneWidget);

        // Select 200% (2×)
        await tester.tap(find.text('200% (2×)'));
        await tester.pumpAndSettle();
        expect(find.text('200%'), findsOneWidget);

        // Select 50% from preset menu (scale < 1.0)
        await tester.tap(
          find.byKey(const Key('lightbox_zoom_percentage_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('50%'));
        await tester.pumpAndSettle();
        expect(find.text('50%'), findsOneWidget);
        final iv = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        expect(
          iv.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(0.5, 0.01),
        );

        // Select 25% from preset menu (minimum scale < 1.0)
        await tester.tap(
          find.byKey(const Key('lightbox_zoom_percentage_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('25%'));
        await tester.pumpAndSettle();
        expect(find.text('25%'), findsOneWidget);
        expect(
          iv.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(0.25, 0.01),
        );

        // Test slider moving below 1.0 continuously
        final slider = tester.widget<Slider>(
          find.byKey(const Key('lightbox_zoom_slider')),
        );
        slider.onChanged!(0.75);
        await tester.pump();
        slider.onChanged!(0.60);
        await tester.pump();
        slider.onChanged!(0.40);
        await tester.pumpAndSettle();
        expect(find.text('40%'), findsOneWidget);
        expect(
          iv.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(0.40, 0.01),
        );
        expect(iv.transformationController!.value.storage[12].isFinite, isTrue);
        expect(iv.transformationController!.value.storage[13].isFinite, isTrue);

        // 9. Tap Fit button resets scale
        await tester.tap(find.byKey(const Key('lightbox_fit_button')).first);
        await tester.pumpAndSettle();
        expect(find.text('100%'), findsOneWidget);

        // 10. Close dialog via top-right close button
        await tester.tap(find.byKey(const Key('lightbox_close_button')).first);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('image_lightbox_dialog')), findsNothing);
      },
    );

    testWidgets(
      'Lightbox dialog renders without RenderFlex overflow on narrow viewport',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final imageAsset = Asset(
          fileHash: 'img-hash-001',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: imageAsset,
            musicService: service,
            width: 360,
          ),
        );
        await tester.pumpAndSettle();

        // Tap the preview surface to open lightbox
        await tester.tap(find.byKey(const Key('image_preview_surface')));
        await tester.pumpAndSettle();

        // Verify lightbox is open and no RenderFlex overflow exception occurred
        expect(find.byKey(const Key('image_lightbox_dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify zoom toolbar and close button exist
        expect(find.byKey(const Key('lightbox_fit_button')), findsWidgets);
        expect(find.byKey(const Key('lightbox_close_button')), findsWidgets);

        // Close dialog
        await tester.tap(find.byKey(const Key('lightbox_close_button')).first);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('image_lightbox_dialog')), findsNothing);
      },
    );
  });

  group('Audio Versions Loading Stability and Skeleton Placeholder', () {
    testWidgets(
      'Skeleton placeholder is rendered while loading audio versions, maintaining reserved geometry',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final versionsCompleter = Completer<List<Audio>>();
        final delayedService = _DelayedAudioVersionsMusicService(
          versionsCompleter,
        );
        final tracks = await delayedService.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: delayedService,
          ),
        );
        // Pump one frame while versions fetch is pending in background
        await tester.pump();

        // 1. Verify skeleton placeholder is rendered
        final skeletonFinder = find.byKey(const Key('audio_versions_skeleton'));
        final skeletonCardFinder = find.byKey(
          const Key('audio_version_card_skeleton'),
        );
        expect(skeletonFinder, findsOneWidget);
        expect(skeletonCardFinder, findsWidgets);
        expect(find.byType(LyraSkeleton), findsWidgets);

        // 2. Verify skeleton card reserves ~48px height
        final skeletonCardSize = tester.getSize(skeletonCardFinder.first);
        expect(skeletonCardSize.height, equals(48.0));

        // 3. Verify downstream section ("Audio Specifications") is positioned below skeleton
        final specFinder = find.text('Audio Specifications');
        expect(specFinder, findsOneWidget);
        final specTop = tester.getTopLeft(specFinder).dy;
        final skeletonTop = tester.getTopLeft(skeletonFinder).dy;
        expect(specTop, greaterThan(skeletonTop + 48.0));

        // 4. Complete versions future and settle
        final versions = [
          Audio(
            pcmHash: track.pcmHash,
            parentHash: '',
            qualityScore: 99,
            bitDepth: 24,
            sampleRate: 96000,
            channels: 2,
            durationMs: 432000.0,
            assets: [
              Asset(
                fileHash: 'file-001',
                mimeType: 'audio/flac',
                assetType: 'audio',
                fileSize: 10000000,
                createdAt: DateTime(2026, 1, 1),
                verified: true,
              ),
            ],
          ),
        ];
        versionsCompleter.complete(versions);
        await tester.pump();
        await tester.pumpAndSettle();

        // 5. Verify resolved audio versions replaces the skeleton seamlessly
        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(find.byKey(const Key('audio_versions_section')), findsOneWidget);
        expect(find.text('Audio Versions'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Master'), findsOneWidget);
      },
    );

    testWidgets(
      'Pure image asset does not display audio version skeleton or version section while loading or settled',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final versionsCompleter = Completer<List<Audio>>();
        final delayedService = _DelayedAudioVersionsMusicService(
          versionsCompleter,
        );
        final imageAsset = Asset(
          fileHash: 'img-hash-001',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: imageAsset,
            musicService: delayedService,
          ),
        );
        // Pump frame during loading
        await tester.pump();

        // Skeleton must NOT appear for image asset
        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(
          find.byKey(const Key('audio_version_card_skeleton')),
          findsNothing,
        );
        expect(find.text('Audio Versions'), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(find.byKey(const Key('audio_versions_section')), findsNothing);
        expect(find.text('Audio Versions'), findsNothing);
      },
    );

    testWidgets(
      'Non-audio non-image asset does not display audio version skeleton',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final textAsset = Asset(
          fileHash: 'txt-hash-001',
          mimeType: 'text/plain',
          fileSize: 1024,
          createdAt: DateTime(2026, 1, 15, 10, 30),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            asset: textAsset,
            musicService: service,
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(
          find.byKey(const Key('audio_version_card_skeleton')),
          findsNothing,
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(find.byKey(const Key('audio_versions_section')), findsNothing);
        expect(find.text('Audio Versions'), findsNothing);
      },
    );

    testWidgets(
      'Audio versions section is wrapped in AnimatedSize with fast duration and easeInOutCubic curve',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        final animatedSizeFinder = find.byKey(
          const Key('audio_versions_animated_size'),
        );
        expect(animatedSizeFinder, findsOneWidget);
        final animatedSize = tester.widget<AnimatedSize>(animatedSizeFinder);
        expect(animatedSize.duration, equals(LyraAnimation.fast));
        expect(animatedSize.curve, equals(Curves.easeInOutCubic));
      },
    );

    testWidgets(
      'State caching retains audio versions without clearing when track updates without changing ID',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audio Versions'), findsOneWidget);
        expect(find.byKey(const Key('audio_versions_section')), findsOneWidget);

        // Update track metadata (same ID)
        final updatedTrack = track.copyWith(
          title: 'Hotel California (Updated Title)',
        );
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: updatedTrack,
            musicService: service,
          ),
        );
        await tester.pump();

        // Versions should remain without flashing back to skeleton
        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(find.byKey(const Key('audio_versions_section')), findsOneWidget);
        expect(find.text('Audio Versions'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioInspectorDrawer._saveEditing() aborts save when track changes while confirmation dialog is pending',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track1 = tracks.firstWhere((t) => t.id == 'trk-001');
        final track2 = tracks.firstWhere((t) => t.id == 'trk-002');

        Track? updatedCallbackTrack;

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track1,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Modify title
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Mutated Title From Track 1',
        );
        await tester.pumpAndSettle();

        // Click Save -> Dialog opens
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Confirm Metadata Changes'), findsOneWidget);

        // While dialog is open, the parent changes track to track2
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track2,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pump();

        // Now confirm the dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // Since track changed during dialog, _saveEditing must abort:
        expect(updatedCallbackTrack, isNull);
        final track2InService = (await service.getTracks()).firstWhere(
          (t) => t.id == 'trk-002',
        );
        expect(
          track2InService.title,
          isNot(equals('Mutated Title From Track 1')),
        );
      },
    );

    testWidgets(
      'AudioInspectorDrawer._selectVersion() ignores stale in-flight results when newer version is selected',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final v1Completer = Completer<SourceData?>();
        final v2Completer = Completer<SourceData?>();

        final v1 = Audio(
          pcmHash: 'pcm-v1',
          parentHash: '',
          qualityScore: 90,
          bitDepth: 24,
          sampleRate: 96000,
          channels: 2,
          durationMs: 200000.0,
          assets: [
            Asset(
              fileHash: 'file-v1',
              mimeType: 'audio/flac',
              fileSize: 1000,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        );

        final v2 = Audio(
          pcmHash: 'pcm-v2',
          parentHash: 'pcm-v1',
          qualityScore: 80,
          bitDepth: 16,
          sampleRate: 44100,
          channels: 2,
          durationMs: 200000.0,
          assets: [
            Asset(
              fileHash: 'file-v2',
              mimeType: 'audio/mp3',
              fileSize: 500,
              createdAt: DateTime(2026, 1, 2),
            ),
          ],
        );

        final service = _ControllableVersionMusicService([v1, v2]);
        service.sourceCompleters['file-v1'] = v1Completer;
        service.sourceCompleters['file-v2'] = v2Completer;

        final track = Track(
          id: 'trk-versions-race',
          pcmHash: 'pcm-v1',
          title: 'Race Test',
          artistName: 'Test Artist',
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        // Initial load resolves v1 as active, wait for microtask then AnimatedSize to settle
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Now select v2
        final v2Finder = find.textContaining(v2.shortPcmHash);
        expect(v2Finder, findsOneWidget);
        await tester.ensureVisible(v2Finder);
        await tester.tap(v2Finder);
        await tester.pump();

        // Complete v2 source data first
        v2Completer.complete(
          SourceData(
            id: 'sd-v2',
            fileHash: 'file-v2',
            sourceType: 'digital_download',
            originalPath: '/music/v2.mp3',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Digital Download'), findsOneWidget);

        // Now complete the stale v1 source data with CD-Rip
        v1Completer.complete(
          SourceData(
            id: 'sd-v1',
            fileHash: 'file-v1',
            sourceType: 'cd_rip',
            originalPath: '/music/v1.flac',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await tester.pumpAndSettle();

        // Verify stale v1 result did NOT overwrite v2's source data
        expect(find.text('Digital Download'), findsOneWidget);
        expect(find.text('CD-Rip'), findsNothing);
      },
    );

    testWidgets(
      'AudioInspectorDrawer._selectVersion() ignores stale results when track entity changes in-flight',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final v2Completer = Completer<SourceData?>();

        final v1 = Audio(
          pcmHash: 'pcm-v1',
          parentHash: '',
          qualityScore: 90,
          bitDepth: 24,
          sampleRate: 96000,
          channels: 2,
          durationMs: 200000.0,
          assets: [
            Asset(
              fileHash: 'file-v1',
              mimeType: 'audio/flac',
              fileSize: 1000,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        );

        final v2 = Audio(
          pcmHash: 'pcm-v2',
          parentHash: 'pcm-v1',
          qualityScore: 80,
          bitDepth: 16,
          sampleRate: 44100,
          channels: 2,
          durationMs: 200000.0,
          assets: [
            Asset(
              fileHash: 'file-v2',
              mimeType: 'audio/mp3',
              fileSize: 500,
              createdAt: DateTime(2026, 1, 2),
            ),
          ],
        );

        final service = _ControllableVersionMusicService([v1, v2]);
        service.sourceCompleters['file-v2'] = v2Completer;

        final track1 = Track(
          id: 'trk-race-1',
          pcmHash: 'pcm-v1',
          title: 'Track 1',
          artistName: 'Artist 1',
        );

        final track2 = Track(
          id: 'trk-race-2',
          pcmHash: 'pcm-other',
          title: 'Track 2',
          artistName: 'Artist 2',
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track1, musicService: service),
        );
        await tester.pumpAndSettle();

        // Tap v2 to start _selectVersion
        await tester.tap(find.textContaining(v2.shortPcmHash));
        await tester.pump();

        // While v2 is in flight, parent switches to track2
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track2, musicService: service),
        );
        await tester.pumpAndSettle();

        // Now v2 completes
        v2Completer.complete(
          SourceData(
            id: 'sd-v2-race',
            fileHash: 'file-v2',
            sourceType: 'vinyl_rip',
            originalPath: '/music/v2.mp3',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await tester.pumpAndSettle();

        // Since track changed to track2, v2's source data must NOT be shown
        expect(find.text('Vinyl Rip'), findsNothing);
      },
    );

    testWidgets(
      'Selecting derived audio version without assets queries parent audio details instead of querying CAS asset with PCM hash',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final queriedAssetHashes = <String>[];
        final queriedAudioDetailsHashes = <String>[];

        const masterPcmHash = 'pcm-master-001';
        const derivedPcmHash = 'pcm-derived-002';
        const masterFileHash = 'file-master-real-cas-hash';

        final masterAudio = Audio(
          pcmHash: masterPcmHash,
          parentHash: '',
          qualityScore: 95,
          bitDepth: 24,
          sampleRate: 96000,
          channels: 2,
          durationMs: 240000.0,
          assets: [
            Asset(
              fileHash: masterFileHash,
              mimeType: 'audio/flac',
              assetType: 'audio',
              fileSize: 20000000,
              createdAt: DateTime(2026, 1, 1),
              verified: true,
            ),
          ],
        );

        final derivedAudio = Audio(
          pcmHash: derivedPcmHash,
          parentHash: masterPcmHash,
          qualityScore: 85,
          bitDepth: 16,
          sampleRate: 44100,
          channels: 2,
          durationMs: 240000.0,
          assets: [], // Empty assets, points to parentHash
        );

        final testService = _DomainTopologyMockMusicService(
          versions: [masterAudio, derivedAudio],
          onGetAsset: (hash) => queriedAssetHashes.add(hash),
          onGetAudioDetails: (hash) => queriedAudioDetailsHashes.add(hash),
          masterAudio: masterAudio,
        );

        final track = Track(
          id: 'trk-topo-001',
          pcmHash: masterPcmHash,
          title: 'Topology Test Track',
          artistName: 'Test Artist',
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: testService,
          ),
        );
        await tester.pumpAndSettle();

        // Tap on derived version card
        final derivedCard = find.textContaining(derivedAudio.shortPcmHash);
        expect(derivedCard, findsOneWidget);
        await tester.tap(derivedCard);
        await tester.pumpAndSettle();

        // CRITICAL DOMAIN TOPOLOGY ASSERTION:
        // 1. parentHash (pcm-master-001) MUST NOT be queried as a fileHash in getAsset!
        expect(queriedAssetHashes, isNot(contains(masterPcmHash)));
        // 2. parentHash MUST be passed to getAudioDetails to resolve the parent's audio entity
        expect(queriedAudioDetailsHashes, contains(masterPcmHash));
        // 3. The parent's real fileHash (file-master-real-cas-hash) MUST be queried in getAsset
        expect(queriedAssetHashes, contains(masterFileHash));
      },
    );

    testWidgets(
      'Track with empty pcmHash does not show audio versions skeleton while loading',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableVersionMusicService([]);
        final pendingSourceCompleter = Completer<SourceData?>();
        service.sourceCompleters['file-load-pending'] = pendingSourceCompleter;

        final trackNoPcm = Track(
          id: 'trk-no-pcm',
          pcmHash: '',
          title: 'No Audio Entity Track',
          artistName: 'Draft Artist',
        );

        final pendingAsset = Asset(
          fileHash: 'file-load-pending',
          mimeType: 'audio/flac',
          fileSize: 1000,
          createdAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: trackNoPcm,
            asset: pendingAsset,
            musicService: service,
          ),
        );
        await tester.pump();

        // Skeleton MUST NOT be shown because track has empty pcmHash
        expect(find.byKey(const Key('audio_versions_skeleton')), findsNothing);
        expect(
          find.byKey(const Key('audio_version_card_skeleton')),
          findsNothing,
        );
      },
    );

    testWidgets('Digital provenance formats timestamp converted to UTC', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final localTime = DateTime(2026, 1, 15, 10, 30);
      final utcExpected =
          '${localTime.toUtc().toIso8601String().replaceAll('T', ' ').substring(0, 19)} UTC';

      final asset = Asset(
        fileHash: 'test-hash-utc',
        mimeType: 'audio/flac',
        fileSize: 1024,
        createdAt: localTime,
      );

      await tester.pumpWidget(_buildAudioInspectorTestWidget(asset: asset));
      await tester.pumpAndSettle();

      expect(find.text(utcExpected), findsOneWidget);
    });

    testWidgets(
      'Master version secondary badge uses secondaryForeground token for WCAG contrast',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        final masterTextFinder = find.descendant(
          of: find.byType(LyraBadge),
          matching: find.text('Master'),
        );
        expect(masterTextFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(masterTextFinder);
        final tokens = LyraThemeTokens.dark();
        expect(textWidget.style?.color, equals(tokens.secondaryForeground));
        expect(textWidget.style?.color, isNot(equals(tokens.textMuted)));
      },
    );

    testWidgets(
      'LyraSpinner is rendered during Save and Version Switch loading states',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.updateTrackCompleter = Completer<Track>();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // 1. Verify LyraSpinner during Save button loading
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Verify Save button has no checkmark icon in idle state
        final saveButtonFinder = find.byKey(const Key('inspector_save_button'));
        final idleSaveBtn = tester.widget<LyraButton>(saveButtonFinder.first);
        expect(idleSaveBtn.leading, isNull);
        expect(
          find.descendant(
            of: saveButtonFinder,
            matching: find.byIcon(LucideIcons.check),
          ),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Title Diff for Spinner Test',
        );
        await tester.pumpAndSettle();

        // Tap Save button -> opens confirmation dialog
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        // Verify "Confirm & Save" dialog button has no checkmark icon
        final confirmBtnFinder = find.widgetWithText(
          LyraButton,
          'Confirm & Save',
        );
        final confirmBtn = tester.widget<LyraButton>(confirmBtnFinder);
        expect(confirmBtn.leading, isNull);
        expect(
          find.descendant(
            of: confirmBtnFinder,
            matching: find.byIcon(LucideIcons.check),
          ),
          findsNothing,
        );

        // Tap Confirm & Save in dialog
        await tester.tap(confirmBtnFinder);
        // Dialog pops; updateTrack is now in flight
        await tester.pump();

        final saveSpinnerFinder = find.descendant(
          of: find.byKey(const Key('inspector_save_button')),
          matching: find.byType(LyraSpinner),
        );
        expect(saveSpinnerFinder, findsOneWidget);
        expect(find.text('Saving...'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('inspector_save_button')),
            matching: find.byIcon(LucideIcons.check),
          ),
          findsNothing,
        );

        // Complete save
        service.updateTrackCompleter!.complete(
          track.copyWith(title: 'Title Diff for Spinner Test'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LyraSpinner), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);

        // 2. Verify LyraSpinner during Version Switch button loading
        final cdVersion = find.text('WAV (Lossless) · 16-bit/44.1kHz');
        await tester.tap(cdVersion);
        await tester.pumpAndSettle();

        final setActiveBtn = find.text('Set as Active Audio');
        expect(setActiveBtn, findsOneWidget);

        // Verify "Set as Active Audio" button has no checkmark icon when idle
        final setActiveBtnFinder = find.widgetWithText(
          LyraButton,
          'Set as Active Audio',
        );
        final setActiveWidget = tester.widget<LyraButton>(setActiveBtnFinder);
        expect(setActiveWidget.leading, isNull);
        expect(
          find.descendant(
            of: setActiveBtnFinder,
            matching: find.byIcon(LucideIcons.check),
          ),
          findsNothing,
        );

        service.switchAudioCompleter = Completer<void>();

        await tester.tap(setActiveBtn);
        await tester.pump(); // Enter _isSwitchingActive state

        final switchSpinnerFinder = find.descendant(
          of: find.widgetWithText(LyraButton, 'Switching Audio...'),
          matching: find.byType(LyraSpinner),
        );
        expect(switchSpinnerFinder, findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(LyraButton, 'Switching Audio...'),
            matching: find.byIcon(LucideIcons.check),
          ),
          findsNothing,
        );

        service.switchAudioCompleter!.complete();
        await tester.pumpAndSettle();

        expect(find.byType(LyraSpinner), findsNothing);
        expect(find.text('Set as Active Audio'), findsNothing);
      },
    );

    testWidgets(
      'Anti-false-positive: Save failure retains edit mode and form input without calling onTrackUpdated',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.failUpdateTrack = true;
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        bool onTrackUpdatedCalled = false;
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: service,
            onTrackUpdated: (_) {
              onTrackUpdatedCalled = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Change title
        final titleField = find
            .byKey(const Key('inspector_edit_title_input'))
            .first;
        await tester.enterText(titleField, 'Failed Title Save Attempt');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm save dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // Must NOT pretend update succeeded:
        expect(onTrackUpdatedCalled, isFalse);
        // Form must remain open in edit mode so user input is not lost
        expect(
          find.byKey(const Key('inspector_edit_title_input')).first,
          findsOneWidget,
        );
        expect(find.text('Failed Title Save Attempt'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsNothing);
        // Loading state must be reset
        expect(find.widgetWithText(LyraButton, 'Saving...'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Save'), findsOneWidget);
      },
    );

    testWidgets(
      'Save loading state resets in finally even if onTrackUpdated throws',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: service,
            onTrackUpdated: (_) {
              throw Exception('Callback failure during track update');
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Callback Throw Title',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // Loading spinner must not be stuck; _isSaving must be false
        expect(find.widgetWithText(LyraButton, 'Saving...'), findsNothing);
      },
    );

    testWidgets(
      'Audio Specifications section header spinner uses textMuted token for contrast while loading',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _DelayedAudioVersionsMusicService(
          Completer<List<Audio>>(),
        );
        final track = Track(
          id: 'trk-001',
          pcmHash: 'pcm-loading-001',
          title: 'Section Spinner Contrast Track',
        );

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pump(); // Start loading, do not settle

        final headerSpinnerFinder = find.descendant(
          of: find.byType(AudioInspectorDrawer),
          matching: find.byType(LyraSpinner),
        );
        expect(headerSpinnerFinder, findsOneWidget);

        final spinner = tester.widget<LyraSpinner>(headerSpinnerFinder);
        final tokens = LyraThemeTokens.dark();
        expect(spinner.color, equals(tokens.textMuted));
      },
    );

    testWidgets(
      'Saving metadata cleanly unfocuses active text input via FocusScope.of(context).unfocus()',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Focus title input field (managed by generic FocusScope, not artist/album focus nodes)
        final titleEditable = find.byType(EditableText).first;
        await tester.tap(titleEditable);
        await tester.pumpAndSettle();

        expect(
          tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
          isTrue,
        );

        // Tap Save
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm save
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pump();

        // Focus must be completely unfocused from text fields
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNull,
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Switching active audio prevents re-entrant invocation when already in flight',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.switchAudioCompleter = Completer<void>();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Select non-active version
        final cdVersion = find.text('WAV (Lossless) · 16-bit/44.1kHz');
        await tester.tap(cdVersion);
        await tester.pumpAndSettle();

        final setActiveBtnFinder = find.widgetWithText(
          LyraButton,
          'Set as Active Audio',
        );
        expect(setActiveBtnFinder, findsOneWidget);

        final btnWidget = tester.widget<LyraButton>(setActiveBtnFinder);
        expect(btnWidget.onPressed, isNotNull);

        // First click triggers switch
        btnWidget.onPressed!();
        // Immediate second click (before rebuild or during async operation)
        btnWidget.onPressed!();

        // Must be guarded: switchTrackAudio must only be invoked once
        expect(service.switchAudioCallCount, equals(1));

        service.switchAudioCompleter!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Rapid double clicking Confirm & Save in _MetadataDiffDialog guards against double popping underlying route',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        final navKey = GlobalKey<NavigatorState>();
        final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
        await tester.pumpWidget(
          ShadApp(
            navigatorKey: navKey,
            theme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
            ),
            home: LyraDesignSystemScope(
              factory: const ShadcnFactory(),
              tokens: LyraThemeTokens.dark(),
              themeModeNotifier: themeNotifier,
              child: const Scaffold(body: Text('Base Root Route')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push inspector route onto navigator
        navKey.currentState!.push(
          MaterialPageRoute(
            builder: (ctx) => LyraDesignSystemScope(
              factory: const ShadcnFactory(),
              tokens: LyraThemeTokens.dark(),
              themeModeNotifier: themeNotifier,
              child: Scaffold(
                body: AudioInspectorDrawer(
                  track: track,
                  musicService: service,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioInspectorDrawer), findsOneWidget);

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Change title
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'New Title For Double Pop',
        );
        await tester.pumpAndSettle();

        // Click Save -> diff dialog opens
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        final confirmFinder = find.widgetWithText(LyraButton, 'Confirm & Save');
        final confirmBtn = tester.widget<LyraButton>(confirmFinder);
        expect(confirmBtn.onPressed, isNotNull);

        // Simulate rapid double tap: two invocations of onPressed before the route animation finishes
        confirmBtn.onPressed!();
        confirmBtn.onPressed!();
        await tester.pumpAndSettle();

        // The inspector drawer must NOT have been popped off the navigator
        expect(find.byType(AudioInspectorDrawer), findsOneWidget);
        expect(find.text('Base Root Route'), findsNothing);
      },
    );

    testWidgets(
      'Audio version selection is disabled while switching active audio (_isSwitchingActive is true)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.switchAudioCompleter = Completer<void>();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Find another version to inspect first
        final cdVersion = find.text('WAV (Lossless) · 16-bit/44.1kHz');
        await tester.tap(cdVersion);
        await tester.pumpAndSettle();

        // Trigger switch active audio
        final setActiveBtn = find.widgetWithText(
          LyraButton,
          'Set as Active Audio',
        );
        await tester.tap(setActiveBtn);
        await tester.pump(); // Start switch, _isSwitchingActive is now true

        // Verify version items in audio_versions_section have onTap == null
        final gestures = tester.widgetList<GestureDetector>(
          find.descendant(
            of: find.byKey(const Key('audio_versions_section')),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(gestures, isNotEmpty);
        for (final gesture in gestures) {
          expect(gesture.onTap, isNull);
        }

        service.switchAudioCompleter!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Validates that title is not empty and displays validation error preventing save',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Clear title field (set to whitespace)
        final titleInput = find
            .byKey(const Key('inspector_edit_title_input'))
            .first;
        await tester.enterText(titleInput, '   ');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pumpAndSettle();

        // Dialog must NOT appear
        expect(find.byKey(const Key('metadata_diff_dialog')), findsNothing);

        // Validation error must appear
        expect(
          find.byKey(const Key('inspector_edit_title_error')),
          findsOneWidget,
        );
        expect(find.text('Title cannot be empty'), findsOneWidget);
      },
    );

    testWidgets(
      'Normalizes empty or whitespace metadata strings to null in updated track',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        Track? savedTrack;
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: track,
            musicService: service,
            onTrackUpdated: (updated) {
              savedTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Clear artist and album fields to empty / whitespace
        await tester.enterText(
          find.byKey(const Key('inspector_edit_artist_input')).first,
          '   ',
        );
        await tester.enterText(
          find.byKey(const Key('inspector_edit_album_input')).first,
          '',
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm save
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        expect(savedTrack, isNotNull);
        expect(savedTrack!.artistName, isNull);
        expect(savedTrack!.albumTitle, isNull);
      },
    );

    testWidgets(
      'Displays error banner in edit form when save fails instead of silent failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.failUpdateTrack = true;
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Modify title
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Title To Cause Error',
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm in dialog
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pumpAndSettle();

        // Error banner must be visible
        expect(
          find.byKey(const Key('inspector_save_error_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Database update failed'), findsOneWidget);
      },
    );

    testWidgets(
      'Save button displays LyraSpinner and Saving... for a perceptible feedback duration when saving with standard MockMusicService',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.firstWhere((t) => t.id == 'trk-001');

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // 1. Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // 2. Modify title to generate metadata diff
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Perceptible Duration Title',
        );
        await tester.pumpAndSettle();

        // 3. Click Save button -> opens confirmation dialog
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        // 4. Confirm in dialog
        final confirmBtnFinder = find.widgetWithText(
          LyraButton,
          'Confirm & Save',
        );
        await tester.tap(confirmBtnFinder);
        // Pump 1 frame for dialog pop & initiating save
        await tester.pump();

        final saveSpinnerFinder = find.descendant(
          of: find.byKey(const Key('inspector_save_button')),
          matching: find.byType(LyraSpinner),
        );

        // Spinner and "Saving..." must be visible during the minimum perceptible duration
        expect(saveSpinnerFinder, findsOneWidget);
        expect(find.text('Saving...'), findsOneWidget);

        // Advance 200ms (within the 350ms perceptible feedback period)
        await tester.pump(const Duration(milliseconds: 200));

        // Spinner and "Saving..." must still be visible and edit form still active
        expect(saveSpinnerFinder, findsOneWidget);
        expect(find.text('Saving...'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsNothing);

        // Advance another 200ms (400ms total, exceeding the 350ms duration) and settle
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // After the perceptible period elapses, save finishes and edit mode exits
        expect(find.byType(LyraSpinner), findsNothing);
        expect(find.text('Saving...'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);
        expect(find.text('Perceptible Duration Title'), findsWidgets);
      },
    );

    testWidgets(
      'When saving Track A fails while in-flight and inspected track changes to Track B before failure completes, Track B does not display save error banner',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.updateTrackCompleter = Completer<Track>();
        final tracks = await service.getTracks();
        final trackA = tracks.firstWhere((t) => t.id == 'trk-001');
        final trackB = tracks.firstWhere((t) => t.id == 'trk-002');

        // 1. Render inspector with Track A
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: trackA, musicService: service),
        );
        await tester.pumpAndSettle();

        // 2. Enter edit mode on Track A
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // 3. Modify title on Track A
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Track A Pending Title',
        );
        await tester.pumpAndSettle();

        // 4. Click Save button -> opens confirmation dialog
        await tester.tap(find.byKey(const Key('inspector_save_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 5. Confirm in dialog -> initiates updateTrack (waiting on updateTrackCompleter)
        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pump();

        // Verify save is in flight for Track A
        expect(find.text('Saving...'), findsOneWidget);

        // 6. While save is in flight, the user switches inspection to Track B
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: trackB, musicService: service),
        );
        await tester.pumpAndSettle();

        // Enter edit mode on Track B
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // 7. Now Track A's async save operation completes with an error
        service.updateTrackCompleter!.completeError(
          Exception('Database write failed for Track A'),
        );
        await tester.pumpAndSettle();

        // 8. Verify Track B does NOT display Track A's save error banner
        expect(
          find.byKey(const Key('inspector_save_error_banner')),
          findsNothing,
        );
        expect(
          find.textContaining('Database write failed for Track A'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'When switching active audio on Track A is in-flight and inspected track changes to Track B before switch completes, Track B is not overwritten and onActiveAudioChanged is not invoked',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.switchAudioCompleter = Completer<void>();
        final tracks = await service.getTracks();
        final trackA = tracks.firstWhere((t) => t.id == 'trk-001');
        final trackB = tracks.firstWhere((t) => t.id == 'trk-002');

        final trackBVersion2 = Audio(
          pcmHash:
              'e3b0c44200000000000000000000000000000000000000000000000000009624',
          parentHash: trackB.pcmHash,
          qualityScore: 95,
          bitDepth: 24,
          sampleRate: 96000,
          channels: 2,
          durationMs: 562000.0,
          integratedLoudness: -19.0,
          truePeak: -1.0,
          assets: [
            Asset(
              fileHash: 'track-b-v2-file',
              mimeType: 'audio/flac',
              assetType: 'audio',
              fileSize: 190000000,
              createdAt: DateTime(2026, 1, 16, 14, 20),
              verified: true,
            ),
          ],
        );

        final masterB = Audio(
          pcmHash: trackB.pcmHash,
          parentHash: '',
          qualityScore: 98,
          bitDepth: 24,
          sampleRate: 192000,
          channels: 2,
          durationMs: 562000.0,
          integratedLoudness: -18.5,
          truePeak: -1.2,
          assets: [
            Asset(
              fileHash: trackB.pcmHash,
              mimeType: 'audio/flac',
              assetType: 'audio',
              fileSize: 382910400,
              createdAt: DateTime(2026, 1, 16, 14, 20),
              verified: true,
            ),
          ],
        );

        service.customAudioVersions[trackB.pcmHash] = [masterB, trackBVersion2];
        service.customAudioDetails[trackBVersion2.pcmHash] = trackBVersion2;
        service.customAudioDetails[masterB.pcmHash] = masterB;

        String? switchedHash;

        // 1. Render inspector with Track A
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: trackA,
            musicService: service,
            onActiveAudioChanged: (newHash) {
              switchedHash = newHash;
            },
          ),
        );
        await tester.pumpAndSettle();

        // 2. In Track A, select non-active audio version (16-bit/44.1kHz CD WAV)
        final cdVersion = find.text('WAV (Lossless) · 16-bit/44.1kHz');
        expect(cdVersion, findsOneWidget);
        await tester.tap(cdVersion);
        await tester.pumpAndSettle();

        // 3. Tap "Set as Active Audio" on Track A -> initiates switchTrackAudio
        final setActiveBtn = find.widgetWithText(
          LyraButton,
          'Set as Active Audio',
        );
        expect(setActiveBtn, findsOneWidget);
        await tester.tap(setActiveBtn);
        await tester.pump();

        // 4. While switch is in-flight on Track A, change inspected track to Track B
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: trackB,
            musicService: service,
            onActiveAudioChanged: (newHash) {
              switchedHash = newHash;
            },
          ),
        );
        await tester.pumpAndSettle();

        // 5. Complete Track A's audio switch operation
        service.switchAudioCompleter!.complete();
        await tester.pumpAndSettle();

        // 6. Verify onActiveAudioChanged was NOT invoked for the wrong track
        expect(switchedHash, isNull);

        // 7. Verify Track B's specs were not overwritten with Track A's switched version (44.1 kHz / 16-bit)
        expect(find.text('192 kHz'), findsWidgets);
        expect(find.text('44.1 kHz'), findsNothing);

        // 8. Assert Track B does NOT show 'Switching Audio...'
        expect(find.text('Switching Audio...'), findsNothing);

        // 9. Assert Track B's version cards have onTap != null (interactive and not locked)
        final versionDetectors = tester.widgetList<GestureDetector>(
          find.descendant(
            of: find.byKey(const Key('audio_versions_section')),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(versionDetectors.length, greaterThanOrEqualTo(2));
        for (final detector in versionDetectors) {
          expect(detector.onTap, isNotNull);
        }

        // 10. Clicking another version on Track B and activating switch works cleanly
        service.switchAudioCompleter = null;
        final trackBAltVersionFinder = find.text(
          'FLAC (Lossless) · 24-bit/96kHz',
        );
        expect(trackBAltVersionFinder, findsOneWidget);
        await tester.tap(trackBAltVersionFinder);
        await tester.pumpAndSettle();

        final trackBSetActiveBtn = find.widgetWithText(
          LyraButton,
          'Set as Active Audio',
        );
        expect(trackBSetActiveBtn, findsOneWidget);
        await tester.tap(trackBSetActiveBtn);
        await tester.pumpAndSettle();

        expect(switchedHash, equals(trackBVersion2.pcmHash));
        expect(service.switchAudioCallCount, equals(2));
      },
    );

    testWidgets(
      'When Track B initiates a save while Track A slower save finishes in the background, Track B _isSaving is not prematurely extinguished by Track A finally block',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        final tracks = await service.getTracks();
        final trackA = tracks.firstWhere((t) => t.id == 'trk-001');
        final trackB = tracks.firstWhere((t) => t.id == 'trk-002');

        final trackACompleter = Completer<Track>();
        final trackBCompleter = Completer<Track>();
        service.updateTrackCompleters[trackA.id] = trackACompleter;
        service.updateTrackCompleters[trackB.id] = trackBCompleter;

        Track? updatedCallbackTrack;

        // 1. Render inspector with Track A
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: trackA,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // 2. Enter edit mode on Track A, change title, and initiate save
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Track A Renamed',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pump(); // initiates Track A save in background

        // 3. Switch to Track B while Track A save is in flight
        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(
            track: trackB,
            musicService: service,
            onTrackUpdated: (updated) {
              updatedCallbackTrack = updated;
            },
          ),
        );
        await tester.pumpAndSettle();

        // 4. Enter edit mode on Track B, change title, and initiate save
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Track B Renamed',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(LyraButton, 'Confirm & Save'));
        await tester.pump(); // initiates Track B save in background

        // Verify Track B is currently in saving state
        expect(find.text('Saving...'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Save'), findsNothing);

        // 5. Complete Track A slower save in the background
        trackACompleter.complete(trackA.copyWith(title: 'Track A Renamed'));
        // Pump enough for Track A's Future.wait minFeedbackDuration (350ms) to elapse,
        // but DO NOT complete trackBCompleter.
        await tester.pump(const Duration(milliseconds: 400));

        // 6. Assert Track B's _isSaving was NOT extinguished by Track A's finally block
        expect(find.text('Saving...'), findsOneWidget);
        expect(find.widgetWithText(LyraButton, 'Save'), findsNothing);

        // 7. Complete Track B's save
        trackBCompleter.complete(trackB.copyWith(title: 'Track B Renamed'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // 8. Track B exits saving and edit mode cleanly
        expect(find.text('Saving...'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);
        expect(updatedCallbackTrack?.title, equals('Track B Renamed'));
      },
    );

    testWidgets(
      'Save button immediately displays LyraSpinner and Saving... in confirmation state, reverts on cancel, and preserves spinner continuously through confirm save',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = _ControllableInspectorLoadingMusicService();
        service.updateTrackCompleter = Completer<Track>();
        final tracks = await service.getTracks();
        final track = tracks.first;

        await tester.pumpWidget(
          _buildAudioInspectorTestWidget(track: track, musicService: service),
        );
        await tester.pumpAndSettle();

        // 1. Enter edit mode
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        final saveBtnFinder = find.byWidgetPredicate(
          (w) => w is LyraButton && w.key == const Key('inspector_save_button'),
        );
        expect(saveBtnFinder, findsOneWidget);

        // Initial state before tapping Save: leading is null, text is 'Save'
        final initialSaveBtn = tester.widget<LyraButton>(saveBtnFinder);
        expect(initialSaveBtn.leading, isNull);
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Save')),
          findsOneWidget,
        );
        expect(initialSaveBtn.onPressed, isNotNull);

        // Edit title to generate diff
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Testing Spinner on Confirm',
        );
        await tester.pumpAndSettle();

        // 2. Tap Save button -> confirmation state (_isConfirming = true)
        await tester.tap(saveBtnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Diff dialog must be displayed
        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);

        // Requirement: Save button on screen IMMEDIATELY displays [LyraSpinner(size: 14.0)] Saving... and onPressed is null
        final confirmingSaveBtn = tester.widget<LyraButton>(saveBtnFinder);
        expect(confirmingSaveBtn.onPressed, isNull);
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byType(LyraSpinner),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Saving...')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Save')),
          findsNothing,
        );

        // 3. Cancel the confirmation dialog
        await tester.tap(
          find.byKey(const Key('diff_dialog_cancel_button')).first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Confirmation dialog dismissed
        expect(find.byKey(const Key('metadata_diff_dialog')), findsNothing);

        // Requirement: Reverts to [Save] with leading: null and enabled onPressed
        final revertedSaveBtn = tester.widget<LyraButton>(saveBtnFinder);
        expect(revertedSaveBtn.onPressed, isNotNull);
        expect(revertedSaveBtn.leading, isNull);
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byType(LyraSpinner),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Save')),
          findsOneWidget,
        );

        // 4. Tap Save again to open confirmation dialog
        await tester.tap(saveBtnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('metadata_diff_dialog')), findsOneWidget);
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byType(LyraSpinner),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Saving...')),
          findsOneWidget,
        );

        // 5. Confirm dialog
        final confirmBtnFinder = find
            .byKey(const Key('diff_dialog_confirm_button'))
            .first;
        expect(confirmBtnFinder, findsOneWidget);
        await tester.tap(confirmBtnFinder);

        // Advance 1 frame for dialog pop & start save
        await tester.pump();

        // Requirement: _isConfirming resets, _isSaving = true is set, preserving [LyraSpinner] Saving... continuously
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byType(LyraSpinner),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Saving...')),
          findsOneWidget,
        );

        // Advance 200ms (within minFeedbackDuration of 350ms)
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byType(LyraSpinner),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: saveBtnFinder, matching: find.text('Saving...')),
          findsOneWidget,
        );

        // 6. Complete save and let minFeedbackDuration pass
        service.updateTrackCompleter!.complete(
          track.copyWith(title: 'Testing Spinner on Confirm'),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Save finishes and edit mode cleanly closes
        expect(find.byType(LyraSpinner), findsNothing);
        expect(find.text('Saving...'), findsNothing);
        expect(find.widgetWithText(LyraButton, 'Edit'), findsOneWidget);
      },
    );
  });
}

class _ControllableInspectorLoadingMusicService extends MockMusicService {
  Completer<Track>? updateTrackCompleter;
  Completer<void>? switchAudioCompleter;
  int switchAudioCallCount = 0;
  bool failUpdateTrack = false;
  final Map<String, Completer<Track>> updateTrackCompleters = {};
  final Map<String, List<Audio>> customAudioVersions = {};
  final Map<String, Audio> customAudioDetails = {};

  @override
  Future<Audio?> getAudioDetails(String pcmHash) async {
    if (customAudioDetails.containsKey(pcmHash)) {
      return customAudioDetails[pcmHash];
    }
    return super.getAudioDetails(pcmHash);
  }

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) async {
    if (customAudioVersions.containsKey(pcmHash)) {
      return customAudioVersions[pcmHash]!;
    }
    return super.getAudioVersions(pcmHash);
  }

  @override
  Future<Track> updateTrack(Track track) async {
    if (failUpdateTrack) {
      throw Exception('Database update failed');
    }
    if (updateTrackCompleters.containsKey(track.id)) {
      return updateTrackCompleters[track.id]!.future;
    }
    if (updateTrackCompleter != null) {
      return updateTrackCompleter!.future;
    }
    return super.updateTrack(track);
  }

  @override
  Future<void> switchTrackAudio(String trackId, String newPcmHash) async {
    switchAudioCallCount++;
    if (switchAudioCompleter != null) {
      await switchAudioCompleter!.future;
    }
    return super.switchTrackAudio(trackId, newPcmHash);
  }
}

class _DelayedAudioVersionsMusicService extends MockMusicService {
  final Completer<List<Audio>> versionsCompleter;

  _DelayedAudioVersionsMusicService(this.versionsCompleter);

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) =>
      versionsCompleter.future;
}

class _ControllableVersionMusicService extends MockMusicService {
  final List<Audio> versions;
  final Map<String, Completer<SourceData?>> sourceCompleters = {};

  _ControllableVersionMusicService(this.versions);

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) async => versions;

  @override
  Future<SourceData?> getSourceData(String fileHash) {
    if (sourceCompleters.containsKey(fileHash)) {
      return sourceCompleters[fileHash]!.future;
    }
    return super.getSourceData(fileHash);
  }
}

class _DomainTopologyMockMusicService extends MockMusicService {
  final List<Audio> versions;
  final void Function(String hash) onGetAsset;
  final void Function(String hash) onGetAudioDetails;
  final Audio masterAudio;

  _DomainTopologyMockMusicService({
    required this.versions,
    required this.onGetAsset,
    required this.onGetAudioDetails,
    required this.masterAudio,
  });

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) async => versions;

  @override
  Future<Audio?> getAudioDetails(String pcmHash) async {
    onGetAudioDetails(pcmHash);
    if (pcmHash == masterAudio.pcmHash) {
      return masterAudio;
    }
    for (final v in versions) {
      if (v.pcmHash == pcmHash) return v;
    }
    return null;
  }

  @override
  Future<Asset?> getAsset(String fileHash) async {
    onGetAsset(fileHash);
    if (masterAudio.assets.isNotEmpty &&
        masterAudio.assets.first.fileHash == fileHash) {
      return masterAudio.assets.first;
    }
    return super.getAsset(fileHash);
  }
}
