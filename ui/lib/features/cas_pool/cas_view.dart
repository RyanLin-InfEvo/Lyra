// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../models/cas_object.dart';

/// View displaying low-level Content Addressable Storage (CAS) blocks and SHA-256 hashes.
class CasView extends StatelessWidget {
  final List<CasObject> casObjects;
  final VoidCallback? onVerifyAll;

  const CasView({super.key, required this.casObjects, this.onVerifyAll});

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    int totalBytes = 0;
    for (final obj in casObjects) {
      totalBytes += obj.sizeBytes;
    }
    final totalSizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

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
                  Text(
                    'Content Addressable Storage',
                    style: LyraTypography.h2(tokens),
                  ),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    'Immutable, cryptographic SHA-256 chunk storage pool',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              LyraButton.outline(
                size: LyraButtonSize.sm,
                onPressed: onVerifyAll,
                leading: const Icon(LucideIcons.shieldCheck, size: 16.0),
                child: const Text('Verify All Blobs'),
              ),
            ],
          ),
        ),

        // Storage Metrics Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: LyraCard(
                  padding: const EdgeInsets.all(LyraSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BLOBS',
                        style: LyraTypography.small(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${casObjects.length}',
                        style: LyraTypography.h2(tokens),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: LyraCard(
                  padding: const EdgeInsets.all(LyraSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL CAS SIZE',
                        style: LyraTypography.small(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text('$totalSizeMb MB', style: LyraTypography.h2(tokens)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: LyraCard(
                  padding: const EdgeInsets.all(LyraSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INTEGRITY HASH',
                        style: LyraTypography.small(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        'SHA-256 (Bit-Perfect)',
                        style: LyraTypography.h3(tokens),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: LyraSpacing.lg),

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
              Expanded(
                flex: 5,
                child: Text(
                  'SHA-256 CONTENT ADDRESS',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SIZE',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'MIME TYPE',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'STATUS',
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

        // Blobs List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
            itemCount: casObjects.length,
            separatorBuilder: (context, index) => Container(
              height: 1.0,
              color: tokens.border.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              final obj = casObjects[index];
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LyraSpacing.xl,
                    vertical: LyraSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.fileCode,
                              size: 16.0,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(width: LyraSpacing.sm),
                            Expanded(
                              child: Text(
                                obj.hash,
                                style: LyraTypography.mono(
                                  tokens,
                                  fontSize: 12.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          obj.formattedSize,
                          style: LyraTypography.small(tokens),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          obj.mimeType,
                          style: LyraTypography.small(
                            tokens,
                          ).copyWith(color: tokens.textMuted),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: LyraBadge.success(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.check,
                                  size: 10.0,
                                  color: Color(0xFFFFFFFF),
                                ),
                                SizedBox(width: 4.0),
                                Text('Verified'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
