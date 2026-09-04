import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/kit/details/catalog_play_filters.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shell/shell_bus.dart';

/// One pack-declared top-bar menu tab (`filters.menus[]`).
class CatalogChromeMenuItem {
  const CatalogChromeMenuItem({
    required this.id,
    required this.label,
    this.filter,
    this.hideTypeFilterRails = false,
  });

  final String id;
  final String label;
  final Map<String, dynamic>? filter;

  /// When selected, hide layout rails marked `hideWhenTypeFilter`.
  final bool hideTypeFilterRails;
}

/// Pack-declared `filters` action — loaded per [pluginId], no tab/product names.
class CatalogPackFiltersRegistry {
  CatalogPackFiltersRegistry._();

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final Map<String, _PackFilters> _byPlugin = {};
  static final Set<String> _loaded = {};
  static final Map<String, Future<void>> _inflight = {};

  @visibleForTesting
  static void seedFromJson(String pluginId, Map<String, dynamic> json) {
    final id = pluginId.trim();
    _byPlugin[id] = _PackFilters.fromJson(json);
    _loaded.add(id);
    revision.value++;
  }

  @visibleForTesting
  static void clearForTest() {
    _byPlugin.clear();
    _loaded.clear();
    _inflight.clear();
    revision.value++;
  }

  /// Drop cached pack filters (pack install / refresh / enable).
  static void invalidate([String? pluginId]) {
    if (pluginId != null) {
      final id = pluginId.trim();
      _byPlugin.remove(id);
      _loaded.remove(id);
      _inflight.remove(id);
    } else {
      _byPlugin.clear();
      _loaded.clear();
      _inflight.clear();
    }
    revision.value++;
  }

  static Future<void> ensureLoaded(String pluginId, {bool force = false}) async {
    final id = pluginId.trim();
    if (id.isEmpty) return;
    if (force) {
      _loaded.remove(id);
      _inflight.remove(id);
    } else if (_loaded.contains(id)) {
      return;
    }
    final pending = _inflight[id];
    if (pending != null) return pending;

    final future = _load(id, forceRefresh: force);
    _inflight[id] = future;
    return future;
  }

  static Future<void> _load(
    String pluginId, {
    bool forceRefresh = false,
  }) async {
    try {
      final env = await CatalogRuntime.instance.run(
        pluginId: pluginId,
        action: 'filters',
        params: const {},
        forceRefresh: forceRefresh,
      );
      if (!env.ok) return;
      final data = env.data;
      final pack = _PackFilters.fromJson(
        data is Map ? Map<String, dynamic>.from(data as Map) : const {},
      );
      _byPlugin[pluginId] = pack;

      // Stale disk cache can return `{}` — bust once before freezing chrome.
      if (!forceRefresh && pack.isChromeEmpty) {
        await _load(pluginId, forceRefresh: true);
        return;
      }

      _loaded.add(pluginId);
      revision.value++;
    } catch (_) {
      // Transient — do not cache empty; next [ensureLoaded] retries.
    } finally {
      _inflight.remove(pluginId);
    }
  }

  /// Pack `filters.menus[]` — arbitrary toggle tabs (any count / labels).
  static List<CatalogChromeMenuItem> menusFor(String pluginId) {
    return (_byPlugin[pluginId] ?? _PackFilters.empty).menus;
  }

  static CatalogChromeMenuItem? menuById(String pluginId, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final m in menusFor(pluginId)) {
      if (m.id == id) return m;
    }
    return null;
  }

  static List<({String id, String label})> categoriesFor(String pluginId) {
    final pack = _byPlugin[pluginId] ?? _PackFilters.empty;
    return [
      for (final f in pack.fields)
        for (final o in f.options)
          if (o.showInMenu) (id: o.id, label: o.label),
    ];
  }

  static List<CatalogPlayFilterSpec> playFiltersFor(String pluginId) {
    return (_byPlugin[pluginId] ?? _PackFilters.empty).play;
  }

  static List<
      ({
        String id,
        String label,
        List<int> movieGenres,
        List<int> tvGenres,
      })> genreRowsFor(String pluginId) {
    return (_byPlugin[pluginId] ?? _PackFilters.empty).genreRows;
  }

  static ({List<int> movieGenres, List<int> tvGenres})? lookupGenreRow(
    String pluginId,
    String? id,
  ) {
    if (id == null) return null;
    for (final row in genreRowsFor(pluginId)) {
      if (row.id == id) {
        return (movieGenres: row.movieGenres, tvGenres: row.tvGenres);
      }
    }
    return null;
  }

  static List<Map<String, dynamic>?> activeFilters({
    required String pluginId,
    required String? tabId,
  }) {
    final pack = _byPlugin[pluginId] ?? _PackFilters.empty;
    if (tabId == null) return const [];
    final menuId = ShellBus.hubSelectedMenuIdFor(tabId).value;
    final selected = ShellBus.hubSelectedCategoryIdFor(tabId).value;
    final out = <Map<String, dynamic>?>[
      ...pack.menuFilters(menuId),
      if (selected != null) ...pack.categoryFilters(selected),
    ];
    return out;
  }

  /// True when the selected pack menu asks to hide `hideWhenTypeFilter` rails.
  static bool selectedMenuHidesTypeFilterRails({
    required String pluginId,
    required String? tabId,
  }) {
    if (tabId == null) return false;
    final menu = menuById(pluginId, ShellBus.hubSelectedMenuIdFor(tabId).value);
    return menu?.hideTypeFilterRails == true;
  }
}

class _PackFilters {
  const _PackFilters({
    required this.menus,
    required this.fields,
    required this.genreRows,
    required this.play,
  });

  final List<CatalogChromeMenuItem> menus;
  final List<_FilterField> fields;
  final List<
      ({
        String id,
        String label,
        List<int> movieGenres,
        List<int> tvGenres,
      })> genreRows;
  final List<CatalogPlayFilterSpec> play;

  int get categoryOptionCount => [
    for (final f in fields)
      for (final o in f.options)
        if (o.showInMenu) o,
  ].length;

  bool get isChromeEmpty =>
      menus.isEmpty && categoryOptionCount == 0 && play.isEmpty;

  static const empty = _PackFilters(
    menus: [],
    fields: [],
    genreRows: [],
    play: [],
  );

  factory _PackFilters.fromJson(Map<String, dynamic> json) {
    final fields = <_FilterField>[];
    final rawFields = json['fields'];
    if (rawFields is List) {
      for (final f in rawFields) {
        if (f is! Map) continue;
        fields.add(_FilterField.fromJson(Map<String, dynamic>.from(f)));
      }
    }
    final genreRows = <({
      String id,
      String label,
      List<int> movieGenres,
      List<int> tvGenres,
    })>[];
    final rawGenreRows = json['genreRows'];
    if (rawGenreRows is List) {
      for (final row in rawGenreRows) {
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);
        genreRows.add((
          id: (m['id'] ?? '').toString(),
          label: (m['label'] ?? m['id'] ?? '').toString(),
          movieGenres: _intList(m['movieGenres']),
          tvGenres: _intList(m['tvGenres']),
        ));
      }
    }
    final play = <CatalogPlayFilterSpec>[];
    final rawPlay = json['play'];
    if (rawPlay is List) {
      for (final row in rawPlay) {
        if (row is! Map) continue;
        play.add(CatalogPlayFilterSpec.fromJson(Map<String, dynamic>.from(row)));
      }
    }

    var menus = <CatalogChromeMenuItem>[];
    final rawMenus = json['menus'];
    if (rawMenus is List) {
      for (final row in rawMenus) {
        if (row is! Map) continue;
        final item = _menuFromJson(Map<String, dynamic>.from(row));
        if (item != null) menus.add(item);
      }
    }
    // Legacy `media.films` / `media.series` → menus (until packs migrate).
    if (menus.isEmpty && json['media'] is Map) {
      menus = _menusFromLegacyMedia(Map<String, dynamic>.from(json['media'] as Map));
    }

    return _PackFilters(
      menus: menus,
      fields: fields,
      genreRows: genreRows,
      play: play,
    );
  }

  List<Map<String, dynamic>?> menuFilters(String? menuId) {
    if (menuId == null || menuId.isEmpty) return const [];
    for (final m in menus) {
      if (m.id == menuId && m.filter != null) return [m.filter];
    }
    return const [];
  }

  List<Map<String, dynamic>?> categoryFilters(String selectedId) {
    for (final field in fields) {
      for (final opt in field.options) {
        if (opt.id == selectedId) {
          final filter = opt.filter ??
              (opt.value != null
                  ? catalogFilterFromSelection(
                      field: field.field,
                      value: opt.value,
                    )
                  : null);
          return filter == null ? const [] : [filter];
        }
      }
    }
    return const [];
  }
}

CatalogChromeMenuItem? _menuFromJson(Map<String, dynamic> json) {
  final id = (json['id'] ?? json['label'] ?? '').toString().trim();
  if (id.isEmpty) return null;
  return CatalogChromeMenuItem(
    id: id,
    label: (json['label'] ?? id).toString(),
    filter: CatalogFilterAst.parse(json['filter']),
    hideTypeFilterRails: json['hideTypeFilterRails'] == true ||
        json['hideWhenTypeFilter'] == true,
  );
}

List<CatalogChromeMenuItem> _menusFromLegacyMedia(Map<String, dynamic> media) {
  final out = <CatalogChromeMenuItem>[];
  final films = CatalogFilterAst.parse(media['films']);
  if (films != null) {
    out.add(
      CatalogChromeMenuItem(
        id: 'films',
        label: 'Films',
        filter: films,
        hideTypeFilterRails: true,
      ),
    );
  }
  final series = CatalogFilterAst.parse(media['series']);
  if (series != null) {
    final label = (media['seriesLabel'] ?? 'Series').toString();
    out.add(
      CatalogChromeMenuItem(
        id: 'series',
        label: label.isEmpty ? 'Series' : label,
        filter: series,
        hideTypeFilterRails: true,
      ),
    );
  }
  return out;
}

class _FilterField {
  _FilterField({
    required this.field,
    required this.options,
  });

  final String field;
  final List<_FilterOption> options;

  factory _FilterField.fromJson(Map<String, dynamic> json) {
    final opts = <_FilterOption>[];
    final raw = json['options'];
    if (raw is List) {
      for (final o in raw) {
        if (o is! Map) continue;
        opts.add(_FilterOption.fromJson(Map<String, dynamic>.from(o)));
      }
    }
    return _FilterField(
      field: (json['field'] ?? 'genre').toString(),
      options: opts,
    );
  }
}

class _FilterOption {
  _FilterOption({
    required this.id,
    required this.label,
    this.value,
    this.filter,
    this.showInMenu = true,
  });

  final String id;
  final String label;
  final dynamic value;
  final Map<String, dynamic>? filter;
  final bool showInMenu;

  factory _FilterOption.fromJson(Map<String, dynamic> json) {
    return _FilterOption(
      id: (json['id'] ?? json['label'] ?? '').toString(),
      label: (json['label'] ?? json['id'] ?? '').toString(),
      value: json['value'],
      filter: CatalogFilterAst.parse(json['filter']),
      showInMenu: json['menu'] != false && json['categoriesMenu'] != false,
    );
  }
}

List<int> _intList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final v in raw)
      if (v is num) v.toInt(),
  ];
}
