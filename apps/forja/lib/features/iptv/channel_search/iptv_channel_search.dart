import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:rust/rust.dart' show runLiveSportsFetchJson;

/// Thin IPTV host glue for Live TV channel search (RFC-096).
///
/// Engine owns ranking (`sport_match_streams`). This class resolves portal
/// credentials, calls Rust, normalizes play URLs/logos, and caches results.
abstract final class IptvChannelSearch {
  IptvChannelSearch._();

  static const _cacheTtl = Duration(minutes: 30);
  static const _epgBatchSize = 12;

  /// In-session Portals pick (Live Sports / IPTV). Prefer over disk last-key.
  /// Set from [IptvController] when the active portal changes.
  static String? sessionPortalKey;

  /// Last / requested Xtream or Stalker portal for Forja Sports.
  static Future<VerifiedPortal?> resolvePortal({String? portalKey}) async {
    final portals = await IptvStore.load();

    VerifiedPortal? pickSports(String key) {
      final k = key.trim();
      if (k.isEmpty) return null;
      for (final p in portals) {
        if (p.key == k && p.portal.platform.supportsForjaSports) return p;
      }
      return null;
    }

    final explicit = pickSports(portalKey ?? '');
    if (explicit != null) return explicit;

    final session = pickSports(sessionPortalKey ?? '');
    if (session != null) return session;

    final last = pickSports(await IptvStore.loadLastPortalKey() ?? '');
    if (last != null) return last;

    // Last portal may be M3U / deleted — use any Forja Sports-capable portal.
    for (final p in portals) {
      if (p.portal.platform.supportsForjaSports) return p;
    }
    return null;
  }

  /// Opaque game map from a schedule row (pack `sportMatchGame` or passthrough).
  static Map<String, dynamic> gameFromLegacyRow(Map<String, dynamic> row) {
    final raw = row['sportMatchGame'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final title = (row['title'] ?? row['name'] ?? '').toString().trim();
    final home = (row['homeTeam'] ?? '').toString().trim();
    final away = (row['awayTeam'] ?? '').toString().trim();
    final category = (row['category'] ?? row['sport'] ?? '').toString().trim();
    final dateMs = switch (row['dateMs']) {
      final num n => n.toInt(),
      _ => int.tryParse((row['dateMs'] ?? '').toString()) ?? 0,
    };
    return {
      'id': (row['id'] ?? '').toString(),
      'title': title,
      'sport': category,
      'category': category,
      'homeTeam': home,
      'awayTeam': away,
      'dateMs': dateMs,
      if (dateMs > 0)
        'date': DateTime.fromMillisecondsSinceEpoch(dateMs, isUtc: true)
            .toIso8601String(),
    };
  }

  static Map<String, dynamic> gameFromMatch(MatchEvent match) {
    if (match.sportMatchGame != null) {
      return Map<String, dynamic>.from(match.sportMatchGame!);
    }
    return gameFromLegacyRow({
      'id': match.id,
      'title': match.title,
      'homeTeam': match.homeTeam,
      'awayTeam': match.awayTeam,
      'category': match.category,
      'dateMs': match.dateMs,
    });
  }

  static Future<List<IptvPlaySource>> search({
    required Map<String, dynamic> game,
    List<String> categoryIds = const [],
    String? portalKey,
    void Function(List<IptvPlaySource> batch)? onPartial,
    bool force = false,
  }) async {
    final portal = await resolvePortal(portalKey: portalKey);
    if (portal == null) {
      debugPrint('[IptvChannelSearch] no Xtream/Stalker portal for Live TV');
      return [];
    }

    final home = (game['homeTeam'] ?? '').toString().trim();
    final away = (game['awayTeam'] ?? '').toString().trim();
    final title = (game['title'] ?? '').toString().trim();
    if (home.isEmpty && away.isEmpty && title.isEmpty) {
      debugPrint('[IptvChannelSearch] no title/teams for search');
      return [];
    }

    final broadcastCount = () {
      final raw = game['broadcastChannels'] ?? game['broadcast_channels'];
      return raw is List ? raw.length : 0;
    }();
    debugPrint(
      '[IptvChannelSearch] start portal=${portal.key} '
      'title="$title" teams="$home"/"$away" broadcasts=$broadcastCount',
    );

    final cats = List<String>.from(categoryIds);
    final cacheKey = _cacheKey(
      portalKey: portal.key,
      categoryIds: cats,
      game: game,
    );
    if (force) {
      _cache.remove(cacheKey);
      _inFlight.remove(cacheKey);
    } else {
      final cached = _cacheGet(cacheKey);
      if (cached != null) {
        final logos = await _ensureLogos(cached, portal.key);
        final result = _ensureUrls(logos, portal);
        onPartial?.call(result);
        return result;
      }
      final inflight = _inFlight[cacheKey];
      if (inflight != null) {
        inflight.subscribe(onPartial);
        return inflight.future;
      }
    }

    late final _Inflight coordinator;
    final future = () async {
      try {
        final p = portal.portal;
        final Map<String, dynamic> portalCreds;
        if (p.platform == IptvPortalPlatform.stalker) {
          portalCreds = {
            'stalker': {
              'url': p.url,
              'username': p.username,
              'password': p.password,
            },
          };
        } else {
          portalCreds = {
            'xtream': {
              'url': p.url,
              'username': p.username,
              'password': p.password,
            },
          };
        }
        final requestBase = {
          'action': 'sport_match_streams',
          'game': game,
          ...portalCreds,
          'category_ids': cats,
        };

        void emitPartial(List<IptvPlaySource> batch) => coordinator.emit(batch);

        final excludeStreamIds = <String>[];
        final accumulated = <IptvPlaySource>[];

        void trackExcludeIds(Iterable<IptvPlaySource> batch) {
          for (final s in batch) {
            final id = (s.streamId ?? '').trim();
            if (id.isNotEmpty) excludeStreamIds.add(id);
          }
        }

        final fastRaw = await runLiveSportsFetchJson(
          jsonEncode({...requestBase, 'skip_epg': true}),
        );
        final fastParsed = jsonDecode(fastRaw) as Map<String, dynamic>;
        if (_cancelled(fastParsed)) {
          debugPrint('[IptvChannelSearch] cancelled (fast)');
          return <IptvPlaySource>[];
        }
        if (fastParsed.containsKey('error')) {
          debugPrint(
            '[IptvChannelSearch] fast error: ${fastParsed['error']}',
          );
        } else {
          final fast = _parseItems(
            fastParsed['items'] as List? ?? [],
            platform: p.platform,
          );
          final fastNorm = _ensureUrls(fast, portal);
          emitPartial(fastNorm);
          accumulated.addAll(fastNorm);
          trackExcludeIds(fastNorm);
          debugPrint('[IptvChannelSearch] fast hits=${fastNorm.length}');
        }

        var epgOffset = 0;
        var epgMore = true;
        while (epgMore) {
          final raw = await runLiveSportsFetchJson(
            jsonEncode({
              ...requestBase,
              'epg_offset': epgOffset,
              'epg_limit': _epgBatchSize,
              'exclude_stream_ids': excludeStreamIds,
            }),
          );
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          if (_cancelled(parsed)) {
            debugPrint(
              '[IptvChannelSearch] cancelled (epg) kept=${accumulated.length}',
            );
            return accumulated;
          }
          if (parsed.containsKey('error')) {
            debugPrint(
              '[IptvChannelSearch] streams error: ${parsed['error']}',
            );
            break;
          }
          final batch = _parseItems(
            parsed['items'] as List? ?? [],
            platform: p.platform,
          );
          if (batch.isNotEmpty) {
            final normalized = _ensureUrls(batch, portal);
            emitPartial(normalized);
            accumulated.addAll(normalized);
            trackExcludeIds(normalized);
          }
          epgMore = parsed['epg_more'] == true;
          if (epgMore) {
            epgOffset = (parsed['epg_next_offset'] as num?)?.toInt() ??
                epgOffset + _epgBatchSize;
          }
        }

        debugPrint('[IptvChannelSearch] done hits=${accumulated.length}');
        if (accumulated.isEmpty) return <IptvPlaySource>[];
        final enriched = await _ensureLogos(accumulated, portal.key);
        _cachePut(cacheKey, enriched);
        return enriched;
      } catch (e, st) {
        debugPrint('[IptvChannelSearch] failed: $e\n$st');
        rethrow;
      } finally {
        _inFlight.remove(cacheKey);
      }
    }();

    coordinator = _Inflight(future);
    coordinator.subscribe(onPartial);
    _inFlight[cacheKey] = coordinator;
    return future;
  }

  /// JSON rows for the JS host bridge (`ctx.host.iptv.searchChannels`).
  static Future<List<Map<String, dynamic>>> searchAsMaps({
    required Map<String, dynamic> game,
    List<String> categoryIds = const [],
    String? portalKey,
  }) async {
    final sources = await search(
      game: game,
      categoryIds: categoryIds,
      portalKey: portalKey,
    );
    return [
      for (final s in sources)
        {
          'url': s.url,
          'label': s.label,
          if ((s.detail ?? '').trim().isNotEmpty) 'detail': s.detail,
          if ((s.logoUrl ?? '').trim().isNotEmpty) 'logoUrl': s.logoUrl,
          if ((s.streamId ?? '').trim().isNotEmpty) 'streamId': s.streamId,
          if ((s.epgChannelId ?? '').trim().isNotEmpty)
            'epgChannelId': s.epgChannelId,
          if (s.liveSourceKind != null)
            'liveSourceKind': s.liveSourceKind!.name,
        },
    ];
  }

  static void invalidateCache() {
    _cache.clear();
    _inFlight.clear();
  }
}

class _CacheEntry {
  final DateTime expiresAt;
  final List<IptvPlaySource> sources;
  const _CacheEntry({required this.expiresAt, required this.sources});
}

final Map<String, _CacheEntry> _cache = {};

final class _Inflight {
  _Inflight(this.future);

  final Future<List<IptvPlaySource>> future;
  final List<IptvPlaySource> _accumulated = [];
  final Set<String> _seenKeys = {};
  final List<void Function(List<IptvPlaySource> batch)> _listeners = [];

  void subscribe(void Function(List<IptvPlaySource> batch)? onPartial) {
    if (onPartial == null) return;
    if (_accumulated.isNotEmpty) {
      onPartial(List<IptvPlaySource>.from(_accumulated));
    }
    _listeners.add(onPartial);
  }

  void emit(List<IptvPlaySource> batch) {
    if (batch.isEmpty) return;
    final fresh = <IptvPlaySource>[];
    for (final s in batch) {
      final id = (s.streamId ?? '').trim();
      final url = s.url.trim();
      final key = id.isNotEmpty ? 'id:$id' : 'url:$url';
      if (id.isEmpty && url.isEmpty) continue;
      if (!_seenKeys.add(key)) continue;
      fresh.add(s);
      _accumulated.add(s);
    }
    if (fresh.isEmpty) return;
    for (final listener
        in List<void Function(List<IptvPlaySource> batch)>.from(_listeners)) {
      listener(fresh);
    }
  }
}

final Map<String, _Inflight> _inFlight = {};

String _fixtureKey(Map<String, dynamic> game) {
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

String _cacheKey({
  required String portalKey,
  required List<String> categoryIds,
  required Map<String, dynamic> game,
}) {
  final cats = List<String>.from(categoryIds)..sort();
  return '$portalKey|${cats.join(',')}|${_fixtureKey(game)}';
}

List<IptvPlaySource>? _cacheGet(String key) {
  final hit = _cache[key];
  if (hit == null) return null;
  if (DateTime.now().isAfter(hit.expiresAt) || hit.sources.isEmpty) {
    _cache.remove(key);
    return null;
  }
  return List<IptvPlaySource>.from(hit.sources);
}

void _cachePut(String key, List<IptvPlaySource> sources) {
  if (sources.isEmpty) return;
  _cache[key] = _CacheEntry(
    expiresAt: DateTime.now().add(IptvChannelSearch._cacheTtl),
    sources: List<IptvPlaySource>.from(sources),
  );
}

bool _cancelled(Map<String, dynamic> parsed) =>
    (parsed['error'] ?? '').toString() == 'cancelled';

List<IptvPlaySource> _parseItems(
  List<dynamic> list, {
  IptvPortalPlatform platform = IptvPortalPlatform.xtream,
}) {
  final kind = switch (platform) {
    IptvPortalPlatform.stalker => IptvLiveSourceKind.iptvStalker,
    _ => IptvLiveSourceKind.iptvXtream,
  };
  final out = <IptvPlaySource>[];
  for (final s in list) {
    if (s is! Map) continue;
    final url = s['url']?.toString().trim() ?? '';
    final streamId = (s['stream_id'] ?? s['streamId'] ?? '').toString().trim();
    final epgChannelId =
        (s['epg_channel_id'] ?? s['epgChannelId'] ?? '').toString().trim();
    if (platform == IptvPortalPlatform.stalker) {
      if (streamId.isEmpty) continue;
    } else {
      if (url.isEmpty) continue;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        continue;
      }
    }
    final channel = (s['name'] ?? 'Stream').toString().trim();
    final category = (s['title'] ?? '').toString().trim();
    final logo = (s['logo'] ?? s['stream_icon'] ?? s['cover'] ?? '')
        .toString()
        .trim();
    final name = channel.isEmpty ? 'Stream' : channel;
    out.add(IptvPlaySource(
      url: url,
      label: name,
      detail: category.isEmpty ? null : category,
      logoUrl: logo.isEmpty ? null : logo,
      streamId: streamId.isEmpty ? null : streamId,
      epgChannelId: epgChannelId.isEmpty ? null : epgChannelId,
      liveSourceKind: kind,
    ));
  }
  return out;
}

List<IptvPlaySource> _ensureUrls(
  List<IptvPlaySource> sources,
  VerifiedPortal portal,
) {
  if (sources.isEmpty || portal.portal.platform != IptvPortalPlatform.xtream) {
    return sources;
  }
  final p = portal.portal;
  return [
    for (final s in sources)
      () {
        final id = (s.streamId ?? '').trim();
        if (id.isEmpty) return s;
        final url = IptvClient.streamUrl(
          p,
          IptvStream(
            streamId: id,
            name: '',
            icon: '',
            categoryId: '',
            containerExt: 'ts',
            epgChannelId: '',
            kind: 'live',
          ),
        );
        if (url.isEmpty || url == s.url) return s;
        return IptvPlaySource(
          url: url,
          label: s.label,
          detail: s.detail,
          logoUrl: s.logoUrl,
          streamId: s.streamId,
          epgChannelId: s.epgChannelId,
          headers: s.headers,
          liveSourceKind: s.liveSourceKind,
        );
      }(),
  ];
}

Future<List<IptvPlaySource>> _ensureLogos(
  List<IptvPlaySource> sources,
  String portalKey,
) async {
  if (sources.isEmpty) return sources;
  final needLogo = sources.any((s) => (s.logoUrl ?? '').trim().isEmpty);
  final needEpg = sources.any(
    (s) =>
        (s.streamId ?? '').trim().isNotEmpty &&
        (s.epgChannelId ?? '').trim().isEmpty,
  );
  if (!needLogo && !needEpg) return sources;

  final byId = <String, String>{};
  final byEpgId = <String, String>{};
  final byName = <String, String>{};
  try {
    final shelf = await IptvCatalogDiskStore.load(portalKey, IptvSection.live);
    if (shelf != null) {
      for (final s in shelf.streams) {
        final id = s.streamId.trim();
        if (id.isNotEmpty) {
          final epgId = s.epgChannelId.trim();
          if (epgId.isNotEmpty) byEpgId[id] = epgId;
        }
        final icon = s.icon.trim();
        if (icon.isEmpty) continue;
        if (id.isNotEmpty) byId[id] = icon;
        final n = s.name.trim().toLowerCase();
        if (n.isNotEmpty) byName.putIfAbsent(n, () => icon);
      }
    }
  } catch (e) {
    debugPrint('[IptvChannelSearch] catalog logo lookup failed: $e');
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
        final id = (s.streamId ?? '').trim();
        String? logo = (s.logoUrl ?? '').trim().isNotEmpty ? s.logoUrl : null;
        if (logo == null || logo.isEmpty) {
          if (id.isNotEmpty) logo = byId[id];
          logo ??= lookup(s.chromeTitle);
        }
        final epgId = (s.epgChannelId ?? '').trim().isNotEmpty
            ? s.epgChannelId
            : (id.isNotEmpty ? byEpgId[id] : null);
        if (logo == s.logoUrl && epgId == s.epgChannelId) return s;
        return IptvPlaySource(
          url: s.url,
          label: s.label,
          detail: s.detail,
          logoUrl: logo ?? s.logoUrl,
          streamId: s.streamId,
          epgChannelId: epgId,
          headers: s.headers,
          liveSourceKind: s.liveSourceKind,
        );
      }(),
  ];
}
