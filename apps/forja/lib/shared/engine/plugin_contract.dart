/// Machine-readable EngineJS pack contracts — `plugins/sdk/schema/*.json`.
library;

import 'package:forja/shared/catalog/catalog_pack_assets.dart';
import 'package:forja/shared/catalog/protocol.dart';

/// Validates pack manifests at install time (mirrors [manifest.schema.json]).
abstract final class PluginContract {
  static const manifestSchemaVersion = 1;
  static const supportedKinds = {
    'http',
    'hop',
    'catalog',
    'host',
    'torrent',
  };

  static const catalogErrorCodes = {
    'INVALID_ACTION',
    'INVALID_PARAMS',
    'NOT_FOUND',
    'AUTH_REQUIRED',
    'AUTH_EXPIRED',
    'RATE_LIMIT',
    'UPSTREAM',
    'PARSE',
    'UNSUPPORTED_KIT',
    'CANCELLED',
  };

  /// Throws [FormatException] when [map] violates the manifest contract.
  static void validateManifest(Map<String, dynamic> map) {
    final schema = map['schema'];
    if (schema != null && schema != manifestSchemaVersion) {
      throw FormatException('unsupported manifest schema: $schema');
    }
    _requireString(map, 'id');
    _requireString(map, 'name');
    _requireString(map, 'version');
    // Pack never owns on/off — host Settings (Forja Packs / Features) only.
    if (map.containsKey('enabled')) {
      throw const FormatException(
        'manifest must not declare enabled — host Settings owns on/off',
      );
    }
    final prelude = map['prelude'];
    if (prelude != null && !_nonEmptyString(prelude)) {
      throw const FormatException('manifest prelude must be a non-empty string');
    }

    final pluginsRaw = map['plugins'];
    if (pluginsRaw is! List || pluginsRaw.isEmpty) {
      throw const FormatException('manifest has no plugins');
    }

    final seenIds = <String>{};
    for (final raw in pluginsRaw) {
      if (raw is! Map) {
        throw const FormatException('manifest plugin entry must be an object');
      }
      final plugin = Map<String, dynamic>.from(raw);
      final id = _requireString(plugin, 'id');
      if (!seenIds.add(id)) {
        throw FormatException('duplicate plugin id in manifest: $id');
      }
      _requireString(plugin, 'name');
      if (plugin.containsKey('enabled')) {
        throw FormatException(
          'plugin $id must not declare enabled — host Settings owns on/off',
        );
      }
      final entry = plugin['entry'] ?? plugin['filename'];
      if (!_nonEmptyString(entry)) {
        throw FormatException('plugin $id missing entry');
      }
      final kind = plugin['kind'];
      final kindName = kind?.toString().trim() ?? '';
      if (kindName.isNotEmpty && !supportedKinds.contains(kindName)) {
        throw FormatException('plugin $id unsupported kind: $kindName');
      }
      final protocol = plugin['protocol'];
      if (protocol is num && protocol.toInt() < 1) {
        throw FormatException('plugin $id protocol must be >= 1');
      }
      final kit = plugin['kit'];
      if (kit is num && kit.toInt() < 1) {
        throw FormatException('plugin $id kit must be >= 1');
      }
      if (kindName == 'catalog') {
        if (kit is num && kit.toInt() > hostKitVersion) {
          throw FormatException(
            'plugin $id requires kit ${kit.toInt()} (host $hostKitVersion)',
          );
        }
        if (protocol is num && protocol.toInt() > hostProtocolVersion) {
          throw FormatException(
            'plugin $id requires protocol ${protocol.toInt()} '
            '(host $hostProtocolVersion)',
          );
        }
      }
      final nav = plugin['nav'];
      if (nav != null) {
        if (nav is! Map) {
          throw FormatException('plugin $id nav must be an object');
        }
        final navMap = Map<String, dynamic>.from(nav);
        _requireString(navMap, 'tabId');
        _requireString(navMap, 'label');
        final icon = navMap['icon'];
        if (icon != null) {
          final s = icon.toString().trim();
          if (s.isNotEmpty) {
            if (s.startsWith('assets/') || s.contains('..')) {
              throw FormatException(
                'plugin $id nav.icon must be pack-relative (icons/…) '
                'or forja://asset/… — not Flutter assets/ or ..',
              );
            }
            final ok = s.startsWith('forja://asset/') ||
                CatalogPackAssets.isPackNavIcon(s);
            if (!ok) {
              throw FormatException(
                'plugin $id nav.icon must be pack-relative (icons/…) '
                'or forja://asset/…',
              );
            }
          }
        }
      }
    }
  }

  /// Throws [FormatException] when [raw] is not a catalog envelope list/map.
  static void validateCatalogEnvelope(dynamic raw) {
    final env = _envelopeMap(raw);
    if (env == null) {
      throw const FormatException('catalog response is not an envelope');
    }
    if (env['ok'] is! bool) {
      throw const FormatException('catalog envelope missing ok');
    }
    final kit = env['kit'];
    if (kit is! num || kit.toInt() < 1) {
      throw const FormatException('catalog envelope kit must be >= 1');
    }
    final protocol = env['protocol'];
    if (protocol is! num || protocol.toInt() < 1) {
      throw const FormatException('catalog envelope protocol must be >= 1');
    }
    if (!_nonEmptyString(env['action'])) {
      throw const FormatException('catalog envelope missing action');
    }
    final ok = env['ok'] == true;
    if (ok) {
      if (env['error'] != null) {
        throw const FormatException(
          'catalog success envelope must not include error',
        );
      }
      return;
    }
    final err = env['error'];
    if (err is! Map) {
      throw const FormatException('catalog error envelope missing error object');
    }
    final errMap = Map<String, dynamic>.from(err);
    final code = errMap['code']?.toString().trim().toUpperCase();
    if (code == null || code.isEmpty || !catalogErrorCodes.contains(code)) {
      throw FormatException('catalog error unknown code: ${errMap['code']}');
    }
    if (errMap['message'] == null) {
      throw const FormatException('catalog error missing message');
    }
  }

  /// Throws [FormatException] when [raw] is not a VOD stream array.
  static void validateVodStreams(dynamic raw) {
    if (raw is! List) {
      throw const FormatException('VOD extract must return an array');
    }
    for (final row in raw) {
      if (row is! Map) {
        throw const FormatException('VOD stream row must be an object');
      }
      final m = Map<String, dynamic>.from(row);
      final url = m['url'] ?? m['file'] ?? m['src'];
      if (!_nonEmptyString(url)) {
        throw const FormatException('VOD stream row missing url/file/src');
      }
    }
  }

  /// Throws [FormatException] when [raw] is not a torrent search array.
  static void validateTorrentSearch(dynamic raw) {
    if (raw is! List) {
      throw const FormatException('torrent search must return an array');
    }
    for (final row in raw) {
      validateTorrentRow(row);
    }
  }

  static void validateTorrentRow(dynamic row) {
    if (row is! Map) {
      throw const FormatException('torrent row must be an object');
    }
    final m = Map<String, dynamic>.from(row);
    _requireString(m, 'name');
    final magnet = _requireString(m, 'magnet');
    if (!magnet.startsWith('magnet:?xt=urn:btih:')) {
      throw FormatException('torrent row invalid magnet: $magnet');
    }
    _requireString(m, 'seeders');
    _requireString(m, 'size');
    _requireString(m, 'source');
  }

  static Map<String, dynamic>? _envelopeMap(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return m.containsKey('ok') ? m : null;
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static String _requireString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (!_nonEmptyString(v)) {
      throw FormatException('missing or empty $key');
    }
    return v.toString().trim();
  }

  static bool _nonEmptyString(dynamic v) =>
      v != null && v.toString().trim().isNotEmpty;
}
