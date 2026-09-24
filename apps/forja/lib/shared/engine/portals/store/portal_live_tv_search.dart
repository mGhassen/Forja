import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja/shared/engine/portals/channel_search/match_fixture_keys.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/iptv_catalog_db.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_page.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/vault/engine_vault.dart';
import 'package:rust/rust.dart' show runLiveSportsFetchJson;

/// Host-side Live TV channel match for nested `plugin.run(searchChannels)`.
///
/// Engine owns ranking via Rust `sport_match_streams` (broadcast + EPG). This
/// class resolves the portal, calls that action, and normalizes play URLs /
/// logos into the maps the Live Sports hub expects.
///
/// Nested under Live Sports `liveTv`, pack `searchChannels` cannot fork a
/// second flutter_js heap — so the host bridge lands here instead of running
/// the IPTV pack's catalog_page loop.
abstract final class PortalLiveTvSearch {
  PortalLiveTvSearch._();

  static const _cacheTtl = Duration(minutes: 30);
  static const _epgBatchSize = 12;

  static int _session = 0;
  static final Map<String, _CacheEntry> _cache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};
  static String? _activePortalKey;

  /// Drop in-flight matching (Providers tab / background). Safe anytime.
  static void cancel({String reason = 'cancel'}) {
    _session++;
    _inFlight.clear();
    debugPrint('[PortalLiveTvSearch] cancel session=$_session ($reason)');
  }

  /// Clear result cache (portal change / shelf warm for a new key).
  static void invalidateCache() {
    _cache.clear();
    _inFlight.clear();
    _activePortalKey = null;
    debugPrint('[PortalLiveTvSearch] cache invalidated');
  }

  static bool get appInForeground {
    final life = SchedulerBinding.instance.lifecycleState;
    return life == null ||
        life == AppLifecycleState.resumed ||
        life == AppLifecycleState.inactive;
  }

  /// Returns playable source maps (`url` / `label` / `liveSourceKind` / …).
  static Future<List<Map<String, dynamic>>> search(
    Map<String, dynamic> params,
  ) async {
    if (!appInForeground) {
      debugPrint('[PortalLiveTvSearch] skip — app not foreground');
      return const [];
    }

    final session = _session;
    bool dead() => session != _session || !appInForeground;

    final verified = await _resolvePortal();
    if (dead() || verified == null) return const [];

    if (_activePortalKey != null &&
        _activePortalKey != verified.key) {
      _cache.clear();
      _inFlight.clear();
    }
    _activePortalKey = verified.key;

    final gameRaw = params['game'];
    final game = gameRaw is Map
        ? Map<String, dynamic>.from(gameRaw)
        : <String, dynamic>{};
    final categoryIds = <String>[
      for (final e in (params['categoryIds'] is List
          ? params['categoryIds'] as List
          : const []))
        e.toString().trim(),
    ]..removeWhere((e) => e.isEmpty);

    final home = (game['homeTeam'] ?? '').toString().trim();
    final away = (game['awayTeam'] ?? '').toString().trim();
    final title = (game['title'] ?? '').toString().trim();
    if (home.isEmpty && away.isEmpty && title.isEmpty) {
      debugPrint('[PortalLiveTvSearch] no title/teams for search');
      return const [];
    }

    final force = params['force'] == true || params['refresh'] == true;
    final cacheKey = _cacheKey(
      portalKey: verified.key,
      categoryIds: categoryIds,
      game: game,
    );
    if (force) {
      _cache.remove(cacheKey);
      _inFlight.remove(cacheKey);
    } else {
      final cached = _cacheGet(cacheKey);
      if (cached != null) {
        if (dead()) return const [];
        return cached;
      }
      final pending = _inFlight[cacheKey];
      if (pending != null) return pending;
    }

    final future = _runMatch(
      verified: verified,
      game: game,
      categoryIds: categoryIds,
      cacheKey: cacheKey,
      dead: dead,
    );
    if (!force) _inFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      final cur = _inFlight[cacheKey];
      if (identical(cur, future)) _inFlight.remove(cacheKey);
    }
  }

  static Future<List<Map<String, dynamic>>> _runMatch({
    required VerifiedPortal verified,
    required Map<String, dynamic> game,
    required List<String> categoryIds,
    required String cacheKey,
    required bool Function() dead,
  }) async {
    try {
      final portal = verified.portal;
      if (portal.platform.supportsForjaSports) {
        try {
          await PortalCatalogPage.ensureSection(
            portal: portal,
            section: 'live',
          );
        } catch (e) {
          debugPrint('[PortalLiveTvSearch] live shelf ensure failed: $e');
        }
        if (dead()) return const [];
      }
      final Map<String, dynamic> portalCreds;
      if (portal.platform == PortalPlatform.stalker) {
        portalCreds = {
          'stalker': {
            'url': portal.url,
            'username': portal.username,
            'password': portal.password,
          },
        };
      } else {
        portalCreds = {
          'xtream': {
            'url': portal.url,
            'username': portal.username,
            'password': portal.password,
          },
        };
      }
      final requestBase = {
        'action': 'sport_match_streams',
        'game': game,
        ...portalCreds,
        'category_ids': categoryIds,
      };

      final broadcastCount = () {
        final raw = game['broadcastChannels'] ?? game['broadcast_channels'];
        return raw is List ? raw.length : 0;
      }();
      debugPrint(
        '[PortalLiveTvSearch] start portal=${verified.key} '
        'title="${game['title']}" teams="${game['homeTeam']}"/'
        '"${game['awayTeam']}" broadcasts=$broadcastCount',
      );

      final excludeStreamIds = <String>[];
      final accumulated = <Map<String, dynamic>>[];
      final seen = <String>{};

      void trackExclude(Iterable<Map<String, dynamic>> batch) {
        for (final s in batch) {
          final id = (s['streamId'] ?? '').toString().trim();
          if (id.isNotEmpty) excludeStreamIds.add(id);
        }
      }

      void merge(Iterable<Map<String, dynamic>> batch) {
        for (final s in batch) {
          final id = (s['streamId'] ?? '').toString().trim();
          final url = (s['url'] ?? '').toString().trim();
          final key = id.isNotEmpty ? 'id:$id' : 'url:$url';
          if (id.isEmpty && url.isEmpty) continue;
          if (!seen.add(key)) continue;
          accumulated.add(s);
        }
      }

      final fastRaw = await runLiveSportsFetchJson(
        jsonEncode({...requestBase, 'skip_epg': true}),
      );
      if (dead()) return const [];
      final fastParsed = _decode(fastRaw);
      if (_cancelled(fastParsed)) return const [];
      if (fastParsed.containsKey('error')) {
        debugPrint('[PortalLiveTvSearch] fast error: ${fastParsed['error']}');
      } else {
        final fast = _parseItems(
          fastParsed['items'] as List? ?? const [],
          verified: verified,
        );
        merge(fast);
        trackExclude(fast);
        debugPrint('[PortalLiveTvSearch] fast hits=${fast.length}');
      }

      var epgOffset = 0;
      var epgMore = true;
      while (epgMore) {
        if (dead()) return accumulated;
        final raw = await runLiveSportsFetchJson(
          jsonEncode({
            ...requestBase,
            'epg_offset': epgOffset,
            'epg_limit': _epgBatchSize,
            'exclude_stream_ids': excludeStreamIds,
          }),
        );
        if (dead()) return accumulated;
        final parsed = _decode(raw);
        if (_cancelled(parsed)) return accumulated;
        if (parsed.containsKey('error')) {
          debugPrint('[PortalLiveTvSearch] epg error: ${parsed['error']}');
          break;
        }
        final batch = _parseItems(
          parsed['items'] as List? ?? const [],
          verified: verified,
        );
        if (batch.isNotEmpty) {
          merge(batch);
          trackExclude(batch);
        }
        epgMore = parsed['epg_more'] == true;
        if (epgMore) {
          epgOffset = (parsed['epg_next_offset'] as num?)?.toInt() ??
              epgOffset + _epgBatchSize;
        }
      }

      if (dead()) return accumulated;
      debugPrint('[PortalLiveTvSearch] done hits=${accumulated.length}');
      if (accumulated.isEmpty) return const [];
      final enriched = await _ensureLogos(accumulated, verified.key);
      if (dead()) return enriched;
      _cachePut(cacheKey, enriched);
      return enriched;
    } catch (e, st) {
      debugPrint('[PortalLiveTvSearch] failed: $e\n$st');
      return const [];
    }
  }

  static Future<VerifiedPortal?> _resolvePortal() async {
    try {
      await PortalVaultInventory.ensureMigratedFromStore();
      final portals = await PortalsHost.loadVaultVerifiedPortals();
      if (portals.isEmpty) return null;

      final activeRaw =
          (await EngineVault.get(PortalVaultKeys.active) ?? '').toString().trim();

      VerifiedPortal? firstSports;
      for (final p in portals) {
        if (!p.portal.platform.supportsForjaSports) continue;
        firstSports ??= p;
        if (activeRaw.isEmpty) continue;
        if (PortalsHost.samePortalKey(p.key, activeRaw) ||
            PortalsHost.samePortalKey(p.credKey, activeRaw) ||
            PortalsHost.samePortalKey(
              PortalsHost.packPortalKey(p.portal),
              activeRaw,
            )) {
          return p;
        }
      }
      return firstSports;
    } catch (e, st) {
      debugPrint('[PortalLiveTvSearch] resolve portal failed: $e\n$st');
      return null;
    }
  }

  static Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return {'error': 'empty'};
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {'error': 'bad_json'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static bool _cancelled(Map<String, dynamic> parsed) =>
      (parsed['error'] ?? '').toString() == 'cancelled';

  static List<Map<String, dynamic>> _parseItems(
    List<dynamic> list, {
    required VerifiedPortal verified,
  }) {
    final portal = verified.portal;
    final kind = portal.platform == PortalPlatform.stalker
        ? 'iptvStalker'
        : 'iptvXtream';
    final out = <Map<String, dynamic>>[];
    for (final s in list) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      var url = (m['url'] ?? '').toString().trim();
      final streamId =
          (m['stream_id'] ?? m['streamId'] ?? '').toString().trim();
      final epgChannelId =
          (m['epg_channel_id'] ?? m['epgChannelId'] ?? '').toString().trim();
      if (portal.platform == PortalPlatform.stalker) {
        if (streamId.isEmpty) continue;
      } else {
        if (streamId.isNotEmpty) {
          final rebuilt = PortalClient.streamUrl(
            portal,
            PortalStream(
              streamId: streamId,
              name: '',
              icon: '',
              categoryId: '',
              containerExt: 'ts',
              epgChannelId: '',
              kind: 'live',
            ),
          );
          if (rebuilt.isNotEmpty) url = rebuilt;
        }
        if (url.isEmpty) continue;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          continue;
        }
      }
      final channel = (m['name'] ?? 'Stream').toString().trim();
      final category = (m['title'] ?? '').toString().trim();
      final logo = (m['logo'] ?? m['stream_icon'] ?? m['cover'] ?? '')
          .toString()
          .trim();
      out.add({
        'url': url,
        'label': channel.isEmpty ? 'Stream' : channel,
        if (category.isNotEmpty) 'detail': category,
        if (logo.isNotEmpty) 'logoUrl': logo,
        'provider': verified.displayLabel,
        'portalKey': PortalsHost.packPortalKey(portal),
        if (streamId.isNotEmpty) 'streamId': streamId,
        if (epgChannelId.isNotEmpty) 'epgChannelId': epgChannelId,
        'liveSourceKind': kind,
      });
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> _ensureLogos(
    List<Map<String, dynamic>> sources,
    String portalKey,
  ) async {
    if (sources.isEmpty) return sources;
    final needLogo =
        sources.any((s) => (s['logoUrl'] ?? '').toString().trim().isEmpty);
    final needEpg = sources.any(
      (s) =>
          (s['streamId'] ?? '').toString().trim().isNotEmpty &&
          (s['epgChannelId'] ?? '').toString().trim().isEmpty,
    );
    if (!needLogo && !needEpg) return sources;

    final byId = <String, String>{};
    final byEpgId = <String, String>{};
    final byName = <String, String>{};
    try {
      final shelf = IptvCatalogDb.exportShelf(portalKey, 'live');
      final streams = shelf?['streams'];
      if (streams is List) {
        for (final raw in streams) {
          if (raw is! Map) continue;
          final s = Map<String, dynamic>.from(raw);
          final id =
              (s['id'] ?? s['stream_id'] ?? s['streamId'] ?? '')
                  .toString()
                  .trim();
          final epgId =
              (s['epgChannelId'] ?? s['epg_channel_id'] ?? '')
                  .toString()
                  .trim();
          if (id.isNotEmpty && epgId.isNotEmpty) byEpgId[id] = epgId;
          final icon =
              (s['icon'] ?? s['logo'] ?? s['stream_icon'] ?? '')
                  .toString()
                  .trim();
          if (icon.isEmpty) continue;
          if (id.isNotEmpty) byId[id] = icon;
          final n = (s['name'] ?? s['title'] ?? '').toString().trim().toLowerCase();
          if (n.isNotEmpty) byName.putIfAbsent(n, () => icon);
        }
      }
    } catch (e) {
      debugPrint('[PortalLiveTvSearch] catalog logo lookup failed: $e');
    }
    if (byId.isEmpty && byName.isEmpty && byEpgId.isEmpty) return sources;

    String? lookup(String channelName) {
      final key = channelName.trim().toLowerCase();
      if (key.isEmpty) return null;
      final exact = byName[key];
      if (exact != null && exact.isNotEmpty) return exact;
      final stem = key.replaceFirst(RegExp(r'\s+\d+$'), '').trim();
      if (stem.isNotEmpty && stem != key) {
        final byStem = byName[stem];
        if (byStem != null && byStem.isNotEmpty) return byStem;
      }
      for (final e in byName.entries) {
        if (e.key.isEmpty) continue;
        if (key.startsWith('${e.key} ') || e.key.startsWith('$key ')) {
          return e.value;
        }
      }
      return null;
    }

    return [
      for (final s in sources)
        () {
          final id = (s['streamId'] ?? '').toString().trim();
          var logo = (s['logoUrl'] ?? '').toString().trim();
          if (logo.isEmpty) {
            if (id.isNotEmpty) logo = byId[id] ?? '';
            if (logo.isEmpty) {
              logo = lookup((s['label'] ?? '').toString()) ?? '';
            }
          }
          var epg = (s['epgChannelId'] ?? '').toString().trim();
          if (epg.isEmpty && id.isNotEmpty) epg = byEpgId[id] ?? '';
          if (logo == (s['logoUrl'] ?? '').toString().trim() &&
              epg == (s['epgChannelId'] ?? '').toString().trim()) {
            return s;
          }
          return {
            ...s,
            if (logo.isNotEmpty) 'logoUrl': logo,
            if (epg.isNotEmpty) 'epgChannelId': epg,
          };
        }(),
    ];
  }

  static String _fixtureKey(Map<String, dynamic> game) {
    final home = (game['homeTeam'] ?? '').toString();
    final away = (game['awayTeam'] ?? '').toString();
    final pair = matchTeamPairKey(home, away);
    if (pair != null) return 't:$pair';
    final title = matchTextKey((game['title'] ?? '').toString());
    final dateMs = switch (game['dateMs']) {
      final num n => n.toInt(),
      _ => int.tryParse((game['dateMs'] ?? '').toString()) ?? 0,
    };
    if (title.isNotEmpty && dateMs > 0) {
      return 'n:$title@${dateMs ~/ 60000}';
    }
    if (title.isNotEmpty) return 'n:$title';
    final id = (game['id'] ?? '').toString().trim();
    return id.isEmpty ? 'id:unknown' : 'id:$id';
  }

  static String _cacheKey({
    required String portalKey,
    required List<String> categoryIds,
    required Map<String, dynamic> game,
  }) {
    final cats = List<String>.from(categoryIds)..sort();
    return '$portalKey|${cats.join(',')}|${_fixtureKey(game)}';
  }

  static List<Map<String, dynamic>>? _cacheGet(String key) {
    final hit = _cache[key];
    if (hit == null) return null;
    if (DateTime.now().isAfter(hit.expiresAt) || hit.sources.isEmpty) {
      _cache.remove(key);
      return null;
    }
    return [for (final s in hit.sources) Map<String, dynamic>.from(s)];
  }

  static void _cachePut(String key, List<Map<String, dynamic>> sources) {
    if (sources.isEmpty) return;
    _cache[key] = _CacheEntry(
      expiresAt: DateTime.now().add(_cacheTtl),
      sources: [for (final s in sources) Map<String, dynamic>.from(s)],
    );
  }

  @visibleForTesting
  static String fixtureKeyForTest(Map<String, dynamic> game) =>
      _fixtureKey(game);

  /// Kept for unit tests that assert broadcast/team token overlap helpers.
  @visibleForTesting
  static bool channelMatchesGameForTest(
    String name,
    Map<String, dynamic> game,
  ) {
    final n = _normToken(name);
    if (n.isEmpty) return false;
    final home = _normToken((game['homeTeam'] ?? '').toString());
    final away = _normToken((game['awayTeam'] ?? '').toString());
    final title = _normToken((game['title'] ?? '').toString());
    final broadcasts = game['broadcastChannels'];
    if (broadcasts is List) {
      for (final b in broadcasts) {
        final token = _normToken(b.toString());
        if (token.isNotEmpty && (n.contains(token) || token.contains(n))) {
          return true;
        }
      }
    }
    if (home.isNotEmpty &&
        away.isNotEmpty &&
        n.contains(home) &&
        n.contains(away)) {
      return true;
    }
    if (home.isNotEmpty && n.contains(home)) return true;
    if (away.isNotEmpty && n.contains(away)) return true;
    if (title.isNotEmpty && n.contains(title)) return true;
    return false;
  }

  static String _normToken(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class _CacheEntry {
  const _CacheEntry({required this.expiresAt, required this.sources});
  final DateTime expiresAt;
  final List<Map<String, dynamic>> sources;
}
