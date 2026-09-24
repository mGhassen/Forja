import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/iptv_catalog_db.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_shelf_store.dart';
import 'package:rust/rust.dart';

/// Host-owned portal catalog paging (RFC-109 / RFC-116).
///
/// Fetches shelves into Rust SQLite; returns one page of stream maps to pack JS
/// — never the full `streams[]` array across the bridge.
abstract final class PortalCatalogPage {
  PortalCatalogPage._();

  static const defaultPageSize = 48;
  static const maxPageSize = 128;

  /// `engine.request('iptv', { action: 'catalog_page', … })`.
  static Future<Map<String, dynamic>> run(Map<String, dynamic> body) async {
    final url = (body['url'] ?? '').toString().trim();
    final username = (body['username'] ?? '').toString();
    final password = (body['password'] ?? '').toString();
    if (url.isEmpty) {
      return {
        'ok': false,
        'error': 'missing_url',
        'categories': [],
        'streams': [],
      };
    }

    final platform = PortalPlatform.fromString(
      (body['platform'] ?? body['type'] ?? 'xtream').toString(),
    );
    final sectionRaw =
        (body['section'] ?? 'live').toString().trim().toLowerCase();
    final section = _section(sectionRaw);
    final sectionWire = _sectionWire(section);

    final portal = Portal(
      url: url,
      username: username,
      password: password,
      platform: platform,
      userAgent: (body['userAgent'] ?? body['user_agent'] ?? '').toString(),
    );
    final portalKey = portal.key;

    final refresh = body['refresh'] == true ||
        body['force'] == true ||
        body['skipCache'] == true;

    final ensured = await _ensureShelf(
      portal: portal,
      portalKey: portalKey,
      sectionWire: sectionWire,
      timeoutSecs: (body['timeout_secs'] as num?)?.toInt() ??
          (body['timeoutSecs'] as num?)?.toInt() ??
          _timeoutSecs(section),
      refresh: refresh,
    );
    if (!ensured) {
      return {
        'ok': false,
        'error': 'catalog_failed',
        'message': 'Could not load catalog',
        'categories': [],
        'streams': [],
      };
    }

    final pageBody = <String, dynamic>{
      ...body,
      'portal_hash': IptvCatalogDb.portalHash(portalKey),
      'section': sectionWire,
    };
    // page / has_shelf run via EngineJobs (spawn_blocking) — not UI isolate.
    final page = await IptvCatalogDb.page(pageBody);
    if (page['error'] != null && page['ok'] != true) {
      return {
        'ok': false,
        'error': page['error']?.toString() ?? 'page_failed',
        'categories': [],
        'streams': [],
      };
    }
    return page;
  }

  static Future<bool> _ensureShelf({
    required Portal portal,
    required String portalKey,
    required String sectionWire,
    required int timeoutSecs,
    required bool refresh,
  }) async {
    if (!refresh && await IptvCatalogDb.hasShelf(portalKey, sectionWire)) {
      return true;
    }

    // One-time import from legacy JSON shelf files when SQLite is empty.
    if (!refresh) {
      final legacy = await PortalCatalogShelfStore.load(portalKey, sectionWire);
      if (legacy != null &&
          (legacy.streams.isNotEmpty || legacy.categories.isNotEmpty)) {
        final ok = await IptvCatalogDb.replaceShelf(
          portalKey: portalKey,
          section: sectionWire,
          categories: legacy.categories,
          streams: legacy.streams,
        );
        if (ok) {
          unawaited(PortalCatalogShelfStore.deleteShelf(portalKey, sectionWire));
          return true;
        }
      }
    }

    try {
      final body = <String, dynamic>{
        'action': 'catalog',
        'platform': portal.platform.wire,
        'url': portal.url,
        'username': portal.username,
        'password': portal.password,
        'section': sectionWire,
        'timeout_secs': timeoutSecs.clamp(1, 180),
        if (portal.userAgent.isNotEmpty) 'user_agent': portal.userAgent,
      };
      final raw = await runIptvXtreamJson(jsonEncode(body));
      if (raw.trim().isEmpty) return false;
      final parsed = await Isolate.run(() {
        final v = jsonDecode(raw);
        if (v is! Map) return null;
        return Map<String, dynamic>.from(v);
      });
      if (parsed == null) return false;
      if (parsed['error'] != null) {
        debugPrint(
          '[PortalCatalogPage] catalog error: ${parsed['error']}',
        );
        return false;
      }
      final cats = _asMapList(parsed['categories']);
      final streams = _asMapList(parsed['streams']);
      if (cats.isEmpty && streams.isEmpty) return false;
      return IptvCatalogDb.replaceShelf(
        portalKey: portalKey,
        section: sectionWire,
        categories: cats,
        streams: streams,
      );
    } catch (e, st) {
      debugPrint('[PortalCatalogPage] fetch failed: $e\n$st');
      return false;
    }
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  @visibleForTesting
  static List<Map<String, dynamic>> filterSort({
    required List<Map<String, dynamic>> streams,
    String categoryId = '',
    String q = '',
    List<String> streamIds = const [],
    bool streamIdsSet = false,
    String sort = 'playlist',
  }) {
    Iterable<Map<String, dynamic>> rows = streams;

    if (streamIdsSet || streamIds.isNotEmpty) {
      if (streamIds.isEmpty) return const [];
      final want = {for (final id in streamIds) id};
      final byId = <String, Map<String, dynamic>>{};
      for (final s in streams) {
        final id = _streamId(s);
        if (id.isNotEmpty && want.contains(id)) byId[id] = s;
      }
      return [for (final id in streamIds) if (byId[id] != null) byId[id]!];
    }

    if (categoryId.isNotEmpty &&
        categoryId != 'all' &&
        !categoryId.startsWith('__')) {
      rows = rows.where((s) {
        final cid =
            (s['categoryId'] ?? s['category_id'] ?? 'all').toString().trim();
        return cid == categoryId;
      });
    }

    if (q.isNotEmpty) {
      final needle = q.toLowerCase();
      rows = rows.where((s) {
        final name = (s['name'] ?? s['title'] ?? '').toString().toLowerCase();
        final cat = (s['categoryId'] ?? s['category_id'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(needle) || cat.contains(needle);
      });
    }

    final list = rows.toList();
    if (sort == 'nameAsc' || sort == 'nameDesc') {
      final desc = sort == 'nameDesc';
      list.sort((a, b) {
        final an = (a['name'] ?? '').toString().toLowerCase();
        final bn = (b['name'] ?? '').toString().toLowerCase();
        final c = an.compareTo(bn);
        return desc ? -c : c;
      });
    }
    return list;
  }

  static String _streamId(Map<String, dynamic> s) =>
      (s['id'] ?? s['stream_id'] ?? s['series_id'] ?? s['cmd'] ?? '')
          .toString()
          .trim();

  static PortalSection _section(String raw) {
    if (raw == 'movies' || raw == 'movie' || raw == 'vod') {
      return PortalSection.vod;
    }
    if (raw == 'series' || raw == 'tv') return PortalSection.series;
    return PortalSection.live;
  }

  static String _sectionWire(PortalSection s) => switch (s) {
        PortalSection.live => 'live',
        PortalSection.vod => 'vod',
        PortalSection.series => 'series',
      };

  static int _timeoutSecs(PortalSection s) => switch (s) {
        PortalSection.live => 90,
        PortalSection.vod => 60,
        PortalSection.series => 60,
      };
}
