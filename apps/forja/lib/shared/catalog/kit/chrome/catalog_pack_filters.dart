import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/kit/details/catalog_play_filters.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shell/shell_bus.dart';

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

      // Stale disk cache can return `{}` — bust once before freezing the menu.
      if (!forceRefresh && pack.categoryOptionCount == 0) {
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
    final media = ShellBus.hubCategoryFor(tabId).value;
    final selected = ShellBus.hubSelectedCategoryIdFor(tabId).value;
    final out = <Map<String, dynamic>?>[
      ...pack.mediaFilters(media),
      if (selected != null) ...pack.categoryFilters(selected),
    ];
    return out;
  }
}

class _PackFilters {
  const _PackFilters({
    required this.fields,
    required this.media,
    required this.genreRows,
    required this.play,
  });

  final List<_FilterField> fields;
  final _MediaFilters media;
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

  static const empty = _PackFilters(
    fields: [],
    media: _MediaFilters.empty,
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

    return _PackFilters(
      fields: fields,
      media: _MediaFilters.fromJson(
        json['media'] is Map
            ? Map<String, dynamic>.from(json['media'] as Map)
            : const {},
      ),
      genreRows: genreRows,
      play: play,
    );
  }

  List<Map<String, dynamic>?> mediaFilters(ShellHomeCategory? media) {
    return mediaFiltersForMedia(media, mediaRules: this.media);
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

List<Map<String, dynamic>?> mediaFiltersForMedia(
  ShellHomeCategory? media, {
  required _MediaFilters mediaRules,
}) {
  return switch (media) {
    ShellHomeCategory.films => mediaRules.films,
    ShellHomeCategory.tvShows => mediaRules.series,
    null => const [],
  };
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

class _MediaFilters {
  const _MediaFilters({this.films = const [], this.series = const []});

  static const empty = _MediaFilters();

  final List<Map<String, dynamic>?> films;
  final List<Map<String, dynamic>?> series;

  factory _MediaFilters.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>?> parse(dynamic raw) {
      if (raw is! Map) return const [];
      final f = CatalogFilterAst.parse(Map<String, dynamic>.from(raw));
      return f == null ? const [] : [f];
    }

    return _MediaFilters(
      films: parse(json['films']),
      series: parse(json['series']),
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
