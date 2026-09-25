import 'package:forja/shared/engine/models/models.dart';
import 'package:forja_foundation/protocol/pack_capabilities.dart';

/// Shell top menu overlays the hub body. Heroes bleed under it and inset
/// their own text. Any other leading section must start below the menu.
double hubFirstSectionTopInset({
  required bool menuVisible,
  required bool leadingIsHero,
  required double menuHeight,
}) {
  if (!menuVisible || leadingIsHero || menuHeight <= 0) return 0;
  return menuHeight;
}

/// Same gate as [PluginKitTopBar]: shell menu mounts, or the body owns chrome.
bool hubShellTopBarVisible(
  EnginePlugin? plugin, {
  required bool hasVerticalFilters,
}) {
  if (plugin != null && hubLayoutOnlyBodyChrome(plugin)) return false;
  if (plugin == null) return hasVerticalFilters;
  return plugin.hasCapability(PackCapabilities.search) ||
      plugin.hasCapability(PackCapabilities.filters) ||
      hasVerticalFilters;
}

/// Layout-only hubs paint their own composition chrome in-body.
bool hubLayoutOnlyBodyChrome(EnginePlugin plugin) {
  final caps = plugin.capabilities.map((c) => c.toLowerCase()).toSet();
  if (!caps.contains('nav') || !caps.contains('layout')) return false;
  const browse = {
    'rail',
    'feed',
    'search',
    'filters',
    'host_search',
    'structured_search',
    'details',
  };
  // feed without rail/filters still browse. layout+feed+liveTv only → body chrome.
  if (caps.contains('livetv') || caps.contains('listportals')) return true;
  if (caps.contains('feed') &&
      !caps.contains('rail') &&
      !caps.contains('filters') &&
      !caps.contains('search')) {
    return true;
  }
  return caps.intersection(browse).isEmpty;
}
