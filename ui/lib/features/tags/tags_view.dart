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
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../models/tag.dart';

/// Callback type for creating a new tag entity.
typedef CreateTagCallback =
    Future<void> Function({required String name, required String category});

/// Responsive grid view for tag catalog management, filtering, creation, and deletion.
class TagsView extends StatefulWidget {
  final List<Tag> tags;
  final Map<String, int> tagTrackCounts;
  final ValueChanged<Tag>? onTagSelected;
  final CreateTagCallback? onCreateTag;
  final ValueChanged<Tag>? onDeleteTag;

  const TagsView({
    super.key,
    required this.tags,
    this.tagTrackCounts = const {},
    this.onTagSelected,
    this.onCreateTag,
    this.onDeleteTag,
  });

  @override
  State<TagsView> createState() => _TagsViewState();
}

class _TagsViewState extends State<TagsView> {
  late final TextEditingController _searchController;
  String _selectedCategory = 'all';
  bool _showCreateDialog = false;
  Tag? _tagToDelete;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final categoriesSet = <String>{'all'};
    for (final tag in widget.tags) {
      if (tag.category.isNotEmpty) {
        categoriesSet.add(tag.category.toLowerCase());
      }
    }
    return categoriesSet.toList();
  }

  List<Tag> get _filteredTags {
    final query = _searchController.text.trim().toLowerCase();
    return widget.tags.where((tag) {
      final matchesQuery =
          query.isEmpty ||
          tag.displayName.toLowerCase().contains(query) ||
          tag.displayCategory.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'all' ||
          tag.displayCategory.toLowerCase() == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.tags.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.tag, size: 48.0, color: tokens.textMuted),
                const SizedBox(height: LyraSpacing.md),
                Text('No tags created yet', style: LyraTypography.h3(tokens)),
                const SizedBox(height: LyraSpacing.xs),
                Text(
                  'Create tags to organize and categorize audio tracks.',
                  style: LyraTypography.muted(tokens),
                ),
                const SizedBox(height: LyraSpacing.lg),
                if (widget.onCreateTag != null)
                  LyraButton(
                    onPressed: () => setState(() => _showCreateDialog = true),
                    leading: const Icon(LucideIcons.plus, size: 16.0),
                    child: const Text('Create Tag'),
                  ),
              ],
            ),
          ),
          if (_showCreateDialog) _buildCreateDialog(tokens),
        ],
      );
    }

    final filtered = _filteredTags;

    return Stack(
      children: [
        Column(
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
                      Text('Tags', style: LyraTypography.h2(tokens)),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        '${widget.tags.length} categorization labels',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Search / Filter Input
                  SizedBox(
                    width: 220.0,
                    child: LyraInput(
                      controller: _searchController,
                      placeholder: 'Filter tags...',
                      leading: Icon(
                        LucideIcons.search,
                        size: 14.0,
                        color: tokens.textMuted,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.sm),
                  if (widget.onCreateTag != null)
                    LyraButton(
                      size: LyraButtonSize.sm,
                      onPressed: () => setState(() => _showCreateDialog = true),
                      leading: const Icon(LucideIcons.plus, size: 16.0),
                      child: const Text('New Tag'),
                    ),
                ],
              ),
            ),

            // Category Filter Pills
            if (_categories.length > 2)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LyraSpacing.xl,
                  vertical: LyraSpacing.xs,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      final count = cat == 'all'
                          ? widget.tags.length
                          : widget.tags
                                .where((t) => t.category.toLowerCase() == cat)
                                .length;
                      final label = cat == 'all'
                          ? 'All ($count)'
                          : '${cat[0].toUpperCase()}${cat.substring(1)} ($count)';

                      return Padding(
                        padding: const EdgeInsets.only(right: LyraSpacing.xs),
                        child: LyraButton(
                          size: LyraButtonSize.sm,
                          variant: isSelected
                              ? LyraButtonVariant.secondary
                              : LyraButtonVariant.ghost,
                          onPressed: () =>
                              setState(() => _selectedCategory = cat),
                          child: Text(label),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Main Tag Grid / Empty Filter State
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.searchX,
                            size: 40.0,
                            color: tokens.textMuted,
                          ),
                          const SizedBox(height: LyraSpacing.md),
                          Text(
                            'No matching tags found',
                            style: LyraTypography.h4(tokens),
                          ),
                          const SizedBox(height: LyraSpacing.xs),
                          Text(
                            'Try a different search keyword or category filter.',
                            style: LyraTypography.muted(tokens),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        int crossAxisCount = 2;
                        if (width > 1200) {
                          crossAxisCount = 4;
                        } else if (width > 900) {
                          crossAxisCount = 3;
                        } else if (width > 600) {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LyraSpacing.xl,
                            vertical: LyraSpacing.sm,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: LyraSpacing.lg,
                                mainAxisSpacing: LyraSpacing.lg,
                                childAspectRatio: 1.3,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final tag = filtered[index];
                            final count = widget.tagTrackCounts[tag.id] ?? 0;
                            return _TagCard(
                              tag: tag,
                              trackCount: count,
                              tokens: tokens,
                              onTap: () => widget.onTagSelected?.call(tag),
                              onDelete: widget.onDeleteTag != null
                                  ? () => setState(() => _tagToDelete = tag)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),

        // Create Tag Dialog
        if (_showCreateDialog) _buildCreateDialog(tokens),

        // Delete Tag Confirmation Dialog
        if (_tagToDelete != null) _buildDeleteDialog(tokens),
      ],
    );
  }

  Widget _buildCreateDialog(LyraThemeTokens tokens) {
    return Container(
      color: const Color(0x80000000),
      alignment: Alignment.center,
      child: _CreateTagModal(
        tokens: tokens,
        onClose: () => setState(() => _showCreateDialog = false),
        onCreate: (name, category) async {
          setState(() => _showCreateDialog = false);
          if (widget.onCreateTag != null) {
            await widget.onCreateTag!(name: name, category: category);
          }
        },
      ),
    );
  }

  Widget _buildDeleteDialog(LyraThemeTokens tokens) {
    final tag = _tagToDelete!;
    return Container(
      color: const Color(0x80000000),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: LyraDialog(
          title: Row(
            children: [
              Icon(LucideIcons.trash2, size: 18.0, color: tokens.destructive),
              const SizedBox(width: LyraSpacing.sm),
              Text('Delete Tag', style: LyraTypography.h3(tokens)),
            ],
          ),
          description: Text(
            'Are you sure you want to delete "${tag.displayName}"? This will remove this tag from all assigned tracks.',
            style: LyraTypography.muted(tokens),
          ),
          actions: [
            LyraButton.ghost(
              size: LyraButtonSize.sm,
              onPressed: () => setState(() => _tagToDelete = null),
              child: const Text('Cancel'),
            ),
            LyraButton.destructive(
              size: LyraButtonSize.sm,
              onPressed: () {
                final toDelete = _tagToDelete;
                setState(() => _tagToDelete = null);
                if (toDelete != null && widget.onDeleteTag != null) {
                  widget.onDeleteTag!(toDelete);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagCard extends StatefulWidget {
  final Tag tag;
  final int trackCount;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _TagCard({
    required this.tag,
    required this.trackCount,
    required this.tokens,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_TagCard> createState() => _TagCardState();
}

class _TagCardState extends State<_TagCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final tag = widget.tag;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        color: tokens.secondary,
                        borderRadius: LyraRadius.mdRadius,
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.tag,
                          size: 18.0,
                          color: tokens.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    LyraBadge.secondary(
                      child: Text(tag.displayCategory.toUpperCase()),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  tag.displayName,
                  style: LyraTypography.h4(tokens),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: LyraSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.trackCount} ${widget.trackCount == 1 ? 'track' : 'tracks'}',
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted),
                    ),
                    if (widget.onDelete != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              LucideIcons.trash2,
                              size: 14.0,
                              color: _isHovered
                                  ? tokens.destructive
                                  : tokens.textMuted.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTagModal extends StatefulWidget {
  final LyraThemeTokens tokens;
  final VoidCallback onClose;
  final Future<void> Function(String name, String category) onCreate;

  const _CreateTagModal({
    required this.tokens,
    required this.onClose,
    required this.onCreate,
  });

  @override
  State<_CreateTagModal> createState() => _CreateTagModalState();
}

class _CreateTagModalState extends State<_CreateTagModal> {
  late final TextEditingController _nameController;
  String _selectedCategory = 'genre';
  bool _isCreating = false;

  final List<String> _presetCategories = const [
    'genre',
    'quality',
    'format',
    'source',
    'type',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    await widget.onCreate(name, _selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460.0),
      child: LyraDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(LyraSpacing.xs),
              decoration: BoxDecoration(
                color: tokens.secondary,
                borderRadius: LyraRadius.smRadius,
              ),
              child: Icon(LucideIcons.tag, size: 18.0, color: tokens.primary),
            ),
            const SizedBox(width: LyraSpacing.sm),
            Text('Create Tag', style: LyraTypography.h3(tokens)),
          ],
        ),
        description: Text(
          'Add a new categorization tag to label and filter tracks in your library.',
          style: LyraTypography.muted(tokens),
        ),
        actions: [
          LyraButton.ghost(
            size: LyraButtonSize.sm,
            onPressed: widget.onClose,
            child: const Text('Cancel'),
          ),
          LyraButton(
            size: LyraButtonSize.sm,
            onPressed: _isCreating ? null : _handleSubmit,
            leading: _isCreating
                ? const Icon(LucideIcons.loader2, size: 14.0)
                : const Icon(LucideIcons.check, size: 14.0),
            child: Text(_isCreating ? 'Creating...' : 'Create Tag'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: LyraSpacing.md),
            Text(
              'TAG NAME',
              style: LyraTypography.small(
                tokens,
              ).copyWith(fontWeight: FontWeight.bold, color: tokens.textMuted),
            ),
            const SizedBox(height: LyraSpacing.xs),
            LyraInput(
              controller: _nameController,
              placeholder: 'e.g. Audiophile Remaster, DSD, Jazz',
              autofocus: true,
              onSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: LyraSpacing.md),
            Text(
              'CATEGORY',
              style: LyraTypography.small(
                tokens,
              ).copyWith(fontWeight: FontWeight.bold, color: tokens.textMuted),
            ),
            const SizedBox(height: LyraSpacing.xs),
            Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children: _presetCategories.map((cat) {
                final isSel = _selectedCategory == cat;
                return LyraButton(
                  variant: isSel
                      ? LyraButtonVariant.primary
                      : LyraButtonVariant.outline,
                  size: LyraButtonSize.sm,
                  onPressed: () => setState(() => _selectedCategory = cat),
                  child: Text('${cat[0].toUpperCase()}${cat.substring(1)}'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
