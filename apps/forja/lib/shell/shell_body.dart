import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';

class ShellBody extends StatelessWidget {
  const ShellBody({
    super.key,
    required this.selectedIndex,
    required this.visibleIds,
    required this.mountedTabIds,
    required this.tabFor,
  });

  final int selectedIndex;
  final List<String> visibleIds;
  final Set<String> mountedTabIds;
  final Widget Function(String id) tabFor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.shellOverlayHasPage,
      builder: (context, overlayOpen, _) {
        return ExcludeFocus(
          excluding: overlayOpen,
          child: IndexedStack(
            index: selectedIndex,
            // Stable keys so reordering / show-hide of nav tabs does not
            // dispose and recreate other tab States (e.g. Settings category).
            children: visibleIds.map((id) {
              return KeyedSubtree(
                key: ValueKey<String>('shell-tab-$id'),
                child: mountedTabIds.contains(id)
                    ? tabFor(id)
                    : const SizedBox.shrink(),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
