import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/services/follow/list_follow.dart';
import 'package:forja/shared/foundation/services/follow/kit_list_status_button.dart';

/// Details hero pin — same glass **+** + floating status menu as movie rows.
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
      KitListStatusControl.extraFocusSlots(menuOpen);

  Future<bool> _setStatus(BuildContext context, String to) async {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    return ListFollow.setStatus(target, to, container: container);
  }

  @override
  Widget build(BuildContext context) {
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
