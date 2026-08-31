import 'models.dart';

/// Live sport plugin capability keys (`catalog` schedule, `resolve` stream).
abstract final class LiveSportCapabilities {
  static const catalog = 'catalog';
  static const resolve = 'resolve';

  /// Site-name id → legacy twin plugin ids (catalog, live resolve).
  static const legacyTwinIds = <String, (String catalog, String? resolve)>{
    'streamed': ('catalog-streamed', 'live-streamed'),
    'ppv': ('catalog-ppv', 'live-ppv'),
    'streamfree': ('catalog-streamfree', 'live-streamfree'),
    'timstreams': ('catalog-timstreams', 'live-timstreams'),
    'watchfooty': ('catalog-watchfooty', 'live-watchfooty'),
    'streamic': ('catalog-streamic', 'live-streamic'),
    'espn': ('catalog-espn', null),
  };

  static String normalizePluginId(String pluginId) {
    final id = pluginId.trim();
    if (id.startsWith('live-')) return id.substring('live-'.length);
    if (id.startsWith('catalog-')) return id.substring('catalog-'.length);
    return id;
  }

  static bool defaultEnabled(EnginePlugin plugin, String capability) {
    final cap = capability.trim().toLowerCase();
    if (cap == catalog) {
      return plugin.config['catalogEnabled'] as bool? ?? plugin.enabled;
    }
    if (cap == resolve) {
      return plugin.config['resolveEnabled'] as bool? ?? plugin.enabled;
    }
    return plugin.enabled;
  }

  static String capabilityPrefsKey(
    String sourceUrl,
    String pluginId,
    String capability,
  ) {
    final hash = EnginePack.urlHash(sourceUrl);
    final id = Uri.encodeComponent(pluginId);
    final cap = Uri.encodeComponent(capability.trim().toLowerCase());
    return 'live_cap_${hash}_${id}_$cap';
  }
}
