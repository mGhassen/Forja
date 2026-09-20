import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_shelf_store.dart';
import 'package:rust/rust.dart';

/// Host-owned portal catalog paging (RFC-109 / issue 290).
///
/// Fetches + caches full shelves in Dart (file + Isolate). Returns only one
/// page of stream maps to pack JS — never the full `streams[]` array.
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

    final snap = await _ensureShelf(
      portal: portal,
      portalKey: portalKey,
      sectionWire: sectionWire,
      timeoutSecs: (body['timeout_secs'] as num?)?.toInt() ??
          (body['timeoutSecs'] as num?)?.toInt() ??
          _timeoutSecs(section),
      refresh: refresh,
    );
    if (snap == null) {
      return {
        'ok': false,
        'error': 'catalog_failed',
        'message': 'Could not load catalog',
        'categories': [],
        'streams': [],
      };
    }

    final categories = snap.categories;
    final sort = (body['sort'] ?? 'playlist').toString().trim();
    final q = (body['q'] ?? body['query'] ?? '').toString().trim();
    var categoryId =
        (body['category_id'] ?? body['categoryId'] ?? '').toString().trim();

    final hasStreamIdsKey =
        body.containsKey('stream_ids') || body.containsKey('streamIds');
    final streamIdsRaw = body['stream_ids'] ?? body['streamIds'];
    final streamIds = <String>[];
    if (streamIdsRaw is List) {
      for (final e in streamIdsRaw) {
        final id = e.toString().trim();
        if (id.isNotEmpty) streamIds.add(id);
      }
    }

    var page = (body['page'] as num?)?.toInt() ?? 1;
    if (page < 1) page = 1;
    var pageSize = (body['page_size'] as num?)?.toInt() ??
        (body['pageSize'] as num?)?.toInt() ??
        (body['limit'] as num?)?.toInt() ??
        defaultPageSize;
    if (pageSize < 1) pageSize = defaultPageSize;
    if (streamIds.isNotEmpty) {
      // Favorites / watched — return requested ids (capped).
      if (pageSize < streamIds.length) pageSize = streamIds.length;
      if (pageSize > 256) pageSize = 256;
    } else if (pageSize > maxPageSize) {
      pageSize = maxPageSize;
    }

    // Explicit stream_ids list (even empty Favorites/Watched) must not fall
    // through to the first category page.
    if (hasStreamIdsKey) {
      categoryId = '';
    } else if (streamIds.isEmpty && q.isEmpty && categoryId.isEmpty) {
      // Search / id lookup: scan whole shelf. Else default to first category
      // when none selected (rail opens on first group — never ship every stream).
      categoryId = _firstCategoryId(categories);
    }

    final filtered = filterSort(
      streams: snap.streams,
      categoryId: categoryId,
      q: q,
      streamIds: streamIds,
      sort: sort,
    );

    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <Map<String, dynamic>>[]
        : filtered.sublist(
            start,
            start + pageSize > filtered.length
                ? filtered.length
                : start + pageSize,
          );
    final hasMore = start + slice.length < filtered.length;

    return {
      'ok': true,
      'categories': categories,
      'streams': slice,
      'page': page,
      'pageSize': pageSize,
      'page_size': pageSize,
      'hasMore': hasMore,
      'has_more': hasMore,
      'total': filtered.length,
      'categoryId': categoryId,
      'category_id': categoryId,
    };
  }

  static Future<PortalCatalogShelfSnap?> _ensureShelf({
    required Portal portal,
    required String portalKey,
    required String sectionWire,
    required int timeoutSecs,
    required bool refresh,
  }) async {
    if (!refresh) {
      final cached =
          await PortalCatalogShelfStore.load(portalKey, sectionWire);
      if (cached != null &&
          (cached.streams.isNotEmpty || cached.categories.isNotEmpty)) {
        return cached;
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
      if (raw.trim().isEmpty) return null;
      final parsed = await Isolate.run(() {
        final v = jsonDecode(raw);
        if (v is! Map) return null;
        return Map<String, dynamic>.from(v);
      });
      if (parsed == null) return null;
      if (parsed['error'] != null) {
        debugPrint(
          '[PortalCatalogPage] catalog error: ${parsed['error']}',
        );
        return null;
      }
      final cats = _asMapList(parsed['categories']);
      final streams = _asMapList(parsed['streams']);
      final snap = PortalCatalogShelfSnap(
        categories: cats,
        streams: streams,
      );
      if (cats.isNotEmpty || streams.isNotEmpty) {
        await PortalCatalogShelfStore.save(portalKey, sectionWire, snap);
      }
      return snap;
    } catch (e, st) {
      debugPrint('[PortalCatalogPage] fetch failed: $e\n$st');
      return null;
    }
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static String _firstCategoryId(List<Map<String, dynamic>> cats) {
    for (final c in cats) {
      final id = (c['id'] ?? c['category_id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  @visibleForTesting
  static List<Map<String, dynamic>> filterSort({
    required List<Map<String, dynamic>> streams,
    String categoryId = '',
    String q = '',
    List<String> streamIds = const [],
    String sort = 'playlist',
  }) {
    Iterable<Map<String, dynamic>> rows = streams;

    if (streamIds.isNotEmpty) {
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
