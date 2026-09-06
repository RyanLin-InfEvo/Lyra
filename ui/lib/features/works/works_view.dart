// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../models/work.dart';

/// High-density table view of Tier 1 musical composition works.
class WorksView extends StatelessWidget {
  final List<Work> works;
  final ValueChanged<Work>? onWorkSelected;

  const WorksView({super.key, required this.works, this.onWorkSelected});

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (works.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.layers, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No musical works found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to automatically resolve musical composition works.',
              style: LyraTypography.muted(tokens),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.lg,
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Musical Works', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${works.length} compositions (Tier 1)',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              LyraBadge.secondary(child: Text('${works.length} Works')),
            ],
          ),
        ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.border, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40.0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '#',
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'COMPOSITION TITLE',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'COMPOSITION YEAR / DATE',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ISWC',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'MUSICBRAINZ ID',
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
            itemCount: works.length,
            itemExtent: 60.0,
            itemBuilder: (context, index) {
              final work = works[index];
              return _WorkRow(
                index: index + 1,
                work: work,
                onTap: () => onWorkSelected?.call(work),
                tokens: tokens,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkRow extends StatefulWidget {
  final int index;
  final Work work;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _WorkRow({
    required this.index,
    required this.work,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_WorkRow> createState() => _WorkRowState();
}

class _WorkRowState extends State<_WorkRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final work = widget.work;

    String dateText = '-';
    if (work.compositionStartYear != null) {
      if (work.compositionEndYear != null &&
          work.compositionEndYear != work.compositionStartYear) {
        dateText = '${work.compositionStartYear}–${work.compositionEndYear}';
      } else {
        dateText = '${work.compositionStartYear}';
      }
    } else if (work.compositionDateText != null) {
      dateText = work.compositionDateText!;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? tokens.secondary.withValues(alpha: 0.5) : null,
            border: Border(
              bottom: BorderSide(
                color: tokens.border.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40.0,
                child: Text(
                  '${widget.index}',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  work.title,
                  style: LyraTypography.p(
                    tokens,
                  ).copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  dateText,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                ),
              ),
              Expanded(
                flex: 3,
                child: work.iswc != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: LyraBadge.outline(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          child: Text(
                            work.iswc!,
                            style: LyraTypography.mono(tokens, fontSize: 10.0),
                          ),
                        ),
                      )
                    : Text(
                        '-',
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(color: tokens.textMuted),
                      ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    work.musicbrainzId ?? '-',
                    style: LyraTypography.mono(
                      tokens,
                      fontSize: 10.0,
                    ).copyWith(color: tokens.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
