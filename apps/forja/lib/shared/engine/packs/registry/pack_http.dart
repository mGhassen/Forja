import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';


/// System DNS first, Cloudflare DoH (`1.1.1.1`) when lookup fails.
///
/// Hotspots often break the phone DNS forwarder while browsers still work via
/// DoH. Hitting DoH by literal IP bootstraps without system DNS.
///
/// Used for pack install, flutter_js host HTTP, and (via Android
/// [HttpOverrides]) every Dart [HttpClient] including Supabase sync.
abstract final class PackHttp {
  static const Duration defaultTimeout = Duration(seconds: 45);

  /// Cap system DNS — Android TV/emulator can hang forever on lookup.
  /// On timeout / failure we fall through to DoH.
  static const Duration systemDnsTimeout = Duration(seconds: 5);

  /// Cloudflare DNS-over-HTTPS (JSON) — IP so we do not need recursive DNS.
  static const String dohUrl = 'https://1.1.1.1/dns-query';

  /// Optional override for tests (DoH + pack GET).
  @visibleForTesting
  static http.Client? debugClient;

  /// Optional host→addrs override for tests (skip real lookup / DoH).
  @visibleForTesting
  static Future<List<InternetAddress>> Function(String host)? debugResolve;

  /// Wire system→DoH resolve into an existing [HttpClient] (SNI preserved).
  static void attachDohResolver(HttpClient client) {
    client.connectionFactory = _connect;
  }

  /// Shared client: resolve each host via [resolveHost] (system → DoH).
  static http.Client ioClient() {
    final client = HttpClient();
    attachDohResolver(client);
    return IOClient(client);
  }

  /// Numeric IPv4/IPv6 only — never call system DNS / DoH (DoH bootstrap).
  static InternetAddress? parseLiteralIp(String host) {
    final h = host.trim();
    if (h.isEmpty) return null;
    try {
      return InternetAddress(h);
    } on ArgumentError {
      return null;
    }
  }

  static Future<ConnectionTask<Socket>> _connect(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null) {
      return Socket.startConnect(proxyHost, proxyPort!);
    }
    final host = url.host;
    if (host.isEmpty) {
      throw const SocketException('Failed host lookup: empty host');
    }
    final addrs = await resolveHost(host);
    if (addrs.isEmpty) {
      throw SocketException('Failed host lookup: $host');
    }
    final port = url.hasPort
        ? url.port
        : (url.scheme == 'https' ? 443 : 80);
    // Prefer IPv4 on flaky hotspots.
    final preferred = addrs.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addrs.first,
    );
    return _startConnect(url, preferred, port, sniHost: host);
  }

  /// Connect to [addr] without DNS — used for DoH bootstrap to `1.1.1.1`.
  static Future<ConnectionTask<Socket>> _connectLiteral(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null) {
      return Socket.startConnect(proxyHost, proxyPort!);
    }
    final lit = parseLiteralIp(url.host);
    if (lit == null) {
      throw SocketException('DoH bootstrap needs IP host, got ${url.host}');
    }
    final port = url.hasPort
        ? url.port
        : (url.scheme == 'https' ? 443 : 80);
    return _startConnect(url, lit, port, sniHost: url.host);
  }

  static Future<ConnectionTask<Socket>> _startConnect(
    Uri url,
    InternetAddress preferred,
    int port, {
    required String sniHost,
  }) async {
    if (url.scheme != 'https') {
      return Socket.startConnect(preferred, port);
    }
    // Connect to resolved IP, then TLS with SNI = hostname (not the IP).
    // Custom factory must return a SecureSocket for https — plain TCP on :443
    // makes Dart parse TLS bytes as HTTP → "Invalid request method".
    final plain = await Socket.startConnect(preferred, port);
    final secure = plain.socket.then(
      (s) => SecureSocket.secure(s, host: sniHost),
    );
    return ConnectionTask.fromSocket(secure, plain.cancel);
  }

  static Future<http.Response> get(
    Uri uri, {
    Duration timeout = defaultTimeout,
  }) async {
    final override = debugClient;
    if (override != null) {
      return override.get(uri).timeout(
        timeout,
        onTimeout: () => throw TimeoutException('plugin fetch $uri'),
      );
    }

    final host = uri.host;
    if (host.isEmpty) {
      throw ArgumentError('pack URL missing host: $uri');
    }

    final io = ioClient();
    try {
      return await io.get(uri).timeout(
        timeout,
        onTimeout: () => throw TimeoutException('plugin fetch $uri'),
      );
    } finally {
      io.close();
    }
  }

  /// System [InternetAddress.lookup], then DoH A (then AAAA) via `1.1.1.1`.
  static Future<List<InternetAddress>> resolveHost(String host) async {
    final debug = debugResolve;
    if (debug != null) return debug(host);

    // IP literals must not hit system DNS — Android hangs on lookup("1.1.1.1")
    // when Private DNS is broken, then DoH recurses into itself.
    final lit = parseLiteralIp(host);
    if (lit != null) return [lit];

    try {
      final addrs = await InternetAddress.lookup(host).timeout(
        systemDnsTimeout,
      );
      if (addrs.isNotEmpty) return addrs;
    } on TimeoutException catch (e) {
      debugPrint('[PackHttp] system DNS timed out ($host): $e — trying DoH');
    } on SocketException catch (e) {
      debugPrint('[PackHttp] system DNS failed ($host): $e — trying DoH');
    } catch (e) {
      debugPrint('[PackHttp] system DNS failed ($host): $e — trying DoH');
    }

    final viaDoh = await lookupDoh(host);
    if (viaDoh.isNotEmpty) {
      debugPrint(
        '[PackHttp] DoH resolved $host → ${viaDoh.map((a) => a.address).join(', ')}',
      );
    }
    return viaDoh;
  }

  /// Cloudflare DNS-over-HTTPS JSON API (bootstrapped at `1.1.1.1`).
  static Future<List<InternetAddress>> lookupDoh(String host) async {
    final name = host.trim().toLowerCase();
    if (name.isEmpty) return const [];
    if (parseLiteralIp(name) != null) return const [];

    final a = await _dohQuery(name, 'A');
    if (a.isNotEmpty) return a;
    return _dohQuery(name, 'AAAA');
  }

  /// HttpClient that connects to DoH by IP only — never [attachDohResolver].
  static http.Client _dohBootstrapClient() {
    final client = HttpClient();
    // HttpOverrides may have already attached DoH; overwrite to break recursion.
    client.connectionFactory = _connectLiteral;
    return IOClient(client);
  }

  static Future<List<InternetAddress>> _dohQuery(
    String name,
    String type,
  ) async {
    final uri = Uri.parse(dohUrl).replace(
      queryParameters: {'name': name, 'type': type},
    );
    final client = debugClient ?? _dohBootstrapClient();
    final owned = debugClient == null;
    try {
      final resp = await client
          .get(
            uri,
            headers: const {'Accept': 'application/dns-json'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];
      return parseDohAnswers(resp.body, type: type);
    } catch (e) {
      debugPrint('[PackHttp] DoH $type failed ($name): $e');
      return const [];
    } finally {
      if (owned) client.close();
    }
  }

  /// Parse Cloudflare/Google `application/dns-json` Answer data.
  @visibleForTesting
  static List<InternetAddress> parseDohAnswers(
    String body, {
    required String type,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const [];
      final answer = decoded['Answer'];
      if (answer is! List) return const [];
      final out = <InternetAddress>[];
      final want = type.toUpperCase() == 'AAAA'
          ? InternetAddressType.IPv6
          : InternetAddressType.IPv4;
      for (final raw in answer) {
        if (raw is! Map) continue;
        final data = (raw['data'] as String?)?.trim() ?? '';
        if (data.isEmpty) continue;
        // Skip CNAMEs etc. — type 1 = A, 28 = AAAA.
        final t = raw['type'];
        if (t is int) {
          if (want == InternetAddressType.IPv4 && t != 1) continue;
          if (want == InternetAddressType.IPv6 && t != 28) continue;
        }
        try {
          final addr = InternetAddress(data);
          if (addr.type == want) out.add(addr);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Short user-facing reason for Settings toasts / official install banner.
  static String humanizeError(Object error, [String? url]) {
    final host = () {
      final u = (url ?? '').trim();
      if (u.isEmpty) return null;
      try {
        final h = Uri.parse(u).host;
        return h.isEmpty ? null : h;
      } catch (_) {
        return null;
      }
    }();

    if (error is ManifestGoneException) {
      final path = error.url.trim().isNotEmpty
          ? error.url.trim()
          : (url ?? '').trim();
      final code = error.statusCode;
      if (code != null) {
        return 'Manifest not found (HTTP $code): $path';
      }
      return 'Manifest not found: $path';
    }

    if (error is TimeoutException) {
      final where = host != null ? ' ($host)' : '';
      return 'Pack download timed out$where. Check network or DNS.';
    }

    final text = error.toString();
    final dns = text.contains('Failed host lookup') ||
        text.contains('No address associated with hostname') ||
        text.contains('Name or service not known') ||
        (error is SocketException &&
            (error.osError?.errorCode == 7 ||
                error.message.contains('Failed host lookup')));
    if (dns) {
      final where = host ?? 'host';
      return 'Cannot resolve $where (DNS). '
          'Try another network, set DNS to 1.1.1.1, or install from a local path.';
    }

    return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
