// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../controllers/audio_device_controller.dart';
import '../models/audio_device.dart';

/// Interactive button and popover menu for inspecting and switching audio output devices.
class AudioDeviceButton extends StatefulWidget {
  final AudioDeviceController controller;

  const AudioDeviceButton({super.key, required this.controller});

  @override
  State<AudioDeviceButton> createState() => _AudioDeviceButtonState();
}

class _AudioDeviceButtonState extends State<AudioDeviceButton> {
  late final ShadPopoverController _popoverController;

  @override
  void initState() {
    super.initState();
    _popoverController = ShadPopoverController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AudioDeviceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _popoverController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  IconData _iconForDevice(AudioDevice? device) {
    final name = (device?.name ?? '').toLowerCase();
    if (name.contains('headphone') ||
        name.contains('earphone') ||
        name.contains('airpod')) {
      return LucideIcons.headphones;
    }
    return LucideIcons.speaker;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final currentDevice = widget.controller.currentDevice;
    final iconData = _iconForDevice(currentDevice);

    return ShadPopover(
      controller: _popoverController,
      closeOnTapOutside: true,
      padding: EdgeInsets.zero,
      shadows: const [],
      decoration: const ShadDecoration(
        canMerge: false,
        border: ShadBorder.none,
        focusedBorder: ShadBorder.none,
        errorBorder: ShadBorder.none,
        secondaryBorder: ShadBorder.none,
        secondaryFocusedBorder: ShadBorder.none,
        secondaryErrorBorder: ShadBorder.none,
        disableSecondaryBorder: true,
      ),
      // The popover anchor is configured so that followerAnchor is bottomLeft and
      // targetAnchor is topRight, placing the overlay to the left of the button.
      // Offset (-8, -12) shifts it leftwards to ensure it does not stick flush
      // against the right screen border, and floats 12px above the player bar.
      anchor: const ShadAnchorAuto(
        offset: Offset(-8.0, -12.0),
        followerAnchor: Alignment.bottomLeft,
        targetAnchor: Alignment.topRight,
      ),
      popover: (popoverContext) {
        return _buildPopoverContent(context, tokens);
      },
      child: Tooltip(
        message: 'Audio Output: ${currentDevice?.name ?? 'System Audio'}',
        child: LyraButton.ghost(
          size: LyraButtonSize.sm,
          width: 28.0,
          height: 28.0,
          padding: EdgeInsets.zero,
          onPressed: () => _popoverController.toggle(),
          child: Icon(iconData, size: 18.0, color: tokens.text),
        ),
      ),
    );
  }

  Widget _buildPopoverContent(BuildContext context, LyraThemeTokens tokens) {
    final devices = widget.controller.devices;
    final currentId = widget.controller.currentDeviceId;

    return Container(
      width: 312.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: tokens.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24.0,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 6.0,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.speaker, size: 16.0, color: tokens.textMuted),
                const SizedBox(width: 8.0),
                Text(
                  'Audio Output',
                  style: LyraTypography.p(tokens).copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1.0,
            color: tokens.border,
            margin: const EdgeInsets.only(top: 4.0, bottom: 6.0),
          ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: LyraSpacing.md,
              ),
              child: Text(
                'No output devices found',
                style: LyraTypography.muted(tokens).copyWith(fontSize: 13.0),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...devices.map((device) {
              final isSelected = device.id == currentId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: _DeviceItem(
                  device: device,
                  isSelected: isSelected,
                  tokens: tokens,
                  icon: _iconForDevice(device),
                  onTap: () {
                    widget.controller.selectDevice(device.id);
                    _popoverController.hide();
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DeviceItem extends StatefulWidget {
  final AudioDevice device;
  final bool isSelected;
  final LyraThemeTokens tokens;
  final IconData icon;
  final VoidCallback onTap;

  const _DeviceItem({
    required this.device,
    required this.isSelected,
    required this.tokens,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DeviceItem> createState() => _DeviceItemState();
}

class _DeviceItemState extends State<_DeviceItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isSelected = widget.isSelected;

    final String specDetails;
    if (widget.device.maxSampleRate >= 1000) {
      specDetails =
          '${widget.device.maxSampleRate ~/ 1000}kHz • ${widget.device.maxChannels}ch';
    } else {
      specDetails = '${widget.device.maxChannels}ch';
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? tokens.secondary
                : (isSelected
                      ? tokens.secondary.withValues(alpha: 0.6)
                      : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18.0,
                color: isSelected ? tokens.primary : tokens.textMuted,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.device.name,
                      style: LyraTypography.p(tokens).copyWith(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: tokens.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      widget.device.isDefault
                          ? '$specDetails • Default'
                          : specDetails,
                      style: LyraTypography.muted(
                        tokens,
                      ).copyWith(fontSize: 11.5, height: 1.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8.0),
                Icon(LucideIcons.check, size: 16.0, color: tokens.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
