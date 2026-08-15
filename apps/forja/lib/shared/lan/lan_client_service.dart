import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

import 'lan_pairing_presence.dart';
import 'lan_prefs.dart';

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

/// HTTP client for paired LAN desktop server.
class LanClientService {
  LanClientService._();
  static final LanClientService instance = LanClientService._();

  /// Last magnet successfully opened via [openStream] (kind torrent).
  /// Used to `/close` even when the play URL was rewritten or magnet parse fails.
  String? _lastOpenedTorrentMagnet;

  Future<bool> checkHealth(String host, int port) async {
    final info = await fetchHealth(host, port);
    return info != null;
  }

  Future<LanServerInfo?> fetchHealth(String host, int port) async {
    try {
      final r = await http
          .get(Uri.parse('http://$host:$port/health'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return LanServerInfo(
        serverId: json['server_id']?.toString() ?? '',
        host: host,
        port: port,
        version: json['version']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Authenticated ping so the desktop can mark this device online.
  Future<bool> pingStatus(String host, int port) async =>
      await pingStatusJson(host, port) != null;

  /// `null` = unreachable / 401. Empty map = online, no torrent.
  /// Map with `info_hash` = desktop is serving a torrent.
  Future<Map<String, dynamic>?> pingStatusJson(String host, int port) async {
    final token = await LanPrefs.instance.token;
    if (token == null || token.isEmpty) return null;
    try {
      final r = await http
          .get(
            Uri.parse('http://$host:$port/status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 401) {
        await LanPrefs.instance.clearServer();
        LanPairingPresence.instance.notifyChanged();
        return null;
      }
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(r.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return const <String, dynamic>{};
    } catch (_) {
      return null;
    }
  }

  Future<bool> _probeAndTouch(
    String host,
    int port, {
    String? expectedServerId,
  }) async {
    final info = await fetchHealth(host, port);
    if (info == null) return false;
    if (expectedServerId != null &&
        expectedServerId.isNotEmpty &&
        info.serverId.isNotEmpty &&
        info.serverId != expectedServerId) {
      return false;
    }
    await pingStatus(host, port);
    return true;
  }

  Future<String?> pair({
    required String host,
    required int port,
    required String code,
    String? deviceId,
    String? label,
  }) async {
    final id = deviceId ?? await LanPrefs.instance.deviceId();
    final deviceLabel = label ?? LanPrefs.defaultDeviceLabel();
    try {
      final r = await http
          .post(
            Uri.parse('http://$host:$port/pair'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code,
              'device_id': id,
              'label': deviceLabel,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final token = json['token']?.toString();
      if (token == null || token.isEmpty) return null;
      await LanPrefs.instance.setToken(token);
      await LanPrefs.instance.setServer(
        host: host,
        port: port,
        serverId: json['server_id']?.toString(),
      );
      LanPairingPresence.instance.notifyChanged();
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<String?> openStream({
    required String kind,
    String? magnet,
    int? season,
    int? episode,
    int? fileIdx,
    String? upstreamUrl,
    String? proxyToken,
    Map<String, String>? headers,
    String? host,
    int? port,
  }) async {
    final prefs = LanPrefs.instance;
    final token = await prefs.token;
    var h = host ?? await prefs.serverHost;
    var p = port ?? await prefs.serverPort;
    if (token == null || h == null || p == null) return null;

    // Stale port after desktop restart — rediscover before open.
    if (!await _probeAndTouch(
      h,
      p,
      expectedServerId: await prefs.serverId,
    )) {
      if (!await verifyPairedConnection()) return null;
      h = await prefs.serverHost;
      p = await prefs.serverPort;
      if (h == null || p == null) return null;
    }

    final body = <String, dynamic>{
      'kind': kind,
      'host': h,
      'magnet': ?magnet,
      'season': ?season,
      'episode': ?episode,
      'file_idx': ?fileIdx,
      'upstream_url': ?upstreamUrl,
      'proxy_token': ?proxyToken,
      if (headers != null && headers.isNotEmpty) 'headers': headers,
    };

    try {
      final r = await http
          .post(
            Uri.parse('http://$h:$p/open'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
      if (r.statusCode == 401) {
        await prefs.clearServer();
        LanPairingPresence.instance.notifyChanged();
        return null;
      }
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final playUrl = json['play_url']?.toString();
      if (kind == 'torrent' &&
          playUrl != null &&
          playUrl.isNotEmpty &&
          magnet != null &&
          magnet.isNotEmpty) {
        _lastOpenedTorrentMagnet = magnet;
      }
      return playUrl;
    } catch (_) {
      return null;
    }
  }

  /// Tell the desktop to stop a LAN torrent swarm (keeps cache/history).
  ///
  /// When [infoHash]/magnet parse to a hash, desktop only stops if it still
  /// matches the active swarm (safe after source-switch `/open`). When no
  /// hash is available, desktop stops whatever is active — better than
  /// leaving the download running after TV exit.
  Future<bool> closeTorrent({String? infoHash, String? magnet}) async {
    final hash = (infoHash?.trim().isNotEmpty == true)
        ? infoHash!.trim()
        : infoHashFromMagnet(magnet);

    final prefs = LanPrefs.instance;
    final token = await prefs.token;
    var h = await prefs.serverHost;
    var p = await prefs.serverPort;
    if (token == null || h == null || p == null) {
      debugPrint('[LAN] closeTorrent skipped — not paired');
      return false;
    }

    if (!await _probeAndTouch(
      h,
      p,
      expectedServerId: await prefs.serverId,
    )) {
      if (!await verifyPairedConnection()) {
        debugPrint('[LAN] closeTorrent failed — desktop unreachable');
        return false;
      }
      h = await prefs.serverHost;
      p = await prefs.serverPort;
      if (h == null || p == null) return false;
    }

    final body = <String, dynamic>{
      'kind': 'torrent',
      if (hash != null && hash.isNotEmpty) 'info_hash': hash,
    };

    try {
      final r = await http
          .post(
            Uri.parse('http://$h:$p/close'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 401) {
        await prefs.clearServer();
        LanPairingPresence.instance.notifyChanged();
        debugPrint('[LAN] closeTorrent 401 — cleared pairing');
        return false;
      }
      if (r.statusCode != 200) {
        debugPrint('[LAN] closeTorrent HTTP ${r.statusCode}: ${r.body}');
        return false;
      }
      if (_lastOpenedTorrentMagnet != null &&
          magnet != null &&
          magnet.isNotEmpty &&
          _lastOpenedTorrentMagnet == magnet) {
        _lastOpenedTorrentMagnet = null;
      } else if (hash == null || hash.isEmpty) {
        _lastOpenedTorrentMagnet = null;
      }
      final hashLabel = (hash != null && hash.isNotEmpty)
          ? (hash.length > 8 ? '${hash.substring(0, 8)}…' : hash)
          : 'active';
      debugPrint('[LAN] closeTorrent ok hash=$hashLabel');
      return true;
    } catch (e) {
      debugPrint('[LAN] closeTorrent error: $e');
      return false;
    }
  }

  /// Fire-and-forget close when this play was a remounted LAN torrent.
  ///
  /// Deferred past MediaKit/MediaCodec dispose — sync prefs + HTTP in the
  /// same window as surface teardown ANRs Android TV (issue 128 pattern).
  void releaseLanTorrentIfNeeded({
    String? playUrl,
    String? magnet,
  }) {
    final mag = (magnet != null && magnet.isNotEmpty)
        ? magnet
        : _lastOpenedTorrentMagnet;
    final url = playUrl ?? '';
    final lanUrl = url.isNotEmpty && isLanTorrentStreamUrl(url);
    // Magnet + non-local /torrents/ path (covers odd hosts); never local engine.
    final magnetLan = mag != null &&
        mag.isNotEmpty &&
        url.contains('/torrents/') &&
        url.contains('/stream/') &&
        !isLoopbackPlayHost(url);
    // Paired client opened this magnet on desktop even if URL rewrite failed.
    final trackedLan = mag != null &&
        mag.isNotEmpty &&
        _lastOpenedTorrentMagnet != null &&
        _lastOpenedTorrentMagnet == mag;
    if (!lanUrl && !magnetLan && !trackedLan) {
      debugPrint('[LAN] release skip — not a LAN torrent session');
      return;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () async {
        await closeTorrent(magnet: mag);
      }),
    );
  }

  /// Cancel/fail during resolve — desktop may already be downloading.
  void releaseLanTorrentAfterCancel({String? magnet}) {
    final mag = (magnet != null && magnet.isNotEmpty)
        ? magnet
        : _lastOpenedTorrentMagnet;
    if ((mag == null || mag.isEmpty) && _lastOpenedTorrentMagnet == null) {
      debugPrint('[LAN] cancel release skip — no magnet');
      return;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 200), () async {
        await closeTorrent(magnet: mag ?? _lastOpenedTorrentMagnet);
      }),
    );
  }

  /// Health on saved address; on failure browse mDNS for the same `server_id`
  /// and rewrite host/port (desktop restart / sticky-port miss).
  Future<bool> verifyPairedConnection() async {
    final prefs = LanPrefs.instance;
    if (!await prefs.isPaired) return false;
    final host = await prefs.serverHost;
    final port = await prefs.serverPort;
    final serverId = await prefs.serverId;
    if (host == null || port == null) return false;

    if (await _probeAndTouch(host, port, expectedServerId: serverId)) {
      return true;
    }

    if (serverId == null || serverId.isEmpty) return false;
    for (final s in _browseServers()) {
      if (s.serverId != serverId) continue;
      if (!await _probeAndTouch(
        s.host,
        s.port,
        expectedServerId: serverId,
      )) {
        continue;
      }
      await prefs.setServer(
        host: s.host,
        port: s.port,
        serverId: serverId,
      );
      return true;
    }
    return false;
  }

  List<LanServerInfo> _browseServers() {
    if (!Engine.isReady) return const [];
    try {
      final raw = RustLib.instance.lanBrowseServersJson(timeoutMs: 3000);
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

/// Remounted desktop torrent HTTP URL (not localhost — that is local engine).
bool isLanTorrentStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (isLoopbackPlayHost(url)) return false;
  return uri.path.contains('/torrents/') && uri.path.contains('/stream/');
}

bool isLoopbackPlayHost(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

String? infoHashFromMagnet(String? magnet) {
  if (magnet == null || magnet.isEmpty) return null;
  final m = RegExp(
    r'xt=urn:btih:([a-fA-F0-9]{40}|[a-zA-Z2-7]{32})',
    caseSensitive: false,
  ).firstMatch(magnet);
  return m?.group(1)?.toLowerCase();
}
