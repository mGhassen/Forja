import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:rust/rust.dart';

const _statuses =
    <({String id, String label, IconData icon, IconData selectedIcon})>[
  (
    id: 'plantowatch',
    label: 'Plan to Watch',
    icon: Icons.bookmark_add_outlined,
    selectedIcon: Icons.bookmark_rounded,
  ),
  (
    id: 'watching',
    label: 'Watching',
    icon: Icons.play_circle_outline_rounded,
    selectedIcon: Icons.play_circle_rounded,
  ),
  (
    id: 'hold',
    label: 'On Hold',
    icon: Icons.pause_circle_outline_rounded,
    selectedIcon: Icons.pause_circle_rounded,
  ),
  (
    id: 'completed',
    label: 'Completed',
    icon: Icons.check_circle_outline_rounded,
    selectedIcon: Icons.check_circle_rounded,
  ),
  (
    id: 'dropped',
    label: 'Dropped',
    icon: Icons.cancel_outlined,
    selectedIcon: Icons.cancel_rounded,
  ),
];

class HubListStatusHero extends StatefulWidget {
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

  static int extraFocusSlots(bool menuOpen) => menuOpen ? _statuses.length : 0;

  @override
  State<HubListStatusHero> createState() => _HubListStatusHeroState();
}

class _HubListStatusHeroState extends State<HubListStatusHero> {
  bool _open = false;
  bool _busy = false;

  IconData _plusIcon(String? status) {
    for (final s in _statuses) {
      if (s.id == status) return s.selectedIcon;
    }
    return Icons.add_rounded;
  }

  String _plusLabel(String? status) {
    for (final s in _statuses) {
      if (s.id == status) return s.label;
    }
    return 'My List';
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _busy = true);
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    final ok = await HubListFollow.setStatus(
      widget.target,
      to,
      container: container,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _open = false;
    });
    widget.onMenuOpenChanged?.call(false);
    final label = _statuses.where((s) => s.id == to).firstOrNull?.label ?? to;
    if (ok) {
      ForjaToast.success(label);
    } else {
      ForjaToast.error('Saved locally · Simkl failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId;
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(widget.target.uniqueId);
        final status = inList
            ? MyListService().statusOf(widget.target.uniqueId)
            : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroPillIconGroup(
              tvTabId: tv,
              tvRowId: tv != null ? MediaDetailsTv.heroRowId : null,
              tvItemIndexStart: widget.tvItemIndexStart,
              onUpEdge: widget.onUpEdge,
              slots: [
                HeroPillIconSlot(
                  label: _plusLabel(status),
                  icon: _plusIcon(status),
                  onTap: () {
                    final next = !_open;
                    setState(() => _open = next);
                    widget.onMenuOpenChanged?.call(next);
                  },
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(width: 10),
              HeroPillIconGroup(
                tvTabId: tv,
                tvRowId: tv != null ? MediaDetailsTv.heroRowId : null,
                tvItemIndexStart: widget.tvItemIndexStart + 1,
                onUpEdge: widget.onUpEdge,
                slots: [
                  for (final s in _statuses)
                    HeroPillIconSlot(
                      label: s.label,
                      icon: s.id == status ? s.selectedIcon : s.icon,
                      onTap: _busy ? null : () => _setStatus(s.id),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
