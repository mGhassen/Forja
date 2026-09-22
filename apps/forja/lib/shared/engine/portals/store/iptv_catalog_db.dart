import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// Thin host wrapper around Rust `iptv_catalog_json` (RFC-116).
abstract final class IptvCatalogDb {
  IptvCatalogDb._();

  static String portalHash(String portalKey) =>
      sha256.convert(utf8.encode(portalKey.trim())).toString();

  static Map<String, dynamic> _call(Map<String, dynamic> body) {
    if (!Engine.isReady) {
      return {'error': 'engine_not_ready'};
    }
    try {
      final raw = RustLib.instance.iptvCatalogJson(jsonEncode(body));
      if (raw.trim().isEmpty) return {'error': 'empty'};
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {'error': 'bad_json'};
    } catch (e) {
      debugPrint('[IptvCatalogDb] $e');
      return {'error': e.toString()};
    }
  }

  static bool hasShelf(String portalKey, String section) {
    final r = _call({
      'action': 'has_shelf',
      'portal_hash': portalHash(portalKey),
      'section': section,
    });
    return r['has'] == true;
  }

  static Future<bool> replaceShelf({
    required String portalKey,
    required String section,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> streams,
  }) async {
    final r = _call({
      'action': 'replace_shelf',
      'portal_hash': portalHash(portalKey),
      'section': section,
      'categories': categories,
      'streams': streams,
    });
    return r['ok'] == true;
  }

  static Map<String, dynamic> page(Map<String, dynamic> body) {
    return _call({
      ...body,
      'action': 'page',
      if (body['portal_hash'] == null && body['portal_key'] != null)
        'portal_hash': portalHash(body['portal_key'].toString()),
    });
  }

  static Map<String, dynamic>? exportShelf(String portalKey, String section) {
    final r = _call({
      'action': 'export_shelf',
      'portal_hash': portalHash(portalKey),
      'section': section,
    });
    if (r['ok'] != true) return null;
    return r;
  }

  static List<Map<String, dynamic>> streamsByIds({
    required String portalKey,
    required String section,
    required List<String> streamIds,
  }) {
    final r = _call({
      'action': 'streams_by_ids',
      'portal_hash': portalHash(portalKey),
      'section': section,
      'stream_ids': streamIds,
    });
    final list = r['streams'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static Future<void> clearAll() async {
    _call({'action': 'clear'});
  }

  // Alive
  static Map<String, dynamic>? aliveLoad(String portalKey) {
    final r = _call({
      'action': 'alive_load',
      'portal_hash': portalHash(portalKey),
    });
    final snap = r['snap'];
    if (snap == null || snap is! Map) return null;
    return Map<String, dynamic>.from(snap);
  }

  static void aliveSave({
    required String portalKey,
    required int checkedAt,
    required Set<String> ids,
    bool liveOnly = false,
  }) {
    _call({
      'action': 'alive_save',
      'portal_hash': portalHash(portalKey),
      'at': checkedAt,
      'ids': ids.toList(),
      'liveOnly': liveOnly,
    });
  }

  static void aliveSetLiveOnly(String portalKey, bool liveOnly) {
    _call({
      'action': 'alive_set_live_only',
      'portal_hash': portalHash(portalKey),
      'liveOnly': liveOnly,
    });
  }

  static void aliveClear(String portalKey) {
    _call({
      'action': 'alive_clear',
      'portal_hash': portalHash(portalKey),
    });
  }

  static void aliveClearAll() {
    _call({'action': 'alive_clear_all'});
  }

  // Channel hits
  static List<Map<String, dynamic>> channelHitsLoad(String channelId) {
    final r = _call({
      'action': 'channel_hits_load',
      'channel_id': channelId,
    });
    final hits = r['hits'];
    if (hits is! List) return const [];
    return [
      for (final e in hits)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static void channelHitsSave(String channelId, List<Map<String, dynamic>> hits) {
    _call({
      'action': 'channel_hits_save',
      'channel_id': channelId,
      'hits': hits,
    });
  }

  static void channelHitsClear(String channelId) {
    _call({'action': 'channel_hits_clear', 'channel_id': channelId});
  }

  static void channelHitsClearAll() {
    _call({'action': 'channel_hits_clear_all'});
  }
}
