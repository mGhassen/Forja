import 'package:forja/shared/engine/models/models.dart';

class PackAddonSettingsOption {
  const PackAddonSettingsOption({required this.id, required this.label});

  final String id;
  final String label;
}

enum PackAddonSettingsFieldType { toggle, select, text, multiSelect }

class PackAddonSettingsField {
  const PackAddonSettingsField({
    required this.id,
    required this.label,
    required this.type,
    this.subtitle = '',
    this.defaultBool = false,
    this.defaultString = '',
    this.defaultStringList = const [],
    this.options = const [],
  });

  final String id;
  final String label;
  final PackAddonSettingsFieldType type;
  final String subtitle;
  final bool defaultBool;
  final String defaultString;

  /// Default selected ids for [PackAddonSettingsFieldType.multiSelect].
  final List<String> defaultStringList;
  final List<PackAddonSettingsOption> options;

  static PackAddonSettingsField? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString().trim();
    final label = (j['label'] ?? '').toString().trim();
    if (id.isEmpty || label.isEmpty) return null;
    final typeRaw = (j['type'] ?? '').toString().trim().toLowerCase();
    final type = switch (typeRaw) {
      'toggle' => PackAddonSettingsFieldType.toggle,
      'select' => PackAddonSettingsFieldType.select,
      'text' => PackAddonSettingsFieldType.text,
      'multi_select' || 'chips' || 'multiselect' =>
        PackAddonSettingsFieldType.multiSelect,
      _ => null,
    };
    if (type == null) return null;

    final options = <PackAddonSettingsOption>[];
    final optsRaw = j['options'];
    if (optsRaw is List) {
      for (final o in optsRaw) {
        if (o is! Map) continue;
        final oid = (o['id'] ?? '').toString().trim();
        final olabel = (o['label'] ?? oid).toString().trim();
        if (oid.isEmpty) continue;
        options.add(PackAddonSettingsOption(id: oid, label: olabel));
      }
    }
    if ((type == PackAddonSettingsFieldType.select ||
            type == PackAddonSettingsFieldType.multiSelect) &&
        options.isEmpty) {
      return null;
    }

    final subtitle = (j['subtitle'] ?? '').toString();
    var defaultBool = false;
    var defaultString = '';
    var defaultStringList = const <String>[];
    final def = j['default'];
    if (type == PackAddonSettingsFieldType.toggle) {
      defaultBool = def == true;
    } else if (type == PackAddonSettingsFieldType.multiSelect) {
      if (def is List) {
        defaultStringList = [
          for (final e in def) e.toString().trim(),
        ].where((s) => s.isNotEmpty).toList();
      }
    } else {
      defaultString = def?.toString() ?? '';
    }
    return PackAddonSettingsField(
      id: id,
      label: label,
      type: type,
      subtitle: subtitle,
      defaultBool: defaultBool,
      defaultString: defaultString,
      defaultStringList: defaultStringList,
      options: options,
    );
  }
}

class PackAddonSettingsSpec {
  const PackAddonSettingsSpec({
    required this.pluginId,
    required this.pluginName,
    required this.addonId,
    required this.group,
    required this.order,
    required this.fields,
  });

  final String pluginId;
  final String pluginName;

  /// Optional host Addon id (RFC-089). Empty when settings render under Forja Packs.
  final String addonId;
  final String group;
  final int order;
  final List<PackAddonSettingsField> fields;

  /// Parses [plugin.settings] when the block has fields.
  ///
  /// [addon] is optional (RFC-093) — used only when contributing into a host
  /// Addon detail page via [listForAddon].
  static PackAddonSettingsSpec? fromPlugin(EnginePlugin plugin) {
    final raw = plugin.settings;
    if (raw == null || raw.isEmpty) return null;
    final fieldsRaw = raw['fields'];
    if (fieldsRaw is! List || fieldsRaw.isEmpty) return null;
    final fields = <PackAddonSettingsField>[];
    for (final e in fieldsRaw) {
      if (e is! Map) continue;
      final field = PackAddonSettingsField.fromJson(
        Map<String, dynamic>.from(e),
      );
      if (field != null) fields.add(field);
    }
    if (fields.isEmpty) return null;
    final addonId = (raw['addon'] ?? '').toString().trim();
    final groupRaw = (raw['group'] ?? '').toString().trim();
    final orderRaw = raw['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse(orderRaw?.toString() ?? '') ?? 100;
    return PackAddonSettingsSpec(
      pluginId: plugin.id,
      pluginName: plugin.name,
      addonId: addonId,
      group: groupRaw.isNotEmpty ? groupRaw : plugin.name,
      order: order,
      fields: fields,
    );
  }

  /// Specs for [addonId] from enabled plugins (sorted by [order] then name).
  ///
  /// Matches `settings.addon` or, when addon is omitted, [pluginId] == [addonId].
  static List<PackAddonSettingsSpec> listForAddon(
    Iterable<EnginePlugin> plugins, {
    required String addonId,
  }) {
    final want = addonId.trim();
    if (want.isEmpty) return const [];
    final out = <PackAddonSettingsSpec>[];
    for (final p in plugins) {
      if (!p.enabled) continue;
      final spec = fromPlugin(p);
      if (spec == null) continue;
      final bucket =
          spec.addonId.isNotEmpty ? spec.addonId : p.id;
      if (bucket != want) continue;
      out.add(spec);
    }
    return _sorted(out);
  }

  /// Specs for plugins in a pack expand (enabled or not — pack row owns gate).
  static List<PackAddonSettingsSpec> listForPlugins(
    Iterable<EnginePlugin> plugins,
  ) {
    final out = <PackAddonSettingsSpec>[];
    for (final p in plugins) {
      final spec = fromPlugin(p);
      if (spec == null) continue;
      out.add(spec);
    }
    return _sorted(out);
  }

  /// Distinct non-empty `settings.addon` ids from enabled plugins (RFC-089).
  ///
  /// Used to invent Addons rows for pack-only buckets (not in the host catalog).
  static List<PackAddonSettingsSpec> listContributingEnabled(
    Iterable<EnginePlugin> plugins,
  ) {
    final out = <PackAddonSettingsSpec>[];
    for (final p in plugins) {
      if (!p.enabled) continue;
      final spec = fromPlugin(p);
      if (spec == null || spec.addonId.isEmpty) continue;
      out.add(spec);
    }
    return _sorted(out);
  }

  static List<PackAddonSettingsSpec> _sorted(List<PackAddonSettingsSpec> out) {
    out.sort((a, b) {
      final c = a.order.compareTo(b.order);
      if (c != 0) return c;
      return a.pluginName.compareTo(b.pluginName);
    });
    return out;
  }
}
