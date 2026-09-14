import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';

export 'package:forja_foundation/widgets/chrome/portals_chip.dart' show PortalsChip;

/// Layout-zone wrapper over [PortalsChip].
///
/// Host injects TV/shell focus via [interactiveBuilder]. Default uses
/// package [FocusableTap] (no `package:forja` shell).
class KitPortalsChip extends StatelessWidget {
  const KitPortalsChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.hasPortal = false,
    this.checking = false,
    this.healthy,
    this.seatsUsed,
    this.seatsMax,
    this.compact = false,
    this.accentColor,
    this.tvFocus = false,
    this.interactiveBuilder,
    this.onFocusChange,
    this.onHoverChange,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool hasPortal;
  final bool checking;
  final bool? healthy;
  final String? seatsUsed;
  final String? seatsMax;
  final bool compact;
  final Color? accentColor;
  final bool tvFocus;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;

  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
  })? interactiveBuilder;

  @override
  Widget build(BuildContext context) {
    return PortalsChip(
      label: label,
      onTap: onTap,
      selected: selected,
      hasPortal: hasPortal,
      checking: checking,
      healthy: healthy,
      seatsUsed: seatsUsed,
      seatsMax: seatsMax,
      compact: compact,
      accentColor: accentColor,
      tvFocus: tvFocus,
      onFocusChange: onFocusChange,
      onHoverChange: onHoverChange,
      interactiveBuilder: interactiveBuilder ??
          ({
            required child,
            required onTap,
            onFocusChange,
            onHoverChange,
          }) =>
              FocusableTap(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
    );
  }
}
