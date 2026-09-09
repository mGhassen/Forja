import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';

/// Pack-declared Connected Services auth (RFC-102).
///
/// Host discovers enabled plugins with `settings.addon: connected_services`
/// and a non-empty `settings.auth` block. No pack-id branches.
class PackConnectedAuthSpec {
  const PackConnectedAuthSpec({
    required this.pluginId,
    required this.pluginName,
    required this.label,
    required this.order,
    this.subtitle = '',
    this.extractPluginIds = const [],
    this.kind = 'session',
  });

  final String pluginId;
  final String pluginName;
  final String label;
  final String subtitle;
  final int order;
  final String kind;
  final List<String> extractPluginIds;

  static PackConnectedAuthSpec? fromPlugin(EnginePlugin plugin) {
    final raw = plugin.settings;
    if (raw == null || raw.isEmpty) return null;
    final addon = (raw['addon'] ?? '').toString().trim();
    if (addon != SettingsAddonId.connectedServices) return null;
    final authRaw = raw['auth'];
    if (authRaw is! Map) return null;
    final auth = Map<String, dynamic>.from(authRaw);
    final label = (auth['label'] ?? raw['group'] ?? plugin.name)
        .toString()
        .trim();
    if (label.isEmpty) return null;
    final orderRaw = raw['order'] ?? auth['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse(orderRaw?.toString() ?? '') ?? 100;
    final extractIds = <String>[];
    final extractRaw = raw['extractPluginIds'] ?? raw['extract_plugin_ids'];
    if (extractRaw is List) {
      for (final e in extractRaw) {
        final id = e.toString().trim();
        if (id.isNotEmpty) extractIds.add(id);
      }
    }
    return PackConnectedAuthSpec(
      pluginId: plugin.id,
      pluginName: plugin.name,
      label: label,
      subtitle: (auth['subtitle'] ?? '').toString().trim(),
      order: order,
      kind: (auth['kind'] ?? 'session').toString().trim().toLowerCase(),
      extractPluginIds: extractIds,
    );
  }

  static List<PackConnectedAuthSpec> listEnabled(Iterable<EnginePlugin> plugins) {
    final out = <PackConnectedAuthSpec>[];
    for (final p in plugins) {
      if (!p.enabled) continue;
      final spec = fromPlugin(p);
      if (spec != null) out.add(spec);
    }
    out.sort((a, b) {
      final c = a.order.compareTo(b.order);
      if (c != 0) return c;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return out;
  }
}
