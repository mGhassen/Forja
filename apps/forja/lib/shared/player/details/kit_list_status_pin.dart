import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';

export 'package:forja_foundation/widgets/details/list_status_pin.dart'
    show
        ListStatusOption,
        ListStatusMenuRow,
        ListStatusPopupPanel,
        ListStatusPin,
        kListStatusOptions,
        listStatusPinColor,
        listStatusPinIcon,
        listStatusLabel;

typedef KitListStatusOption = ListStatusOption;
typedef KitListStatusMenuRow = ListStatusMenuRow;
typedef KitListStatusPopupPanel = ListStatusPopupPanel;

const kKitListStatusOptions = kListStatusOptions;

Color kitListStatusPinColor(String? status) => listStatusPinColor(status);
IconData kitListStatusPinIcon(String? status) => listStatusPinIcon(status);
String kitListStatusLabel(String? status, {String fallback = 'My List'}) =>
    listStatusLabel(status, fallback: fallback);

/// Host mapper — wires shell TV flags into [ListStatusPin].
class KitListStatusPin extends StatelessWidget {
  const KitListStatusPin({
    super.key,
    required this.currentStatus,
    required this.onSelect,
    this.options = kListStatusOptions,
    this.busy = false,
    this.iconSize,
    this.iconColor,
    this.excludeFromTvTraversal = false,
    this.menuOffset = const Offset(0, 28),
  });

  final String? currentStatus;
  final List<ListStatusOption> options;
  final Future<void> Function(String statusId) onSelect;
  final bool busy;
  final double? iconSize;
  final Color? iconColor;
  final bool excludeFromTvTraversal;
  final Offset menuOffset;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    return ListStatusPin(
      currentStatus: currentStatus,
      onSelect: onSelect,
      options: options,
      busy: busy,
      iconSize: iconSize,
      iconColor: iconColor,
      excludeFromTvTraversal: excludeFromTvTraversal,
      menuOffset: menuOffset,
      useFocusableChips: policy.useFocusableMoodChips,
      scaleOnHover: policy.scaleOnHover,
    );
  }
}
