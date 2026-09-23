// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_copy_button.dart';
import 'package:ui/design_system/widgets/lyra_input.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/asset.dart';
import 'package:ui/features/models/audio.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
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
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

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
  });
}
