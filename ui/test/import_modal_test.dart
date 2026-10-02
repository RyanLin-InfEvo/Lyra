// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_dialog.dart';
import 'package:ui/features/import/import_modal.dart';
import 'package:ui/features/models/track.dart';

Widget _buildImportModalTest({
  required VoidCallback onClose,
  Future<Track> Function({
    required String title,
    required String artist,
    required String album,
    required String format,
    required int sampleRate,
    required int bitDepth,
    required String simulatedHash,
  })?
  onImport,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final tokens = LyraThemeTokens.dark();
        final shadTheme = ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadZincColorScheme.dark(),
        );

        return ShadTheme(
          data: shadTheme,
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: Scaffold(
              body: ImportAudioModal(
                onClose: onClose,
                onImport:
                    onImport ??
                    ({
                      required title,
                      required artist,
                      required album,
                      required format,
                      required sampleRate,
                      required bitDepth,
                      required simulatedHash,
                    }) async {
                      return Track(
                        id: 'test-track',
                        title: title,
                        artistName: artist,
                        albumTitle: album,
                        durationMs: 180000,
                        format: format,
                        sampleRate: sampleRate,
                        bitDepth: bitDepth,
                        pcmHash: simulatedHash,
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
  testWidgets(
    'Clicking the X button in ImportAudioModal invokes widget.onClose',
    (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        _buildImportModalTest(
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImportAudioModal), findsOneWidget);
      expect(find.text('Import Audio to CAS Pool'), findsOneWidget);

      final closeIcon = find.descendant(
        of: find.byType(LyraDialog),
        matching: find.byIcon(LucideIcons.x),
      );
      expect(closeIcon, findsOneWidget);

      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    },
  );
}
