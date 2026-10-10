// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_input.dart';
import 'package:ui/features/albums/albums_view.dart';
import 'package:ui/features/artists/artists_view.dart';
import 'package:ui/features/cas_pool/cas_view.dart';
import 'package:ui/features/common/context_menu_coordinator.dart';
import 'package:ui/features/inspector/asset_inspector_drawer.dart';
import 'package:ui/features/player/views/now_playing_view.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/models/work.dart';
import 'package:ui/features/playlists/playlist_detail_view.dart';
import 'package:ui/features/playlists/playlists_view.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/settings/settings_view.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/shell/header_bar.dart';
import 'package:ui/features/shell/player_bar.dart';
import 'package:ui/features/shell/sidebar.dart';
import 'package:ui/features/tags/tags_view.dart';
import 'package:ui/features/tracks/tracks_view.dart';
import 'package:ui/features/works/works_view.dart';

Widget _buildAppShellTest({
  MockMusicService? service,
  ValueNotifier<ThemeMode>? themeNotifier,
  Curve? nowPlayingCurve,
  Duration? nowPlayingDuration,
  PreferencesService? preferencesService,
  Map<String, Set<String>>? initialTaggedTrackIds,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final musicService = service ?? MockMusicService();

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
            child: AppShell(
              musicService: musicService,
              nowPlayingCurve: nowPlayingCurve ?? LyraAnimation.defaultCurve,
              nowPlayingDuration: nowPlayingDuration ?? LyraAnimation.sheet,
              preferencesService: preferencesService,
              initialTaggedTrackIds: initialTaggedTrackIds,
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('AppShell renders sidebar, header, tracks, and player bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // Verify Brand / Sidebar
    expect(find.text('Lyra Audio'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Works'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('All Playlists'), findsNothing);
    expect(find.text('CAS Storage'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Tracks table loaded
    expect(find.text('Tracks Library'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Hotel California (Live on MTV 1994)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('So What'),
      ),
      findsOneWidget,
    );

    // Verify Player Bar
    expect(find.byType(LyraPlayerBar), findsOneWidget);

    // Verify redundant status badges are removed per Rule 3
    expect(find.text('Bit-Perfect Engine'), findsNothing);
    expect(find.text('CAS Validated'), findsNothing);
    expect(find.text('Direct Out'), findsNothing);
    expect(find.text('Bit-Perfect CAS'), findsNothing);
  });

  testWidgets('AppShell navigates between all sidebar tabs', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // 1. Switch to Works
    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(find.byType(WorksView), findsOneWidget);
    expect(find.text('Musical Works'), findsOneWidget);
    expect(find.text('Hotel California'), findsOneWidget);

    // 2. Switch to Albums
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumsView), findsOneWidget);
    expect(find.text('Kind of Blue'), findsOneWidget);
    expect(find.text('Hell Freezes Over'), findsOneWidget);

    // 3. Switch to Artists
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistsView), findsOneWidget);
    expect(find.text('Miles Davis'), findsWidgets);
    expect(find.text('Pink Floyd'), findsWidgets);

    // 4. Switch to Playlists
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistsView), findsOneWidget);
    expect(find.text('Audiophile Reference Master'), findsWidgets);
    expect(find.text('Late Night Jazz'), findsWidgets);

    // 5. Switch to Tags
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(find.byType(TagsView), findsOneWidget);
    expect(find.text('Tags'), findsWidgets);
    expect(find.text('Audiophile'), findsWidgets);
    expect(find.text('Hi-Res'), findsWidgets);

    // 6. Switch to CAS Storage
    await tester.tap(find.text('CAS Storage').first);
    await tester.pumpAndSettle();
    expect(find.byType(CasView), findsOneWidget);
    expect(find.text('CAS Storage'), findsWidgets);
    expect(find.text('Integrity Hash'), findsOneWidget);

    // 7. Switch to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Waveform Visualization'), findsOneWidget);
    expect(find.text('Zinc Dark'), findsOneWidget);

    // 8. Switch back to Tracks
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(find.byType(TracksView), findsOneWidget);
  });

  testWidgets('AppShell search bar filters tracks in real-time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // Enter search query
    final searchInput = find.byType(EditableText).first;
    await tester.enterText(searchInput, 'Daft Punk');
    await tester.pumpAndSettle();

    // Should find Giorgio by Moroder in TracksView but not Hotel California
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Giorgio by Moroder'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Hotel California (Live on MTV 1994)'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'AppShell sidebar tag click filters tracks library with badge and Tags header opens TagsView',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Switch to Albums first
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumsView), findsOneWidget);

      // Click 'Audiophile' tag in sidebar
      expect(find.text('Audiophile'), findsOneWidget);
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();

      // Should navigate to TracksView with filter badge 'Tag: Audiophile'
      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: Audiophile'),
        ),
        findsOneWidget,
      );

      // Search controller must NOT be mutated
      final searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // Clear filter via X button
      await tester.tap(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.byIcon(LucideIcons.x),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: Audiophile'),
        ),
        findsNothing,
      );

      // Click 'Tags' header in sidebar -> navigates to TagsView
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(find.byType(TagsView), findsOneWidget);
      expect(find.text('Tags'), findsWidgets);
    },
  );

  testWidgets('AppShell sidebar tag tapping toggles selection ON and OFF', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // 1. Initial state: Audiophile capsule is rendered
    expect(find.text('Audiophile'), findsOneWidget);

    // 2. Tap Audiophile capsule -> selects it, showing filter badge
    await tester.tap(find.text('Audiophile'));
    await tester.pumpAndSettle();

    expect(find.byType(TracksView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Tag: Audiophile'),
      ),
      findsOneWidget,
    );

    // 3. Tap Audiophile capsule again -> toggles OFF, clearing filter badge
    await tester.tap(find.text('Audiophile'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Tag: Audiophile'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'AppShell sidebar supports multi-selection of tags and toggling',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Tap Audiophile -> verify filter 'Tag: Audiophile'
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: Audiophile'),
        ),
        findsOneWidget,
      );

      // 2. Tap Hi-Res -> verify multi-tag filter 'Tags: Audiophile, Hi-Res'
      await tester.tap(find.text('Hi-Res'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tags: Audiophile, Hi-Res'),
        ),
        findsOneWidget,
      );

      // 3. Tap Audiophile again -> verify toggles off, leaving 'Tag: Hi-Res'
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: Hi-Res'),
        ),
        findsOneWidget,
      );

      // 4. Tap Hi-Res again -> verify toggles off, clearing the filter
      await tester.tap(find.text('Hi-Res'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: Hi-Res'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.textContaining('Tag'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AppShell clears _activeTrackFilter unconditionally when switching tabs from sidebar',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Filter by Audiophile tag
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();

      expect(find.text('Tag: Audiophile'), findsWidgets);
      final shellState = tester.state<AppShellState>(find.byType(AppShell));
      expect(shellState.activeTrackFilter, isNotNull);
      expect(shellState.activeTrackFilter!.label, equals('Tag: Audiophile'));

      // 2. Switch to Albums tab via sidebar
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();

      // 3. activeTrackFilter must be cleared unconditionally on tab switch
      expect(shellState.activeTrackFilter, isNull);
      expect(find.text('Tag: Audiophile'), findsNothing);
    },
  );

  testWidgets(
    'AppShell onWorkSelected resets selectedTagId, selectedTagIds, and selectedPlaylistId',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();

      final shellState = tester.state<AppShellState>(find.byType(AppShell));
      final worksView = tester.widget<WorksView>(find.byType(WorksView));

      // Simulate residual tag and playlist selections
      shellState.setTagAndPlaylistSelectionForTesting(
        tagId: 'tag-001',
        tagIds: {'tag-001'},
        playlistId: 'pl-001',
      );

      // Invoke onWorkSelected callback
      worksView.onWorkSelected!(
        const Work(id: 'wrk-test', title: 'Hotel California'),
      );
      await tester.pumpAndSettle();

      // Acceptance Criteria: onWorkSelected must reset _selectedTagId, _selectedTagIds, _selectedPlaylistId
      expect(shellState.selectedTagId, isNull);
      expect(shellState.selectedTagIds, isEmpty);
      expect(shellState.selectedPlaylistId, isNull);
      expect(
        shellState.activeTrackFilter?.label,
        equals('Work: Hotel California'),
      );
    },
  );

  testWidgets(
    'AppShell filters by hierarchical tag audio/low_quality with subTagName via _taggedTrackIdsByTag',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MockMusicService(
        tags: [
          ...MockMusicService.defaultTags,
          const Tag(
            id: 'tag-008',
            name: 'audio/low_quality',
            category: 'audio',
          ),
        ],
      );
      await tester.pumpWidget(
        _buildAppShellTest(
          service: service,
          initialTaggedTrackIds: {
            'tag-008': {'trk-007'},
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Group # audio has low_quality capsule
      expect(find.text('# audio'), findsOneWidget);
      expect(find.text('low_quality'), findsOneWidget);

      // 2. Tap low_quality capsule -> selects it, filter badge shown
      await tester.tap(find.text('low_quality'));
      await tester.pumpAndSettle();

      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: audio/low_quality'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Brothers in Arms'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Dire Straits'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsNothing,
      );

      // 3. Tap low_quality capsule again -> toggles OFF
      await tester.tap(find.text('low_quality'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Tag: audio/low_quality'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AppShell PlaylistsView "New Playlist" action creates playlist and sidebar has no redundant button',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Verify no "+ New Playlist" button in sidebar
      expect(find.text('+ New Playlist'), findsNothing);

      // Navigate to Playlists tab
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);

      // Click top-right 'New Playlist' button in PlaylistsView
      final newPlaylistBtn = find.descendant(
        of: find.byType(PlaylistsView),
        matching: find.text('New Playlist'),
      );
      expect(newPlaylistBtn, findsOneWidget);
      await tester.tap(newPlaylistBtn);
      await tester.pumpAndSettle();

      // Should have newly created playlist in the list
      expect(find.text('New Playlist 4'), findsWidgets);
    },
  );

  testWidgets(
    'AppShell clicking a playlist opens PlaylistDetailView and back navigation returns to PlaylistsView',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Navigate to Playlists tab
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(find.byType(PlaylistDetailView), findsNothing);

      // Click on a playlist card
      await tester.tap(find.text('Audiophile Reference Master').first);
      await tester.pumpAndSettle();

      // Verify PlaylistDetailView is now displayed
      expect(find.byType(PlaylistDetailView), findsOneWidget);
      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('Audiophile Reference Master'), findsWidgets);
      expect(find.text('Play All'), findsOneWidget);
      expect(find.text('Shuffle All'), findsOneWidget);

      // Click back button in PlaylistDetailView
      await tester.tap(
        find.byKey(const Key('playlist_detail_back_button')).first,
      );
      await tester.pumpAndSettle();

      // Verify returned to PlaylistsView
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(find.byType(PlaylistDetailView), findsNothing);

      // Re-enter PlaylistDetailView
      await tester.tap(find.text('Audiophile Reference Master').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailView), findsOneWidget);

      // Click 'Playlists' in sidebar navigation to return to grid
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(find.byType(PlaylistDetailView), findsNothing);
    },
  );

  testWidgets(
    'AppShell removes duplicate track by index from playlist without affecting earlier instance',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MockMusicService();
      final dupPl = await service.createPlaylist(
        title: 'Duplicates Test',
        trackIds: const ['trk-001', 'trk-002', 'trk-001'],
      );

      await tester.pumpWidget(_buildAppShellTest(service: service));
      await tester.pumpAndSettle();

      // Navigate to Playlists tab
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();

      // Click on 'Duplicates Test' playlist
      await tester.tap(find.text('Duplicates Test').first);
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistDetailView), findsOneWidget);
      // Key for 2nd instance of trk-001 is playlist_track_trk-001_1
      final secondInstance = find.byKey(
        const ValueKey('playlist_track_trk-001_1'),
      );
      expect(secondInstance, findsOneWidget);

      // Right-click second instance and remove
      await tester.tap(
        secondInstance,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from Playlist'));
      await tester.pumpAndSettle();

      // Verify second instance is removed, first instance remains
      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_1')),
        findsNothing,
      );

      // Verify updated trackIds in service
      final updatedPlaylists = await service.getPlaylists();
      final updatedPl = updatedPlaylists.firstWhere((p) => p.id == dupPl.id);
      expect(updatedPl.trackIds, equals(['trk-001', 'trk-002']));
    },
  );

  testWidgets(
    'AppShell resets _selectedPlaylistId when switching to Playlists tab from another tab',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Go to Playlists tab and click a playlist
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audiophile Reference Master').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailView), findsOneWidget);

      // 2. Switch to Tracks tab
      await tester.tap(find.text('Tracks').first);
      await tester.pumpAndSettle();
      expect(find.byType(TracksView), findsOneWidget);
      expect(find.byType(PlaylistDetailView), findsNothing);

      // 3. Switch back to Playlists tab
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();

      // Should open PlaylistsView grid, NOT the previously selected playlist
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(find.byType(PlaylistDetailView), findsNothing);
    },
  );

  testWidgets(
    'AppShell top search bar does not wipe out tracks when resolving playlist tracks',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Type search in top search bar that only matches 'Daft Punk' (trk-003)
      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Daft Punk');
      await tester.pumpAndSettle();

      // Go to Playlists tab
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();

      // Click on 'Audiophile Reference Master' which contains trk-001, trk-002, trk-003
      await tester.tap(find.text('Audiophile Reference Master').first);
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistDetailView), findsOneWidget);
      // All 3 tracks should be resolved from _catalogTracks, not lost!
      expect(
        find.descendant(
          of: find.byType(PlaylistDetailView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PlaylistDetailView),
          matching: find.text('So What'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PlaylistDetailView),
          matching: find.text('Giorgio by Moroder'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AppShell responsive sidebar collapses automatically on small screens and allows toggle',
    (tester) async {
      // 1. Wide Desktop (1280px) -> Sidebar expanded by default
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      expect(find.text('Lyra Audio'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

      // 2. Toggle collapse manually on wide desktop
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);

      // 3. Small Screen (< 900px, e.g. 800px) -> Effective collapsed
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LyraSidebar),
          matching: find.text('Collapse'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'LyraSidebar icons and logo are precisely centered when collapsed',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Collapse sidebar
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();

      // 1. Sidebar width is 64.0
      final sidebarFinder = find.byType(LyraSidebar);
      expect(sidebarFinder, findsOneWidget);
      final sidebarSize = tester.getSize(sidebarFinder);
      expect(sidebarSize.width, 64.0);

      // 2. Logo icon is centered at x = 31.5 (64px width - 1px right border = 63px content width)
      final musicIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.music),
      );
      expect(musicIcon, findsOneWidget);
      expect(tester.getCenter(musicIcon).dx, 31.5);

      // 3. Navigation icons are centered at x = 31.5
      final tracksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listMusic),
      );
      expect(tracksIcon, findsOneWidget);
      expect(tester.getCenter(tracksIcon).dx, 31.5);

      final worksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.layers),
      );
      expect(worksIcon, findsOneWidget);
      expect(tester.getCenter(worksIcon).dx, 31.5);

      final albumsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.disc),
      );
      expect(albumsIcon, findsOneWidget);
      expect(tester.getCenter(albumsIcon).dx, 31.5);

      final artistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.mic),
      );
      expect(artistsIcon, findsOneWidget);
      expect(tester.getCenter(artistsIcon).dx, 31.5);

      final playlistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listPlus),
      );
      expect(playlistsIcon, findsOneWidget);
      expect(tester.getCenter(playlistsIcon).dx, 31.5);

      final tagIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.tag),
      );
      expect(tagIcon, findsOneWidget);
      expect(tester.getCenter(tagIcon).dx, 31.5);

      final casIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.hardDrive),
      );
      expect(casIcon, findsOneWidget);
      expect(tester.getCenter(casIcon).dx, 31.5);

      final settingsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.settings),
      );
      expect(settingsIcon, findsOneWidget);
      expect(tester.getCenter(settingsIcon).dx, 31.5);

      // 4. Collapse toggle icon is not present at sidebar bottom per HIG
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsNothing,
      );

      // 5. Verify text labels are hidden
      expect(find.text('Tracks'), findsNothing);
      expect(find.text('Works'), findsNothing);
      expect(find.text('Albums'), findsNothing);
      expect(find.text('Artists'), findsNothing);
      expect(
        find.descendant(of: sidebarFinder, matching: find.text('Collapse')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AppShell search bar query does not filter or wipe out left sidebar playlists',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Verify sidebar contains initial playlists
      final sidebarFinder = find.byType(LyraSidebar);
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Audiophile Reference Master'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Late Night Jazz'),
        ),
        findsOneWidget,
      );

      // Perform a search query that matches a track but NO playlist
      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Daft Punk');
      await tester.pumpAndSettle();

      // Main content filtered
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Giorgio by Moroder'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsNothing,
      );

      // Left sidebar navigation playlists remain intact and visible
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Audiophile Reference Master'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Late Night Jazz'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AppShell AlbumsView navigation to TracksView scopes tracks cleanly without mutating search input',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Navigate to Albums
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumsView), findsOneWidget);

      // Click 'Hell Freezes Over' album card
      await tester.tap(find.text('Hell Freezes Over'));
      await tester.pumpAndSettle();

      // Should be in TracksView
      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Album: Hell Freezes Over'),
        ),
        findsOneWidget,
      );

      // Search controller must NOT be mutated
      final searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // Clear filter via X button
      await tester.tap(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.byIcon(LucideIcons.x),
        ),
      );
      await tester.pumpAndSettle();

      // All tracks restored
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Album: Hell Freezes Over'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AppShell WorksView and ArtistsView navigation to TracksView scopes tracks cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Works navigation
      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();
      expect(find.byType(WorksView), findsOneWidget);

      await tester.tap(find.text('Hotel California'));
      await tester.pumpAndSettle();

      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Work: Hotel California'),
        ),
        findsOneWidget,
      );

      // Search text still empty
      var searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // 2. Artists navigation
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistsView), findsOneWidget);

      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();

      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Blue in Green'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Artist: Miles Davis'),
        ),
        findsOneWidget,
      );

      // Search text still empty
      searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // 3. Clicking Tracks in sidebar clears scoped filter
      await tester.tap(find.text('Tracks'));
      await tester.pumpAndSettle();

      expect(find.text('Artist: Miles Davis'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Toggling theme from header updates background, sidebar, playlist cards, and tags in real-time',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(_buildAppShellTest(themeNotifier: themeNotifier));
      await tester.pumpAndSettle();

      // 1. Initial dark mode
      expect(themeNotifier.value, equals(ThemeMode.dark));
      final scaffoldDark = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldDark.backgroundColor, equals(LyraColors.zinc950));

      // Toggle to Light Mode via theme button in HeaderBar (shows sun icon in dark mode)
      final themeToggleBtn = find.byIcon(LucideIcons.sun);
      expect(themeToggleBtn, findsOneWidget);
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.light));
      expect(find.byIcon(LucideIcons.moon), findsOneWidget);
      final scaffoldLight = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldLight.backgroundColor, equals(const Color(0xFFFFFFFF)));

      // 2. Check PlaylistsView in Light Mode
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);

      // Verify that ShadTheme inside PlaylistsView is light
      final playlistsElement = find.byType(PlaylistsView).evaluate().first;
      final playlistsShadTheme = ShadTheme.of(playlistsElement);
      expect(playlistsShadTheme.brightness, equals(Brightness.light));
      expect(
        playlistsShadTheme.colorScheme.card,
        equals(const ShadZincColorScheme.light().card),
      );

      // 3. Check TagsView in Light Mode
      await tester.tap(find.text('Tags').first);
      await tester.pumpAndSettle();
      expect(find.byType(TagsView), findsOneWidget);

      final tagsElement = find.byType(TagsView).evaluate().first;
      final tagsShadTheme = ShadTheme.of(tagsElement);
      expect(tagsShadTheme.brightness, equals(Brightness.light));
      expect(
        tagsShadTheme.colorScheme.card,
        equals(const ShadZincColorScheme.light().card),
      );

      // 4. Check SettingsView and switch back to Dark Mode via Settings card
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsOneWidget);

      // Tap the Zinc Dark theme option card
      await tester.tap(find.text('Zinc Dark'));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.dark));
      final scaffoldBackDark = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldBackDark.backgroundColor, equals(LyraColors.zinc950));
    },
  );

  testWidgets(
    'AppShell opens AssetInspectorDrawer from PlayerBar, track info icon, track resolution badge, and dynamically updates on track switch',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Initial State: Inspector is closed
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 2. Open Inspector via PlayerBar inspect button
      final playerBarFinder = find.byType(LyraPlayerBar);
      final playerBarInspectBtn = find.descendant(
        of: playerBarFinder,
        matching: find.byIcon(LucideIcons.fileSearch),
      );
      expect(playerBarInspectBtn, findsOneWidget);
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();

      // Drawer is opened
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
      expect(find.text('Audio Specifications'), findsOneWidget);
      expect(find.text('Source Information'), findsOneWidget);

      // 3. Dynamic track update: while inspector is open, select a different track ('So What')
      final soWhatTrack = find.descendant(
        of: find.byType(TracksView),
        matching: find.text('So What'),
      );
      expect(soWhatTrack, findsOneWidget);
      await tester.tap(soWhatTrack);
      await tester.pumpAndSettle();

      // Inspector dynamically updates to 'So What'
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AssetInspectorDrawer),
          matching: find.text('So What'),
        ),
        findsWidgets,
      );

      // 4. Toggle Inspector off via PlayerBar button
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 5. Open Inspector via Track row resolution badge
      final firstTrackResolutionBadge = find.descendant(
        of: find.byType(TracksView),
        matching: find.textContaining('24-bit/96kHz'),
      );
      expect(firstTrackResolutionBadge, findsWidgets);
      await tester.tap(firstTrackResolutionBadge.first);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);

      // 6. Close Drawer via X button in header
      final drawerCloseBtn = find.descendant(
        of: find.byType(AssetInspectorDrawer),
        matching: find.byIcon(LucideIcons.x),
      );
      expect(drawerCloseBtn, findsOneWidget);
      await tester.tap(drawerCloseBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 7. Open Inspector via PlayerBar inspect button again
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);

      // 8. Close Drawer again
      await tester.tap(drawerCloseBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 9. Open Inspector by clicking on a Track Resolution Badge
      final trackResolutionBadge = find.descendant(
        of: find.byType(TracksView),
        matching: find.textContaining('24-bit/96kHz'),
      );
      expect(trackResolutionBadge, findsWidgets);
      await tester.tap(trackResolutionBadge.first);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);
      expect(find.text('CD-Rip'), findsOneWidget);

      // 10. Navigate to CAS Storage and click a blob to inspect
      await tester.tap(find.text('CAS Storage').first);
      await tester.pumpAndSettle();
      expect(find.byType(CasView), findsOneWidget);

      // Tap on a CAS object row cell (MIME type) in CasView to inspect asset
      final casRowCell = find.text('audio/flac').first;
      expect(casRowCell, findsOneWidget);
      await tester.tap(casRowCell);
      await tester.pumpAndSettle();

      // Verify inspector switches to CAS Asset mode
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('CAS Asset'), findsOneWidget);
    },
  );

  testWidgets(
    'AppShell keeps Sidebar, HeaderBar, and PlayerBar visible and interactive when NowPlaying is expanded',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Play a track by tapping the first track in TracksView
      final trackFinder = find
          .text('Hotel California (Live on MTV 1994)')
          .first;
      await tester.tap(trackFinder);
      await tester.pumpAndSettle();

      // Verify NowPlayingView is initially pre-warmed offscreen
      final initialSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('now_playing_animated_slide')),
      );
      expect(initialSlide.offset, equals(const Offset(0.0, 1.0)));
      final initialIgnorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('now_playing_ignore_pointer')),
      );
      expect(initialIgnorePointer.ignoring, isTrue);
      final initialVisibility = tester.widget<Visibility>(
        find.byKey(const ValueKey('now_playing_visibility')),
      );
      expect(initialVisibility.visible, isFalse);
      expect(initialVisibility.maintainState, isTrue);

      // PlayerBar toggle button is chevronUp
      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);

      // 2. Expand NowPlaying by tapping the expand button on PlayerBar
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      // NowPlayingView is now slid into view in the center area
      final expandedSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('now_playing_animated_slide')),
      );
      expect(expandedSlide.offset, equals(Offset.zero));
      final expandedIgnorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('now_playing_ignore_pointer')),
      );
      expect(expandedIgnorePointer.ignoring, isFalse);
      final expandedVisibility = tester.widget<Visibility>(
        find.byKey(const ValueKey('now_playing_visibility')),
      );
      expect(expandedVisibility.visible, isTrue);
      expect(find.byType(NowPlayingView), findsOneWidget);

      // 3. Verify Sidebar, HeaderBar, and PlayerBar remain fully visible!
      expect(find.byType(LyraSidebar), findsOneWidget);
      expect(find.byType(LyraHeaderBar), findsOneWidget);
      expect(find.byType(LyraPlayerBar), findsOneWidget);

      // PlayerBar now shows chevronDown with Collapse tooltip
      expect(find.byTooltip('Collapse Now Playing'), findsOneWidget);

      // Sidebar items remain visible
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsWidgets);

      // HeaderBar search input remains interactive
      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Miles');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(searchInput);
      expect(editable.controller.text, equals('Miles'));

      // 4. Collapse NowPlaying by tapping the Collapse button on PlayerBar
      await tester.tap(find.byTooltip('Collapse Now Playing'));
      await tester.pumpAndSettle();

      // NowPlayingView is collapsed and slid back offscreen
      final collapsedSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('now_playing_animated_slide')),
      );
      expect(collapsedSlide.offset, equals(const Offset(0.0, 1.0)));
      final collapsedIgnorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('now_playing_ignore_pointer')),
      );
      expect(collapsedIgnorePointer.ignoring, isTrue);
      final collapsedVisibility = tester.widget<Visibility>(
        find.byKey(const ValueKey('now_playing_visibility')),
      );
      expect(collapsedVisibility.visible, isFalse);
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);

      // 5. Expand again and collapse via Escape keyboard shortcut
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedSlide>(
              find.byKey(const ValueKey('now_playing_animated_slide')),
            )
            .offset,
        equals(Offset.zero),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedSlide>(
              find.byKey(const ValueKey('now_playing_animated_slide')),
            )
            .offset,
        equals(const Offset(0.0, 1.0)),
      );
    },
  );

  testWidgets(
    'NowPlayingView overlay does not have artificial drop shadow BoxShadow in Light Theme',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final lightThemeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
      addTearDown(lightThemeNotifier.dispose);

      await tester.pumpWidget(
        _buildAppShellTest(themeNotifier: lightThemeNotifier),
      );
      await tester.pumpAndSettle();

      // Start playback and expand Now Playing
      final trackFinder = find
          .descendant(
            of: find.byType(TracksView),
            matching: find.text('Hotel California (Live on MTV 1994)'),
          )
          .first;
      await tester.tap(trackFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingView), findsOneWidget);

      // Ensure there is no DecoratedBox ancestor with BoxShadow between Visibility and NowPlayingView
      final nowPlayingVisibility = find.byKey(
        const ValueKey('now_playing_visibility'),
      );
      final decoratedBoxAncestors = find.ancestor(
        of: find.byType(NowPlayingView),
        matching: find.descendant(
          of: nowPlayingVisibility,
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(decoratedBoxAncestors, findsNothing);
    },
  );

  testWidgets(
    'AppShell isolates AnimatedSlide within RepaintBoundary and supports custom animation curve and duration',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const customCurve = LyraAnimation.springGentle;
      const customDuration = Duration(milliseconds: 280);

      await tester.pumpWidget(
        _buildAppShellTest(
          nowPlayingCurve: customCurve,
          nowPlayingDuration: customDuration,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify AnimatedSlide configured with custom curve and duration
      final slideFinder = find.byKey(
        const ValueKey('now_playing_animated_slide'),
      );
      expect(slideFinder, findsOneWidget);
      final slideWidget = tester.widget<AnimatedSlide>(slideFinder);
      expect(slideWidget.curve, equals(customCurve));
      expect(slideWidget.duration, equals(customDuration));

      // 2. Verify AnimatedSlide is isolated inside an outer RepaintBoundary
      final ancestorRepaint = find.ancestor(
        of: slideFinder,
        matching: find.byType(RepaintBoundary),
      );
      expect(ancestorRepaint, findsWidgets);

      // 3. Verify HeaderBar and PlayerBar are encapsulated within RepaintBoundary
      expect(
        find.ancestor(
          of: find.byType(LyraHeaderBar),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byType(LyraPlayerBar),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'AppShell persists column visibility customizations across tab switches',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      final tracksHeader = find.byKey(const Key('tracks_table_header'));
      expect(tracksHeader, findsOneWidget);

      // In initial Tracks view, verify Album is visible
      expect(
        find.descendant(of: tracksHeader, matching: find.text('Album')),
        findsOneWidget,
      );

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.down(tester.getCenter(tracksHeader));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('track_col_menu_album')));
      await tester.pumpAndSettle();

      // Album is now hidden
      expect(
        find.descendant(of: tracksHeader, matching: find.text('Album')),
        findsNothing,
      );

      // Switch to Works tab
      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();
      expect(find.byType(WorksView), findsOneWidget);

      // Right click Works header to toggle off Year / Date
      final worksHeader = find.byKey(const Key('works_table_header'));
      expect(worksHeader, findsOneWidget);

      await gesture.down(tester.getCenter(worksHeader));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('work_col_menu_date')));
      await tester.pumpAndSettle();

      expect(find.text('COMPOSITION YEAR / DATE'), findsNothing);

      // Switch back to Tracks tab
      await tester.tap(find.text('Tracks'));
      await tester.pumpAndSettle();
      expect(find.byType(TracksView), findsOneWidget);

      final tracksHeaderAgain = find.byKey(const Key('tracks_table_header'));
      // Verify Album is still hidden (session persistence)
      expect(
        find.descendant(of: tracksHeaderAgain, matching: find.text('Album')),
        findsNothing,
      );

      // Switch back to Works tab
      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();
      expect(find.byType(WorksView), findsOneWidget);

      // Verify COMPOSITION YEAR / DATE is still hidden (session persistence)
      expect(find.text('COMPOSITION YEAR / DATE'), findsNothing);
    },
  );

  testWidgets('AppShell persists column order customizations across tab switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // 1. In TracksView, verify # is to the left of Time
    final tracksHeader = find.byKey(const Key('tracks_table_header'));
    expect(tracksHeader, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('#')).dx,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(of: tracksHeader, matching: find.text('Time')),
            )
            .dx,
      ),
    );

    // Right-click Tracks header to reorder Time to the front
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(tester.getCenter(tracksHeader));
    await gesture.up();
    await tester.pumpAndSettle();

    final durationGrip = find.descendant(
      of: find.byKey(const Key('track_col_menu_duration')),
      matching: find.byIcon(LucideIcons.gripVertical),
    );
    await tester.timedDrag(
      durationGrip,
      const Offset(0, -450),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(
            find.descendant(of: tracksHeader, matching: find.text('Time')),
          )
          .dx,
      lessThan(tester.getTopLeft(find.text('#')).dx),
    );

    // 2. Switch to Works tab
    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(find.byType(WorksView), findsOneWidget);

    // In WorksView, verify # is to the left of MUSICBRAINZ ID
    final worksHeader = find.byKey(const Key('works_table_header'));
    expect(
      tester.getTopLeft(find.text('#')).dx,
      lessThan(tester.getTopLeft(find.text('MUSICBRAINZ ID')).dx),
    );

    // Right-click Works header to reorder MUSICBRAINZ ID to the front
    await gesture.down(tester.getCenter(worksHeader));
    await gesture.up();
    await tester.pumpAndSettle();

    final mbGrip = find.descendant(
      of: find.byKey(const Key('work_col_menu_musicbrainzId')),
      matching: find.byIcon(LucideIcons.gripVertical),
    );
    await tester.timedDrag(
      mbGrip,
      const Offset(0, -320),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('MUSICBRAINZ ID')).dx,
      lessThan(tester.getTopLeft(find.text('#')).dx),
    );

    // 3. Switch back to Tracks tab
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(find.byType(TracksView), findsOneWidget);

    // Verify Time is STILL to the left of # (column order preserved across tabs)
    final tracksHeaderRevisited = find.byKey(const Key('tracks_table_header'));
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: tracksHeaderRevisited,
              matching: find.text('Time'),
            ),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: tracksHeaderRevisited,
                matching: find.text('#'),
              ),
            )
            .dx,
      ),
    );

    // 4. Switch back to Works tab
    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(find.byType(WorksView), findsOneWidget);

    // Verify MUSICBRAINZ ID is STILL to the left of # (column order preserved across tabs)
    expect(
      tester.getTopLeft(find.text('MUSICBRAINZ ID')).dx,
      lessThan(tester.getTopLeft(find.text('#')).dx),
    );
  });

  testWidgets(
    'Desktop keyboard shortcuts: Spacebar toggles playback guarded against text input',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Initial state: not playing, Play button shown
      expect(find.byIcon(LucideIcons.play), findsOneWidget);
      expect(find.byIcon(LucideIcons.pause), findsNothing);

      // Press Space when not in text input -> Toggles to playing
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.pause), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsNothing);

      // Press Space again -> Toggles to paused
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.play), findsOneWidget);
      expect(find.byIcon(LucideIcons.pause), findsNothing);

      // Focus the search bar EditableText
      final searchInput = find.byType(EditableText).first;
      await tester.tap(searchInput);
      await tester.pumpAndSettle();

      // Ensure search input is focused
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNotNull,
      );

      // Press Space while typing in search bar -> Should NOT trigger playback
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.play), findsOneWidget);
      expect(find.byIcon(LucideIcons.pause), findsNothing);
    },
  );

  testWidgets(
    'Desktop keyboard shortcuts: Meta+F/Ctrl+F focuses search input and Meta+I/Ctrl+I toggles inspector drawer',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Inspector drawer initially closed
      expect(find.byType(AudioInspectorDrawer), findsNothing);

      // Meta+I toggles inspector drawer open
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorDrawer), findsOneWidget);

      // Meta+I toggles inspector drawer closed
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorDrawer), findsNothing);

      // Ctrl+I toggles inspector drawer open
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorDrawer), findsOneWidget);

      // Meta+F focuses search bar
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      final searchInput = find.byType(EditableText).first;
      expect(
        tester.widget<EditableText>(searchInput).focusNode.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'Desktop keyboard shortcuts: Meta+I/Ctrl+I in expanded NowPlayingView toggles Details tab',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Expand NowPlayingView
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingView), findsOneWidget);
      // Initially Tab 0 (Up Next)
      expect(find.byType(AudioInspectorContent), findsNothing);

      // Meta+I toggles to Details (Tab 2)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorContent), findsOneWidget);

      // Ctrl+I toggles back to Up Next (Tab 0)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorContent), findsNothing);
    },
  );

  testWidgets(
    'Native dialog routing: Import Audio opens as modal dialog route and dismisses on cancel',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Tap Import Audio
      await tester.tap(find.text('Import Audio'));
      await tester.pumpAndSettle();

      // Modal dialog is open
      expect(find.text('Import Audio to CAS Pool'), findsOneWidget);

      // Tap Cancel button inside modal dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Modal dialog is dismissed
      expect(find.text('Import Audio to CAS Pool'), findsNothing);
    },
  );

  testWidgets(
    'Native dialog routing: Add to Playlist opens as modal dialog route and allows creating new playlist',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Start playing a track so player bar has currentTrack
      await tester.tap(find.text('Hotel California (Live on MTV 1994)').first);
      await tester.pumpAndSettle();

      // Tap Add to Playlist in Player Bar
      final addToPlaylistFinder = find.byTooltip('Add to Playlist');
      expect(addToPlaylistFinder, findsOneWidget);
      await tester.tap(addToPlaylistFinder);
      await tester.pumpAndSettle();

      // Modal dialog route is open
      expect(find.text('Add to Playlist'), findsOneWidget);

      // Tap New Playlist in dialog
      await tester.tap(find.text('New Playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Create & Add'), findsOneWidget);
      expect(find.text('Enter a name for the new playlist'), findsOneWidget);

      // Tap Back in dialog
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Add to Playlist'), findsOneWidget);

      // Press Escape to dismiss dialog route
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Add to Playlist'), findsNothing);
    },
  );

  testWidgets(
    'submitting search with enter collapses expanded NowPlayingView and displays search results',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Expand NowPlayingView by tapping expand button on PlayerBar
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      // Verify NowPlayingView is visible / expanded
      expect(find.byType(NowPlayingView), findsOneWidget);
      final expandedSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('now_playing_animated_slide')),
      );
      expect(expandedSlide.offset, equals(Offset.zero));

      final nowPlayingNotifier =
          tester
                  .widget<ValueListenableBuilder<bool>>(
                    find.byKey(const ValueKey('now_playing_expanded_builder')),
                  )
                  .valueListenable
              as ValueNotifier<bool>;
      expect(nowPlayingNotifier.value, isTrue);

      // Enter search text into find.byType(LyraInput)
      final searchInput = find.byType(LyraInput);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'So What');
      await tester.pumpAndSettle();

      // Trigger submit action (Enter / done action)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify NowPlayingView is collapsed
      expect(nowPlayingNotifier.value, isFalse);
      final collapsedSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('now_playing_animated_slide')),
      );
      expect(collapsedSlide.offset, equals(const Offset(0.0, 1.0)));
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);

      // Verify search results are displayed
      expect(find.text('So What'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Hotel California (Live on MTV 1994)'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'submitting search with enter from non-library tab switches to tracks tab and collapses NowPlayingView',
    (tester) async {
      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsOneWidget);

      // Expand NowPlayingView
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      final nowPlayingNotifier =
          tester
                  .widget<ValueListenableBuilder<bool>>(
                    find.byKey(const ValueKey('now_playing_expanded_builder')),
                  )
                  .valueListenable
              as ValueNotifier<bool>;
      expect(nowPlayingNotifier.value, isTrue);

      // Enter search text and submit
      final searchInput = find.byType(LyraInput);
      await tester.enterText(searchInput, 'Eagles');
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // NowPlayingView is collapsed
      expect(nowPlayingNotifier.value, isFalse);

      // Current tab was switched to Tracks and displays results
      expect(find.byType(TracksView), findsOneWidget);
      expect(find.byType(SettingsView), findsNothing);
      expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);
      expect(find.text('So What'), findsNothing);
    },
  );

  testWidgets('clicking any sidebar button collapses expanded NowPlayingView', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    final nowPlayingNotifier =
        tester
                .widget<ValueListenableBuilder<bool>>(
                  find.byKey(const ValueKey('now_playing_expanded_builder')),
                )
                .valueListenable
            as ValueNotifier<bool>;

    // 1. Expand NowPlayingView -> click Albums sidebar button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(AlbumsView), findsOneWidget);

    // 2. Expand NowPlayingView -> click Tracks sidebar button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(TracksView), findsOneWidget);

    // 3. Expand NowPlayingView -> click Playlists header button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(PlaylistsView), findsOneWidget);

    // 4. Expand NowPlayingView -> click a specific playlist item in sidebar -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    // Find playlist in sidebar (Audiophile Reference Master)
    final sidebarPlaylist = find.descendant(
      of: find.byType(LyraSidebar),
      matching: find.text('Audiophile Reference Master'),
    );
    expect(sidebarPlaylist, findsOneWidget);
    await tester.tap(sidebarPlaylist);
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(PlaylistDetailView), findsOneWidget);

    // 5. Expand NowPlayingView -> click Settings sidebar button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(SettingsView), findsOneWidget);

    // 6. Expand NowPlayingView -> click Works sidebar button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(WorksView), findsOneWidget);

    // 7. Expand NowPlayingView -> click Tags sidebar button -> collapses
    await tester.tap(find.byTooltip('Expand Now Playing'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isTrue);
    expect(nowPlayingNotifier.value, isTrue);

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(shellState.isNowPlayingExpanded, isFalse);
    expect(nowPlayingNotifier.value, isFalse);
    expect(find.byType(TagsView), findsOneWidget);
  });

  group('AppShell Preferences & State Persistence Tests', () {
    testWidgets(
      'AppShell restores sidebar collapsed state, volume, and custom column orders from PreferencesService',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          isSidebarCollapsed: true,
          volume: 0.42,
          trackColumnOrder: [
            'duration',
            'title',
            'album',
            'resolution',
            'index',
          ],
          trackVisibleColumns: {'duration', 'title', 'album'},
          workColumnOrder: ['date', 'title', 'composer'],
          workVisibleColumns: {'date', 'title'},
          playlistColumnOrder: ['duration', 'title'],
          playlistVisibleColumns: {'duration', 'title'},
        );

        await tester.pumpWidget(_buildAppShellTest(preferencesService: prefs));
        await tester.pumpAndSettle();

        final shellState = tester.state<AppShellState>(find.byType(AppShell));

        // 1. Sidebar is collapsed initially
        expect(shellState.isSidebarCollapsed, isTrue);

        // 2. Volume is initialized to saved value
        expect(shellState.volumeNotifier.value, 0.42);

        // 3. Track columns restored
        expect(shellState.trackColumnOrder.first, TrackColumn.duration);
        expect(shellState.trackVisibleColumns.map((c) => c.name).toSet(), {
          'duration',
          'title',
          'album',
        });

        // 4. Work columns restored
        expect(shellState.workColumnOrder.first, WorkColumn.date);
        expect(shellState.workVisibleColumns.map((c) => c.name).toSet(), {
          'date',
          'title',
        });

        // 5. Playlist columns restored
        expect(shellState.playlistColumnOrder.first, TrackColumn.duration);
        expect(shellState.playlistVisibleColumns.map((c) => c.name).toSet(), {
          'duration',
          'title',
        });
      },
    );

    testWidgets(
      'Toggling sidebar or modifying volume/columns updates PreferencesService',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          isSidebarCollapsed: false,
          volume: 0.85,
        );

        await tester.pumpWidget(_buildAppShellTest(preferencesService: prefs));
        await tester.pumpAndSettle();

        final shellState = tester.state<AppShellState>(find.byType(AppShell));

        // 1. Toggle sidebar via header button
        expect(prefs.isSidebarCollapsed, isFalse);
        final toggleSidebarFinder = find.byTooltip('Collapse sidebar');
        expect(toggleSidebarFinder, findsOneWidget);
        await tester.tap(toggleSidebarFinder);
        await tester.pumpAndSettle();

        expect(shellState.isSidebarCollapsed, isTrue);
        expect(prefs.isSidebarCollapsed, isTrue);

        // Toggle back
        final expandSidebarFinder = find.byTooltip('Expand sidebar');
        expect(expandSidebarFinder, findsOneWidget);
        await tester.tap(expandSidebarFinder);
        await tester.pumpAndSettle();

        expect(shellState.isSidebarCollapsed, isFalse);
        expect(prefs.isSidebarCollapsed, isFalse);

        // 2. Modify volume updates PreferencesService (debounced)
        shellState.volumeNotifier.value = 0.35;
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(prefs.volume, 0.35);

        // 3. Modifying track columns updates PreferencesService
        final tracksView = tester.widget<TracksView>(find.byType(TracksView));
        tracksView.onColumnOrderChanged?.call([
          TrackColumn.album,
          TrackColumn.title,
        ]);
        await tester.pumpAndSettle();
        expect(prefs.getTrackColumnOrder(), ['album', 'title']);

        tracksView.onVisibleColumnsChanged?.call({
          TrackColumn.title,
          TrackColumn.album,
        });
        await tester.pumpAndSettle();
        expect(prefs.getTrackVisibleColumns(), {'title', 'album'});

        // 4. Switch to Works tab and modify work columns
        await tester.tap(find.text('Works'));
        await tester.pumpAndSettle();

        final worksView = tester.widget<WorksView>(find.byType(WorksView));
        worksView.onColumnOrderChanged?.call([
          WorkColumn.composer,
          WorkColumn.title,
        ]);
        await tester.pumpAndSettle();
        expect(prefs.getWorkColumnOrder(), ['composer', 'title']);

        worksView.onVisibleColumnsChanged?.call({
          WorkColumn.title,
          WorkColumn.composer,
        });
        await tester.pumpAndSettle();
        expect(prefs.getWorkVisibleColumns(), {'title', 'composer'});

        // 5. Switch to Playlists tab, open playlist detail, and modify playlist columns
        await tester.tap(find.text('Playlists'));
        await tester.pumpAndSettle();

        // Tap the first playlist card
        await tester.tap(find.text('Audiophile Reference Master').first);
        await tester.pumpAndSettle();

        final playlistDetail = tester.widget<PlaylistDetailView>(
          find.byType(PlaylistDetailView),
        );
        playlistDetail.onColumnOrderChanged?.call([
          TrackColumn.duration,
          TrackColumn.title,
        ]);
        await tester.pumpAndSettle();
        expect(prefs.getPlaylistColumnOrder(), ['duration', 'title']);

        playlistDetail.onVisibleColumnsChanged?.call({
          TrackColumn.duration,
          TrackColumn.title,
        });
        await tester.pumpAndSettle();
        expect(prefs.getPlaylistVisibleColumns(), {'duration', 'title'});
      },
    );

    testWidgets(
      'TracksView context menu Go to Album and Go to Artist filter tracks and update view',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // Right-click on first track in TracksView
        final trackFinder = find
            .text('Hotel California (Live on MTV 1994)')
            .first;
        await tester.tap(
          trackFinder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Go to Album'), findsOneWidget);
        await tester.tap(find.text('Go to Album'));
        await tester.pumpAndSettle();

        // Filter token in header should show "Album: Hell Freezes Over"
        expect(find.text('Album: Hell Freezes Over'), findsOneWidget);

        // Clear filter by tapping X on badge
        await tester.tap(find.byIcon(LucideIcons.x).first);
        await tester.pumpAndSettle();
        expect(find.text('Album: Hell Freezes Over'), findsNothing);

        // Right-click and choose Go to Artist
        await tester.tap(
          trackFinder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Go to Artist'), findsOneWidget);
        await tester.tap(find.text('Go to Artist'));
        await tester.pumpAndSettle();

        expect(find.text('Artist: Eagles'), findsOneWidget);
      },
    );

    testWidgets(
      'navigating to Album/Artist from UpNextTab collapses NowPlayingView, clears sidebar selection, and filters tracks',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. Play first track so queue is active and player bar is visible
        await tester.tap(
          find.text('Hotel California (Live on MTV 1994)').first,
        );
        await tester.pumpAndSettle();

        // 2. Select 'Audiophile' tag in sidebar to establish non-null _selectedTagId
        await tester.tap(find.text('Audiophile'));
        await tester.pumpAndSettle();
        expect(find.text('Tag: Audiophile'), findsOneWidget);

        // 3. Expand NowPlayingView
        expect(find.byTooltip('Expand Now Playing'), findsOneWidget);
        await tester.tap(find.byTooltip('Expand Now Playing'));
        await tester.pumpAndSettle();

        final nowPlayingNotifier =
            tester
                    .widget<ValueListenableBuilder<bool>>(
                      find.byKey(
                        const ValueKey('now_playing_expanded_builder'),
                      ),
                    )
                    .valueListenable
                as ValueNotifier<bool>;
        expect(nowPlayingNotifier.value, isTrue);

        // 4. In UpNextTab, right click on 'So What' row
        final soWhatFinder = find.descendant(
          of: find.byKey(const ValueKey('up_next_tab')),
          matching: find.text('So What'),
        );
        expect(soWhatFinder, findsOneWidget);
        await tester.tap(
          soWhatFinder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Go to Album'), findsOneWidget);

        // 5. Tap 'Go to Album'
        await tester.tap(find.text('Go to Album'));
        await tester.pumpAndSettle();

        // NowPlayingView must be collapsed
        expect(nowPlayingNotifier.value, isFalse);
        final collapsedSlide = tester.widget<AnimatedSlide>(
          find.byKey(const ValueKey('now_playing_animated_slide')),
        );
        expect(collapsedSlide.offset, isNot(equals(Offset.zero)));

        // Sidebar selection for Tag must be cleared
        expect(find.text('Tag: Audiophile'), findsNothing);

        // TracksView is visible and filtered to 'Album: Kind of Blue'
        expect(find.byType(TracksView), findsOneWidget);
        expect(find.text('Album: Kind of Blue'), findsOneWidget);

        // 'So What' matches, while 'Hotel California' does not and is filtered out of TracksView
        expect(
          find.descendant(
            of: find.byType(TracksView),
            matching: find.text('So What'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(TracksView),
            matching: find.text('Hotel California (Live on MTV 1994)'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'cross-widget context menu transfer closes TracksView context menu when UpNextTab row is right-clicked',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. Play first track to populate player queue
        await tester.tap(
          find.text('Hotel California (Live on MTV 1994)').first,
        );
        await tester.pumpAndSettle();

        // 2. Right-click on first track in TracksView
        final trackFinder = find
            .text('Hotel California (Live on MTV 1994)')
            .first;
        await tester.tap(
          trackFinder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Add to Playlist...'), findsOneWidget);

        // 3. Expand NowPlayingView
        await tester.tap(find.byTooltip('Expand Now Playing'));
        await tester.pumpAndSettle();

        // 4. In UpNextTab, right-click on 'So What'
        final soWhatFinder = find.descendant(
          of: find.byKey(const ValueKey('up_next_tab')),
          matching: find.text('So What'),
        );
        await tester.tap(
          soWhatFinder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        // Exactly one context menu should be active and open
        expect(find.text('Remove from Queue'), findsOneWidget);
        // The active controller belongs to the UpNextTab context menu
        expect(LyraContextMenuCoordinator.activeController, isNotNull);
      },
    );

    testWidgets(
      'AppShell: AudioInspectorDrawer edits track, updating table and player bar in real time',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // Start playback of first track (trk-001: Hotel California)
        await tester.tap(
          find.text('Hotel California (Live on MTV 1994)').first,
        );
        await tester.pumpAndSettle();

        // Open inspector with Meta+I
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        expect(find.byType(AudioInspectorDrawer), findsOneWidget);

        // Click Edit button in AudioInspectorDrawer
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        // Edit Title
        await tester.enterText(
          find.byKey(const Key('inspector_edit_title_input')).first,
          'Hotel California (Renamed in Test)',
        );
        await tester.pumpAndSettle();

        // Click Save
        await tester.tap(find.widgetWithText(LyraButton, 'Save'));
        await tester.pumpAndSettle();

        // Confirm & Save in diff dialog
        final confirmBtn = find.widgetWithText(LyraButton, 'Confirm & Save');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.first);
          await tester.pumpAndSettle();
        }

        // Verify updated title appears in TracksView table, PlayerBar, and AudioInspectorDrawer
        expect(find.text('Hotel California (Renamed in Test)'), findsWidgets);
      },
    );

    testWidgets(
      'AppShell: clicking Track A -> enter Inspector Edit -> click Track B switches tracks cleanly without freezing',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        await tester.pumpWidget(_buildAppShellTest(service: service));
        await tester.pumpAndSettle();

        // Start playback of first track (trk-001: Hotel California)
        await tester.tap(
          find.text('Hotel California (Live on MTV 1994)').first,
        );
        await tester.pumpAndSettle();

        // Open inspector with Meta+I
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        expect(find.byType(AudioInspectorDrawer), findsOneWidget);

        // Click Edit button in AudioInspectorDrawer
        await tester.tap(find.widgetWithText(LyraButton, 'Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Metadata'), findsOneWidget);

        // Now click second track ('So What') in TracksView table
        final soWhatTrack = find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        );
        expect(soWhatTrack, findsOneWidget);
        await tester.tap(soWhatTrack);
        await tester.pumpAndSettle();

        // Inspector should update to 'So What' and not hang
        expect(
          find.descendant(
            of: find.byType(AudioInspectorDrawer),
            matching: find.text('So What'),
          ),
          findsWidgets,
        );
        expect(find.text('Edit Metadata'), findsNothing);
      },
    );

    testWidgets(
      'AppShell navigates between CAS Storage sub-tabs from left sidebar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. Expand CAS Storage section via chevron
        await tester.tap(find.byKey(const Key('cas_header_chevron')));
        await tester.pumpAndSettle();

        // 2. Navigate to CAS Storage via sidebar sub-item 'Storage Overview'
        await tester.tap(find.text('Storage Overview'));
        await tester.pumpAndSettle();

        expect(find.byType(CasView), findsOneWidget);
        expect(find.text('Integrity Hash'), findsOneWidget);

        // 2. Click 'Database Explorer' sub-item in sidebar
        await tester.tap(find.text('Database Explorer'));
        await tester.pumpAndSettle();

        expect(find.byType(DatabaseExplorerTab), findsOneWidget);
        expect(find.text('Database Health Status'), findsOneWidget);
        expect(find.text('Integrity Hash'), findsNothing);

        // 3. Click 'Engine Settings' sub-item in sidebar
        await tester.tap(find.text('Engine Settings'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Output device selection, exclusive mode, hardware buffer frames, volume strategy, and resampler profiles.',
          ),
          findsOneWidget,
        );

        // 4. Click back to 'Storage Overview'
        await tester.tap(find.text('Storage Overview'));
        await tester.pumpAndSettle();

        expect(find.text('Integrity Hash'), findsOneWidget);
      },
    );

    testWidgets(
      'AppShell retains DatabaseExplorerController state across tab navigations',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. Expand CAS Storage section and go to Database Explorer
        await tester.tap(find.byKey(const Key('cas_header_chevron')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Database Explorer'));
        await tester.pumpAndSettle();

        expect(find.byType(DatabaseExplorerTab), findsOneWidget);

        // 2. Switch table in Database Explorer to 'Track'
        final casView = tester.widget<CasView>(find.byType(CasView));
        expect(casView.dbController, isNotNull);
        final dbController = casView.dbController!;
        dbController.selectTable('Track');
        await tester.pumpAndSettle();
        expect(dbController.selectedTable, equals('Track'));

        // 3. Navigate away to Tracks tab
        await tester.tap(find.text('Tracks').first);
        await tester.pumpAndSettle();
        expect(find.byType(TracksView), findsOneWidget);

        // 4. Navigate back to Database Explorer
        await tester.tap(find.text('Database Explorer'));
        await tester.pumpAndSettle();

        // 5. DatabaseExplorerController is retained and table remains 'Track'
        final casViewReturned = tester.widget<CasView>(find.byType(CasView));
        expect(casViewReturned.dbController, same(dbController));
        expect(dbController.selectedTable, equals('Track'));
      },
    );

    testWidgets(
      'Defect 5: AppShell maintains CasController and BackendSettingsController symmetry with DatabaseExplorerController',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. Expand CAS Storage section and go to CAS Storage Overview
        await tester.tap(find.byKey(const Key('cas_header_chevron')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Storage Overview'));
        await tester.pumpAndSettle();

        expect(find.byType(CasView), findsOneWidget);
        final casView = tester.widget<CasView>(find.byType(CasView));
        expect(
          casView.controller,
          isNotNull,
          reason: 'CasController must be owned symmetrically by AppShell',
        );
        expect(
          casView.backendSettingsController,
          isNotNull,
          reason:
              'BackendSettingsController must be owned symmetrically by AppShell',
        );
        expect(casView.dbController, isNotNull);

        final casController = casView.controller!;
        final backendSettingsController = casView.backendSettingsController!;

        // 2. Navigate away to Tracks
        await tester.tap(find.text('Tracks').first);
        await tester.pumpAndSettle();
        expect(find.byType(TracksView), findsOneWidget);

        // 3. Navigate back to CAS Storage Overview
        await tester.tap(find.text('Storage Overview'));
        await tester.pumpAndSettle();

        // 4. Verify controllers are retained symmetrically
        final casViewReturned = tester.widget<CasView>(find.byType(CasView));
        expect(casViewReturned.controller, same(casController));
        expect(
          casViewReturned.backendSettingsController,
          same(backendSettingsController),
        );
      },
    );

    testWidgets(
      'AppShell clears _selectedTagId when switching away from tracks and tapping tag from TagsView always switches to tracks view and filters',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildAppShellTest());
        await tester.pumpAndSettle();

        // 1. In tracks view, tap Audiophile tag to select it
        await tester.tap(find.text('Audiophile'));
        await tester.pumpAndSettle();
        expect(find.byType(TracksView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TracksView),
            matching: find.text('Tag: Audiophile'),
          ),
          findsOneWidget,
        );

        // 2. Switch away to Tags tab via onTabSelected
        final sidebar = tester.widget<LyraSidebar>(find.byType(LyraSidebar));
        sidebar.onTabSelected(AppTab.tags);
        await tester.pumpAndSettle();
        expect(find.byType(TagsView), findsOneWidget);

        // 3. Tap Audiophile tag in TagsView
        await tester.tap(
          find.descendant(
            of: find.byType(TagsView),
            matching: find.text('Audiophile'),
          ),
        );
        await tester.pumpAndSettle();

        // 4. Must switch back to TracksView with filter active, NOT stay in TagsView / deselect!
        expect(find.byType(TracksView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TracksView),
            matching: find.text('Tag: Audiophile'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AppShell empty or whitespace tag names do not match every track in catalog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService(
          tags: [
            ...MockMusicService.defaultTags,
            const Tag(id: 'tag-empty', name: '', category: 'general'),
          ],
        );
        await tester.pumpWidget(_buildAppShellTest(service: service));
        await tester.pumpAndSettle();

        // Go to Tags tab
        await tester.tap(find.text('Tags').first);
        await tester.pumpAndSettle();
        expect(find.byType(TagsView), findsOneWidget);

        // In TagsView, find the empty tag ('Untitled Tag') and tap it
        expect(find.text('Untitled Tag'), findsOneWidget);
        await tester.tap(find.text('Untitled Tag'));
        await tester.pumpAndSettle();

        // Switched to TracksView with filter
        expect(find.byType(TracksView), findsOneWidget);

        // Empty tag name must NOT match every track in catalog
        expect(find.text('No matching tracks found'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TracksView),
            matching: find.text('Hotel California (Live on MTV 1994)'),
          ),
          findsNothing,
        );
      },
    );

    group('Scoped Tag Matching Rules (Task 4)', () {
      test(
        'scoped artist tag matches artist name and does NOT match track title',
        () {
          const tag = Tag(
            id: 'tag-artist-time',
            name: 'artist/Time',
            category: 'artist',
          );
          const trackPinkFloyd = Track(
            id: 'trk-pf-time',
            title: 'Time',
            artistName: 'Pink Floyd',
            albumTitle: 'The Dark Side of the Moon',
            genre: 'Rock',
          );
          // "Time" is the title, NOT the artist -> must NOT match
          expect(AppShellState.trackMatchesTag(trackPinkFloyd, tag), isFalse);

          const trackTimeArtist = Track(
            id: 'trk-time-band',
            title: 'Jungle Love',
            artistName: 'The Time',
            albumTitle: 'Ice Cream Castle',
            genre: 'Funk',
          );
          expect(AppShellState.trackMatchesTag(trackTimeArtist, tag), isTrue);
        },
      );

      test(
        'scoped genre tag matches track genre and does NOT match track title',
        () {
          const genreTag = Tag(
            id: 'tag-genre-jazz',
            name: 'genre/Jazz',
            category: 'genre',
          );
          const trackWithGenre = Track(
            id: 'trk-jazz-1',
            title: 'Blue in Green',
            artistName: 'Miles Davis',
            albumTitle: 'Kind of Blue',
            genre: 'Jazz',
          );
          expect(
            AppShellState.trackMatchesTag(trackWithGenre, genreTag),
            isTrue,
          );

          const trackWithTitleJazz = Track(
            id: 'trk-rock-jazz-song',
            title: 'Jazz Police',
            artistName: 'Leonard Cohen',
            albumTitle: 'I\'m Your Man',
            genre: 'Singer-Songwriter',
          );
          // "Jazz Police" has Jazz in title, but genre is Singer-Songwriter -> must NOT match
          expect(
            AppShellState.trackMatchesTag(trackWithTitleJazz, genreTag),
            isFalse,
          );
        },
      );

      test('scoped album tag matches album title and does NOT match artist', () {
        const albumTag = Tag(
          id: 'tag-album-abbey',
          name: 'album/Abbey Road',
          category: 'album',
        );
        const trackOnAlbum = Track(
          id: 'trk-beatles-come-together',
          title: 'Come Together',
          artistName: 'The Beatles',
          albumTitle: 'Abbey Road',
          genre: 'Rock',
        );
        expect(AppShellState.trackMatchesTag(trackOnAlbum, albumTag), isTrue);

        const trackWithArtistAbbey = Track(
          id: 'trk-abbey-lincoln',
          title: 'Afro Blue',
          artistName: 'Abbey Lincoln',
          albumTitle: 'Abbey Is Blue',
          genre: 'Jazz',
        );
        // Abbey Lincoln has Abbey in artist, but album is Abbey Is Blue (not Abbey Road) -> must NOT match
        expect(
          AppShellState.trackMatchesTag(trackWithArtistAbbey, albumTag),
          isFalse,
        );
      });

      test(
        'general un-scoped tag matches across genre as well as standard fields',
        () {
          const flatGenreTag = Tag(
            id: 'tag-flat-fusion',
            name: 'Fusion',
            category: 'general',
          );
          const trackFusionGenre = Track(
            id: 'trk-fusion-genre',
            title: 'Chameleon',
            artistName: 'Herbie Hancock',
            albumTitle: 'Head Hunters',
            genre: 'Jazz-Fusion',
          );
          expect(
            AppShellState.trackMatchesTag(trackFusionGenre, flatGenreTag),
            isTrue,
          );
        },
      );
    });
  });
}
