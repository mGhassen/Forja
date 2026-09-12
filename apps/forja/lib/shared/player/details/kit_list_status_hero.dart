import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja/shared/player/details/kit_list_status_pin.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/hero_pill_buttons.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja_foundation/widgets/details/list_status_hero.dart';

/// Details hero pin — host wires [ListFollow] into foundation [ListStatusHero].
class KitListStatusHero extends StatelessWidget {
  const KitListStatusHero({
    super.key,
    required this.target,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onMenuOpenChanged,
    this.enabled = true,
  });

  final ListFollowTarget target;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final ValueChanged<bool>? onMenuOpenChanged;
  final bool enabled;

  static int extraFocusSlots(bool menuOpen) =>
      ListStatusHero.extraFocusSlots(menuOpen);

  Future<bool> _setStatus(BuildContext context, String to) async {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    return ListFollow.setStatus(target, to, container: container);
  }

  @override
  Widget build(BuildContext context) {
    // Prefer the shared host control (bookmark listen + TV dismiss + toast).
    return KitListStatusControl(
      uniqueId: target.uniqueId,
      onSetStatus: (to) => _setStatus(context, to),
      tvTabId: tvTabId,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      onMenuOpenChanged: onMenuOpenChanged,
      enabled: enabled,
    );
  }
}

/// Optional props-only path (no bookmark listen) for synthetic previews.
class KitListStatusHeroPaint extends StatelessWidget {
  const KitListStatusHeroPaint({
    super.key,
    required this.currentStatus,
    required this.onSetStatus,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onMenuOpenChanged,
    this.enabled = true,
  });

  final String? currentStatus;
  final Future<bool> Function(String status) onSetStatus;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final ValueChanged<bool>? onMenuOpenChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    return ListStatusHero(
      currentStatus: currentStatus,
      onSetStatus: onSetStatus,
      enabled: enabled,
      onMenuOpenChanged: onMenuOpenChanged,
      useFocusableChips: policy.useFocusableMoodChips,
      scaleOnHover: policy.scaleOnHover,
      triggerBuilder: (context, {required status, required onTap, required menuOpen}) {
        return HeroPillIconGroup(
          tvTabId: tvTabId,
          tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: tvItemIndexStart,
          onUpEdge: onUpEdge,
          slots: [
            HeroPillIconSlot(
              label: kitListStatusLabel(status),
              iconWidget: Icon(
                kitListStatusPinIcon(status),
                size: 20,
                color: kitListStatusPinColor(status),
              ),
              onTap: onTap,
              suppressActive: menuOpen,
            ),
          ],
        );
      },
    );
  }
}
