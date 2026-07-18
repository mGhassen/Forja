import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
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
  List<CdnRefererRule> get cdnRefererRules => _snap.cdnRefererRules;

  /// Load disk cache (if any), then refresh from Supabase when configured.
  Future<void> ensureLoaded() async {
    await _loadDiskCache();
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
      if (kDebugMode) {
        debugPrint('[ProviderRuntime] remote applied schema=${_snap.schema}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProviderRuntime] refresh failed: $e');
    }
  }

  /// Test-only: replace snapshot without network.
  @visibleForTesting
  void debugSetSnapshot(ProviderRuntimeSnapshot snap) {
    _snap = snap;
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

  factory AnimeEmbedHostConfig.fromJson(Map<String, dynamic>? j, AnimeEmbedHostConfig fallback) {
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
    return hostContains.any((p) => p.isNotEmpty && host.contains(p.toLowerCase()));
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
  final AnimeEmbedHostConfig megaplay;
  final AnimeEmbedHostConfig vidwish;
  final List<String> miruroOrigins;
  final List<CdnRefererRule> cdnRefererRules;

  const ProviderRuntimeSnapshot({
    required this.schema,
    required this.megaplay,
    required this.vidwish,
    required this.miruroOrigins,
    required this.cdnRefererRules,
  });

  factory ProviderRuntimeSnapshot.builtins() => ProviderRuntimeSnapshot(
        schema: ProviderRuntimeConfig.supportedSchema,
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
    return ProviderRuntimeSnapshot(
      schema: schema,
      megaplay: megaplay,
      vidwish: vidwish,
      miruroOrigins: origins,
      cdnRefererRules: rules,
    );
  }

  ProviderRuntimeSnapshot merged(ProviderRuntimeSnapshot overlay) {
    return ProviderRuntimeSnapshot(
      schema: overlay.schema,
      megaplay: megaplay.merged(overlay.megaplay),
      vidwish: vidwish.merged(overlay.vidwish),
      miruroOrigins: overlay.miruroOrigins.isNotEmpty
          ? overlay.miruroOrigins
          : miruroOrigins,
      cdnRefererRules: overlay.cdnRefererRules.isNotEmpty
          ? overlay.cdnRefererRules
          : cdnRefererRules,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'anime': {
          'megaplay': megaplay.toJson(),
          'vidwish': vidwish.toJson(),
          'miruroOrigins': miruroOrigins,
        },
        'cdnRefererRules': cdnRefererRules.map((r) => r.toJson()).toList(),
      };
}
