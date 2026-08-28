// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/artists/artists_view.dart';
import 'package:ui/features/models/artist.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/work.dart';
import 'package:ui/features/playlists/playlists_view.dart';
import 'package:ui/features/works/works_view.dart';

Widget _buildViewTest(Widget child) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();

  return ShadApp(
    themeMode: ThemeMode.dark,
    darkTheme: ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    ),
    home: LyraDesignSystemScope(
      factory: factory,
      tokens: tokens,
      themeModeNotifier: themeModeNotifier,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('WorksView Tests', () {
    final sampleWorks = [
      const Work(
        id: 'wrk-1',
        title: 'Symphony No. 5 in C Minor',
        compositionStartYear: 1804,
        compositionEndYear: 1808,
        iswc: 'T-070.111.222-3',
        musicbrainzId: 'mb-1',
      ),
      const Work(
        id: 'wrk-2',
        title: 'Kind of Blue Compositions',
        compositionDateText: '1959',
      ),
    ];

    testWidgets('WorksView renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const WorksView(works: [])));
      await tester.pumpAndSettle();

      expect(find.text('No musical works found'), findsOneWidget);
    });

    testWidgets('WorksView renders list and triggers selection', (
      tester,
    ) async {
      Work? selectedWork;

      await tester.pumpWidget(
        _buildViewTest(
          WorksView(
            works: sampleWorks,
            onWorkSelected: (w) => selectedWork = w,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Musical Works'), findsOneWidget);
      expect(find.text('Symphony No. 5 in C Minor'), findsOneWidget);
      expect(find.text('1804–1808'), findsOneWidget);
      expect(find.text('T-070.111.222-3'), findsOneWidget);

      await tester.tap(find.text('Symphony No. 5 in C Minor'));
      await tester.pumpAndSettle();
      expect(selectedWork?.id, equals('wrk-1'));
    });
  });

  group('ArtistsView Tests', () {
    final sampleArtists = [
      const Artist(
        id: 'art-1',
        name: 'Miles Davis',
        role: 'Trumpet / Composer',
      ),
      const Artist(id: 'art-2', name: 'Pink Floyd', role: 'Progressive Rock'),
    ];

    testWidgets('ArtistsView renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const ArtistsView(artists: [])));
      await tester.pumpAndSettle();

      expect(find.text('No artists found'), findsOneWidget);
    });

    testWidgets('ArtistsView renders grid and triggers selection', (
      tester,
    ) async {
      Artist? selectedArtist;

      await tester.pumpWidget(
        _buildViewTest(
          ArtistsView(
            artists: sampleArtists,
            onArtistSelected: (a) => selectedArtist = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Miles Davis'), findsOneWidget);
      expect(find.text('Trumpet / Composer'), findsOneWidget);
      expect(find.text('Pink Floyd'), findsOneWidget);

      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();
      expect(selectedArtist?.id, equals('art-1'));
    });
  });

  group('PlaylistsView Tests', () {
    final samplePlaylists = [
      Playlist(
        id: 'pl-1',
        title: 'Master Reference',
        description: '24/192 recordings',
        trackIds: const ['t-1', 't-2', 't-3'],
      ),
    ];

    testWidgets('PlaylistsView renders empty state and new playlist action', (
      tester,
    ) async {
      bool newPlaylistCalled = false;

      await tester.pumpWidget(
        _buildViewTest(
          PlaylistsView(
            playlists: const [],
            onNewPlaylist: () => newPlaylistCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No playlists created yet'), findsOneWidget);
      final createBtn = find.text('Create Playlist');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();
      expect(newPlaylistCalled, isTrue);
    });

    testWidgets('PlaylistsView renders cards and triggers callbacks', (
      tester,
    ) async {
      Playlist? selectedPl;
      bool newPlCalled = false;

      await tester.pumpWidget(
        _buildViewTest(
          PlaylistsView(
            playlists: samplePlaylists,
            onPlaylistSelected: (pl) => selectedPl = pl,
            onNewPlaylist: () => newPlCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Master Reference'), findsOneWidget);
      expect(find.text('3 tracks'), findsOneWidget);

      // Tap playlist card
      await tester.tap(find.text('Master Reference'));
      await tester.pumpAndSettle();
      expect(selectedPl?.id, equals('pl-1'));

      // Tap header New Playlist button
      await tester.tap(find.text('New Playlist'));
      await tester.pumpAndSettle();
      expect(newPlCalled, isTrue);
    });

    testWidgets(
      'PlaylistsView top-right New Playlist button is the designated creation entry in populated view',
      (tester) async {
        bool createClicked = false;

        await tester.pumpWidget(
          _buildViewTest(
            PlaylistsView(
              playlists: samplePlaylists,
              onNewPlaylist: () => createClicked = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top right button exists in header row
        final newPlaylistBtn = find.text('New Playlist');
        expect(newPlaylistBtn, findsOneWidget);

        await tester.tap(newPlaylistBtn);
        await tester.pumpAndSettle();
        expect(createClicked, isTrue);
      },
    );
  });
}
