import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:forja/shared/engine/runtime/open/host_playback_open.dart';
import 'package:forja/shared/engine/vault/engine_vault.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shared/player/sources/stream_play_hooks.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Thin pack-driven portal VOD play — vault portals + stream URL shape.
/// Browse UI lives in the IPTV hub pack; this only wires details → [HostPlaybackOpen].
abstract final class PackStreamPlayHooks {
  PackStreamPlayHooks._();

  /// Pack vault inventory key (hubs/iptv `_prefs.js`).
  static const _vaultPortals = 'iptv.portals';
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    KitStreamPlayHooks.hubDetailsParams = _hubDetailsParams;
    KitStreamPlayHooks.resolvePortalFromMeta = _resolvePortal;
    KitStreamPlayHooks.playPortalFromContext = _playFromContext;
    KitStreamPlayHooks.openVodStream = _openVodStream;
  }

  static Map<String, dynamic> _hubDetailsParams(MetaItem seed) {
    final open = seed.open;
    final extras = open?.extras ?? const <String, dynamic>{};
    return {
      'id': open?.id ?? seed.id,
      'streamId': extras['streamId'] ?? open?.id ?? seed.id,
      'portalKey': extras['portalKey'] ?? '',
      // Prefer cleaned display name; keep raw only as last resort.
      'name': extras['name'] ?? seed.name ?? extras['streamName'],
      'title': extras['name'] ?? seed.name ?? extras['streamName'],
      'streamName': extras['streamName'] ?? extras['name'] ?? seed.name,
      'icon': extras['streamIcon'] ?? extras['icon'] ?? seed.poster,
      'poster': extras['streamIcon'] ?? extras['icon'] ?? seed.poster,
      'plot': extras['plot'] ?? seed.description,
      'description': extras['plot'] ?? seed.description,
      'kind': extras['kind'] ?? (extras['movie'] == true ? 'vod' : 'series'),
      'movie': extras['movie'] == true,
      'categoryId': extras['categoryId'] ?? '',
      'containerExt': extras['containerExt'] ?? '',
      'platform': extras['platform'] ?? 'xtream',
      if (extras['portalEpisodes'] != null)
        'portalEpisodes': extras['portalEpisodes'],
    };
  }

  static Future<Object?> _resolvePortal(MetaItem meta) async {
    final key = (meta.open?.extras['portalKey'] ?? '').toString().trim();
    if (key.isEmpty) return null;
    final portals = await _loadPortals();
    for (final p in portals) {
      if (_portalKey(p) == key) return p;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _loadPortals() async {
    final raw = await EngineVault.get(_vaultPortals);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return [
        for (final e in parsed)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String _portalKey(Map<String, dynamic> portal) {
    final url = (portal['url'] ?? '').toString().trim().toLowerCase();
    final user = (portal['username'] ?? '').toString().trim().toLowerCase();
    return '$url|$user';
  }

  static String _normBase(String url) {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) return '';
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
      u = 'http://$u';
    }
    return u.replaceFirst(RegExp(r'/player_api\.php$', caseSensitive: false), '');
  }

  static String _streamUrl({
    required Map<String, dynamic> portal,
    required String folder,
    required String id,
    required String ext,
  }) {
    final base = _normBase((portal['url'] ?? '').toString());
    final user = (portal['username'] ?? '').toString();
    final pass = (portal['password'] ?? '').toString();
    final e = ext.replaceFirst(RegExp(r'^\.'), '');
    final useExt = e.isEmpty ? (folder == 'live' ? 'ts' : 'mp4') : e;
    if (base.isEmpty || user.isEmpty || pass.isEmpty || id.isEmpty) return '';
    return '$base/$folder/${Uri.encodeComponent(user)}/'
        '${Uri.encodeComponent(pass)}/${Uri.encodeComponent(id)}.$useExt';
  }

  static Future<void> _playFromContext({
    required BuildContext context,
    required PlayContext ctx,
  }) async {
    final meta = ctx.metaItem;
    if (meta == null) return;
    final portalRaw = await _resolvePortal(meta);
    if (portalRaw is! Map<String, dynamic> || !context.mounted) {
      ForjaToast.error('Portal not found');
      return;
    }
    final open = meta.open;
    final extras = open?.extras ?? const <String, dynamic>{};
    final isMovie = extras['movie'] == true ||
        extras['kind'] == 'vod' ||
        extras['kind'] == 'movie' ||
        meta.type == 'movie';
    final containerExt =
        (extras['containerExt'] ?? 'mp4').toString().replaceFirst(RegExp(r'^\.'), '');

    if (isMovie) {
      final streamId =
          (extras['streamId'] ?? open?.id ?? '').toString().trim();
      final url = _streamUrl(
        portal: portalRaw,
        folder: 'movie',
        id: streamId,
        ext: containerExt,
      );
      if (!context.mounted) return;
      if (url.isEmpty) {
        ForjaToast.error('Could not open stream');
        return;
      }
      await HostPlaybackOpen.openUrl(
        context: context,
        url: url,
        title: meta.name,
        headers: const {'User-Agent': 'Mozilla/5.0'},
      );
      return;
    }

    final videos = meta.videos;
    final epNum = ctx.episode ?? 1;
    MetaVideo? selected;
    for (final v in videos) {
      if ((v.episode ?? 1) == epNum) {
        selected = v;
        break;
      }
    }
    selected ??= videos.isEmpty ? null : videos.first;
    if (selected == null) {
      ForjaToast.error('No episode selected');
      return;
    }
    final url = _streamUrl(
      portal: portalRaw,
      folder: 'series',
      id: selected.id,
      ext: containerExt,
    );
    if (!context.mounted) return;
    if (url.isEmpty) {
      ForjaToast.error('Could not open episode');
      return;
    }
    await HostPlaybackOpen.openUrl(
      context: context,
      url: url,
      title: 'Ep ${selected.episode ?? epNum} · ${selected.title}',
      headers: const {'User-Agent': 'Mozilla/5.0'},
    );
  }

  static Future<void> _openVodStream(
    BuildContext context, {
    required Object stream,
    required Object portal,
  }) async {
    if (stream is! Map || portal is! Map) return;
    final s = Map<String, dynamic>.from(stream);
    final p = Map<String, dynamic>.from(portal);
    final kind = (s['kind'] ?? 'vod').toString();
    final folder = kind == 'series' ? 'series' : 'movie';
    final id = (s['streamId'] ?? s['id'] ?? '').toString();
    final ext = (s['containerExt'] ?? 'mp4').toString();
    final url = _streamUrl(portal: p, folder: folder, id: id, ext: ext);
    if (url.isEmpty || !context.mounted) return;
    await HostPlaybackOpen.openUrl(
      context: context,
      url: url,
      title: (s['name'] ?? 'Stream').toString(),
      headers: const {'User-Agent': 'Mozilla/5.0'},
    );
  }
}
