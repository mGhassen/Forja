import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// KissKH mirror host selection — settings / engine activation only.
abstract final class KissKhMirror {
  KissKhMirror._();

  static const primaryBaseUrl = 'https://kisskh.co';
  static const defaultMirrorHost = 'kisskh.co';

  static const mirrorHosts = <String>[
    'kisskh.co',
    'kisskh.nl',
    'kisskh.ovh',
    'kisskh.la',
    'kisskh.do',
    'kisskh.is',
    'kisskh.id',
  ];

  static Map<String, String> get settingsCatalog => {
        for (final host in mirrorHosts) host: mirrorLabel(host),
      };

  static List<String> mergeMirrorOrder(List<String> enabled) {
    final on = enabled.map(normalizeMirrorId).toSet();
    return [
      for (final host in mirrorHosts)
        if (on.contains(host)) host,
    ];
  }

  static String activeHostFromOrder(List<String> enabled) {
    final merged = mergeMirrorOrder(enabled);
    return merged.isEmpty ? defaultMirrorHost : merged.first;
  }

  static List<String> toggleMirrorInOrder({
    required List<String> current,
    required String host,
    required bool enabled,
  }) {
    final id = normalizeMirrorId(host);
    if (enabled) {
      if (current.contains(id)) return mergeMirrorOrder(current);
      return mergeMirrorOrder([...current, id]);
    }
    if (current.length <= 1) return mergeMirrorOrder(current);
    return mergeMirrorOrder(current.where((h) => h != id).toList());
  }

  static Future<String> ensureActiveMirrorFromSettings() async {
    final order = await SettingsService().getEnabledAsianDramaProviderOrder();
    final host = activeHostFromOrder(order);
    await activateEndpoint(baseUrlForHost(host));
    return host;
  }

  static String mirrorLabel(String hostOrId) => normalizeMirrorId(hostOrId);

  static String normalizeMirrorId(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'kisskh') return 'kisskh.co';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value)?.host.toLowerCase() ?? 'kisskh.co';
    }
    return value;
  }

  static bool isMirrorHost(String id) {
    return mirrorHosts.contains(normalizeMirrorId(id));
  }

  static String baseUrlForHost(String hostOrId) {
    return 'https://${normalizeMirrorId(hostOrId)}';
  }

  static Future<void> activateEndpoint(String baseUrl) async {
    await kisskhCatalog({'action': 'activate_base_url', 'base_url': baseUrl});
  }

  static Future<bool> probeMirror(String hostOrId) async {
    final base = baseUrlForHost(hostOrId);
    debugPrint('[KissKhMirror] probe $base …');
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
