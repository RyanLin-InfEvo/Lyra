// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
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
  double expandedWidth = 210.0,
  bool? showRightBorder,
  bool isResizing = false,
  ValueChanged<double>? onResizeDelta,
  VoidCallback? onResizeStart,
  VoidCallback? onResizeEnd,
  MediaQueryData? mediaQueryData,
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

        Widget scaffold = Scaffold(
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
            expandedWidth: expandedWidth,
            showRightBorder: showRightBorder,
            isResizing: isResizing,
            onResizeDelta: onResizeDelta,
            onResizeStart: onResizeStart,
            onResizeEnd: onResizeEnd,
          ),
        );

        if (mediaQueryData != null) {
          scaffold = MediaQuery(data: mediaQueryData, child: scaffold);
        }

        return ShadTheme(
          data: shadTheme,
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: scaffold,
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

      // Centered icons check at dx = 31.5 (music logo icon removed from header)
      final musicIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.music),
      );
      expect(musicIcon, findsNothing);

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

      // 1. Dark Mode: Inner Sidebar container background is charcoal900 (tokens.sidebar), active item text is softWhite
      final darkInnerContainer = tester.widget<Container>(
        find.byKey(const Key('sidebar_inner_container')),
      );
      final darkDecoration = darkInnerContainer.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(LyraColors.charcoal900));

      final activeTextDark = tester.widget<Text>(find.text('Tracks'));
      expect(activeTextDark.style?.color, equals(LyraColors.softWhite));

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
        equals(LyraColors.softWhite.withValues(alpha: 0.15)),
      );
      final selectedBorder = selectedDec.border as Border?;
      expect(
        selectedBorder?.top.color,
        equals(LyraColors.softWhite.withValues(alpha: 0.65)),
      );

      final selectedText = tester.widget<Text>(find.text('kpop'));
      expect(
        selectedText.style?.color,
        equals(LyraColors.softWhite),
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
        isNot(equals(LyraColors.softWhite.withValues(alpha: 0.15))),
      );

      final unselectedText = tester.widget<Text>(find.text('Audiophile'));
      expect(
        unselectedText.style?.color,
        equals(LyraColors.appleGray),
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
      expect(lqDec.color, equals(LyraColors.softWhite.withValues(alpha: 0.15)));

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
        isNot(equals(LyraColors.softWhite.withValues(alpha: 0.15))),
      );
    },
  );

  testWidgets(
    'LyraSidebar tag capsules adhere to Apple HIG geometry (28px height), full-contrast header, semantics, and keyboard activation',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
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
        expect(headerTextWidget.style?.color, equals(LyraColors.appleGray));

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

        final semanticsNode = tester.getSemantics(semanticsFinder);
        expect(semanticsNode.label, equals('artist/kpop'));
        expect(semanticsNode.flagsCollection.isButton, isTrue);
        expect(
          semanticsNode.flagsCollection.isFocused,
          isNot(ui.Tristate.none),
        );
        expect(
          semanticsNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );

        // 4. Keyboard activation via FocusableActionDetector
        expect(find.byType(FocusableActionDetector), findsWidgets);
        await tester.tap(find.text('kpop'));
        await tester.pumpAndSettle();
        expect(activatedTag?.id, equals('t-1'));

        Focus.of(tester.element(find.text('kpop'))).requestFocus();
        await tester.pump();

        activatedTag = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(activatedTag?.id, equals('t-1'));

        activatedTag = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(activatedTag?.id, equals('t-1'));
      } finally {
        semanticsHandle.dispose();
      }
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

  testWidgets(
    'LyraSidebar during expansion maintains constant relative tag capsule positions (zero Wrap reflow jumping)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final multiRowTags = [
        const Tag(id: 't-1', name: 'genre/Progressive Rock', category: 'genre'),
        const Tag(
          id: 't-2',
          name: 'genre/Classical Symphony',
          category: 'genre',
        ),
        const Tag(
          id: 't-3',
          name: 'genre/Ambient Electronic',
          category: 'genre',
        ),
        const Tag(id: 't-4', name: 'genre/Jazz Fusion', category: 'genre'),
      ];

      // 1. Start in collapsed mode
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: true, tags: multiRowTags),
      );
      await tester.pumpAndSettle();

      // 2. Trigger expansion
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: false, tags: multiRowTags),
      );

      // Measure at intermediate frames (40ms, 100ms, 160ms) and final (200ms)
      Offset? relativeOffsetB;
      Offset? relativeOffsetC;
      Offset? relativeOffsetD;

      for (final ms in [40, 60, 60, 40]) {
        await tester.pump(Duration(milliseconds: ms));

        final aPos = tester.getTopLeft(find.text('Ambient Electronic'));
        final bPos = tester.getTopLeft(find.text('Classical Symphony'));
        final cPos = tester.getTopLeft(find.text('Jazz Fusion'));
        final dPos = tester.getTopLeft(find.text('Progressive Rock'));

        final diffB = bPos - aPos;
        final diffC = cPos - aPos;
        final diffD = dPos - aPos;

        if (relativeOffsetB == null ||
            relativeOffsetC == null ||
            relativeOffsetD == null) {
          relativeOffsetB = diffB;
          relativeOffsetC = diffC;
          relativeOffsetD = diffD;
        } else {
          // Relative dx and dy differences must remain strictly constant across all frames
          expect(diffB.dx, closeTo(relativeOffsetB.dx, 0.01));
          expect(diffB.dy, closeTo(relativeOffsetB.dy, 0.01));
          expect(diffC.dx, closeTo(relativeOffsetC.dx, 0.01));
          expect(diffC.dy, closeTo(relativeOffsetC.dy, 0.01));
          expect(diffD.dx, closeTo(relativeOffsetD.dx, 0.01));
          expect(diffD.dy, closeTo(relativeOffsetD.dy, 0.01));
        }
      }

      await tester.pumpAndSettle();

      // Verify at 210px expanded width that at least two capsules have different dy
      final aFinal = tester.getTopLeft(find.text('Ambient Electronic'));
      final dFinal = tester.getTopLeft(find.text('Progressive Rock'));
      expect(dFinal.dy, greaterThan(aFinal.dy));

      // 3. Trigger collapse and verify relative offsets remain invariant across intermediate frames
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: true, tags: multiRowTags),
      );

      for (final ms in [40, 60, 60]) {
        await tester.pump(Duration(milliseconds: ms));

        final aPos = tester.getTopLeft(find.text('Ambient Electronic'));
        final bPos = tester.getTopLeft(find.text('Classical Symphony'));
        final cPos = tester.getTopLeft(find.text('Jazz Fusion'));
        final dPos = tester.getTopLeft(find.text('Progressive Rock'));

        final diffB = bPos - aPos;
        final diffC = cPos - aPos;
        final diffD = dPos - aPos;

        expect(diffB.dx, closeTo(relativeOffsetB!.dx, 0.01));
        expect(diffB.dy, closeTo(relativeOffsetB.dy, 0.01));
        expect(diffC.dx, closeTo(relativeOffsetC!.dx, 0.01));
        expect(diffC.dy, closeTo(relativeOffsetC.dy, 0.01));
        expect(diffD.dx, closeTo(relativeOffsetD!.dx, 0.01));
        expect(diffD.dy, closeTo(relativeOffsetD.dy, 0.01));
      }

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'LyraSidebar leading navigation icons smoothly interpolate position between 31.5 and 24.0 without snapping',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      final tracksIcon = find.byIcon(LucideIcons.listMusic);
      expect(tester.getCenter(tracksIcon).dx, equals(31.5));

      // Trigger expansion
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));

      // Frame at 40ms (curve easeInOutCubic: progress is small, dx between 24.0 and 31.5)
      await tester.pump(const Duration(milliseconds: 40));
      final dxAt40 = tester.getCenter(tracksIcon).dx;
      expect(dxAt40, lessThan(31.5));
      expect(dxAt40, greaterThan(24.0));

      // Frame at 100ms (t = 0.5, easeInOutCubic(0.5) = 0.5, dx lerp(31.5, 24.0, 0.5) = 27.75)
      await tester.pump(const Duration(milliseconds: 60)); // total 100ms
      final dxAt100 = tester.getCenter(tracksIcon).dx;
      expect(dxAt100, closeTo(27.75, 0.5));

      // Complete transition
      await tester.pumpAndSettle();
      expect(tester.getCenter(tracksIcon).dx, equals(24.0));
    },
  );

  testWidgets(
    'LyraSidebar during collapse maintains mounted labels and sub-items at intermediate frames and unmounts upon settle',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('Storage Overview'), findsOneWidget);

      // Trigger collapse
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );

      // At 50ms, labels and sub-sections must still be mounted
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('Storage Overview'), findsOneWidget);

      // At 100ms, labels and sub-sections must still be mounted
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('Storage Overview'), findsOneWidget);

      // Settle completely (controller reverses to 0.0)
      await tester.pumpAndSettle();

      // Now all labels and sub-items must be cleanly unmounted
      expect(find.text('Tracks'), findsNothing);
      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Storage Overview'), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar mid-animation collapse and expansion reversal synchronizes smoothly',
    (tester) async {
      // Expand for 100ms (isCollapsed: true -> false), then reverse to isCollapsed: true at 100ms
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      // Pump 50ms (50ms after reversal)
      await tester.pump(const Duration(milliseconds: 50));
      final widthAt50 = tester.getSize(find.byType(LyraSidebar)).width;
      expect(widthAt50, greaterThan(64.0));
      expect(widthAt50, lessThan(137.0));

      // Pump 50ms (100ms total after reversal)
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(64.0));
      expect(find.text('Tracks'), findsNothing);

      // Pump an extra 50ms and assert width stays locked at 64.0 (no post-completion double-tween)
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(64.0));

      // Collapse for 100ms (isCollapsed: false -> true), then reverse to isCollapsed: false at 100ms
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(210.0));

      // Pump an extra 50ms and assert width stays locked at 210.0
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(210.0));
    },
  );

  testWidgets(
    'LyraSidebar drag resize lifecycle cancels cleanly on collapse and mid-animation resizing snaps',
    (tester) async {
      bool resizeEnded = false;
      bool isCollapsed = false;
      late StateSetter stateSetter;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            stateSetter = setState;
            return _buildSidebarTest(
              isCollapsed: isCollapsed,
              onResizeDelta: (_) {},
              onResizeEnd: () {
                setState(() {
                  resizeEnded = true;
                });
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('sidebar_resize_handle'))),
      );
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();

      // Rebuild with isCollapsed: true while drag is active via setState in parent
      stateSetter(() {
        isCollapsed = true;
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(resizeEnded, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      // Toggle back to isCollapsed: false, pump 40ms, assert dx is mid-interpolation (> 24.0 && < 31.5)
      stateSetter(() {
        isCollapsed = false;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final dxAt40 = tester.getCenter(find.byIcon(LucideIcons.listMusic)).dx;
      expect(dxAt40, lessThan(31.5));
      expect(dxAt40, greaterThan(24.0));
      await tester.pumpAndSettle();

      // Mid-animation snap: trigger expansion (isCollapsed: true -> false), pump 40ms
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pump(const Duration(milliseconds: 40));

      // Rebuild with isResizing: true (isCollapsed: false)
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: false, isResizing: true),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(210.0));
      expect(
        tester.getCenter(find.byIcon(LucideIcons.listMusic)).dx,
        equals(24.0),
      );
    },
  );

  testWidgets(
    'LyraSidebar during collapse excludes pointer events, focus, and semantics from collapsing content',
    (tester) async {
      bool playlistSelected = false;
      bool tagSelected = false;

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          playlists: samplePlaylists,
          tags: sampleTags,
          onPlaylistSelected: (_) => playlistSelected = true,
          onTagSelected: (_) => tagSelected = true,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger collapse, pump 50ms so collapsible content is still mounted
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
          onPlaylistSelected: (_) => playlistSelected = true,
          onTagSelected: (_) => tagSelected = true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Audiophile'), findsOneWidget);
      expect(find.byKey(const Key('playlists_header_chevron')), findsOneWidget);

      await tester.tap(find.text('Favorites'), warnIfMissed: false);
      await tester.tap(find.text('Audiophile'), warnIfMissed: false);
      await tester.tap(
        find.byKey(const Key('playlists_header_chevron')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(playlistSelected, isFalse);
      expect(tagSelected, isFalse);

      expect(
        find.byWidgetPredicate((w) => w is ExcludeFocus && w.excluding == true),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ExcludeSemantics && w.excluding == true,
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();

      // Rebuild with isCollapsed: false and verify 'Favorites' is still visible (proving the chevron tap during collapse was ignored)
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          playlists: samplePlaylists,
          tags: sampleTags,
          onPlaylistSelected: (_) => playlistSelected = true,
          onTagSelected: (_) => tagSelected = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
    },
  );

  testWidgets('LyraSidebar clamps expandedWidth below 64.0 without throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSidebarTest(isCollapsed: false, expandedWidth: 40.0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(LyraSidebar)).width, equals(64.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'LyraSidebar chevron semantics, keyboard activation, and button padding with sub-items',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: false, playlists: samplePlaylists),
      );
      await tester.pumpAndSettle();

      // MED-1: Verify button padding has right: 28.0 when hasSubItems: true in expanded mode
      final playlistsButton = tester.widget<LyraButton>(
        find.widgetWithText(LyraButton, 'Playlists'),
      );
      final padding = playlistsButton.padding as EdgeInsets;
      expect(padding.right, equals(28.0));

      // MED-1: Verify chevron semantics
      final chevronFinder = find.byKey(const Key('playlists_header_chevron'));
      expect(chevronFinder, findsOneWidget);

      final expandedSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: chevronFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.button == true,
          ),
        ),
      );
      expect(expandedSemantics.properties.label, equals('Collapse Playlists'));

      // Verify unfocused border has transparent color with 1.0 width (fixed geometry 24x24)
      final unfocusedChevronContainer = tester.widget<Container>(
        find.descendant(of: chevronFinder, matching: find.byType(Container)),
      );
      final unfocusedDecoration =
          unfocusedChevronContainer.decoration as BoxDecoration?;
      expect(unfocusedDecoration, isNotNull);
      expect(unfocusedDecoration?.border, isNotNull);
      expect(
        unfocusedDecoration!.border!.top.color,
        equals(const Color(0x00000000)),
      );
      expect(unfocusedDecoration.border!.top.width, equals(1.0));
      expect(
        tester.getSize(
          find.descendant(of: chevronFinder, matching: find.byType(Container)),
        ),
        equals(const Size(24.0, 24.0)),
      );

      // Keyboard activation via Enter/Space
      Focus.of(tester.element(chevronFinder)).requestFocus();
      await null;
      await tester.pump();

      final chevronContainer = tester.widget<Container>(
        find.descendant(of: chevronFinder, matching: find.byType(Container)),
      );
      final decoration = chevronContainer.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration?.border, isNotNull);
      expect(decoration!.border!.top.color, equals(LyraColors.softWhite));
      expect(decoration.border!.top.width, equals(1.0));
      expect(
        tester.getSize(
          find.descendant(of: chevronFinder, matching: find.byType(Container)),
        ),
        equals(const Size(24.0, 24.0)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final collapsedSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: chevronFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.button == true,
          ),
        ),
      );
      expect(collapsedSemantics.properties.label, equals('Expand Playlists'));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      final reexpandedSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: chevronFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.button == true,
          ),
        ),
      );
      expect(
        reexpandedSemantics.properties.label,
        equals('Collapse Playlists'),
      );
    },
  );

  testWidgets(
    'LyraSidebar collapsed nav items have tooltips and icons have semantic labels',
    (tester) async {
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Tracks'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);

      final tracksIconWidget = tester.widget<Icon>(
        find.byIcon(LucideIcons.listMusic),
      );
      expect(tracksIconWidget.semanticLabel, equals('Tracks'));
    },
  );

  testWidgets(
    'LyraSidebar reduced motion disables animation settling instantly in 0ms',
    (tester) async {
      const sampleTags = [
        Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
      ];

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          tags: sampleTags,
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          tags: sampleTags,
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump(); // single frame 0ms

      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(210.0));
      expect(
        tester.getCenter(find.byIcon(LucideIcons.listMusic)).dx,
        equals(24.0),
      );

      final tagCapsuleAnimatedContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('kpop'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(tagCapsuleAnimatedContainer.duration, equals(Duration.zero));

      // Dynamic disableAnimations toggle mid-animation
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          mediaQueryData: const MediaQueryData(disableAnimations: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          mediaQueryData: const MediaQueryData(disableAnimations: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50)); // mid-animation

      // Update mediaQueryData to disableAnimations: true mid-flight
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump(); // single frame

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(210.0));
    },
  );

  testWidgets(
    'LyraSidebar collapsed mode centers icons at 32px when showRightBorder is false',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(isCollapsed: true, showRightBorder: false),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.byIcon(LucideIcons.listMusic)).dx,
        equals(32.0),
      );
    },
  );

  testWidgets(
    'LyraSidebar responsive layout keeps chevrons and tags within bounds at expandedWidth 160.0',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          expandedWidth: 160.0,
          playlists: const [
            Playlist(id: 'pl-1', title: 'Favorites', trackIds: ['1']),
          ],
          tags: const [
            Tag(id: 't-1', name: 'genre/Progressive Rock', category: 'genre'),
            Tag(id: 't-2', name: 'genre/Classical Symphony', category: 'genre'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(LyraSidebar)).width, equals(160.0));
      expect(
        tester
            .getTopRight(find.byKey(const Key('playlists_header_chevron')))
            .dx,
        lessThanOrEqualTo(160.0),
      );
      expect(
        tester.getTopRight(find.text('Progressive Rock')).dx,
        lessThanOrEqualTo(160.0),
      );
      expect(
        tester.getTopRight(find.text('Classical Symphony')).dx,
        lessThanOrEqualTo(160.0),
      );
      expect(tester.takeException(), isNull);

      // Tap chevron at 160.0px width to collapse playlists and verify 'Favorites' collapses to findsNothing
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();
      expect(find.text('Favorites'), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar updates tag groups when tags list is mutated in-place across rebuilds',
    (tester) async {
      final hostKey = GlobalKey<_MutatingTagsHostState>();
      await tester.pumpWidget(_MutatingTagsHost(key: hostKey));
      await tester.pumpAndSettle();

      expect(find.text('kpop'), findsOneWidget);
      expect(find.text('jazz'), findsNothing);

      hostKey.currentState!.addJazz();
      await tester.pumpAndSettle();

      expect(find.text('jazz'), findsOneWidget);
    },
  );

  testWidgets(
    'Selected sidebar tag capsule uses softer tint and border in Light Mode',
    (tester) async {
      final lightTokens = LyraThemeTokens.light();
      await tester.pumpWidget(
        _buildSidebarTest(
          themeNotifier: ValueNotifier<ThemeMode>(ThemeMode.light),
          tags: const [
            Tag(id: 't-1', name: 'genre/ambient', category: 'genre'),
          ],
          selectedTagId: 't-1',
        ),
      );
      await tester.pumpAndSettle();

      final capsuleContainer = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('ambient'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is AnimatedContainer &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).borderRadius != null,
              ),
            )
            .first,
      );
      final decoration = capsuleContainer.decoration! as BoxDecoration;
      expect(
        decoration.color,
        equals(lightTokens.primary.withValues(alpha: 0.06)),
      );
      expect(
        (decoration.border! as Border).top.color,
        equals(lightTokens.primary.withValues(alpha: 0.28)),
      );
    },
  );
}

class _MutatingTagsHost extends StatefulWidget {
  const _MutatingTagsHost({super.key});

  @override
  State<_MutatingTagsHost> createState() => _MutatingTagsHostState();
}

class _MutatingTagsHostState extends State<_MutatingTagsHost> {
  final List<Tag> tags = [
    const Tag(id: 't-1', name: 'artist/kpop', category: 'artist'),
  ];

  void addJazz() {
    setState(() {
      tags.add(const Tag(id: 't-2', name: 'artist/jazz', category: 'artist'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildSidebarTest(tags: tags);
  }
}

class _BlankSubTag extends Tag {
  const _BlankSubTag()
    : super(id: 't-blank', name: 'artist/blank', category: 'artist');
  @override
  String get subTagName => '   ';
}
