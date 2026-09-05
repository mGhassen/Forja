import 'dart:async';

import 'package:flutter/material.dart';

import '../../protocol.dart';

/// One selectable chip in a [vertical_filters] layout widget.
class CatalogVerticalFilterOption {
  const CatalogVerticalFilterOption({
    required this.id,
    required this.label,
    required this.logo,
    required this.tileColor,
    this.inset = 0.14,
    this.forceWhiteLogo = false,
    this.filter,
  });

  final String id;
  final String label;
  final String logo;
  final Color tileColor;
  final double inset;
  final bool forceWhiteLogo;
  final Map<String, dynamic>? filter;

  factory CatalogVerticalFilterOption.fromJson(Map<String, dynamic> json) {
    return CatalogVerticalFilterOption(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? json['id'] ?? '').toString().trim(),
      logo: (json['logo'] ?? '').toString().trim(),
      tileColor: _parseColor(json['tileColor']) ?? const Color(0xFF000000),
      inset: (json['inset'] as num?)?.toDouble() ?? 0.14,
      forceWhiteLogo: json['forceWhiteLogo'] == true,
      filter: CatalogFilterAst.parse(json['filter']),
    );
  }
}

/// Layout-declared vertical filter strip for a hub tab.
class CatalogVerticalFiltersSpec {
  const CatalogVerticalFiltersSpec({
    required this.widgetId,
    required this.tabId,
    required this.pluginId,
    required this.packSourceUrl,
    required this.showSelectedInTopBar,
    required this.options,
  });

  final String widgetId;
  final String tabId;
  final String pluginId;
  final String packSourceUrl;
  final bool showSelectedInTopBar;
  final List<CatalogVerticalFilterOption> options;

  CatalogVerticalFilterOption? optionById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  factory CatalogVerticalFiltersSpec.fromWidget({
    required Map<String, dynamic> widget,
    required String tabId,
    required String pluginId,
    required String packSourceUrl,
  }) {
    final options = <CatalogVerticalFilterOption>[];
    final raw = widget['options'];
    if (raw is List) {
      for (final o in raw) {
        if (o is! Map) continue;
        final opt = CatalogVerticalFilterOption.fromJson(
          Map<String, dynamic>.from(o),
        );
        if (opt.id.isEmpty || opt.logo.isEmpty) continue;
        options.add(opt);
      }
    }
    return CatalogVerticalFiltersSpec(
      widgetId: (widget['id'] ?? 'vertical_filters').toString(),
      tabId: tabId,
      pluginId: pluginId,
      packSourceUrl: packSourceUrl,
      showSelectedInTopBar: widget['showSelectedInTopBar'] == true,
      options: options,
    );
  }
}

/// Host state for plugin-declared [vertical_filters] widgets.
abstract final class CatalogVerticalFiltersRegistry {
  CatalogVerticalFiltersRegistry._();

  static final ValueNotifier<int> revision = ValueNotifier(0);

  static const Duration menuHoverDelay = Duration(seconds: 1);
  static const Duration menuHoldDelay = Duration(milliseconds: 500);
  static const Duration menuHideDelay = Duration(seconds: 1);

  static const Object menuTapGroup = Object();

  static final Map<String, CatalogVerticalFiltersSpec> _specs = {};
  static final Map<String, ValueNotifier<bool>> _menuVisible = {};
  static final Map<String, ValueNotifier<String?>> _selectedId = {};
  static final Map<String, Timer?> _hideTimers = {};
  static bool _deferredBumpPending = false;

  static void _bump() => revision.value++;

  /// [unregister] runs from [CatalogShell.dispose] while the tree is locked.
  static void _scheduleBump() {
    if (_deferredBumpPending) return;
    _deferredBumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredBumpPending = false;
      revision.value++;
    });
  }

  static bool hasFilters(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty) return false;
    return _specs[id]?.options.isNotEmpty == true;
  }

  static CatalogVerticalFiltersSpec? specFor(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty) return null;
    return _specs[id];
  }

  static ValueNotifier<bool> menuVisibleFor(String tabId) =>
      _menuVisible.putIfAbsent(tabId, () => ValueNotifier(false));

  static ValueNotifier<String?> selectedIdFor(String tabId) =>
      _selectedId.putIfAbsent(tabId, () => ValueNotifier(null));

  static void register(CatalogVerticalFiltersSpec spec) {
    final tabId = spec.tabId;
    _specs[tabId] = spec;
    menuVisibleFor(tabId);
    selectedIdFor(tabId);
    _bump();
  }

  static void unregister(String tabId) {
    _specs.remove(tabId);
    _hideTimers[tabId]?.cancel();
    _hideTimers.remove(tabId);
    _menuVisible.remove(tabId)?.dispose();
    _selectedId.remove(tabId)?.dispose();
    _scheduleBump();
  }

  @visibleForTesting
  static void clearForTest() {
    for (final t in _hideTimers.values) {
      t?.cancel();
    }
    _hideTimers.clear();
    for (final n in _menuVisible.values) {
      n.dispose();
    }
    for (final n in _selectedId.values) {
      n.dispose();
    }
    _menuVisible.clear();
    _selectedId.clear();
    _specs.clear();
    _bump();
  }

  static void syncFromLayout({
    required String tabId,
    required String pluginId,
    required String? packSourceUrl,
    required List<Map<String, dynamic>> widgets,
  }) {
    for (final w in widgets) {
      final type = (w['type'] ?? '').toString().trim();
      if (type != 'vertical_filters' && type != 'host.vertical_filters') {
        continue;
      }
      register(
        CatalogVerticalFiltersSpec.fromWidget(
          widget: w,
          tabId: tabId,
          pluginId: pluginId,
          packSourceUrl: packSourceUrl ?? '',
        ),
      );
      return;
    }
    unregister(tabId);
  }

  static void cancelMenuHide(String tabId) {
    _hideTimers[tabId]?.cancel();
    _hideTimers[tabId] = null;
  }

  static void scheduleMenuHide(String tabId) {
    if (!menuVisibleFor(tabId).value) return;
    cancelMenuHide(tabId);
    _hideTimers[tabId] = Timer(menuHideDelay, () => hideMenu(tabId));
  }

  static void showMenu(String tabId) {
    if (!hasFilters(tabId)) return;
    cancelMenuHide(tabId);
    final n = menuVisibleFor(tabId);
    if (!n.value) n.value = true;
  }

  static void hideMenu(String tabId) {
    cancelMenuHide(tabId);
    final n = menuVisibleFor(tabId);
    if (n.value) n.value = false;
  }

  static void onNavRepress(String tabId) {
    if (!hasFilters(tabId)) return;
    final visible = menuVisibleFor(tabId).value;
    final selected = selectedIdFor(tabId).value;
    if (visible || selected != null) {
      selectedIdFor(tabId).value = null;
      hideMenu(tabId);
      return;
    }
    showMenu(tabId);
  }

  static void onTopLogoTap(String tabId) {
    if (!hasFilters(tabId)) return;
    if (!menuVisibleFor(tabId).value) {
      showMenu(tabId);
      cancelMenuHide(tabId);
      return;
    }
    selectedIdFor(tabId).value = null;
  }

  static void onLeaveTab(String tabId) => hideMenu(tabId);

  static void toggleOption(String tabId, String optionId) {
    final current = selectedIdFor(tabId).value;
    selectedIdFor(tabId).value = current == optionId ? null : optionId;
  }

  static CatalogVerticalFilterOption? selectedOptionFor(String? tabId) {
    final spec = specFor(tabId);
    if (spec == null) return null;
    return spec.optionById(selectedIdFor(spec.tabId).value);
  }

  static Map<String, dynamic>? activeFilterFor(String? tabId) {
    return selectedOptionFor(tabId)?.filter;
  }

  static int? watchProviderIdFor(String? tabId) {
    final filter = activeFilterFor(tabId);
    if (filter == null) return null;
    final value = _filterFieldValue(filter, 'watch_provider');
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed;
  }

  static Object? _filterFieldValue(Map<String, dynamic> node, String field) {
    final op = (node['op'] ?? '').toString();
    if (op == 'eq' && node['field']?.toString() == field) return node['value'];
    if (op == 'in' && node['field']?.toString() == field) {
      final values = node['values'];
      if (values is List && values.isNotEmpty) return values.first;
    }
    final children = node['children'];
    if (children is List) {
      for (final c in children) {
        if (c is! Map) continue;
        final hit = _filterFieldValue(Map<String, dynamic>.from(c), field);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  static String chromeFilterEpoch(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty) return '';
    return selectedIdFor(id).value ?? '';
  }

  static Listenable? chromeFilterListenable(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty || !hasFilters(id)) return null;
    return selectedIdFor(id);
  }
}

Color? _parseColor(Object? raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  var hex = s.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}
