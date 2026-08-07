import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<bool> checkHealth(String host, int port) async {
    try {
      final r = await http
          .get(Uri.parse('http://$host:$port/health'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
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
    final h = host ?? await prefs.serverHost;
    final p = port ?? await prefs.serverPort;
    if (token == null || h == null || p == null) return null;

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
        return null;
      }
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return json['play_url']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifyPairedConnection() async {
    final prefs = LanPrefs.instance;
    if (!await prefs.isPaired) return false;
    final host = await prefs.serverHost;
    final port = await prefs.serverPort;
    if (host == null || port == null) return false;
    return checkHealth(host, port);
  }
}
