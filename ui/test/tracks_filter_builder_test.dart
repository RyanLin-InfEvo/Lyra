// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_select.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/tracks/tracks_view.dart';

class _StatefulFilterHarness extends StatefulWidget {
  final List<Track> allTracks;
  final TrackFilterContext filterContext;

  const _StatefulFilterHarness({
    required this.allTracks,
    required this.filterContext,
  });

  @override
  State<_StatefulFilterHarness> createState() => _StatefulFilterHarnessState();
}

class _StatefulFilterHarnessState extends State<_StatefulFilterHarness> {
  TrackFilterQuery _query = const TrackFilterQuery();

  @override
  Widget build(BuildContext context) {
    final visible = _query.apply(widget.allTracks, widget.filterContext);
    return TracksView(
      tracks: visible,
      currentTrack: null,
      isPlaying: false,
      filterQuery: _query,
      filterContext: widget.filterContext,
      onFilterQueryChanged: (q) => setState(() => _query = q),
      onTrackSelected: (_) {},
      onTogglePlay: () {},
    );
  }
}

Widget _wrapFilterTest(Widget child, {ThemeMode themeMode = ThemeMode.dark}) {
  final isDark = themeMode == ThemeMode.dark;
  final themeNotifier = ValueNotifier<ThemeMode>(themeMode);
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  const factory = ShadcnFactory();
  final shadTheme = ShadThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: isDark
        ? const ShadZincColorScheme.dark()
        : const ShadZincColorScheme.light(),
  );

  return ShadApp(
    title: 'Tracks Filter Builder Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeNotifier,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  const allTracks = [
    Track(
      id: 't1',
      title: 'Track One',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      genre: 'Jazz',
      format: 'FLAC',
    ),
    Track(
      id: 't2',
      title: 'Track Two',
      artistName: 'Eagles',
      albumTitle: 'Hell Freezes Over',
      genre: 'Rock',
      format: 'ALAC',
    ),
    Track(
      id: 't3',
      title: 'Track Three',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      genre: 'Jazz',
      format: 'DSD',
    ),
  ];

  const tags = [
    Tag(id: 'tag-a', name: 'tagA', category: 'mood'),
    Tag(id: 'tag-b', name: 'TagB', category: 'mood'),
  ];

  const playlists = [
    Playlist(id: 'pl-c', title: 'PlaylistC', trackIds: ['t1', 't2']),
    Playlist(id: 'pl-d', title: 'PlaylistD', trackIds: ['t3']),
  ];

  final filterContext = TrackFilterContext.fromLibrary(
    tracks: allTracks,
    tags: tags,
    playlists: playlists,
    taggedTrackIdsByTag: {
      'tag-a': {'t1', 't3'},
      'tag-b': {'t2'},
    },
  );

  testWidgets(
    'TracksView filter builder toggles cleanly and builds (tagA OR TagB) AND PlaylistC interactively',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapFilterTest(
          _StatefulFilterHarness(
            allTracks: allTracks,
            filterContext: filterContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially panel is collapsed and all 3 tracks visible
      expect(find.byKey(const Key('track_filter_builder_panel')), findsNothing);
      expect(find.text('3 tracks'), findsOneWidget);

      // Expand Filter Builder panel
      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('track_filter_builder_panel')),
        findsOneWidget,
      );

      // Open multi-select value picker for the draft rule (Field defaults to Tag, Operator isAnyOf)
      await tester.tap(
        find.byKey(const Key('track_filter_rule_values_draft-rule')),
      );
      await tester.pumpAndSettle();

      // Select tagA and TagB inside popover without closing it after tagA
      await tester.tap(find.text('tagA').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TagB').last);
      await tester.pumpAndSettle();

      // Dismiss popover by clicking outside (on Filter title)
      await tester.tap(find.text('Tracks Library'));
      await tester.pumpAndSettle();

      // Both tagA and TagB match all 3 tracks
      expect(find.text('3 tracks'), findsOneWidget);

      // Add a second rule inside the same AND group and pick Playlist -> PlaylistC
      await tester.tap(find.text('Add Rule'));
      await tester.pumpAndSettle();

      // Second rule field dropdown defaults to Tag; tap the 2nd rule field selector and switch to Playlist
      final fieldSelectors = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_field_',
            ),
      );
      expect(fieldSelectors, findsNWidgets(2));
      await tester.tap(fieldSelectors.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playlist').last);
      await tester.pumpAndSettle();

      // Pick PlaylistC on second rule
      final valueSelectors = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_values_',
            ),
      );
      await tester.tap(valueSelectors.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PlaylistC').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tracks Library'));
      await tester.pumpAndSettle();

      // Track Three is excluded because it is only in PlaylistD
      expect(find.text('2 tracks'), findsOneWidget);
      expect(find.text('Track One'), findsOneWidget);
      expect(find.text('Track Two'), findsOneWidget);
      expect(find.text('Track Three'), findsNothing);

      // Add OR Group -> adds a new OR branch; set its field to Format -> DSD so Track Three comes back!
      await tester.tap(
        find.byKey(const Key('track_filter_add_group_button')).first,
      );
      await tester.pumpAndSettle();

      final fieldSelectorsAfter = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_field_',
            ),
      );
      expect(fieldSelectorsAfter, findsNWidgets(3));
      await tester.tap(fieldSelectorsAfter.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();

      final valueSelectorsAfter = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_values_',
            ),
      );
      await tester.tap(valueSelectorsAfter.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DSD').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracks Library'));
      await tester.pumpAndSettle();

      expect(find.text('3 tracks'), findsOneWidget);
      expect(find.text('Track Three'), findsOneWidget);

      // Clear All restores clean state and hides Clear All button
      await tester.tap(
        find.byKey(const Key('track_filter_clear_all_button')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 tracks'), findsOneWidget);
      expect(
        find.byKey(const Key('track_filter_clear_all_button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TracksView keeps filter builder panel visible and recoverable when 0 tracks match on narrow viewport',
    (tester) async {
      tester.view.physicalSize = const Size(640, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapFilterTest(
          _StatefulFilterHarness(
            allTracks: allTracks,
            filterContext: filterContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();

      // Switch field to Format and operator to isNoneOf, select FLAC/ALAC/DSD -> 0 tracks
      await tester.tap(
        find.byKey(const Key('track_filter_rule_field_draft-rule')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();

      final opSelector = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_operator_',
            ),
      );
      await tester.tap(opSelector.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('is none of').last);
      await tester.pumpAndSettle();

      final valSelector = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_values_',
            ),
      );
      await tester.tap(valSelector.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track_filter_option_FLAC')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track_filter_option_ALAC')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track_filter_option_DSD')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracks Library'));
      await tester.pumpAndSettle();

      expect(find.text('0 tracks'), findsOneWidget);
      expect(find.text('No matching tracks found'), findsOneWidget);
      expect(
        find.byKey(const Key('track_filter_builder_panel')),
        findsOneWidget,
      );

      // Clear filter recovers all 3 tracks
      await tester.tap(
        find.byKey(const Key('track_filter_clear_all_button')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 tracks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing the last rule in the only group resets cleanly instead of leaving an empty group',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapFilterTest(
          _StatefulFilterHarness(
            allTracks: allTracks,
            filterContext: filterContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();

      // Switch field to Format and select DSD (1 track)
      await tester.tap(
        find.byKey(const Key('track_filter_rule_field_draft-rule')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();

      final valSelector = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_rule_values_',
            ),
      );
      await tester.tap(valSelector.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track_filter_option_DSD')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracks Library'));
      await tester.pumpAndSettle();
      expect(find.text('1 tracks'), findsOneWidget);

      // Removing the only rule resets to clean inactive state with fresh draft rule
      final removeButtons = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'track_filter_remove_rule_',
            ),
      );
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('3 tracks'), findsOneWidget);
      expect(
        find.byKey(const Key('track_filter_rule_field_draft-rule')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('track_filter_clear_all_button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TracksView filter builder does not overflow at 2.0x text scale with multiple OR groups on 640x600',
    (tester) async {
      tester.view.physicalSize = const Size(640, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _wrapFilterTest(
          _StatefulFilterHarness(
            allTracks: allTracks,
            filterContext: filterContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('track_filter_add_group_button')).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('track_filter_builder_panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Multi-select token field supports keyboard Enter open and Escape close without search input',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapFilterTest(
          _StatefulFilterHarness(
            allTracks: allTracks,
            filterContext: filterContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();

      // Open via keyboard focus on the token field and Enter key
      final tokenFieldFinder = find.byKey(
        const Key('track_filter_rule_values_draft-rule'),
      );
      final focusFinder = find.descendant(
        of: tokenFieldFinder,
        matching: find.byType(Focus),
      );
      expect(focusFinder, findsWidgets);

      final focusWidget = tester.widget<Focus>(focusFinder.first);
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('track_filter_option_tag-a')),
        findsOneWidget,
      );

      // Escape closes the popover immediately even when options <= 5 (no search input)
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('track_filter_option_tag-a')), findsNothing);
    },
  );

  testWidgets(
    'LyraSelect outside tap onto a TextField does not steal focus back to trigger',
    (tester) async {
      final textFocus = FocusNode();
      addTearDown(textFocus.dispose);

      await tester.pumpWidget(
        _wrapFilterTest(
          Column(
            children: [
              LyraSelect<String>(
                key: const Key('test_lyra_select'),
                value: 'a',
                items: const [
                  LyraSelectItem(value: 'a', label: 'Alpha'),
                  LyraSelectItem(value: 'b', label: 'Beta'),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 160),
              TextField(
                key: const Key('outside_text_field'),
                focusNode: textFocus,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('test_lyra_select')));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.byKey(const Key('outside_text_field')));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
      expect(textFocus.hasFocus, isTrue);
    },
  );

  testWidgets(
    'Light mode filter token chip uses softer neutral tint instead of heavy dark alpha',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final lightTokens = LyraThemeTokens.light();
      final query = TrackFilterQuery(
        groups: [
          TrackFilterGroup(
            id: 'g1',
            rules: [
              TrackFilterRule(
                id: 'r1',
                field: TrackFilterField.tag,
                operator: TrackFilterOperator.isAnyOf,
                values: const ['tag-a'],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapFilterTest(
          themeMode: ThemeMode.light,
          TracksView(
            tracks: allTracks,
            currentTrack: null,
            isPlaying: false,
            filterQuery: query,
            filterContext: filterContext,
            onFilterQueryChanged: (_) {},
            onTrackSelected: (_) {},
            onTogglePlay: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();

      final chipContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('track_filter_token_chip_tag-a')),
          matching: find.byType(Container),
        ),
      );
      final decoration = chipContainer.decoration! as BoxDecoration;
      expect(
        decoration.color,
        equals(lightTokens.primary.withValues(alpha: 0.06)),
      );
      expect(
        (decoration.border! as Border).top.color,
        equals(lightTokens.primary.withValues(alpha: 0.18)),
      );
    },
  );

  testWidgets(
    'Dark mode multi-select token field uses visible charcoal700 idle border',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapFilterTest(
          themeMode: ThemeMode.dark,
          TracksView(
            tracks: allTracks,
            currentTrack: null,
            isPlaying: false,
            filterQuery: const TrackFilterQuery(),
            filterContext: filterContext,
            onFilterQueryChanged: (_) {},
            onTrackSelected: (_) {},
            onTogglePlay: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracks_filter_toggle_button')));
      await tester.pumpAndSettle();

      final fieldContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('track_filter_rule_values_draft-rule')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = fieldContainer.decoration! as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        equals(LyraColors.charcoal700),
      );
    },
  );
}
