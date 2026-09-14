import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/shell/shell_bus.dart';

/// Thin Riverpod adapters over [ShellBus] ValueNotifiers (Phase 1 coexistence).
/// Screens may keep listening to ShellBus directly until fully migrated.

final shellRequestTabProvider = NotifierProvider<ShellRequestTabNotifier, String?>(
  ShellRequestTabNotifier.new,
);

class ShellRequestTabNotifier extends Notifier<String?> {
  @override
  String? build() {
    final n = ShellBus.requestTab;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

final shellChromeRevisionProvider =
    NotifierProvider<ShellChromeRevisionNotifier, int>(
  ShellChromeRevisionNotifier.new,
);

class ShellChromeRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = ShellBus.shellChromeRevision;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}
