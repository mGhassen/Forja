import 'dart:convert';

import 'package:rust/rust.dart';

import 'lan_client_service.dart';

/// mDNS / Rust browse for `_forja._tcp` LAN servers.
class LanDiscoveryService {
  LanDiscoveryService._();
  static final LanDiscoveryService instance = LanDiscoveryService._();

  Future<List<LanServerInfo>> discover({int timeoutMs = 3000}) async {
    if (!Engine.isReady) return const [];
    final raw = RustLib.instance.lanBrowseServersJson(timeoutMs: timeoutMs);
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => LanServerInfo.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.host.isNotEmpty && s.port > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
