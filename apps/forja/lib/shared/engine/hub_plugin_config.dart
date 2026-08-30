import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:rust/rust.dart';

/// Hub plugin manifest helpers — mirror lists, base URL activation (host-agnostic).
abstract final class HubPluginConfig {
  HubPluginConfig._();

  static Future<EnginePlugin?> catalogPluginForTab(String tabId) async {
    final want = tabId.trim();
    if (want.isEmpty) return null;
    final packs = await EngineService.instance.listPacks();
    EnginePlugin? inactive;
    for (final pack in packs) {
      for (final plugin in pack.plugins) {
        if (!plugin.isHubCatalog) continue;
        final navTab = (plugin.nav?['tabId'] ?? '').toString().trim();
        if (navTab != want) continue;
        if (pack.isPluginActive(plugin)) return plugin;
        inactive ??= plugin;
      }
    }
    return inactive;
  }

  static List<String> mirrorHostsFromConfig(Map<String, dynamic> config) {
    final mirrors = config['mirrors'];
    if (mirrors is List && mirrors.isNotEmpty) {
      return [
        for (final raw in mirrors)
          if (normalizeMirrorHost(raw.toString()).isNotEmpty)
            normalizeMirrorHost(raw.toString()),
      ];
    }
    final base = (config['base'] ?? '').toString().trim();
    if (base.isEmpty) return const [];
    return [normalizeMirrorHost(base)];
  }

  static Future<Map<String, String>> mirrorCatalogForTab(String tabId) async {
    final plugin = await catalogPluginForTab(tabId);
    final hosts = plugin == null
        ? SettingsService.asianDramaMirrorHosts
        : mirrorHostsFromConfig(plugin.config);
    final resolved = hosts.isEmpty ? SettingsService.asianDramaMirrorHosts : hosts;
    return {for (final host in resolved) host: mirrorLabel(host)};
  }

  static String mirrorLabel(String hostOrId) => normalizeMirrorHost(hostOrId);

  static String normalizeMirrorHost(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value)?.host.toLowerCase() ?? '';
    }
    return value;
  }

  static List<String> mergeMirrorOrder(List<String> enabled, Iterable<String> catalogHosts) {
    final on = enabled.map(normalizeMirrorHost).where((h) => h.isNotEmpty).toSet();
    return [
      for (final host in catalogHosts)
        if (on.contains(normalizeMirrorHost(host))) normalizeMirrorHost(host),
    ];
  }

  static String activeHostFromOrder(
    List<String> enabled,
    Iterable<String> catalogHosts,
  ) {
    final merged = mergeMirrorOrder(enabled, catalogHosts);
    if (merged.isNotEmpty) return merged.first;
    final first = catalogHosts.map(normalizeMirrorHost).firstWhere(
          (h) => h.isNotEmpty,
          orElse: () => '',
        );
    return first.isEmpty ? SettingsService.asianDramaMirrorHosts.first : first;
  }

  static List<String> toggleMirrorInOrder({
    required List<String> current,
    required Iterable<String> catalogHosts,
    required String host,
    required bool enabled,
  }) {
    final id = normalizeMirrorHost(host);
    if (enabled) {
      if (current.contains(id)) return mergeMirrorOrder(current, catalogHosts);
      return mergeMirrorOrder([...current, id], catalogHosts);
    }
    if (current.length <= 1) return mergeMirrorOrder(current, catalogHosts);
    return mergeMirrorOrder(
      current.where((h) => normalizeMirrorHost(h) != id).toList(),
      catalogHosts,
    );
  }

  static String baseUrlForHost(String hostOrId) {
    final host = normalizeMirrorHost(hostOrId);
    return 'https://$host';
  }

  static Future<void> activateMirrorBaseUrl(String baseUrl) async {
    await kisskhCatalog({'action': 'activate_base_url', 'base_url': baseUrl});
  }

  static Future<bool> probeMirrorBaseUrl(String hostOrId) async {
    final base = baseUrlForHost(hostOrId);
    if (kDebugMode) debugPrint('[HubPluginConfig] probe $base …');
    try {
      final decoded = await kisskhCatalog({
        'action': 'probe_base_url',
        'base_url': base,
      });
      return decoded['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
