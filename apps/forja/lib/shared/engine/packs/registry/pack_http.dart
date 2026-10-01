import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Pack and flutter_js HTTP. Name lookup uses the platform resolver.
abstract final class PackHttp {
  static const Duration defaultTimeout = Duration(seconds: 45);

  /// Optional override for tests (pack GET).
  @visibleForTesting
  static http.Client? debugClient;

  /// Shared client. Android [HttpOverrides] still attach the legacy TLS roots.
  static http.Client ioClient() => IOClient(HttpClient());

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
          'Try another network or install from a local path.';
    }

    return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
