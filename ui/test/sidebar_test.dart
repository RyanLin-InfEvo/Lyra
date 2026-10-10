// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/shell/sidebar.dart';

Widget _buildSidebarTest({
  AppTab currentTab = AppTab.tracks,
  bool isCollapsed = false,
  ValueChanged<AppTab>? onTabSelected,
  VoidCallback? onToggleCollapse,
  List<Playlist> playlists = const [],
  String? selectedPlaylistId,
  ValueChanged<Playlist>? onPlaylistSelected,
  List<Tag> tags = const [],
  String? selectedTagId,
  Iterable<String>? selectedTagIds,
  ValueChanged<Tag>? onTagSelected,
  VoidCallback? onTagsHeaderSelected,
  bool defaultPlaylistsExpanded = true,
  bool defaultTagsExpanded = true,
  CasTab selectedCasTab = CasTab.storageOverview,
  ValueChanged<CasTab>? onCasSubTabSelected,
  VoidCallback? onCasHeaderSelected,
  bool defaultCasExpanded = true,
  ThemeMode themeMode = ThemeMode.dark,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(themeMode);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
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
              body: LyraSidebar(
                currentTab: currentTab,
                isCollapsed: isCollapsed,
                onTabSelected: onTabSelected ?? (_) {},
                onToggleCollapse: onToggleCollapse ?? () {},
                playlists: playlists,
                selectedPlaylistId: selectedPlaylistId,
                onPlaylistSelected: onPlaylistSelected,
                tags: tags,
                selectedTagId: selectedTagId,
                selectedTagIds: selectedTagIds,
                onTagSelected: onTagSelected,
                onTagsHeaderSelected: onTagsHeaderSelected,
                defaultPlaylistsExpanded: defaultPlaylistsExpanded,
                defaultTagsExpanded: defaultTagsExpanded,
                selectedCasTab: selectedCasTab,
                onCasSubTabSelected: onCasSubTabSelected,
                onCasHeaderSelected: onCasHeaderSelected,
                defaultCasExpanded: defaultCasExpanded,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  final samplePlaylists = [
    Playlist(id: 'pl-1', title: 'Favorites', trackIds: const ['1', '2']),
    Playlist(id: 'pl-2', title: 'Studio Master', trackIds: const ['3']),
  ];

  final sampleTags = [
    const Tag(id: 't-1', name: 'Audiophile', category: 'quality'),
    const Tag(id: 't-2', name: 'Hi-Res', category: 'quality'),
    const Tag(id: 't-3', name: 'DSD', category: 'format'),
  ];

  testWidgets('LyraSidebar renders all sections in expanded mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildSidebarTest(playlists: samplePlaylists, tags: sampleTags),
    );
    await tester.pumpAndSettle();

    // Section headers
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);

    // Library items
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Works'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);

    // Playlists items
    expect(find.text('All Playlists'), findsNothing);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Studio Master'), findsOneWidget);

    // Redundant playlist creation entry points removed from sidebar
    expect(find.text('+ New Playlist'), findsNothing);

    // Tag chips
    expect(find.text('Audiophile'), findsOneWidget);
    expect(find.text('Hi-Res'), findsOneWidget);
    expect(find.text('DSD'), findsOneWidget);

    // System items
    expect(find.text('CAS Storage'), findsOneWidget);
    expect(find.text('Storage Overview'), findsOneWidget);
    expect(find.text('Database Explorer'), findsOneWidget);
    expect(find.text('Engine Settings'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);
  });

  testWidgets(
    'LyraSidebar CAS Storage section is expandable, collapsible, and selects sub-tabs cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      CasTab? selectedCasTab;
      AppTab? selectedAppTab;

      await tester.pumpWidget(
        _buildSidebarTest(
          onCasSubTabSelected: (tab) => selectedCasTab = tab,
          onTabSelected: (tab) => selectedAppTab = tab,
        ),
      );
      await tester.pumpAndSettle();

      // Initially expanded
      expect(find.text('Storage Overview'), findsOneWidget);
      expect(find.text('Database Explorer'), findsOneWidget);
      expect(find.text('Engine Settings'), findsOneWidget);

      // Collapse CAS Storage section
      await tester.tap(find.byKey(const Key('cas_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Storage Overview'), findsNothing);
      expect(find.text('Database Explorer'), findsNothing);
      expect(find.text('Engine Settings'), findsNothing);

      // Re-expand CAS Storage section
      await tester.tap(find.byKey(const Key('cas_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Storage Overview'), findsOneWidget);
      expect(find.text('Database Explorer'), findsOneWidget);
      expect(find.text('Engine Settings'), findsOneWidget);

      // Tap Database Explorer sub-item
      await tester.tap(find.text('Database Explorer'));
      await tester.pumpAndSettle();

      expect(selectedCasTab, equals(CasTab.databaseExplorer));
      expect(selectedAppTab, equals(AppTab.casStorage));
    },
  );

  testWidgets(
    'LyraSidebar Playlists and Tags sections are expandable and collapsible',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildSidebarTest(playlists: samplePlaylists, tags: sampleTags),
      );
      await tester.pumpAndSettle();

      // Initially expanded
      expect(find.text('All Playlists'), findsNothing);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Studio Master'), findsOneWidget);
      expect(find.text('Audiophile'), findsOneWidget);
      expect(find.text('Hi-Res'), findsOneWidget);
      expect(find.text('DSD'), findsOneWidget);

      // Collapse PLAYLISTS section by tapping chevron button
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Studio Master'), findsNothing);
      // Tags still visible
      expect(find.text('Audiophile'), findsOneWidget);

      // Re-expand PLAYLISTS section
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Studio Master'), findsOneWidget);

      // Collapse TAGS section by tapping chevron button
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile'), findsNothing);
      expect(find.text('Hi-Res'), findsNothing);
      expect(find.text('DSD'), findsNothing);
      // Playlists still visible
      expect(find.text('Favorites'), findsOneWidget);

      // Re-expand TAGS section
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile'), findsOneWidget);
      expect(find.text('Hi-Res'), findsOneWidget);
      expect(find.text('DSD'), findsOneWidget);
    },
  );

  testWidgets('LyraSidebar tab selection triggers onTabSelected callback', (
    tester,
  ) async {
    AppTab? selectedTab;

    await tester.pumpWidget(
      _buildSidebarTest(onTabSelected: (tab) => selectedTab = tab),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.works));

    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.artists));

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.playlists));

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.tags));
  });

  testWidgets(
    'LyraSidebar Playlists and Tags headers navigate to tab/overview while chevrons toggle collapse independently',
    (tester) async {
      AppTab? selectedTab;
      bool tagsHeaderClicked = false;

      await tester.pumpWidget(
        _buildSidebarTest(
          playlists: samplePlaylists,
          tags: sampleTags,
          onTabSelected: (tab) => selectedTab = tab,
          onTagsHeaderSelected: () => tagsHeaderClicked = true,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tapping Playlists title navigates to AppTab.playlists without collapsing list
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(selectedTab, equals(AppTab.playlists));
      expect(find.text('Favorites'), findsOneWidget);

      // 2. Tapping Playlists chevron toggles collapse without firing onTabSelected
      selectedTab = null;
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();
      expect(selectedTab, isNull);
      expect(find.text('Favorites'), findsNothing);

      // 3. Tapping Tags title calls onTagsHeaderSelected without collapsing tags list
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(tagsHeaderClicked, isTrue);
      expect(find.text('Audiophile'), findsOneWidget);

      // 4. Tapping Tags chevron toggles collapse
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
      await tester.pumpAndSettle();
      expect(find.text('Audiophile'), findsNothing);
    },
  );

  testWidgets('LyraSidebar playlist and tag clicks trigger callbacks', (
    tester,
  ) async {
    Playlist? clickedPlaylist;
    Tag? clickedTag;

    await tester.pumpWidget(
      _buildSidebarTest(
        playlists: samplePlaylists,
        tags: sampleTags,
        onPlaylistSelected: (pl) => clickedPlaylist = pl,
        onTagSelected: (t) => clickedTag = t,
      ),
    );
    await tester.pumpAndSettle();

    // Click playlist item
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(clickedPlaylist?.id, equals('pl-1'));

    // Click tag item
    await tester.tap(find.text('Hi-Res'));
    await tester.pumpAndSettle();
    expect(clickedTag?.name, equals('Hi-Res'));
  });

  testWidgets(
    'LyraSidebar items (Nav, Playlists, Tags) have consistent button sizing and layout',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(
          playlists: samplePlaylists,
          tags: sampleTags,
          selectedTagId: 't-1',
        ),
      );
      await tester.pumpAndSettle();

      final tracksItem = find.text('Tracks');
      final playlistsItem = find.text('Playlists');
      final tagsItem = find.text('Tags');
      final playlistSubItem = find.text('Favorites');
      final tagSubItem = find.text('Audiophile');

      expect(tracksItem, findsOneWidget);
      expect(playlistsItem, findsOneWidget);
      expect(tagsItem, findsOneWidget);
      expect(playlistSubItem, findsOneWidget);
      expect(tagSubItem, findsOneWidget);

      // All main item texts share 13.0 font size
      final tracksText = tester.widget<Text>(tracksItem);
      final playlistsText = tester.widget<Text>(playlistsItem);
      final tagsText = tester.widget<Text>(tagsItem);

      expect(tracksText.style?.fontSize, equals(13.0));
      expect(playlistsText.style?.fontSize, equals(13.0));
      expect(tagsText.style?.fontSize, equals(13.0));
    },
  );

  testWidgets(
    'LyraSidebar adheres to HIG by not placing collapse toggle at sidebar bottom',
    (tester) async {
      await tester.pumpWidget(_buildSidebarTest());
      await tester.pumpAndSettle();

      expect(find.text('Collapse'), findsNothing);
      expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar in collapsed mode has 64px width and centered icons',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      await tester.pumpAndSettle();

      final sidebarFinder = find.byType(LyraSidebar);
      expect(tester.getSize(sidebarFinder).width, 64.0);

      // Text labels should be hidden
      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('PLAYLISTS'), findsNothing);
      expect(find.text('TAGS'), findsNothing);
      expect(find.text('SYSTEM'), findsNothing);
      expect(find.text('Tracks'), findsNothing);
      expect(find.text('Collapse'), findsNothing);

      // Centered icons check at dx = 31.5
      final musicIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.music),
      );
      expect(tester.getCenter(musicIcon).dx, 31.5);

      final tracksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listMusic),
      );
      expect(tester.getCenter(tracksIcon).dx, 31.5);

      final worksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.layers),
      );
      expect(tester.getCenter(worksIcon).dx, 31.5);

      final albumsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.disc),
      );
      expect(tester.getCenter(albumsIcon).dx, 31.5);

      final artistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.mic),
      );
      expect(tester.getCenter(artistsIcon).dx, 31.5);

      final playlistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listPlus),
      );
      expect(tester.getCenter(playlistsIcon).dx, 31.5);

      final tagIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.tag),
      );
      expect(tester.getCenter(tagIcon).dx, 31.5);

      final casIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.hardDrive),
      );
      expect(tester.getCenter(casIcon).dx, 31.5);

      final settingsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.settings),
      );
      expect(tester.getCenter(settingsIcon).dx, 31.5);

      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'LyraSidebar active selection item adapts dynamically between Dark and Light mode in a single frame',
    (tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildSidebarTest(
          currentTab: AppTab.tracks,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pump();

      // 1. Dark Mode: Inner Sidebar container background is zinc900 (tokens.card), active item text is zinc50
      final darkInnerContainer = tester.widget<Container>(
        find.byKey(const Key('sidebar_inner_container')),
      );
      final darkDecoration = darkInnerContainer.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(LyraColors.zinc900));

      final activeTextDark = tester.widget<Text>(find.text('Tracks'));
      expect(activeTextDark.style?.color, equals(LyraColors.zinc50));

      // Switch to Light Mode (single frame 0ms)
      themeNotifier.value = ThemeMode.light;
      await tester.pump();

      // 2. Light Mode: Sidebar background is white (Color(0xFFFFFFFF)), active item text is zinc950
      final lightInnerContainer = tester.widget<Container>(
        find.byKey(const Key('sidebar_inner_container')),
      );
      final lightDecoration = lightInnerContainer.decoration as BoxDecoration;
      expect(lightDecoration.color, equals(const Color(0xFFFFFFFF)));

      final activeTextLight = tester.widget<Text>(find.text('Tracks'));
      expect(activeTextLight.style?.color, equals(LyraColors.zinc950));
    },
  );

  testWidgets(
    'LyraSidebar AnimatedContainer uses easeInOutCubic curve with left-aligned text in expanded mode',
    (tester) async {
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pumpAndSettle();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animatedContainer.curve, equals(Curves.easeInOutCubic));
      expect(
        animatedContainer.duration,
        equals(const Duration(milliseconds: 200)),
      );

      // In expanded mode, tracks icon is left-aligned at x = 24.0 and label is left-aligned at x = 40.0
      final tracksIconExpanded = find.byIcon(LucideIcons.listMusic);
      expect(tester.getCenter(tracksIconExpanded).dx, equals(24.0));
      expect(tester.getTopLeft(find.text('Tracks')).dx, equals(40.0));

      // Rebuild in collapsed mode
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      // In collapsed mode, tracks icon is centered at x = 31.5 and text is hidden
      final tracksIconCollapsed = find.byIcon(LucideIcons.listMusic);
      expect(tester.getCenter(tracksIconCollapsed).dx, equals(31.5));
      expect(find.text('Tracks'), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar expanding from collapsed does not trigger RenderFlex overflow at intermediate widths',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to expanded mode and pump through intermediate frames
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LyraSidebar groups tags in Obsidian 2-tier structure with headers and capsules',
    (tester) async {
      final hierarchicalTags = [
        const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
        const Tag(id: 't-2', name: 'artist/rock', category: 'artist'),
        const Tag(id: 't-3', name: 'audio/low_quality', category: 'audio'),
        const Tag(id: 't-4', name: 'Audiophile', category: 'quality'),
      ];

      await tester.pumpWidget(_buildSidebarTest(tags: hierarchicalTags));
      await tester.pumpAndSettle();

      // Tier 1 group headers
      expect(find.text('# artist'), findsOneWidget);
      expect(find.text('# audio'), findsOneWidget);
      expect(find.text('# quality'), findsOneWidget);

      // Tier 2 capsule labels (subTagName)
      expect(find.text('kpop'), findsOneWidget);
      expect(find.text('rock'), findsOneWidget);
      expect(find.text('low_quality'), findsOneWidget);
      expect(find.text('Audiophile'), findsOneWidget);

      // Tooltips with full names
      expect(find.byTooltip('artist/kpop'), findsOneWidget);
      expect(find.byTooltip('audio/low_quality'), findsOneWidget);
      expect(find.byTooltip('Audiophile'), findsOneWidget);
    },
  );

  testWidgets(
    'LyraSidebar tag capsules do NOT render checkmarks and toggle visual state via capsule color',
    (tester) async {
      final tags = [
        const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
        const Tag(id: 't-2', name: 'Audiophile', category: 'quality'),
      ];

      Tag? tappedTag;
      await tester.pumpWidget(
        _buildSidebarTest(
          tags: tags,
          selectedTagId: 't-1',
          onTagSelected: (t) => tappedTag = t,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Apple HIG & Quiet Defaults: NO checkmarks, NO ticks anywhere
      expect(find.byIcon(LucideIcons.check), findsNothing);

      // 2. Active capsule (kpop) has subtle translucent primary tint (tokens.primary)
      final selectedContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('kpop'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final selectedDec = selectedContainer.decoration as BoxDecoration;
      expect(
        selectedDec.color,
        equals(LyraColors.zinc50.withValues(alpha: 0.15)),
      );
      final selectedBorder = selectedDec.border as Border?;
      expect(
        selectedBorder?.top.color,
        equals(LyraColors.zinc50.withValues(alpha: 0.65)),
      );

      final selectedText = tester.widget<Text>(find.text('kpop'));
      expect(
        selectedText.style?.color,
        equals(LyraColors.zinc50),
      ); // tokens.primary in dark mode
      expect(selectedText.style?.fontWeight, equals(FontWeight.w600));

      // 3. Inactive capsule (Audiophile) has subtle quiet secondary background
      final unselectedContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('Audiophile'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final unselectedDec = unselectedContainer.decoration as BoxDecoration;
      expect(
        unselectedDec.color,
        isNot(equals(LyraColors.zinc50.withValues(alpha: 0.15))),
      );

      final unselectedText = tester.widget<Text>(find.text('Audiophile'));
      expect(
        unselectedText.style?.color,
        equals(LyraColors.zinc400),
      ); // tokens.textMuted in dark mode
      expect(unselectedText.style?.fontWeight, equals(FontWeight.w500));

      // 4. Tapping capsule fires onTagSelected
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();
      expect(tappedTag?.id, equals('t-2'));
    },
  );

  testWidgets(
    'LyraSidebar supports selectedTagIds for multiple/set selection active styling',
    (tester) async {
      final tags = [
        const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
        const Tag(id: 't-2', name: 'audio/low_quality', category: 'audio'),
      ];

      await tester.pumpWidget(
        _buildSidebarTest(tags: tags, selectedTagIds: {'t-2'}),
      );
      await tester.pumpAndSettle();

      final lowQualityContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('low_quality'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final lqDec = lowQualityContainer.decoration as BoxDecoration;
      expect(lqDec.color, equals(LyraColors.zinc50.withValues(alpha: 0.15)));

      final kpopContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('kpop'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final kpopDec = kpopContainer.decoration as BoxDecoration;
      expect(
        kpopDec.color,
        isNot(equals(LyraColors.zinc50.withValues(alpha: 0.15))),
      );
    },
  );

  testWidgets(
    'LyraSidebar tag capsules adhere to Apple HIG geometry (28px height), full-contrast header, semantics, and keyboard activation',
    (tester) async {
      Tag? activatedTag;
      final tags = [
        const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
      ];

      await tester.pumpWidget(
        _buildSidebarTest(tags: tags, onTagSelected: (t) => activatedTag = t),
      );
      await tester.pumpAndSettle();

      // 1. Group header contrast: opacity must be 1.0 (no alpha reduction on textMuted)
      final headerTextWidget = tester.widget<Text>(find.text('# artist'));
      expect(headerTextWidget.style?.color, equals(LyraColors.zinc400));

      // 2. Capsule height must be 28.0 (GEMINI.md mandated fixed geometry)
      final capsuleFinder = find
          .ancestor(
            of: find.text('kpop'),
            matching: find.byType(AnimatedContainer),
          )
          .first;
      final capsuleSize = tester.getSize(capsuleFinder);
      expect(capsuleSize.height, equals(28.0));

      // 3. Accessibility Semantics: button = true, label = 'artist/kpop'
      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'artist/kpop',
      );
      expect(semanticsFinder, findsOneWidget);

      // 4. Keyboard activation via FocusableActionDetector
      expect(find.byType(FocusableActionDetector), findsWidgets);
      await tester.tap(find.text('kpop'));
      await tester.pumpAndSettle();
      expect(activatedTag?.id, equals('t-1'));
    },
  );

  testWidgets(
    'LyraSidebar groups and tag capsules are deterministically sorted alphabetically',
    (tester) async {
      final unsortedTags = [
        const Tag(id: 't-1', name: 'zebra/sub_z', category: 'zebra'),
        const Tag(id: 't-2', name: 'alpha/z_sub', category: 'alpha'),
        const Tag(id: 't-3', name: 'alpha/a_sub', category: 'alpha'),
      ];

      await tester.pumpWidget(_buildSidebarTest(tags: unsortedTags));
      await tester.pumpAndSettle();

      // 1. Group headers must be sorted: '# alpha' before '# zebra'
      final alphaHeaderY = tester.getTopLeft(find.text('# alpha')).dy;
      final zebraHeaderY = tester.getTopLeft(find.text('# zebra')).dy;
      expect(alphaHeaderY, lessThan(zebraHeaderY));

      // 2. Inside '# alpha', capsules must be sorted: 'a_sub' before 'z_sub'
      final aCapsuleX = tester.getTopLeft(find.text('a_sub')).dx;
      final zCapsuleX = tester.getTopLeft(find.text('z_sub')).dx;
      expect(aCapsuleX, lessThan(zCapsuleX));
    },
  );

  testWidgets(
    'LyraSidebar ignores tags whose subTagName is purely whitespace',
    (tester) async {
      final tags = [
        const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
        const _BlankSubTag(),
      ];

      await tester.pumpWidget(_buildSidebarTest(tags: tags));
      await tester.pumpAndSettle();

      expect(find.text('# artist'), findsOneWidget);
      expect(find.text('kpop'), findsOneWidget);
      expect(find.text('   '), findsNothing);
      expect(find.byType(GestureDetector), findsWidgets);
      // Verify tag capsule for blank subTagName is ignored
      expect(find.byTooltip('artist/blank'), findsNothing);
    },
  );
}

class _BlankSubTag extends Tag {
  const _BlankSubTag()
    : super(id: 't-blank', name: 'artist/blank', category: 'artist');
  @override
  String get subTagName => '   ';
}
