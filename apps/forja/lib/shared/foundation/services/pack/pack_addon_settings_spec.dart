import 'package:forja/shared/engine/models/models.dart';

/// One select option for a pack Addon settings field.
class PackAddonSettingsOption {
  const PackAddonSettingsOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Typed field declared under plugin `settings.fields[]` (RFC-089).
enum PackAddonSettingsFieldType { toggle, select, text, multiSelect }

class PackAddonSettingsField {
  const PackAddonSettingsField({
    required this.id,
    required this.type,
    required this.label,
    this.subtitle = '',
    this.defaultBool = false,
    this.defaultString = '',
    this.defaultStringList = const [],
    this.options = const [],
  });

  final String id;
  final PackAddonSettingsFieldType type;
  final String label;
  final String subtitle;
  final bool defaultBool;
  final String defaultString;
  /// Default selected ids for [PackAddonSettingsFieldType.multiSelect].
  final List<String> defaultStringList;
  final List<PackAddonSettingsOption> options;

  static PackAddonSettingsField? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    final typeRaw = (j['type'] ?? '').toString().trim().toLowerCase();
    final type = switch (typeRaw) {
      'toggle' => PackAddonSettingsFieldType.toggle,
      'select' => PackAddonSettingsFieldType.select,
      'text' => PackAddonSettingsFieldType.text,
      'multi_select' || 'multiselect' || 'chips' =>
        PackAddonSettingsFieldType.multiSelect,
      _ => null,
    };
    if (type == null) return null;
    final label = (j['label'] ?? id).toString().trim();
    final subtitle = (j['subtitle'] ?? '').toString().trim();
    final options = <PackAddonSettingsOption>[];
    final rawOpts = j['options'];
    if (rawOpts is List) {
      for (final e in rawOpts) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final oid = (m['id'] ?? '').toString().trim();
        if (oid.isEmpty) continue;
        final olabel = (m['label'] ?? oid).toString().trim();
        options.add(PackAddonSettingsOption(id: oid, label: olabel));
      }
    }
    if ((type == PackAddonSettingsFieldType.select ||
            type == PackAddonSettingsFieldType.multiSelect) &&
        options.isEmpty) {
      return null;
    }
    final def = j['default'];
    var defaultStringList = const <String>[];
    if (def is List) {
      defaultStringList = [
        for (final e in def)
          if (e.toString().trim().isNotEmpty) e.toString().trim(),
      ];
    } else if (def is String && def.trim().isNotEmpty) {
      defaultStringList = [
        for (final p in def.split(','))
          if (p.trim().isNotEmpty) p.trim(),
      ];
    } else if (type == PackAddonSettingsFieldType.multiSelect) {
      defaultStringList = [for (final o in options) o.id];
    }
    return PackAddonSettingsField(
      id: id,
      type: type,
      label: label.isEmpty ? id : label,
      subtitle: subtitle,
      defaultBool: def == true,
      defaultString: def == null
          ? (options.isNotEmpty ? options.first.id : '')
          : (def is List ? defaultStringList.join(',') : def.toString()),
      defaultStringList: defaultStringList,
      options: options,
    );
  }
}

/// Parsed plugin `settings` contribution for an Addons detail slot.
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
  final String addonId;
  final String group;
  final int order;
  final List<PackAddonSettingsField> fields;

  /// Parses [plugin.settings] when the block targets a known addon and has fields.
  static PackAddonSettingsSpec? fromPlugin(EnginePlugin plugin) {
    final raw = plugin.settings;
    if (raw == null || raw.isEmpty) return null;
    final addonId = (raw['addon'] ?? '').toString().trim();
    if (addonId.isEmpty) return null;
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
      if (spec == null || spec.addonId != want) continue;
      out.add(spec);
    }
    out.sort((a, b) {
      final c = a.order.compareTo(b.order);
      if (c != 0) return c;
      return a.pluginName.compareTo(b.pluginName);
    });
    return out;
  }
}
