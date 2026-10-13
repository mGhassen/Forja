import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';

/// Pack `filters` action — `play[]` choice on hub details hero.
class PlayFilterSpec {
  const PlayFilterSpec({
    required this.id,
    required this.field,
    required this.style,
    required this.options,
    this.defaultValue,
    this.source,
    this.settingsField,
  });

  final String id;
  final String field;

  /// `grouped` (single) or `multiselect`.
  final String style;
  final String? defaultValue;
  final List<PlayFilterOption> options;

  /// When `pluginLanguages`, host fills options from installed providers.
  final String? source;

  /// When set, selection persists in [PackSettingsStore] (not watch progress).
  final String? settingsField;

  bool get isMultiselect => style == 'multiselect';

  bool get isPluginLanguagesSource =>
      (source ?? '').trim().toLowerCase() == 'pluginlanguages';

  PlayFilterOption? optionByValue(String? value) {
    if (value == null) return null;
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  String? initialValue(Map<String, dynamic>? progressExtras) {
    if (isMultiselect) return null;
    if (progressExtras != null) {
      final saved = progressExtras[field]?.toString();
      if (optionByValue(saved) != null) return saved;
    }
    final def = defaultValue;
    if (def != null && optionByValue(def) != null) return def;
    return options.isEmpty ? null : options.first.value;
  }

  factory PlayFilterSpec.fromJson(Map<String, dynamic> json) {
    final opts = <PlayFilterOption>[];
    final raw = json['options'];
    if (raw is List) {
      for (final o in raw) {
        if (o is! Map) continue;
        opts.add(PlayFilterOption.fromJson(Map<String, dynamic>.from(o)));
      }
    }
    final def = (json['default'] ?? json['defaultValue'])?.toString();
    final source = (json['source'] ?? '').toString().trim();
    final settingsField = (json['settingsField'] ?? json['settings_field'] ?? '')
        .toString()
        .trim();
    return PlayFilterSpec(
      id: (json['id'] ?? json['field'] ?? '').toString(),
      field: (json['field'] ?? json['id'] ?? '').toString(),
      style: (json['style'] ?? 'grouped').toString(),
      defaultValue: def,
      options: opts,
      source: source.isEmpty ? null : source,
      settingsField: settingsField.isEmpty ? null : settingsField,
    );
  }
}

class PlayFilterOption {
  const PlayFilterOption({
    required this.id,
    required this.label,
    required this.value,
    this.icon,
  });

  final String id;
  final String label;
  final String value;
  final String? icon;

  factory PlayFilterOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['value'] ?? json['label'] ?? '').toString();
    return PlayFilterOption(
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

/// Selected play-filter values keyed by pack [field] name (e.g. `category`).
Map<String, String> catalogPlayFilterValues({
  required String pluginId,
  required Map<String, String> selections,
}) {
  final out = <String, String>{};
  for (final spec in PackFiltersRegistry.playFiltersFor(pluginId)) {
    final v = selections[spec.field];
    if (v != null && v.isNotEmpty) out[spec.field] = v;
  }
  return out;
}

String? catalogPlayAudioCategory(Map<String, String> selections) =>
    selections['category'];
