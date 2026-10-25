import 'dart:convert';

import 'package:forja/shared/platform/platform_channel.dart';
import 'package:rust/rust.dart';

class LanServerInfo {
  const LanServerInfo({
    required this.serverId,
    required this.host,
    required this.port,
    this.version,
  });

  final String serverId;
  final String host;
  final int port;
  final String? version;

  factory LanServerInfo.fromJson(Map<String, dynamic> json) => LanServerInfo(
    serverId: json['server_id']?.toString() ?? '',
    host: json['host']?.toString() ?? '',
    port: (json['port'] as num?)?.toInt() ?? 0,
    version: json['version']?.toString(),
  );

  Uri get baseUri => Uri.parse('http://$host:$port');
}

/// mDNS / Rust browse for `_forja._tcp` LAN servers.
class LanDiscoveryService {
  LanDiscoveryService._();
  static final LanDiscoveryService instance = LanDiscoveryService._();

  Future<List<LanServerInfo>> discover({int timeoutMs = 3000}) async {
    if (!Engine.isReady) return const [];
    // Android filters Wi‑Fi multicast unless MulticastLock is held.
    await PlatformChannel.acquireWifiMulticastLock();
    try {
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
    } finally {
      await PlatformChannel.releaseWifiMulticastLock();
    }
  }
}
