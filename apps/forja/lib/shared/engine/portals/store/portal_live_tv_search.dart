import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_page.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/vault/engine_vault.dart';

/// Host-side Live TV channel match for nested `plugin.run(searchChannels)`.
///
/// Pack `searchChannels` needs flutter_js (vault + `catalog_page`). Nested under
/// Live Sports `liveTv` that path deadlocks on the single JSC queue — this
/// mirrors the pack matcher on the host shelf only.
abstract final class PortalLiveTvSearch {
  PortalLiveTvSearch._();

  static const _pageSize = PortalCatalogPage.maxPageSize;

  /// Returns playable source maps (`url` / `label` / `liveSourceKind` / …).
  static Future<List<Map<String, dynamic>>> search(
    Map<String, dynamic> params,
  ) async {
    final verified = await _resolvePortal();
    if (verified == null) return const [];
    final portal = verified.portal;

    final gameRaw = params['game'];
    final game = gameRaw is Map
        ? Map<String, dynamic>.from(gameRaw)
        : <String, dynamic>{};
    final categoryIds = <String>{
      for (final e in (params['categoryIds'] is List
          ? params['categoryIds'] as List
          : const []))
        e.toString().trim(),
    }..removeWhere((e) => e.isEmpty);

    final needles = _needles(game);
    if (needles.isEmpty) return const [];

    final refresh = params['force'] == true || params['refresh'] == true;
    final seenUrl = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final needle in needles) {
      var page = 1;
      while (true) {
        final pageBody = await PortalCatalogPage.run({
          'url': portal.url,
          'username': portal.username,
          'password': portal.password,
          'platform': portal.platform.wire,
          if (portal.userAgent.isNotEmpty) 'user_agent': portal.userAgent,
          'section': 'live',
          'category_id': '',
          'page': page,
          'page_size': _pageSize,
          'q': needle,
          if (refresh) 'refresh': true,
        });
        if (pageBody['ok'] != true) break;
        final streams = pageBody['streams'];
        if (streams is! List || streams.isEmpty) break;

        for (final raw in streams) {
          if (raw is! Map) continue;
          final st = Map<String, dynamic>.from(raw);
          final cid =
              (st['categoryId'] ?? st['category_id'] ?? '').toString().trim();
          if (categoryIds.isNotEmpty && !categoryIds.contains(cid)) continue;
          final name = (st['name'] ?? st['title'] ?? '').toString();
          if (!_channelMatchesGame(name, game)) continue;

          final stream = _toStream(st);
          if (stream.streamId.isEmpty) continue;
          final url = await PortalClient.resolvePlayUrl(
            portal,
            stream,
            section: 'live',
          );
          if (url == null || url.isEmpty) continue;
          if (!seenUrl.add(url)) continue;

          out.add({
            'url': url,
            'label': stream.name.isEmpty ? name : stream.name,
            'logoUrl': stream.icon,
            'provider': verified.displayLabel,
            'portalKey': PortalsHost.packPortalKey(portal),
            'streamId': stream.streamId,
            if (stream.epgChannelId.isNotEmpty)
              'epgChannelId': stream.epgChannelId,
            'liveSourceKind': portal.platform == PortalPlatform.stalker
                ? 'iptvStalker'
                : 'iptvXtream',
          });
        }

        final hasMore =
            pageBody['hasMore'] == true || pageBody['has_more'] == true;
        if (!hasMore) break;
        page++;
        if (page > 40) break;
      }
    }

    return out;
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

  static List<String> _needles(Map<String, dynamic> game) {
    final out = <String>[];
    void push(Object? v) {
      final t = (v ?? '').toString().trim();
      if (t.isEmpty) return;
      final low = t.toLowerCase();
      for (final e in out) {
        if (e.toLowerCase() == low) return;
      }
      out.add(t);
    }

    push(game['homeTeam']);
    push(game['awayTeam']);
    push(game['title']);
    final broadcasts = game['broadcastChannels'];
    if (broadcasts is List) {
      for (final b in broadcasts) {
        push(b);
      }
    }
    return out;
  }

  static String _normToken(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static bool _channelMatchesGame(String name, Map<String, dynamic> game) {
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

  @visibleForTesting
  static bool channelMatchesGameForTest(
    String name,
    Map<String, dynamic> game,
  ) =>
      _channelMatchesGame(name, game);

  static PortalStream _toStream(Map<String, dynamic> st) {
    final id =
        (st['id'] ?? st['stream_id'] ?? st['cmd'] ?? '').toString().trim();
    final name = (st['name'] ?? st['title'] ?? '').toString().trim();
    final icon = (st['icon'] ?? st['logo'] ?? st['stream_icon'] ?? '')
        .toString()
        .trim();
    final cat =
        (st['categoryId'] ?? st['category_id'] ?? '').toString().trim();
    final ext = (st['containerExt'] ?? st['container_extension'] ?? 'ts')
        .toString()
        .trim();
    final epg =
        (st['epgChannelId'] ?? st['epg_channel_id'] ?? '').toString().trim();
    return PortalStream(
      streamId: id,
      name: name,
      icon: icon,
      categoryId: cat,
      containerExt: ext.isEmpty ? 'ts' : ext,
      kind: 'live',
      epgChannelId: epg,
    );
  }
}
