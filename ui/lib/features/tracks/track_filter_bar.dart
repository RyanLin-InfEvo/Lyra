// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart' show Material, Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_checkbox.dart';
import '../../design_system/widgets/lyra_input.dart';
import 'track_filter_model.dart';

/// Compact Apple-HIG-aligned toggle button for opening/closing the Tracks
/// boolean filter builder panel with fixed 28px geometry.
class TrackFilterToggleButton extends StatefulWidget {
  final bool isExpanded;
  final int activeRuleCount;
  final VoidCallback onPressed;

  const TrackFilterToggleButton({
    super.key,
    required this.isExpanded,
    required this.activeRuleCount,
    required this.onPressed,
  });

  @override
  State<TrackFilterToggleButton> createState() =>
      _TrackFilterToggleButtonState();
}

class _TrackFilterToggleButtonState extends State<TrackFilterToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final hasActiveRules = widget.activeRuleCount > 0;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final backgroundColor = widget.isExpanded || hasActiveRules
        ? tokens.primary.withValues(alpha: _isHovered ? 0.18 : 0.12)
        : (_isHovered ? tokens.secondary : tokens.surfaceElevated);
    final borderColor = widget.isExpanded || hasActiveRules
        ? tokens.primary.withValues(alpha: 0.45)
        : tokens.border;
    final foregroundColor = widget.isExpanded || hasActiveRules
        ? tokens.primary
        : tokens.text;

    return Tooltip(
      message: widget.isExpanded
          ? 'Hide filter builder'
          : 'Show filter builder',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeInOutCubic,
            constraints: const BoxConstraints(minHeight: 28.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: LyraRadius.mdRadius,
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.listFilter,
                  size: 14.0,
                  color: foregroundColor,
                ),
                const SizedBox(width: 6.0),
                Text(
                  'Filter',
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.w500,
                    color: foregroundColor,
                  ),
                ),
                if (hasActiveRules) ...[
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.0,
                      vertical: 1.0,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      '${widget.activeRuleCount}',
                      style: LyraTypography.small(tokens).copyWith(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        color: tokens.primaryForeground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4.0),
                Icon(
                  widget.isExpanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 13.0,
                  color: foregroundColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline multi-condition boolean filter builder panel implementing Scheme A:
///
/// - Top-level groups combine via `OR` (`+ Add OR Group`).
/// - Rules within each group combine via `Match ALL (AND)` or `Match ANY (OR)`.
/// - Each rule holds multi-select tokens joined by `OR` / `AND` / `NOR`.
class TrackFilterBuilderPanel extends StatefulWidget {
  final TrackFilterQuery query;
  final TrackFilterContext filterContext;
  final ValueChanged<TrackFilterQuery> onQueryChanged;

  const TrackFilterBuilderPanel({
    super.key,
    required this.query,
    required this.filterContext,
    required this.onQueryChanged,
  });

  @override
  State<TrackFilterBuilderPanel> createState() =>
      _TrackFilterBuilderPanelState();
}

class _TrackFilterBuilderPanelState extends State<TrackFilterBuilderPanel> {
  int _nextId = 0;

  String _allocId(String prefix) {
    _nextId += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_nextId';
  }

  TrackFilterRule _createBlankRule() => TrackFilterRule(
    id: _allocId('rule'),
    field: TrackFilterField.tag,
    operator: TrackFilterOperator.isAnyOf,
  );

  TrackFilterGroup _createBlankGroup() => TrackFilterGroup(
    id: _allocId('group'),
    combinator: TrackFilterCombinator.and,
    rules: [_createBlankRule()],
  );

  void _updateGroup(int groupIndex, TrackFilterGroup updated) {
    final nextGroups = List<TrackFilterGroup>.from(widget.query.groups);
    if (groupIndex >= 0 && groupIndex < nextGroups.length) {
      nextGroups[groupIndex] = updated;
    } else {
      nextGroups.add(updated);
    }
    widget.onQueryChanged(TrackFilterQuery(groups: nextGroups));
  }

  void _removeGroup(int groupIndex) {
    final nextGroups = List<TrackFilterGroup>.from(widget.query.groups);
    if (groupIndex >= 0 && groupIndex < nextGroups.length) {
      nextGroups.removeAt(groupIndex);
    }
    widget.onQueryChanged(
      nextGroups.isEmpty
          ? const TrackFilterQuery()
          : TrackFilterQuery(groups: nextGroups),
    );
  }

  void _addGroup() {
    final nextGroups = List<TrackFilterGroup>.from(widget.query.groups);
    if (nextGroups.isEmpty) {
      nextGroups.add(_createBlankGroup());
    }
    nextGroups.add(_createBlankGroup());
    widget.onQueryChanged(TrackFilterQuery(groups: nextGroups));
  }

  void _clearAll() {
    widget.onQueryChanged(const TrackFilterQuery());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final groups = widget.query.groups.isNotEmpty
        ? widget.query.groups
        : [
            const TrackFilterGroup(
              id: 'draft-group',
              combinator: TrackFilterCombinator.and,
              rules: [
                TrackFilterRule(
                  id: 'draft-rule',
                  field: TrackFilterField.tag,
                  operator: TrackFilterOperator.isAnyOf,
                ),
              ],
            ),
          ];

    return Container(
      key: const Key('track_filter_builder_panel'),
      margin: const EdgeInsets.only(
        left: LyraSpacing.xl,
        right: LyraSpacing.xl,
        bottom: LyraSpacing.md,
      ),
      padding: const EdgeInsets.all(LyraSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: LyraRadius.lgRadius,
        border: Border.all(color: tokens.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var gi = 0; gi < groups.length; gi++) ...[
            if (gi > 0) _buildGroupOrDivider(tokens),
            _TrackFilterGroupCard(
              group: groups[gi],
              filterContext: widget.filterContext,
              canRemoveGroup: groups.length > 1,
              onChanged: (updatedGroup) => _updateGroup(gi, updatedGroup),
              onRemoveGroup: () => _removeGroup(gi),
              createBlankRule: _createBlankRule,
            ),
          ],
          const SizedBox(height: LyraSpacing.sm),
          Wrap(
            spacing: LyraSpacing.sm,
            runSpacing: LyraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              LyraButton.outline(
                key: const Key('track_filter_add_group_button'),
                size: LyraButtonSize.sm,
                onPressed: _addGroup,
                leading: const Icon(LucideIcons.plus, size: 14.0),
                child: const Text('Add OR Group'),
              ),
              if (widget.query.isActive || widget.query.groups.isNotEmpty)
                LyraButton.ghost(
                  key: const Key('track_filter_clear_all_button'),
                  size: LyraButtonSize.sm,
                  onPressed: _clearAll,
                  leading: const Icon(LucideIcons.x, size: 14.0),
                  child: const Text('Clear All'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupOrDivider(LyraThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LyraSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Container(height: 1.0, color: tokens.borderSubtle)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: tokens.secondary,
                borderRadius: LyraRadius.smRadius,
                border: Border.all(color: tokens.border, width: 1.0),
              ),
              child: Text(
                'OR',
                style: LyraTypography.small(tokens).copyWith(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          Expanded(child: Container(height: 1.0, color: tokens.borderSubtle)),
        ],
      ),
    );
  }
}

class _TrackFilterGroupCard extends StatelessWidget {
  final TrackFilterGroup group;
  final TrackFilterContext filterContext;
  final bool canRemoveGroup;
  final ValueChanged<TrackFilterGroup> onChanged;
  final VoidCallback onRemoveGroup;
  final TrackFilterRule Function() createBlankRule;

  const _TrackFilterGroupCard({
    required this.group,
    required this.filterContext,
    required this.canRemoveGroup,
    required this.onChanged,
    required this.onRemoveGroup,
    required this.createBlankRule,
  });

  void _updateRule(int ruleIndex, TrackFilterRule updatedRule) {
    final nextRules = List<TrackFilterRule>.from(group.rules);
    nextRules[ruleIndex] = updatedRule;
    onChanged(group.copyWith(rules: nextRules));
  }

  void _removeRule(int ruleIndex) {
    final nextRules = List<TrackFilterRule>.from(group.rules)
      ..removeAt(ruleIndex);
    if (nextRules.isEmpty) {
      onRemoveGroup();
      return;
    }
    onChanged(group.copyWith(rules: nextRules));
  }

  void _addRule() {
    final nextRules = List<TrackFilterRule>.from(group.rules)
      ..add(createBlankRule());
    onChanged(group.copyWith(rules: nextRules));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Container(
      key: Key('track_filter_group_${group.id}'),
      padding: const EdgeInsets.all(LyraSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.card.withValues(alpha: 0.85),
        borderRadius: LyraRadius.mdRadius,
        border: Border.all(color: tokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: LyraSpacing.sm,
            runSpacing: LyraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: LyraSpacing.sm,
                runSpacing: LyraSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Combine rules:',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
                  LyraSelect<TrackFilterCombinator>(
                    key: Key('track_filter_group_combinator_${group.id}'),
                    width: 184.0,
                    popoverWidth: 196.0,
                    value: group.combinator,
                    items: const [
                      LyraSelectItem(
                        value: TrackFilterCombinator.and,
                        label: 'Match ALL (AND)',
                      ),
                      LyraSelectItem(
                        value: TrackFilterCombinator.or,
                        label: 'Match ANY (OR)',
                      ),
                    ],
                    onChanged: (nextCombinator) {
                      onChanged(group.copyWith(combinator: nextCombinator));
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: LyraSpacing.xs,
                runSpacing: LyraSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LyraButton.ghost(
                    key: Key('track_filter_add_rule_${group.id}'),
                    size: LyraButtonSize.sm,
                    onPressed: _addRule,
                    leading: const Icon(LucideIcons.plus, size: 14.0),
                    child: const Text('Add Rule'),
                  ),
                  if (canRemoveGroup)
                    LyraButton.ghost(
                      key: Key('track_filter_remove_group_${group.id}'),
                      size: LyraButtonSize.sm,
                      onPressed: onRemoveGroup,
                      leading: const Icon(LucideIcons.trash2, size: 14.0),
                      child: const Text('Remove Group'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
          for (var ri = 0; ri < group.rules.length; ri++) ...[
            if (ri > 0) const SizedBox(height: LyraSpacing.xs),
            _TrackFilterRuleRow(
              rule: group.rules[ri],
              leadingLabel: ri == 0 ? 'Where' : group.combinator.shortLabel,
              filterContext: filterContext,
              onChanged: (updatedRule) => _updateRule(ri, updatedRule),
              onRemove: () => _removeRule(ri),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackFilterRuleRow extends StatelessWidget {
  final TrackFilterRule rule;
  final String leadingLabel;
  final TrackFilterContext filterContext;
  final ValueChanged<TrackFilterRule> onChanged;
  final VoidCallback onRemove;

  const _TrackFilterRuleRow({
    required this.rule,
    required this.leadingLabel,
    required this.filterContext,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final options = filterContext.optionsForField(rule.field);

    return Container(
      key: Key('track_filter_rule_${rule.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.xs,
        vertical: 4.0,
      ),
      child: Wrap(
        spacing: LyraSpacing.sm,
        runSpacing: LyraSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 48.0,
            child: Text(
              leadingLabel,
              style: LyraTypography.small(
                tokens,
              ).copyWith(fontWeight: FontWeight.w600, color: tokens.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          LyraSelect<TrackFilterField>(
            key: Key('track_filter_rule_field_${rule.id}'),
            width: 120.0,
            popoverWidth: 136.0,
            value: rule.field,
            items: [
              for (final field in TrackFilterField.values)
                LyraSelectItem(value: field, label: field.label),
            ],
            onChanged: (nextField) {
              if (nextField == rule.field) return;
              onChanged(rule.copyWith(field: nextField, values: const []));
            },
          ),
          LyraSelect<TrackFilterOperator>(
            key: Key('track_filter_rule_operator_${rule.id}'),
            width: 124.0,
            popoverWidth: 144.0,
            value: rule.operator,
            items: [
              for (final op in rule.field.availableOperators)
                LyraSelectItem(value: op, label: op.label),
            ],
            onChanged: (nextOp) {
              onChanged(rule.copyWith(operator: nextOp));
            },
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180.0, maxWidth: 420.0),
            child: _MultiSelectTokenField(
              key: Key('track_filter_rule_values_${rule.id}'),
              field: rule.field,
              operator: rule.operator,
              selectedValues: rule.values,
              options: options,
              filterContext: filterContext,
              onChanged: (nextValues) {
                onChanged(rule.copyWith(values: nextValues));
              },
            ),
          ),
          LyraButton.ghost(
            key: Key('track_filter_remove_rule_${rule.id}'),
            size: LyraButtonSize.sm,
            onPressed: onRemove,
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
            child: Icon(LucideIcons.x, size: 14.0, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectTokenField extends StatefulWidget {
  final TrackFilterField field;
  final TrackFilterOperator operator;
  final List<String> selectedValues;
  final List<TrackFilterOption> options;
  final TrackFilterContext filterContext;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectTokenField({
    super.key,
    required this.field,
    required this.operator,
    required this.selectedValues,
    required this.options,
    required this.filterContext,
    required this.onChanged,
  });

  @override
  State<_MultiSelectTokenField> createState() => _MultiSelectTokenFieldState();
}

class _MultiSelectTokenFieldState extends State<_MultiSelectTokenField> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  final FocusNode _triggerFocusNode = FocusNode();
  final FocusNode _popoverFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool _isHovered = false;
  bool _isFocused = false;
  double _triggerWidth = 240.0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    _popoverFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _open() {
    if (_overlayController.isShowing) return;
    _searchController.clear();
    _overlayController.show();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _overlayController.isShowing) {
        _popoverFocusNode.requestFocus();
      }
    });
  }

  void _close({bool restoreFocus = true}) {
    if (!_overlayController.isShowing) return;
    _overlayController.hide();
    if (mounted) {
      setState(() {});
      if (restoreFocus) {
        _triggerFocusNode.requestFocus();
      }
    }
  }

  void _toggle() {
    if (_overlayController.isShowing) {
      _close();
    } else {
      _open();
    }
  }

  void _toggleOption(String value) {
    final next = List<String>.from(widget.selectedValues);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    widget.onChanged(next);
  }

  void _removeToken(String value) {
    final next = List<String>.from(widget.selectedValues)..remove(value);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final filteredOptions = _searchQuery.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.label.toLowerCase().contains(_searchQuery))
              .toList();

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          final viewportSize = MediaQuery.sizeOf(context);
          final width = math.min(
            viewportSize.width - 24.0,
            _triggerWidth < 220.0 ? 240.0 : _triggerWidth,
          );
          final maxPopoverHeight = math.min(260.0, viewportSize.height * 0.42);
          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: TapRegion(
                groupId: _tapRegionGroupId,
                onTapOutside: (_) => _close(restoreFocus: false),
                child: Focus(
                  focusNode: _popoverFocusNode,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _close(restoreFocus: true);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Material(
                    color: const Color(0x00000000),
                    child: Container(
                      width: math.max(160.0, width),
                      constraints: BoxConstraints(maxHeight: maxPopoverHeight),
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: tokens.card,
                        borderRadius: LyraRadius.mdRadius,
                        border: Border.all(color: tokens.border, width: 1.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 16.0,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.options.length > 5) ...[
                            LyraInput(
                              controller: _searchController,
                              placeholder:
                                  'Filter ${widget.field.label.toLowerCase()}...',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                          ],
                          if (filteredOptions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(LyraSpacing.md),
                              child: Text(
                                'No options available',
                                style: LyraTypography.small(
                                  tokens,
                                ).copyWith(color: tokens.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: filteredOptions.length,
                                itemBuilder: (context, index) {
                                  final option = filteredOptions[index];
                                  final isSelected = widget.selectedValues
                                      .contains(option.value);
                                  return _TokenOptionRow(
                                    key: Key(
                                      'track_filter_option_${option.value}',
                                    ),
                                    option: option,
                                    isSelected: isSelected,
                                    tokens: tokens,
                                    onTap: () => _toggleOption(option.value),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
              _triggerWidth = constraints.maxWidth;
            }
            return TapRegion(
              groupId: _tapRegionGroupId,
              child: Focus(
                focusNode: _triggerFocusNode,
                onFocusChange: (focused) {
                  if (mounted) {
                    setState(() => _isFocused = focused);
                  }
                },
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.escape &&
                      _overlayController.isShowing) {
                    _close(restoreFocus: true);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (!_overlayController.isShowing) {
                      _open();
                    } else if (event.logicalKey !=
                        LogicalKeyboardKey.arrowDown) {
                      _close(restoreFocus: true);
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: AnimatedContainer(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 140),
                      curve: Curves.easeInOutCubic,
                      constraints: const BoxConstraints(minHeight: 28.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (_isHovered ||
                                _overlayController.isShowing ||
                                _isFocused)
                            ? tokens.secondary
                            : tokens.secondary.withValues(alpha: 0.4),
                        borderRadius: LyraRadius.smRadius,
                        border: Border.all(
                          color:
                              (_isHovered ||
                                  _overlayController.isShowing ||
                                  _isFocused)
                              ? tokens.controlBorderHover
                              : tokens.controlBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: widget.selectedValues.isEmpty
                                ? Text(
                                    'Select ${widget.field.label.toLowerCase()}...',
                                    style: LyraTypography.small(
                                      tokens,
                                    ).copyWith(color: tokens.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Wrap(
                                    spacing: 4.0,
                                    runSpacing: 4.0,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < widget.selectedValues.length;
                                        i++
                                      ) ...[
                                        if (i > 0)
                                          Text(
                                            widget.operator.tokenJoinLabel,
                                            style: LyraTypography.small(tokens)
                                                .copyWith(
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.w700,
                                                  color: tokens.textMuted,
                                                ),
                                          ),
                                        _FilterTokenChip(
                                          key: Key(
                                            'track_filter_token_chip_${widget.selectedValues[i]}',
                                          ),
                                          label: widget.filterContext
                                              .displayLabelFor(
                                                widget.field,
                                                widget.selectedValues[i],
                                              ),
                                          onRemove: () => _removeToken(
                                            widget.selectedValues[i],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 6.0),
                          Icon(
                            _overlayController.isShowing
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 13.0,
                            color: tokens.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterTokenChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterTokenChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Container(
      padding: const EdgeInsets.only(
        left: 6.0,
        right: 3.0,
        top: 2.0,
        bottom: 2.0,
      ),
      decoration: BoxDecoration(
        color: tokens.primary.withValues(alpha: tokens.isDark ? 0.14 : 0.06),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: tokens.primary.withValues(alpha: tokens.isDark ? 0.35 : 0.18),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: LyraTypography.small(tokens).copyWith(
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3.0),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(LucideIcons.x, size: 11.0, color: tokens.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenOptionRow extends StatefulWidget {
  final TrackFilterOption option;
  final bool isSelected;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;

  const _TokenOptionRow({
    super.key,
    required this.option,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_TokenOptionRow> createState() => _TokenOptionRowState();
}

class _TokenOptionRowState extends State<_TokenOptionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isHovered ? tokens.secondary.withValues(alpha: 0.7) : null,
            borderRadius: LyraRadius.smRadius,
          ),
          child: Row(
            children: [
              LyraCheckbox(
                value: widget.isSelected,
                onChanged: (_) => widget.onTap(),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  widget.option.label,
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.text,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
