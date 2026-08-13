import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/widgets/my_list_button.dart';

/// Anime / Asian Drama details — same glass **+** + floating status menu as movies.
class HubListStatusHero extends StatelessWidget {
  const HubListStatusHero({
    super.key,
    required this.target,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onMenuOpenChanged,
  });

  final HubListFollowTarget target;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final ValueChanged<bool>? onMenuOpenChanged;

  static int extraFocusSlots(bool menuOpen) =>
      ListStatusHeroControl.extraFocusSlots(menuOpen);

  Future<bool> _setStatus(BuildContext context, String to) async {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    return HubListFollow.setStatus(target, to, container: container);
  }

  @override
  Widget build(BuildContext context) {
    return ListStatusHeroControl(
      uniqueId: target.uniqueId,
      onSetStatus: (to) => _setStatus(context, to),
      tvTabId: tvTabId,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      onMenuOpenChanged: onMenuOpenChanged,
    );
  }
}
