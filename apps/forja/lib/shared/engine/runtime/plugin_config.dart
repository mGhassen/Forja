import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/runtime/service.dart';

/// Hub plugin manifest helpers — opaque tab → plugin lookup (host-agnostic).
///
/// Mirror activate/probe lives on the pack via [MetaRuntime]; do not hardcode
/// hub tab ids or SettingsService drama host lists here (RFC-109).
abstract final class HubPluginConfig {
  HubPluginConfig._();

  /// First kit plugin whose pack `nav.tabId` (or host nav id) matches [tabId].
  static Future<EnginePlugin?> catalogPluginForTab(String tabId) async {
    final want = tabId.trim();
    if (want.isEmpty) return null;
    final packs = await EngineService.instance.listPacks();
    EnginePlugin? inactive;
    for (final pack in packs) {
      for (final plugin in pack.plugins) {
        if (!plugin.isKitPlugin) continue;
        final navTab = (plugin.nav?['tabId'] ?? '').toString().trim();
        if (navTab.isEmpty) continue;
        final hostId = PluginRegistry.hostNavId(
          sourceUrl: pack.sourceUrl,
          authorTabId: navTab,
        );
        if (navTab != want && hostId != want) continue;
        if (pack.isPluginActive(plugin)) return plugin;
        inactive ??= plugin;
      }
    }
    return inactive;
  }
}
