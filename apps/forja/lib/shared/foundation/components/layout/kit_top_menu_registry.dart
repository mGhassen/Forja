import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

import 'kit_types.dart';

/// Pack-declared `kit.menu` / `kit.tabs` hoisted into the shell top bar.
class KitTopMenuHandle {
  KitTopMenuHandle({
    required this.tabId,
    required this.selections,
    required this.widgetSpecs,
    required this.onSelect,
    this.menuSpec,
    this.tabsSpec,
  });

  final String tabId;
  final Map<String, String> selections;
  final Map<String, Map<String, dynamic>> widgetSpecs;
  final void Function(String widgetId, String value, {required bool toggle})
  onSelect;
  final Map<String, dynamic>? menuSpec;
  final Map<String, dynamic>? tabsSpec;

  bool get isEmpty => menuSpec == null && tabsSpec == null;
}

abstract final class KitTopMenuRegistry {
  KitTopMenuRegistry._();

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final Map<String, KitTopMenuHandle> _handles = {};
  static bool _deferredBumpPending = false;

  static void _scheduleRevisionBump() {
    if (_deferredBumpPending) return;
    _deferredBumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredBumpPending = false;
      revision.value++;
    });
  }

  static KitTopMenuHandle? handleFor(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty) return null;
    final handle = _handles[id];
    if (handle == null || handle.isEmpty) return null;
    return handle;
  }

  static bool hasTopMenu(String? tabId) => handleFor(tabId) != null;

  static void notifySelectionChanged(String tabId) {
    if (_handles.containsKey(tabId.trim())) revision.value++;
  }

  static void syncFromLayout({
    required String tabId,
    required List<Map<String, dynamic>> widgets,
    required Map<String, String> selections,
    required Map<String, Map<String, dynamic>> widgetSpecs,
    required void Function(String widgetId, String value, {required bool toggle})
    onSelect,
  }) {
    final id = tabId.trim();
    if (id.isEmpty) return;

    Map<String, dynamic>? menuSpec;
    Map<String, dynamic>? tabsSpec;
    walkKitWidgets(widgets, (spec) {
      final type = KitTypes.normalize(
        (spec['type'] ?? '').toString(),
        spec,
      );
      // `hoist: false` keeps menu/tabs in the page body (under kit.topBar).
      if (spec['hoist'] == false) return;
      if (type == KitTypes.menu && menuSpec == null) {
        menuSpec = Map<String, dynamic>.from(spec);
      } else if (type == KitTypes.tabs && tabsSpec == null) {
        tabsSpec = Map<String, dynamic>.from(spec);
      }
    });

    if (menuSpec == null && tabsSpec == null) {
      unregister(id);
      return;
    }

    _handles[id] = KitTopMenuHandle(
      tabId: id,
      selections: selections,
      widgetSpecs: widgetSpecs,
      onSelect: onSelect,
      menuSpec: menuSpec,
      tabsSpec: tabsSpec,
    );
    revision.value++;
  }

  static void unregister(String tabId) {
    final id = tabId.trim();
    if (id.isEmpty) return;
    if (_handles.remove(id) != null) _scheduleRevisionBump();
  }

  /// Body inset so [kit.list] clears the overlaid shell top bar
  /// ([KitTopBar] includes [MediaQuery] top padding via [SafeArea]).
  static double bodyTopInset(BuildContext context, String? tabId) {
    final handle = handleFor(tabId);
    if (handle == null) return 0;
    final safeTop = MediaQuery.paddingOf(context).top;
    final barHeight = switch (handle) {
      _ when handle.menuSpec != null && handle.tabsSpec != null =>
        ShellTokens.kitTopBarTwoRowHeight,
      _ when handle.menuSpec != null => ShellTokens.homeTopBarHeight,
      _ when handle.tabsSpec != null => ShellTokens.kitTopBarStatusRowHeight,
      _ => 0.0,
    };
    return safeTop + barHeight;
  }

  @visibleForTesting
  static void clearForTest() {
    _handles.clear();
    revision.value++;
  }
}
