import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/models.dart';

/// Pre-disk install checks — manifest shape is validated earlier via
/// [PluginContract.validateManifest].
///
/// Does **not** eval JS in a VM. Broken scripts fail at first extract for that
/// plugin only — install still commits the pack.
abstract final class PluginInstallValidator {
  /// Per script / prelude body (UTF-8 bytes).
  static const maxScriptBytes = 1024 * 1024;

  /// Sum of all fetched JS bodies in one pack install.
  static const maxPackScriptBytes = 8 * 1024 * 1024;

  static void validateBeforeCommit({
    required String manifestUrl,
    required Map<String, dynamic> manifest,
    required EnginePack pack,
    required Map<String, String> scripts,
    required Map<String, String> preludes,
  }) {
    _validateScriptRefs(manifestUrl: manifestUrl, pack: pack);
    _validateCatalogVersions(pack);
    _validateSizes(scripts: scripts, preludes: preludes);
    _validateIntegrity(
      manifest: manifest,
      scripts: scripts,
      preludes: preludes,
    );
  }

  static void _validateScriptRefs({
    required String manifestUrl,
    required EnginePack pack,
  }) {
    final refs = <String, String>{
      if (pack.prelude.isNotEmpty) 'pack prelude': pack.prelude,
      for (final p in pack.plugins)
        if (p.prelude.isNotEmpty) '${p.id} prelude': p.prelude,
      for (final p in pack.plugins)
        if (p.entry.isNotEmpty && p.needsScript) '${p.id} entry': p.entry,
    };
    for (final e in refs.entries) {
      _assertScriptRefAllowed(
        manifestUrl: manifestUrl,
        ref: e.value,
        label: e.key,
      );
    }
  }

  static void _assertScriptRefAllowed({
    required String manifestUrl,
    required String ref,
    required String label,
  }) {
    final trimmed = ref.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$label: empty script path');
    }
    if (trimmed.contains('\u0000')) {
      throw FormatException('$label: invalid script path');
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final manifestOrigin = _remoteManifestOrigin(manifestUrl);
      if (manifestOrigin == null) {
        throw FormatException(
          '$label: remote script URL not allowed for local manifest',
        );
      }
      final scriptUri = Uri.parse(trimmed);
      if (!_sameOrigin(manifestOrigin, scriptUri)) {
        throw FormatException(
          '$label: script URL must match manifest origin '
          '(${manifestOrigin.host})',
        );
      }
    }
  }

  static Uri? _remoteManifestOrigin(String manifestUrl) {
    final trimmed = manifestUrl.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static bool _sameOrigin(Uri a, Uri b) {
    return a.scheme == b.scheme &&
        a.host.toLowerCase() == b.host.toLowerCase() &&
        a.port == b.port;
  }

  static void _validateCatalogVersions(EnginePack pack) {
    for (final plugin in pack.plugins) {
      if (!plugin.isHubCatalog) continue;
      final kit = plugin.kit;
      if (kit != null && kit > hostKitVersion) {
        throw FormatException(
          'plugin ${plugin.id} requires kit $kit (host $hostKitVersion)',
        );
      }
      final protocol = plugin.protocol;
      if (protocol != null && protocol > hostProtocolVersion) {
        throw FormatException(
          'plugin ${plugin.id} requires protocol $protocol '
          '(host $hostProtocolVersion)',
        );
      }
    }
  }

  static void _validateSizes({
    required Map<String, String> scripts,
    required Map<String, String> preludes,
  }) {
    var total = 0;
    void check(String label, String body) {
      final bytes = utf8.encode(body).length;
      if (bytes > maxScriptBytes) {
        throw FormatException(
          '$label exceeds ${maxScriptBytes ~/ 1024} KiB limit ($bytes bytes)',
        );
      }
      total += bytes;
    }

    for (final e in preludes.entries) {
      check('prelude ${e.key}', e.value);
    }
    for (final e in scripts.entries) {
      check('plugin ${e.key}', e.value);
    }
    if (total > maxPackScriptBytes) {
      throw FormatException(
        'pack scripts exceed ${maxPackScriptBytes ~/ (1024 * 1024)} MiB total '
        '($total bytes)',
      );
    }
  }

  static void _validateIntegrity({
    required Map<String, dynamic> manifest,
    required Map<String, String> scripts,
    required Map<String, String> preludes,
  }) {
    final integrity = manifest['integrity'];
    if (integrity is! Map) return;
    final integrityMap = Map<String, dynamic>.from(integrity);

    final scriptHashes = integrityMap['scripts'];
    if (scriptHashes is Map) {
      for (final e in Map<String, dynamic>.from(scriptHashes).entries) {
        final body = scripts[e.key.toString()];
        if (body == null) continue;
        _assertDigest('plugin ${e.key}', body, e.value);
      }
    }

    final preludeHashes = integrityMap['preludes'];
    if (preludeHashes is Map) {
      for (final e in Map<String, dynamic>.from(preludeHashes).entries) {
        final body = preludes[e.key.toString()];
        if (body == null) continue;
        _assertDigest('prelude ${e.key}', body, e.value);
      }
    }
  }

  static void _assertDigest(String label, String body, dynamic expectedRaw) {
    final expected = expectedRaw?.toString().trim().toLowerCase() ?? '';
    if (expected.isEmpty) {
      throw FormatException('$label: integrity hash is empty');
    }
    final normalized = expected.startsWith('sha256:')
        ? expected.substring('sha256:'.length)
        : expected;
    final actual = sha256.convert(utf8.encode(body)).toString();
    if (actual != normalized) {
      throw FormatException('$label: integrity mismatch');
    }
  }
}
