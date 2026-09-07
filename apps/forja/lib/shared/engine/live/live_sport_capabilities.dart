import 'models.dart';

/// Live sport plugin capability keys (`catalog` schedule, `resolve` stream).
abstract final class LiveSportCapabilities {
  static const catalog = 'catalog';
  static const resolve = 'resolve';

  /// Schedule catalog rows include `sportMatchGame.broadcastChannels` for IPTV
  /// name matching (LiveOnSat, Live Soccer TV International Coverage, …).
  static const broadcast = 'broadcast';

  static String normalizePluginId(String pluginId) {
    final id = pluginId.trim();
    if (id.startsWith('live-')) return id.substring('live-'.length);
    if (id.startsWith('catalog-')) return id.substring('catalog-'.length);
    return id;
  }

  /// Whether a capability is on before the user has a stored Settings pref.
  static bool defaultEnabled(EnginePlugin plugin, String capability) {
    if (!plugin.isLiveSportPlugin) {
      return plugin.enabled;
    }
    final cap = capability.trim().toLowerCase();
    if (cap == broadcast) {
      if (!plugin.supportsLiveBroadcast) return false;
      return plugin.defaultCapabilities[cap] ?? false;
    }
    if (cap != catalog && cap != resolve) return false;
    if (cap == catalog && !plugin.supportsLiveCatalog) return false;
    if (cap == resolve && !plugin.supportsLiveResolve) return false;
    return plugin.defaultCapabilities[cap] ?? false;
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
