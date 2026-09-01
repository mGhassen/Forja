import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';

/// Pack `filters` action — `play[]` grouped choice on hub details hero.
class CatalogPlayFilterSpec {
  const CatalogPlayFilterSpec({
    required this.id,
    required this.field,
    required this.style,
    required this.options,
    this.defaultValue,
  });

  final String id;
  final String field;
  final String style;
  final String? defaultValue;
  final List<CatalogPlayFilterOption> options;

  CatalogPlayFilterOption? optionByValue(String? value) {
    if (value == null) return null;
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  String? initialValue(Map<String, dynamic>? progressExtras) {
    if (progressExtras != null) {
      final saved = progressExtras[field]?.toString();
      if (optionByValue(saved) != null) return saved;
    }
    final def = defaultValue;
    if (def != null && optionByValue(def) != null) return def;
    return options.isEmpty ? null : options.first.value;
  }

  factory CatalogPlayFilterSpec.fromJson(Map<String, dynamic> json) {
    final opts = <CatalogPlayFilterOption>[];
    final raw = json['options'];
    if (raw is List) {
      for (final o in raw) {
        if (o is! Map) continue;
        opts.add(CatalogPlayFilterOption.fromJson(Map<String, dynamic>.from(o)));
      }
    }
    final def = (json['default'] ?? json['defaultValue'])?.toString();
    return CatalogPlayFilterSpec(
      id: (json['id'] ?? json['field'] ?? '').toString(),
      field: (json['field'] ?? json['id'] ?? '').toString(),
      style: (json['style'] ?? 'grouped').toString(),
      defaultValue: def,
      options: opts,
    );
  }
}

class CatalogPlayFilterOption {
  const CatalogPlayFilterOption({
    required this.id,
    required this.label,
    required this.value,
    this.icon,
  });

  final String id;
  final String label;
  final String value;
  final String? icon;

  factory CatalogPlayFilterOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['value'] ?? json['label'] ?? '').toString();
    return CatalogPlayFilterOption(
      id: id,
      label: (json['label'] ?? id).toString(),
      value: (json['value'] ?? id).toString(),
      icon: json['icon']?.toString(),
    );
  }
}

IconData catalogPlayFilterIcon(String? token) {
  return switch (token?.trim().toLowerCase()) {
    'subtitles' || 'subtitles_rounded' => Icons.subtitles_rounded,
    'mic' || 'mic_rounded' => Icons.mic_rounded,
    _ => Icons.tune_rounded,
  };
}

/// Kit grouped play filter — renders pack `filters.play[]` with `style: grouped`.
class CatalogKitGroupedPlayFilter extends StatelessWidget {
  const CatalogKitGroupedPlayFilter({
    super.key,
    required this.spec,
    required this.selected,
    required this.onSelected,
    this.tvTabId,
    this.tvItemIndexStart,
    this.onUpEdge,
  });

  final CatalogPlayFilterSpec spec;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? tvTabId;
  final int? tvItemIndexStart;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    if (spec.style != 'grouped' || spec.options.length < 2) {
      return const SizedBox.shrink();
    }
    return HeroPillSegmentedChoice<String>(
      selected: selected,
      onSelected: onSelected,
      tvTabId: tvTabId,
      tvRowId: tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      segments: [
        for (final o in spec.options)
          HeroPillSegment(
            value: o.value,
            label: o.label,
            icon: catalogPlayFilterIcon(o.icon),
          ),
      ],
    );
  }
}

/// Selected play-filter values keyed by pack [field] name (e.g. `category`).
Map<String, String> catalogPlayFilterValues({
  required String pluginId,
  required Map<String, String> selections,
}) {
  final out = <String, String>{};
  for (final spec in CatalogPackFiltersRegistry.playFiltersFor(pluginId)) {
    final v = selections[spec.field];
    if (v != null && v.isNotEmpty) out[spec.field] = v;
  }
  return out;
}

String? catalogPlayAudioCategory(Map<String, String> selections) =>
    selections['category'];
