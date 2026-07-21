import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remote overlay for provider hosts / paths / CDN Referer rules (RFC-039).
///
/// Built-ins always win when remote is missing or invalid. Extract logic stays
/// in Rust/Dart — this only retargets URLs and playback headers.
class ProviderRuntimeConfig {
  ProviderRuntimeConfig._();
  static final ProviderRuntimeConfig instance = ProviderRuntimeConfig._();

  static const _cacheKey = 'forja_provider_runtime_config_v1';
  static const _cacheAtKey = 'forja_provider_runtime_config_v1_at';
  static const supportedSchema = 1;
  static const ttl = Duration(hours: 6);

  ProviderRuntimeSnapshot _snap = ProviderRuntimeSnapshot.builtins();
  DateTime? _fetchedAt;
  Future<void>? _refresh;

  ProviderRuntimeSnapshot get snapshot => _snap;

  AnimeEmbedHostConfig get megaplay => _snap.megaplay;
  AnimeEmbedHostConfig get vidwish => _snap.vidwish;
  List<String> get miruroOrigins => _snap.miruroOrigins;
  List<String> get kisskhMirrors => _snap.kisskhMirrors;
  List<CdnRefererRule> get cdnRefererRules => _snap.cdnRefererRules;
  Map<String, ProviderUrlTemplates> get templates => _snap.templates;
  Map<String, String> get apis => _snap.apis;
  Map<String, String> get webstreamr => _snap.webstreamr;

  String? api(String key) {
    final v = _snap.apis[key]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  String? webstreamrBase(String sourceId) {
    final v = _snap.webstreamr[sourceId]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// Load disk cache (if any), then refresh from Supabase when configured.
  Future<void> ensureLoaded() async {
    await _loadDiskCache();
    _pushRustOverlay();
    unawaited(refresh());
  }

  Future<void> refresh({bool force = false}) {
    if (!force && _refresh != null) return _refresh!;
    if (!force &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < ttl) {
      return Future.value();
    }
    final fut = _refreshRemote();
    _refresh = fut.whenComplete(() {
      if (identical(_refresh, fut)) _refresh = null;
    });
    return _refresh!;
  }

  Future<void> _loadDiskCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final parsed = ProviderRuntimeSnapshot.tryParse(jsonDecode(raw));
      if (parsed == null) return;
      _snap = ProviderRuntimeSnapshot.builtins().merged(parsed);
      final atMs = p.getInt(_cacheAtKey);
      if (atMs != null) {
        _fetchedAt = DateTime.fromMillisecondsSinceEpoch(atMs);
      }
      if (kDebugMode) {
        debugPrint('[ProviderRuntime] disk cache loaded schema=${_snap.schema}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProviderRuntime] disk cache skip: $e');
    }
  }

  Future<void> _refreshRemote() async {
    try {
      await ForjaSupabase.ensureInitialized();
      final client = ForjaSupabase.clientOrNull;
      if (client == null) return;
      final row = await client
          .from('provider_runtime_config')
          .select('schema_version, config')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return;
      final config = row['config'];
      if (config is! Map) return;
      final parsed = ProviderRuntimeSnapshot.tryParse(
        Map<String, dynamic>.from(config),
      );
      if (parsed == null) {
        if (kDebugMode) {
          debugPrint('[ProviderRuntime] remote schema unsupported — builtins');
        }
        return;
      }
      _snap = ProviderRuntimeSnapshot.builtins().merged(parsed);
      _fetchedAt = DateTime.now();
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, jsonEncode(_snap.toJson()));
      await p.setInt(_cacheAtKey, _fetchedAt!.millisecondsSinceEpoch);
      _pushRustOverlay();
      if (kDebugMode) {
        debugPrint('[ProviderRuntime] remote applied schema=${_snap.schema}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProviderRuntime] refresh failed: $e');
    }
  }

  /// Push current snapshot into the Rust process (call after [Engine.init]).
  void pushToRust() => _pushRustOverlay();

  void _pushRustOverlay() {
    if (!RustLib.isInitialized) return;
    try {
      final err = RustLib.instance.setProviderRuntimeOverlay(
        jsonEncode(_snap.toJson()),
      );
      if (err.isNotEmpty && kDebugMode) {
        debugPrint('[ProviderRuntime] rust overlay: $err');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProviderRuntime] rust overlay skip: $e');
    }
  }

  /// Test-only: replace snapshot without network.
  @visibleForTesting
  void debugSetSnapshot(ProviderRuntimeSnapshot snap) {
    _snap = snap;
    _pushRustOverlay();
  }

  @visibleForTesting
  void debugReset() {
    _snap = ProviderRuntimeSnapshot.builtins();
    _fetchedAt = null;
  }
}

@immutable
class AnimeEmbedHostConfig {
  final String host;
  final String pathCatalog;
  final String pathAnilist;
  final String scrapeReferer;

  const AnimeEmbedHostConfig({
    required this.host,
    required this.pathCatalog,
    required this.pathAnilist,
    required this.scrapeReferer,
  });

  String buildUrl({
    required int anilistId,
    required int episode,
    required String lang,
    String? embedId,
  }) {
    final path = (embedId != null && embedId.isNotEmpty)
        ? pathCatalog
            .replaceAll('{embedId}', embedId)
            .replaceAll('{lang}', lang)
        : pathAnilist
            .replaceAll('{anilistId}', '$anilistId')
            .replaceAll('{ep}', '$episode')
            .replaceAll('{lang}', lang);
    final normalized = path.startsWith('/') ? path : '/$path';
    return 'https://$host$normalized${normalized.contains('?') ? '' : '?autoPlay=1'}';
  }

  AnimeEmbedHostConfig merged(AnimeEmbedHostConfig? o) {
    if (o == null) return this;
    return AnimeEmbedHostConfig(
      host: o.host.isNotEmpty ? o.host : host,
      pathCatalog: o.pathCatalog.isNotEmpty ? o.pathCatalog : pathCatalog,
      pathAnilist: o.pathAnilist.isNotEmpty ? o.pathAnilist : pathAnilist,
      scrapeReferer:
          o.scrapeReferer.isNotEmpty ? o.scrapeReferer : scrapeReferer,
    );
  }

  factory AnimeEmbedHostConfig.fromJson(
    Map<String, dynamic>? j,
    AnimeEmbedHostConfig fallback,
  ) {
    if (j == null) return fallback;
    return AnimeEmbedHostConfig(
      host: (j['host'] as String?)?.trim().isNotEmpty == true
          ? (j['host'] as String).trim()
          : fallback.host,
      pathCatalog: (j['pathCatalog'] as String?)?.trim().isNotEmpty == true
          ? (j['pathCatalog'] as String).trim()
          : fallback.pathCatalog,
      pathAnilist: (j['pathAnilist'] as String?)?.trim().isNotEmpty == true
          ? (j['pathAnilist'] as String).trim()
          : fallback.pathAnilist,
      scrapeReferer: (j['scrapeReferer'] as String?)?.trim().isNotEmpty == true
          ? (j['scrapeReferer'] as String).trim()
          : fallback.scrapeReferer,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'pathCatalog': pathCatalog,
        'pathAnilist': pathAnilist,
        'scrapeReferer': scrapeReferer,
      };
}

@immutable
class ProviderUrlTemplates {
  final String movie;
  final String tv;

  const ProviderUrlTemplates({required this.movie, required this.tv});

  ProviderUrlTemplates merged(ProviderUrlTemplates? o) {
    if (o == null) return this;
    return ProviderUrlTemplates(
      movie: o.movie.isNotEmpty ? o.movie : movie,
      tv: o.tv.isNotEmpty ? o.tv : tv,
    );
  }

  factory ProviderUrlTemplates.fromJson(Map<String, dynamic>? j) {
    return ProviderUrlTemplates(
      movie: (j?['movie'] as String?)?.trim() ?? '',
      tv: (j?['tv'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'movie': movie, 'tv': tv};
}

@immutable
class CdnRefererRule {
  final List<String> hostContains;
  final String referer;
  final String origin;
  final List<String> acceptRefererContains;

  const CdnRefererRule({
    required this.hostContains,
    required this.referer,
    required this.origin,
    this.acceptRefererContains = const [],
  });

  bool matchesStreamUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return hostContains
        .any((p) => p.isNotEmpty && host.contains(p.toLowerCase()));
  }

  bool refererAccepted(String refererUrl) {
    if (refererUrl.trim().isEmpty) return false;
    final h =
        Uri.tryParse(refererUrl)?.host.toLowerCase() ?? refererUrl.toLowerCase();
    if (matchesStreamUrl(refererUrl)) return false; // self-CDN never ok
    final needles = acceptRefererContains.isNotEmpty
        ? acceptRefererContains
        : [
            Uri.tryParse(referer)?.host.toLowerCase() ?? '',
          ].where((s) => s.isNotEmpty);
    return needles.any((n) => h.contains(n.toLowerCase()));
  }

  factory CdnRefererRule.fromJson(Map<String, dynamic> j) {
    final hosts = (j['hostContains'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final accept = (j['acceptRefererContains'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    return CdnRefererRule(
      hostContains: hosts,
      referer: (j['referer'] as String?)?.trim() ?? '',
      origin: (j['origin'] as String?)?.trim() ?? '',
      acceptRefererContains: accept,
    );
  }

  Map<String, dynamic> toJson() => {
        'hostContains': hostContains,
        'referer': referer,
        'origin': origin,
        if (acceptRefererContains.isNotEmpty)
          'acceptRefererContains': acceptRefererContains,
      };
}

@immutable
class ProviderRuntimeSnapshot {
  final int schema;
  final Map<String, ProviderUrlTemplates> templates;
  final Map<String, String> apis;
  final Map<String, String> webstreamr;
  final AnimeEmbedHostConfig megaplay;
  final AnimeEmbedHostConfig vidwish;
  final List<String> miruroOrigins;
  final List<String> kisskhMirrors;
  final List<CdnRefererRule> cdnRefererRules;

  const ProviderRuntimeSnapshot({
    required this.schema,
    required this.templates,
    required this.apis,
    required this.webstreamr,
    required this.megaplay,
    required this.vidwish,
    required this.miruroOrigins,
    required this.kisskhMirrors,
    required this.cdnRefererRules,
  });

  factory ProviderRuntimeSnapshot.builtins() => ProviderRuntimeSnapshot(
        schema: ProviderRuntimeConfig.supportedSchema,
        templates: const {
          'vidlink': ProviderUrlTemplates(
            movie: 'https://vidlink.pro/movie/{tmdb}',
            tv: 'https://vidlink.pro/tv/{tmdb}/{season}/{episode}',
          ),
          'vixsrc': ProviderUrlTemplates(
            movie: 'https://vixsrc.to/movie/{tmdb}/',
            tv: 'https://vixsrc.to/tv/{tmdb}/{season}/{episode}/',
          ),
          'vidnest': ProviderUrlTemplates(
            movie: 'https://vidnest.fun/movie/{tmdb}',
            tv: 'https://vidnest.fun/tv/{tmdb}/{season}/{episode}',
          ),
          'vidzee': ProviderUrlTemplates(
            movie: 'https://player.vidzee.wtf/embed/movie/{tmdb}',
            tv: 'https://player.vidzee.wtf/embed/tv/{tmdb}/{season}/{episode}',
          ),
          'vidrock': ProviderUrlTemplates(
            movie: 'https://vidrock.ru/movie/{tmdb}',
            tv: 'https://vidrock.ru/tv/{tmdb}/{season}/{episode}',
          ),
          'vidfast': ProviderUrlTemplates(
            movie: 'https://vidfast.vc/movie/{tmdb}?autoPlay=true',
            tv: 'https://vidfast.vc/tv/{tmdb}/{season}/{episode}?autoPlay=true',
          ),
          '2embed': ProviderUrlTemplates(
            movie: 'https://2embed.stream/embed/movie/{tmdb}',
            tv: 'https://2embed.stream/embed/tv/{tmdb}/{season}/{episode}',
          ),
          'autoembed': ProviderUrlTemplates(
            movie: 'https://player.autoembed.co/embed/movie/{tmdb}',
            tv: 'https://player.autoembed.co/embed/tv/{tmdb}/{season}-{episode}/',
          ),
          'vidlove': ProviderUrlTemplates(
            movie: 'https://player.vidlove.cc/embed/movie/{tmdb}',
            tv: 'https://player.vidlove.cc/embed/tv/{tmdb}/{season}/{episode}',
          ),
          'vidsrcsbs': ProviderUrlTemplates(
            movie: 'https://vidsrc.sbs/embed/movie/{tmdb}',
            tv: 'https://vidsrc.sbs/embed/tv/{tmdb}/{season}/{episode}',
          ),
          'vidsrcwin': ProviderUrlTemplates(
            movie: 'https://video.moviepire.co/embed/movie/{tmdb}',
            tv: 'https://video.moviepire.co/embed/tv/{tmdb}/{season}/{episode}',
          ),
          '111movies': ProviderUrlTemplates(
            movie: 'https://player.vidlove.cc/embed/movie/{tmdb}',
            tv: 'https://player.vidlove.cc/embed/tv/{tmdb}/{season}/{episode}',
          ),
          'moviesapi': ProviderUrlTemplates(
            movie: 'https://moviesapi.to/movie/{tmdb}',
            tv: 'https://moviesapi.to/tv/{tmdb}-{season}-{episode}',
          ),
        },
        apis: const {
          'vidnestApi': 'https://new.vidnest.fun',
          'vidnestEmbed': 'https://vidnest.fun',
          'anikotoApi': 'https://anikotoapi.site',
          'anikotoTv': 'https://anikototv.to',
          'allanimeApi': 'https://api.allanime.day/api',
          'allanimeReferer': 'https://allmanga.to',
          'allanimeClock': 'https://allanime.day',
          'watchhentaiOrigin': 'https://watchhentai.net',
          'hentainiSite': 'https://hentaini.com',
          'hentainiApi': 'https://admin.hentaini.com/api',
          'videasyApiHost': 'api.wingsdatabase.com',
          'videasyDbHost': 'db.wingsdatabase.com',
          'videasyPlayerOrigin': 'https://player.videasy.to',
          'vidsrcEmbed': 'https://vsembed.su',
          'vixsrcBase': 'https://vixsrc.to',
          'index111477': 'https://a.111477.xyz',
          'rgshowsApi': 'https://api.rgshows.ru',
        },
        webstreamr: const {
          // Aligned with WebStreamrMBG src/source bases (VSEmbed stays api.vidsrcEmbed).
          'vidsrc': 'https://vidsrcme.ru',
          'vixsrc': 'https://vixsrc.to',
          'vidzee': 'https://player.vidzee.wtf',
          'moviebox': 'https://moviebox.ph',
          'rgshows': 'https://rgshows.ru',
          'meinecloud': 'https://meinecloud.click',
          'verhdlink': 'https://verhdlink.cam',
          'megakino': 'https://megakino2.biz',
          'homecine': 'https://www3.homecine.to',
          'mostraguarda': 'https://mostraguarda.stream',
          'eurostreaming': 'https://eurostreaming.luxe',
          'cinehdplus': 'https://cinehdplus.zone',
          'streamkiste': 'https://streamkiste.taxi',
          'frenchcloud': 'https://frenchcloud.cam',
          'cuevana': 'https://ww1.cuevana3.is',
          'hdhub4u': 'https://new1.hdhub4u.limo',
          'einschalten': 'https://einschalten.in',
          'movix': 'https://api.movix.cash',
          'frembed': 'https://frembed.cyou',
          'kokoshka': 'https://kokoshka.digital',
          '4khdhub': 'https://4khdhub.link',
          'filmpalast': 'https://filmpalast.to',
          'vegamovies': 'https://vegamovies.market',
          'kinoger': 'https://kinoger.com',
        },
        megaplay: const AnimeEmbedHostConfig(
          host: 'megaplay.buzz',
          pathCatalog: '/stream/s-2/{embedId}/{lang}',
          pathAnilist: '/stream/ani/{anilistId}/{ep}/{lang}',
          scrapeReferer: 'https://www.enma.lol/',
        ),
        vidwish: const AnimeEmbedHostConfig(
          host: 'vidwish.live',
          pathCatalog: '/stream/s-2/{embedId}/{lang}',
          pathAnilist: '/stream/ani/{anilistId}/{ep}/{lang}',
          scrapeReferer: 'https://www.enma.lol/',
        ),
        miruroOrigins: const [
          'https://www.miruro.tv',
          'https://www.miruro.to',
          'https://www.miruro.bz',
          'https://www.miruro.ru',
        ],
        kisskhMirrors: const [
          'https://kisskh.co',
          'https://kisskh.nl',
          'https://kisskh.ovh',
          'https://kisskh.la',
          'https://kisskh.do',
        ],
        cdnRefererRules: const [
          CdnRefererRule(
            hostContains: [
              'mewstream',
              'nekostream',
              'lostproject',
              'megaplay',
            ],
            referer: 'https://megaplay.buzz/',
            origin: 'https://megaplay.buzz',
            acceptRefererContains: ['megaplay'],
          ),
          CdnRefererRule(
            hostContains: ['watching.onl', 'vidwish'],
            referer: 'https://vidwish.live/',
            origin: 'https://vidwish.live',
            acceptRefererContains: ['vidwish'],
          ),
          CdnRefererRule(
            hostContains: ['fast4speed'],
            referer: 'https://allmanga.to/',
            origin: 'https://allmanga.to',
            acceptRefererContains: ['allmanga'],
          ),
        ],
      );

  static ProviderRuntimeSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final schema = (j['schema'] as num?)?.toInt() ?? 0;
    if (schema != ProviderRuntimeConfig.supportedSchema) return null;
    final anime = (j['anime'] as Map?)?.cast<String, dynamic>();
    final builtins = ProviderRuntimeSnapshot.builtins();
    final megaplay = AnimeEmbedHostConfig.fromJson(
      (anime?['megaplay'] as Map?)?.cast<String, dynamic>(),
      builtins.megaplay,
    );
    final vidwish = AnimeEmbedHostConfig.fromJson(
      (anime?['vidwish'] as Map?)?.cast<String, dynamic>(),
      builtins.vidwish,
    );
    final origins = (anime?['miruroOrigins'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.startsWith('http'))
            .toList() ??
        const <String>[];
    final kisskh = (anime?['kisskhMirrors'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.startsWith('http'))
            .toList() ??
        const <String>[];
    final rules = <CdnRefererRule>[];
    final rawRules = j['cdnRefererRules'] as List?;
    if (rawRules != null) {
      for (final r in rawRules) {
        if (r is! Map) continue;
        final rule = CdnRefererRule.fromJson(r.cast<String, dynamic>());
        if (rule.hostContains.isEmpty || rule.referer.isEmpty) continue;
        rules.add(rule);
      }
    }
    final templates = <String, ProviderUrlTemplates>{};
    final rawTpl = j['templates'] as Map?;
    if (rawTpl != null) {
      for (final e in rawTpl.entries) {
        final id = e.key.toString();
        if (e.value is! Map) continue;
        final t = ProviderUrlTemplates.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        );
        if (t.movie.isEmpty && t.tv.isEmpty) continue;
        templates[id] = t;
      }
    }
    final apis = <String, String>{};
    final rawApis = j['apis'] as Map?;
    if (rawApis != null) {
      for (final e in rawApis.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isEmpty) continue;
        apis[e.key.toString()] = v;
      }
    }
    final webstreamr = <String, String>{};
    final rawWs = j['webstreamr'] as Map?;
    if (rawWs != null) {
      for (final e in rawWs.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (!v.startsWith('http')) continue;
        webstreamr[e.key.toString()] = v;
      }
    }
    return ProviderRuntimeSnapshot(
      schema: schema,
      templates: templates,
      apis: apis,
      webstreamr: webstreamr,
      megaplay: megaplay,
      vidwish: vidwish,
      miruroOrigins: origins,
      kisskhMirrors: kisskh,
      cdnRefererRules: rules,
    );
  }

  ProviderRuntimeSnapshot merged(ProviderRuntimeSnapshot overlay) {
    final tpl = Map<String, ProviderUrlTemplates>.from(templates);
    for (final e in overlay.templates.entries) {
      tpl[e.key] = (tpl[e.key] ?? e.value).merged(e.value);
    }
    final api = Map<String, String>.from(apis)..addAll(overlay.apis);
    final ws = Map<String, String>.from(webstreamr)..addAll(overlay.webstreamr);
    return ProviderRuntimeSnapshot(
      schema: overlay.schema,
      templates: tpl,
      apis: api,
      webstreamr: ws,
      megaplay: megaplay.merged(overlay.megaplay),
      vidwish: vidwish.merged(overlay.vidwish),
      miruroOrigins: overlay.miruroOrigins.isNotEmpty
          ? overlay.miruroOrigins
          : miruroOrigins,
      kisskhMirrors: overlay.kisskhMirrors.isNotEmpty
          ? overlay.kisskhMirrors
          : kisskhMirrors,
      // Overlay first (ops override), then builtins whose host needles are
      // not fully covered — incomplete remote edits must not wipe nekostream.
      cdnRefererRules: _unionCdnRefererRules(
        builtins: cdnRefererRules,
        overlay: overlay.cdnRefererRules,
      ),
    );
  }

  /// Prefer [overlay] rules; keep [builtins] rules whose host needles are not
  /// all present on some overlay rule.
  static List<CdnRefererRule> _unionCdnRefererRules({
    required List<CdnRefererRule> builtins,
    required List<CdnRefererRule> overlay,
  }) {
    if (overlay.isEmpty) return builtins;
    final out = List<CdnRefererRule>.from(overlay);
    for (final b in builtins) {
      final covered = overlay.any((o) {
        if (b.hostContains.isEmpty) return false;
        return b.hostContains.every(
          (needle) => o.hostContains.any(
            (h) => h.toLowerCase() == needle.toLowerCase(),
          ),
        );
      });
      if (!covered) out.add(b);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'templates': {
          for (final e in templates.entries) e.key: e.value.toJson(),
        },
        'apis': apis,
        'webstreamr': webstreamr,
        'anime': {
          'megaplay': megaplay.toJson(),
          'vidwish': vidwish.toJson(),
          'miruroOrigins': miruroOrigins,
          'kisskhMirrors': kisskhMirrors,
        },
        'cdnRefererRules': cdnRefererRules.map((r) => r.toJson()).toList(),
      };
}
