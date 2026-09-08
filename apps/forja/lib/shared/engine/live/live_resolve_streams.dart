import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/foundation/services/registry/kit_iptv_play_hooks.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/iptv/portal_sports/iptv_portal_sports_config.dart';
import 'package:forja/shared/engine/live/live_feed_aggregate.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/lib/schedule_sport_filter.dart';
import 'package:rust/rust.dart'
    show BuiltInPlayerContext, SettingsService, StremioService, runLiveSportsFetchJson;

/// Live resolve + Stremio providers + native play (RFC-091).
/// Live TV portal matching is [IptvPortalSportsMatchService] — not this class.
abstract final class LiveResolveStreams {
  LiveResolveStreams._();

  static const _providersCacheTtl = Duration(minutes: 30);
  static const _stremioProvidersTimeout = Duration(seconds: 12);
  static final Map<String, _ProvidersCacheEntry> _providersCache = {};

  /// Providers rail: Forja Live (all soft-matched catalog siblings) + Stremio.
  static Future<List<IptvPlaySource>> loadProviders(
    Map<String, dynamic> legacyRow, {
    bool force = false,
  }) async {
    final match = MatchEvent.fromLegacyRow(legacyRow);
    final cacheKey = _providersCacheKey(match);
    if (force) {
      _providersCache.remove(cacheKey);
    } else {
      final hit = _providersCache[cacheKey];
      if (hit != null && DateTime.now().isBefore(hit.expiresAt)) {
        if (hit.sources.isNotEmpty) {
          return List<IptvPlaySource>.from(hit.sources);
        }
        _providersCache.remove(cacheKey);
      }
    }

    final out = <IptvPlaySource>[];
    final seen = <String>{};

    await LivePluginEngine.warmPluginMeta();

    Future<void> addBatch(List<IptvPlaySource> batch) async {
      for (final s in batch) {
        final key = s.url.trim().isNotEmpty
            ? 'u:${s.url.trim()}'
            : 'l:${s.label}|${s.liveEngineEmbedUrl ?? ''}';
        if (!seen.add(key)) continue;
        out.add(s);
      }
    }

    // Stremio Catalog chip row — direct /stream only (no Forja sibling fan-out).
    if (match.isStremio) {
      try {
        await addBatch(await _loadStremioProviders(match));
      } catch (e, st) {
        debugPrint('[LiveResolveStreams] Stremio providers error: $e\n$st');
      }
      if (out.isNotEmpty) {
        _providersCache[cacheKey] = _ProvidersCacheEntry(
          expiresAt: DateTime.now().add(_providersCacheTtl),
          sources: List<IptvPlaySource>.from(out),
        );
      }
      return out;
    }

    // Start Stremio soft-match in parallel, but never let it strand the panel
    // after Forja rows are ready (getStreams can hang past catalog soft-match).
    final stremioFuture = _loadStremioProviders(match);
    List<IptvPlaySource> forja = const [];
    try {
      forja = await _loadForjaLiveProviders(match);
      await addBatch(forja);
    } catch (e, st) {
      debugPrint('[LiveResolveStreams] Forja Live providers error: $e\n$st');
    }

    try {
      final stremio = await stremioFuture.timeout(
        _stremioProvidersTimeout,
        onTimeout: () {
          debugPrint(
            '[LiveResolveStreams] Stremio providers timed out after '
            '${_stremioProvidersTimeout.inSeconds}s',
          );
          return const <IptvPlaySource>[];
        },
      );
      await addBatch(stremio);
    } catch (e, st) {
      debugPrint('[LiveResolveStreams] Stremio providers error: $e\n$st');
    }

    if (out.isNotEmpty) {
      _providersCache[cacheKey] = _ProvidersCacheEntry(
        expiresAt: DateTime.now().add(_providersCacheTtl),
        sources: List<IptvPlaySource>.from(out),
      );
    }
    return out;
  }

  /// Open native player for a picked row (Providers unlock or IPTV Stalker link).
  static Future<void> play(
    BuildContext context, {
    required List<IptvPlaySource> sources,
    required IptvPlaySource picked,
    required String title,
    String? subtitle,
  }) async {
    if (!context.mounted) return;
    final kind = picked.liveSourceKind ?? IptvLiveSourceKind.liveEngine;

    if (kind == IptvLiveSourceKind.iptvXtream ||
        kind == IptvLiveSourceKind.iptvStalker) {
      await _playIptvSports(context, sources: sources, picked: picked, title: title);
      return;
    }

    await _playLiveEngine(
      context,
      picked: picked,
      title: title,
      subtitle: subtitle ?? picked.pickerSubtitle ?? '',
    );
  }

  static String _providersCacheKey(MatchEvent match) {
    final addonRev = SettingsService.addonChangeNotifier.value;
    return 'providers:${matchEventViewerKey(match)}:a$addonRev';
  }

  static Future<List<IptvPlaySource>> _loadForjaLiveProviders(
    MatchEvent match,
  ) async {
    final choices = <_StreamChoice>[];
    final seenUrls = <String>{};
    final seenRefs = <String>{};

    final siblings = await _forjaProviderResolveMatches(match);
    final jobs = <(MatchEvent, MatchSourceRef)>[];
    for (final m in siblings) {
      for (final stream in m.inlineStreams) {
        final url = stream.embedUrl.trim();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        choices.add(_StreamChoice(match: m, stream: stream));
      }
      for (final ref in m.sources) {
        final key = 'ref:${m.livePluginId}:${ref.source}:${ref.id}';
        if (!seenRefs.add(key)) continue;
        jobs.add((m, ref));
      }
    }

    for (final (m, ref) in jobs) {
      try {
        final streams = await _forjaLiveStreamsFromSource(m, ref);
        for (final stream in streams) {
          final url = stream.embedUrl.trim();
          if (url.isEmpty || !seenUrls.add(url)) continue;
          choices.add(_StreamChoice(match: m, stream: stream));
        }
      } catch (e) {
        debugPrint('[LiveResolveStreams] resolve ${ref.source}/${ref.id}: $e');
      }
    }

    choices.sort(
      (a, b) => effectiveMatchStreamViewers(b.stream, b.match).compareTo(
        effectiveMatchStreamViewers(a.stream, a.match),
      ),
    );
    return [for (final c in choices) _choiceToPanelSource(c)];
  }

  /// Same fixture across Forja Live catalogs — resolve every sibling plugin.
  static Future<List<MatchEvent>> _forjaProviderResolveMatches(
    MatchEvent anchor,
  ) async {
    final out = <MatchEvent>[];
    final seen = <String>{};

    void add(MatchEvent raw) {
      if (raw.livePluginId.isNotEmpty &&
          LivePluginEngine.cachedIsScheduleEnrich(raw.livePluginId)) {
        return;
      }
      final m = _ensureProviderResolveMatch(raw);
      final key = '${m.livePluginId}|${m.id}';
      if (key == '|' || !seen.add(key)) return;
      if (m.sources.isEmpty && m.inlineStreams.isEmpty) return;
      out.add(m);
    }

    add(anchor);

    List<Map<String, dynamic>> pool =
        rememberedLiveFeedAllCatalogPool() ?? const [];
    if (pool.isEmpty) {
      try {
        pool = await aggregateLiveFeed(const LiveFeedQuery());
      } catch (e) {
        debugPrint('[LiveResolveStreams] Forja sibling pool error: $e');
        return out;
      }
    }

    for (final row in pool) {
      final m = MatchEvent.fromLegacyRow(row);
      if (!_liveCatalogEventMatch(anchor, m)) continue;
      add(m);
    }
    return out;
  }

  /// Catalog rows normally carry `sources[]`; synthesize when the grid lost them.
  static MatchEvent _ensureProviderResolveMatch(MatchEvent match) {
    if (match.sources.isNotEmpty || match.inlineStreams.isNotEmpty) {
      return match;
    }
    final pluginId = match.livePluginId.trim();
    if (pluginId.isEmpty || match.id.isEmpty) return match;
    final source = LivePluginEngine.cachedResolveSourceToken(pluginId);
    final refId = LivePluginEngine.cachedResolveRefId(match.id, pluginId);
    if (source.isEmpty || refId.isEmpty) return match;
    return match.copyWith(
      sources: [MatchSourceRef(source: source, id: refId)],
    );
  }

  static bool _liveCatalogEventMatch(MatchEvent a, MatchEvent b) {
    return _stremioCatalogEventMatch(a, b);
  }

  /// Providers list only — embed / stream mirrors. Goat unlock happens on play.
  static Future<List<MatchStream>> _forjaLiveStreamsFromSource(
    MatchEvent match,
    MatchSourceRef source,
  ) async {
    final pluginId = LivePluginEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty) return const [];

    final token = source.source.trim().toLowerCase();
    if (token == 'echo') return const [];

    final pluginSource = token.isNotEmpty
        ? token
        : LivePluginEngine.cachedResolveSourceToken(pluginId);

    final inline = await _inlineStreamsForSourceRef(match, source);
    if (inline.isNotEmpty) {
      final out = <MatchStream>[];
      final seen = <String>{};
      for (var i = 0; i < inline.length; i++) {
        final row = inline[i];
        final embed = row.embedUrl.trim().isNotEmpty
            ? row.embedUrl.trim()
            : source.iframe.trim();
        if (embed.isEmpty || !seen.add(embed)) continue;
        out.add(
          MatchStream(
            id: row.id.isNotEmpty ? row.id : source.id,
            streamNo: row.streamNo > 0 ? row.streamNo : i + 1,
            language: row.language,
            hd: row.hd,
            embedUrl: embed,
            source: row.source.trim().isNotEmpty ? row.source : pluginSource,
            viewers: row.viewers > 0 ? row.viewers : match.viewers,
            directPlayback: false,
          ),
        );
      }
      if (out.isNotEmpty) return out;
    }

    if (_isStreamedPkGoatSource(token)) {
      final listed = await _fetchStreamedStreams(source, allowFallback: true);
      if (listed.isNotEmpty) {
        return [
          for (final s in listed)
            MatchStream(
              id: s.id.isNotEmpty ? s.id : source.id,
              streamNo: s.streamNo > 0 ? s.streamNo : 1,
              language: s.language,
              hd: s.hd,
              embedUrl: s.embedUrl,
              source: s.source.trim().isNotEmpty ? s.source : pluginSource,
              viewers: s.viewers > 0 ? s.viewers : match.viewers,
              directPlayback: false,
            ),
        ];
      }
    }

    final iframe = source.iframe.trim();
    if (iframe.isNotEmpty) {
      return [
        MatchStream(
          id: source.id,
          streamNo: 1,
          language: '',
          hd: false,
          embedUrl: iframe,
          source: pluginSource.isNotEmpty ? pluginSource : source.source,
          viewers: match.viewers,
          directPlayback: false,
        ),
      ];
    }

    // Non-Streamed packs: one pending row — unlock only when the user plays.
    if (source.id.trim().isEmpty) return const [];
    return [
      MatchStream(
        id: source.id,
        streamNo: 1,
        language: '',
        hd: false,
        embedUrl: 'pending:${match.id}:${source.id}:1',
        source: pluginSource.isNotEmpty ? pluginSource : source.source,
        viewers: match.viewers,
        directPlayback: false,
      ),
    ];
  }

  static bool _isStreamedPkGoatSource(String source) {
    switch (source.trim().toLowerCase()) {
      case 'admin':
      case 'delta':
      case 'golf':
      case 'ppv':
      case 'bravo':
        return true;
      default:
        return false;
    }
  }

  static Future<List<MatchStream>> _fetchStreamedStreams(
    MatchSourceRef sourceRef, {
    bool allowFallback = true,
  }) async {
    if (sourceRef.source.trim().toLowerCase() == 'echo') return const [];
    try {
      final raw = await runLiveSportsFetchJson(
        jsonEncode({
          'action': 'streamed_streams',
          'source': sourceRef.source,
          'id': sourceRef.id,
        }),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) {
        return allowFallback ? _streamedEmbedFallback(sourceRef) : const [];
      }
      final list = parsed['items'] as List? ?? [];
      final rows = list
          .map((s) {
            try {
              return MatchStream.fromJson(s as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<MatchStream>()
          .where((s) => s.embedUrl.isNotEmpty)
          .toList();
      if (rows.isNotEmpty) return rows;
      return allowFallback ? _streamedEmbedFallback(sourceRef) : const [];
    } catch (_) {
      return allowFallback ? _streamedEmbedFallback(sourceRef) : const [];
    }
  }

  static List<MatchStream> _streamedEmbedFallback(MatchSourceRef sourceRef) {
    final source = sourceRef.source.trim();
    final id = sourceRef.id.trim();
    if (source.isEmpty || id.isEmpty) return const [];
    if (!_isStreamedPkGoatSource(source)) return const [];
    if (source.toLowerCase() == 'echo') return const [];
    return [
      MatchStream(
        id: id,
        streamNo: 1,
        language: '',
        hd: false,
        embedUrl: 'https://embed.st/embed/$source/$id/1',
        source: source,
        viewers: 0,
      ),
    ];
  }

  static Future<List<MatchStream>> _inlineStreamsForSourceRef(
    MatchEvent match,
    MatchSourceRef sourceRef,
  ) async {
    final token = sourceRef.source.trim().toLowerCase();
    if (token.isEmpty) return const [];
    return match.inlineStreams
        .where((s) => s.source.trim().toLowerCase() == token)
        .toList();
  }

  static MatchStream _streamFromResolveRow({
    required Map<String, dynamic> row,
    required MatchSourceRef source,
    required MatchEvent match,
    required String pluginSource,
    MatchStream? meta,
    required int index,
  }) {
    final rowViewers = parseLiveViewerCount(row['viewers']);
    final nameRaw =
        (row['name'] ?? row['title'] ?? meta?.language ?? '').toString();
    final fields = forjaLiveStreamFieldsFromRowName(nameRaw);
    final langFromRow = (row['language'] ?? '').toString().trim();
    final language = langFromRow.isNotEmpty
        ? langFromRow
        : (fields.language.isNotEmpty
            ? fields.language
            : (meta?.language ?? ''));
    final hd = row['hd'] == true || meta?.hd == true || fields.hd;
    final metaViewers = meta?.viewers ?? 0;
    final viewers = rowViewers > 0
        ? rowViewers
        : (metaViewers > 0 ? metaViewers : match.viewers);
    final url = (row['url'] ?? '').toString().trim();
    final sourceToken = meta?.source.trim().isNotEmpty == true
        ? meta!.source
        : pluginSource;
    Map<String, String>? resolvedHeaders;
    final h = row['headers'];
    if (h is Map && h.isNotEmpty) {
      resolvedHeaders = {
        for (final e in h.entries) e.key.toString(): e.value.toString(),
      };
    }
    return MatchStream(
      id: source.id,
      streamNo: meta?.streamNo ?? index + 1,
      language: language,
      hd: hd,
      embedUrl: url,
      source: sourceToken,
      viewers: viewers,
      directPlayback: row.containsKey('directPlayback')
          ? row['directPlayback'] == true
          : iptvLiveEnginePlayUrlReady(url),
      resolvedHeaders: resolvedHeaders,
    );
  }

  static IptvPlaySource _choiceToPanelSource(_StreamChoice choice) {
    final stream = choice.stream;
    final match = choice.match;
    final embed = stream.embedUrl.trim();
    final pending = embed.isEmpty || embed.startsWith('pending:');
    final sourceLabel = _sourceLabel(stream.source);
    final title = _streamTitle(stream, sourceLabel);
    final playUrl = pending
        ? 'pending:${match.id}:${stream.id}:${stream.streamNo}'
        : embed;
    final directPlayback = !pending &&
        (stream.directPlayback || iptvLiveEnginePlayUrlReady(embed));
    return IptvPlaySource(
      url: playUrl,
      label: title,
      detail: _streamDetail(stream),
      headers: directPlayback ? (stream.resolvedHeaders ?? const {}) : const {},
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _serverLabelFor(match),
      liveViewerCount: effectiveMatchStreamViewers(stream, match),
      liveStreamHd: stream.hd,
      liveEngineEmbedUrl: directPlayback || pending
          ? null
          : (iptvLiveEnginePlayUrlReady(embed) ? null : embed),
      liveEngineResolveParams: _liveEngineResolveParams(match, stream),
    );
  }

  static String _sourceLabel(String source) {
    if (source.isEmpty) return '';
    return source[0].toUpperCase() + source.substring(1);
  }

  static String _streamTitle(MatchStream stream, String sourceLabel) {
    if (sourceLabel.isNotEmpty && stream.language.isNotEmpty) {
      return '$sourceLabel · ${stream.language}';
    }
    if (sourceLabel.isNotEmpty) return sourceLabel;
    if (stream.language.isNotEmpty) return stream.language;
    if (stream.streamNo > 0) return 'Stream ${stream.streamNo}';
    return 'Stream';
  }

  static String? _streamDetail(MatchStream stream) {
    final parts = <String>[];
    final quality = _qualityLabel(stream);
    if (quality != null) parts.add(quality);
    final host = Uri.tryParse(stream.embedUrl.trim())?.host;
    if (host != null && host.isNotEmpty) parts.add(host);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? _qualityLabel(MatchStream stream) {
    final match = RegExp(
      r'\b(FHD|UHD|HD|4K|SD)\b',
      caseSensitive: false,
    ).firstMatch(stream.language);
    if (match != null) return match.group(1)!.toUpperCase();
    if (stream.hd) return 'HD';
    return null;
  }

  static String _serverLabelFor(MatchEvent match) {
    if (match.isMut) return 'Mut';
    final name = LivePluginEngine.cachedPluginDisplayName(match.livePluginId);
    return name.isEmpty ? 'Live' : name;
  }

  static Map<String, dynamic> _liveEngineResolveParams(
    MatchEvent match,
    MatchStream stream,
  ) {
    return {
      'eventId': match.id,
      'matchId': stream.id,
      'streamNo': stream.streamNo,
      'category': match.category,
      'title': match.title,
      'source': stream.source,
      'livePluginId': match.livePluginId,
      'isForjaLive': match.isForjaLive,
      'isMut': match.isMut,
      'isIframeCatalog': LivePluginEngine.cachedIsIframeLive(
        match.livePluginId,
      ),
      'hd': stream.hd,
      'viewers': stream.viewers,
      'language': stream.language,
    };
  }

  static Future<List<IptvPlaySource>> _loadStremioProviders(
    MatchEvent match,
  ) async {
    if (match.isStremio) {
      return _stremioPlaySourcesFor(match);
    }
    // Soft match against installed sport addons (same event title/teams).
    List<MatchEvent> catalog;
    try {
      catalog = await fetchLiveStremioSportMatches();
    } catch (e) {
      debugPrint('[LiveResolveStreams] Stremio catalog error: $e');
      return const [];
    }
    final hits = catalog.where((m) => _stremioCatalogEventMatch(match, m)).toList();
    if (hits.isEmpty) return const [];
    final batches = await Future.wait(
      hits.take(3).map((hit) async {
        try {
          return await _stremioPlaySourcesFor(hit);
        } catch (e) {
          debugPrint('[LiveResolveStreams] Stremio addon resolve error: $e');
          return const <IptvPlaySource>[];
        }
      }),
    );
    final out = <IptvPlaySource>[];
    final seenUrls = <String>{};
    for (final batch in batches) {
      for (final s in batch) {
        if (!seenUrls.add(s.url)) continue;
        out.add(s);
      }
    }
    return out;
  }

  static Future<List<IptvPlaySource>> _stremioPlaySourcesFor(
    MatchEvent match,
  ) async {
    final out = <IptvPlaySource>[];
    final addonName = match.stremioAddonName.trim().isNotEmpty
        ? match.stremioAddonName.trim()
        : '';
    try {
      final raw = await StremioService().getStreams(
        baseUrl: match.stremioBaseUrl,
        type: match.stremioType,
        id: match.id,
      );
      for (final s in raw) {
        if (s is! Map) continue;
        final url = s['url']?.toString();
        if (!StremioService.isPlayableLiveUrl(url)) continue;
        final name = (s['name'] ?? s['title'] ?? 'Stream').toString().trim();
        out.add(
          IptvPlaySource(
            url: url!,
            label: _stremioStreamDisplayLabel(name, addonName),
            headers: StremioService.liveStreamRequestHeaders(s),
            liveSourceKind: IptvLiveSourceKind.stremio,
            liveProviderBadge: addonName.isEmpty
                ? 'Stremio'
                : 'Stremio · $addonName',
          ),
        );
      }
    } catch (e) {
      debugPrint('[LiveResolveStreams] Stremio stream error: $e');
    }
    return out;
  }

  static String _stremioStreamDisplayLabel(String rawName, String? addonName) {
    final name = rawName.trim();
    if (name.isEmpty) return 'Stream';
    final addon = (addonName ?? '').trim();
    if (addon.isNotEmpty) {
      final prefix = '$addon · ';
      if (name.startsWith(prefix)) {
        final stripped = name.substring(prefix.length).trim();
        if (stripped.isNotEmpty) return stripped;
      }
    }
    final parts = name.split(RegExp(r'\s*[·•]\s*'));
    if (parts.length >= 2) {
      final stripped = parts.sublist(1).join(' · ').trim();
      if (stripped.isNotEmpty) return stripped;
    }
    return name;
  }

  static bool _stremioCatalogEventMatch(MatchEvent engine, MatchEvent stremio) {
    final teamsA = matchTeamPairKeyFromCatalog(
      homeTeam: engine.homeTeam,
      awayTeam: engine.awayTeam,
      title: engine.title,
    );
    final teamsB = matchTeamPairKeyFromCatalog(
      homeTeam: stremio.homeTeam,
      awayTeam: stremio.awayTeam,
      title: stremio.title,
    );
    if (teamsA != null && teamsB != null && teamsA == teamsB) {
      if (engine.dateMs <= 0 || stremio.dateMs <= 0) return true;
      return (engine.dateMs - stremio.dateMs).abs() <=
          const Duration(hours: 6).inMilliseconds;
    }
    final titleA = matchTextKey(engine.title);
    final titleB = matchTextKey(stremio.title);
    return titleA.isNotEmpty && titleA == titleB;
  }

  static Future<void> _playIptvSports(
    BuildContext context, {
    required List<IptvPlaySource> sources,
    required IptvPlaySource picked,
    required String title,
  }) async {
    final ordered = <IptvPlaySource>[
      picked,
      for (final s in sources)
        if (!identical(s, picked) &&
            (s.streamId ?? '').trim() != (picked.streamId ?? '').trim() &&
            (s.url.isEmpty || s.url != picked.url))
          s,
    ];
    final resolved = await _resolveIptvSportsPlayUrls(ordered);
    if (!context.mounted) return;
    if (resolved.isEmpty) {
      ForjaToast.info('Could not open channel');
      return;
    }
    final kind = resolved.first.liveSourceKind ?? IptvLiveSourceKind.iptvXtream;
    final open = KitIptvPlayHooks.openLiveNativePlayer;
    if (open == null) return;
    await open(
      context,
      sources: List<dynamic>.from(resolved),
      title: title,
      subtitle: resolved.first.pickerTitle,
      logoUrl: resolved.first.logoUrl,
      engineContext: BuiltInPlayerContext.iptv,
      liveSourceKind: kind,
    );
  }

  static Future<List<IptvPlaySource>> _resolveIptvSportsPlayUrls(
    List<IptvPlaySource> sources,
  ) async {
    if (sources.isEmpty) return sources;
    final needsLink = sources.any(
      (s) =>
          s.liveSourceKind == IptvLiveSourceKind.iptvStalker ||
          (s.url.trim().isEmpty && (s.streamId ?? '').trim().isNotEmpty),
    );
    if (!needsLink) return sources;

    final config = await IptvPortalSportsConfig.load();
    final armed = await config.resolveForFetch();
    if (armed == null) return [];
    final portals = await IptvStore.load();
    VerifiedPortal? portal;
    for (final p in portals) {
      if (p.key == armed.portalKey) {
        portal = p;
        break;
      }
    }
    if (portal == null ||
        portal.portal.platform != IptvPortalPlatform.stalker) {
      return sources.where((s) => s.url.trim().isNotEmpty).toList();
    }

    final out = <IptvPlaySource>[];
    var minted = false;
    for (final s in sources) {
      final cmd = (s.streamId ?? '').trim();
      final stalkerRow = s.liveSourceKind == IptvLiveSourceKind.iptvStalker ||
          (s.url.trim().isEmpty && cmd.isNotEmpty);
      if (!stalkerRow) {
        if (s.url.trim().isNotEmpty) out.add(s);
        continue;
      }
      if (cmd.isEmpty) {
        if (s.url.trim().isNotEmpty) out.add(s);
        continue;
      }
      if (!minted) {
        final url = await IptvClient.createLink(
          portal.portal,
          cmd: cmd,
          section: 'live',
        );
        if (url == null || url.isEmpty) continue;
        minted = true;
        out.add(
          IptvPlaySource(
            url: url,
            label: s.label,
            detail: s.detail,
            logoUrl: s.logoUrl,
            streamId: s.streamId,
            epgChannelId: s.epgChannelId,
            headers: s.headers,
            liveSourceKind: IptvLiveSourceKind.iptvStalker,
          ),
        );
      } else {
        out.add(
          IptvPlaySource(
            url: '',
            label: s.label,
            detail: s.detail,
            logoUrl: s.logoUrl,
            streamId: s.streamId,
            epgChannelId: s.epgChannelId,
            headers: s.headers,
            liveSourceKind: IptvLiveSourceKind.iptvStalker,
          ),
        );
      }
    }
    return out;
  }

  static Future<void> _playLiveEngine(
    BuildContext context, {
    required IptvPlaySource picked,
    required String title,
    required String subtitle,
  }) async {
    final url = picked.url.trim();
    if (picked.liveSourceKind == IptvLiveSourceKind.stremio &&
        iptvLiveEnginePlayUrlReady(url)) {
      final open = KitIptvPlayHooks.openLiveNativePlayer;
      if (open == null) return;
      await open(
        context,
        sources: <dynamic>[picked],
        title: title,
        subtitle: subtitle,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: IptvLiveSourceKind.stremio,
      );
      return;
    }

    if (iptvLiveEnginePlayUrlReady(url)) {
      final open = KitIptvPlayHooks.openLiveNativePlayer;
      if (open == null) return;
      await open(
        context,
        sources: <dynamic>[picked],
        title: title,
        subtitle: subtitle,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: IptvLiveSourceKind.liveEngine,
        liveEngineResolveSource: resolveLiveEngineSource,
      );
      return;
    }

    IptvPlaySource? resolved;
    final ok = await _runWithCancellableLoading(
      context,
      'Opening stream…',
      (setMessage) async {
        setMessage('Unlocking source…');
        resolved = await resolveLiveEngineSource(
          picked,
          onProgress: setMessage,
        );
      },
    );
    if (!ok || !context.mounted) return;
    final handoff = resolved;
    final handoffUrl = handoff?.url.trim() ?? '';
    if (handoff == null || !iptvLiveEnginePlayUrlReady(handoffUrl)) {
      LivePluginEngine.engineResolveFailed();
      return;
    }
    final open = KitIptvPlayHooks.openLiveNativePlayer;
    if (open == null) return;
    await open(
      context,
      sources: <dynamic>[handoff],
      title: title,
      subtitle: subtitle,
      engineContext: BuiltInPlayerContext.live,
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineResolveSource: resolveLiveEngineSource,
    );
  }

  /// Unlock a Providers catalog row → native play URL (no embed fallback).
  static Future<IptvPlaySource?> resolveLiveEngineSource(
    IptvPlaySource catalog, {
    void Function(String)? onProgress,
    bool forceRefresh = false,
  }) async {
    final params = catalog.liveEngineResolveParams;
    if (params == null) {
      // Stremio / already-ready rows.
      if (iptvLiveEnginePlayUrlReady(catalog.url)) return catalog;
      return null;
    }
    var embed = (catalog.liveEngineEmbedUrl ?? '').trim();
    if (embed.isEmpty) {
      final url = catalog.url.trim();
      if (url.isNotEmpty && !url.startsWith('pending:')) embed = url;
    }
    if (forceRefresh || iptvLiveEngineUrlVolatile(embed)) {
      if (iptvLiveEnginePlayUrlReady(embed)) embed = '';
    }
    final match = _matchFromParams(params);
    final stream = _streamFromParams(params, embedUrl: embed);
    final resolved = await _resolveStreamToEnginePlaySource(
      match,
      stream,
      onProgress: onProgress,
      forceRefresh: forceRefresh || iptvLiveEngineUrlVolatile(catalog.url),
    );
    return resolved?.copyWith(liveEngineResolveParams: params);
  }

  static MatchEvent _matchFromParams(Map<String, dynamic> params) {
    final isForjaLive = params['isForjaLive'] == true;
    final isMut = params['isMut'] == true;
    var pluginId = (params['livePluginId'] ?? '').toString().trim();
    if (pluginId.isEmpty && params['isIframeCatalog'] == true) {
      pluginId =
          LivePluginEngine.cachedIframeProviderResolvePluginId() ?? '';
    }
    return MatchEvent(
      id: (params['eventId'] ?? '').toString(),
      title: (params['title'] ?? '').toString(),
      category: (params['category'] ?? '').toString(),
      dateMs: 0,
      poster: '',
      popular: false,
      airing: true,
      viewers: parseLiveViewerCount(params['viewers']),
      sources: [
        MatchSourceRef(
          source: (params['source'] ?? '').toString(),
          id: (params['matchId'] ?? '').toString(),
        ),
      ],
      catalog: isForjaLive ? 'forja_live' : (isMut ? 'mut' : ''),
      livePluginId: pluginId,
    );
  }

  static MatchStream _streamFromParams(
    Map<String, dynamic> params, {
    required String embedUrl,
  }) {
    return MatchStream(
      id: (params['matchId'] ?? '').toString(),
      streamNo: (params['streamNo'] as num?)?.toInt() ?? 1,
      language: (params['language'] ?? '').toString(),
      hd: params['hd'] == true,
      embedUrl: embedUrl,
      source: (params['source'] ?? '').toString(),
      viewers: parseLiveViewerCount(params['viewers']),
    );
  }

  static MatchSourceRef? _sourceRefForStream(
    MatchEvent match,
    MatchStream stream,
  ) {
    for (final ref in match.sources) {
      if (ref.id == stream.id) return ref;
    }
    final src = stream.source.trim().toLowerCase();
    if (src.isNotEmpty) {
      for (final ref in match.sources) {
        if (ref.source.trim().toLowerCase() == src) return ref;
      }
    }
    if (stream.id.isEmpty && stream.source.trim().isEmpty) return null;
    return MatchSourceRef(
      source: stream.source,
      id: stream.id,
      iframe: stream.embedUrl,
    );
  }

  static Future<IptvPlaySource?> _resolveStreamToEnginePlaySource(
    MatchEvent match,
    MatchStream stream, {
    void Function(String)? onProgress,
    bool allowSourceRefFallback = true,
    bool forceRefresh = false,
  }) async {
    var embed = stream.embedUrl.trim();
    if (embed.startsWith('pending:')) embed = '';
    if (embed.isEmpty) {
      final iframe = _sourceRefForStream(match, stream)?.iframe.trim() ?? '';
      if (iframe.isNotEmpty) embed = iframe;
    }

    final ready = embed.isNotEmpty &&
        (stream.directPlayback || iptvLiveEnginePlayUrlReady(embed));
    final skipReuse =
        forceRefresh || (ready && iptvLiveEngineUrlVolatile(embed));
    if (ready && !skipReuse) {
      final headers = LiveGoatUnlock.withWftyPlaybackReferer(
        embed,
        stream.resolvedHeaders ??
            _liveEmbedStreamHeaders(
              embed,
              catalogReferer: match.isForjaLive
                  ? _forjaLiveCdnReferer(embed)
                  : null,
            ),
      );
      final direct = liveEngineOpenDirect(
        embed,
        pluginDirect: stream.directPlayback,
      );
      if (!direct) onProgress?.call('Preparing playback…');
      final playUrl = direct
          ? embed
          : await LivePluginEngine.proxyPlayUrl(url: embed, headers: headers);
      if (playUrl == null || playUrl.isEmpty) return null;
      return _liveEnginePlaySource(
        match: match,
        stream: stream,
        url: playUrl,
        headers: direct ? headers : const {},
        resolved: true,
      );
    }

    if (skipReuse && iptvLiveEnginePlayUrlReady(embed)) {
      embed = '';
    }

    final iframeCatalog =
        LivePluginEngine.cachedIsIframeLive(match.livePluginId);
    final catalogReferer = iframeCatalog
        ? await LivePluginEngine.iframeLiveWebReferer()
        : (embed.isNotEmpty
            ? (_forjaLiveCdnReferer(embed) ??
                await LivePluginEngine.pluginReferer(
                  match.livePluginId,
                  embedUrl: embed,
                ))
            : await LivePluginEngine.pluginReferer(match.livePluginId));

    if (embed.isNotEmpty &&
        RegExp(r'\.m3u8|\.mp4', caseSensitive: false).hasMatch(embed)) {
      final headers = LiveGoatUnlock.withWftyPlaybackReferer(
        embed,
        iframeCatalog
            ? _tokenizedEmbedStreamHeaders(embed)
            : _liveEmbedStreamHeaders(
                embed,
                catalogReferer: match.isForjaLive
                    ? _forjaLiveCdnReferer(embed)
                    : null,
              ),
      );
      final direct = liveEngineOpenDirect(embed);
      if (!direct) onProgress?.call('Preparing playback…');
      final playUrl = direct
          ? embed
          : await LivePluginEngine.proxyPlayUrl(url: embed, headers: headers);
      if (playUrl == null || playUrl.isEmpty) return null;
      return _liveEnginePlaySource(
        match: match,
        stream: stream,
        url: playUrl,
        headers: direct ? headers : const {},
        resolved: true,
      );
    }

    onProgress?.call('Unlocking source…');
    var pluginId = LivePluginEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty && iframeCatalog) {
      pluginId =
          LivePluginEngine.cachedIframeProviderResolvePluginId() ?? '';
    }
    LiveEngineResolveResult? result;
    if (pluginId.isNotEmpty) {
      result = await LivePluginEngine.resolve(
        pluginId: pluginId,
        params: {
          if (embed.isNotEmpty) 'embedUrl': embed,
          if (embed.isNotEmpty) 'iframe': embed,
          if (embed.isNotEmpty) 'url': embed,
          'source': stream.source,
          'matchId': stream.id,
          'stream': stream.streamNo.toString(),
          'category': match.category,
          'title': match.title,
        },
      );
    }
    if (result == null ||
        !result.playable ||
        !iptvLiveEnginePlayUrlReady(result.url)) {
      if (allowSourceRefFallback && match.isForjaLive) {
        return _unlockForjaLiveSourceRef(match, stream, onProgress: onProgress);
      }
      return null;
    }

    final headers = LiveGoatUnlock.withWftyPlaybackReferer(
      result.url,
      result.headers.isNotEmpty
          ? result.headers
          : iframeCatalog
              ? _tokenizedEmbedStreamHeaders(
                  embed.isNotEmpty ? embed : result.url,
                )
              : _liveEmbedStreamHeaders(
                  result.url,
                  catalogReferer: catalogReferer,
                ),
    );
    final direct = liveEngineOpenDirect(
      result.url,
      pluginDirect: result.directPlayback,
    );
    if (!direct) onProgress?.call('Preparing playback…');
    final playUrl = direct
        ? result.url
        : await LivePluginEngine.proxyPlayUrl(
            url: result.url,
            headers: headers,
          );
    if (playUrl == null || playUrl.isEmpty) return null;
    return _liveEnginePlaySource(
      match: match,
      stream: stream,
      url: playUrl,
      headers: direct ? headers : const {},
      resolved: true,
    );
  }

  static Future<IptvPlaySource?> _unlockForjaLiveSourceRef(
    MatchEvent match,
    MatchStream stream, {
    void Function(String)? onProgress,
  }) async {
    final ref = _sourceRefForStream(match, stream);
    if (ref == null) return null;
    final pluginId = LivePluginEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty) return null;
    var embed = stream.embedUrl.trim();
    if (embed.isEmpty || embed.startsWith('pending:')) {
      embed = ref.iframe.trim();
    }
    if (embed.isEmpty) return null;
    onProgress?.call('Unlocking source…');
    List<Map<String, dynamic>> rows = const [];
    try {
      rows = await EngineService.instance.runLivePlugin(
        pluginId: pluginId,
        action: 'resolve',
        params: {
          'matchId': stream.id.isNotEmpty ? stream.id : ref.id,
          'eventId': match.id,
          'source': stream.source.isNotEmpty ? stream.source : ref.source,
          'category': match.category,
          'title': match.title,
          'stream': stream.streamNo > 0 ? stream.streamNo.toString() : '1',
          'embedUrl': embed,
          'iframe': embed,
          'viewers': stream.viewers > 0 ? stream.viewers : match.viewers,
        },
      );
    } catch (e) {
      debugPrint('[LiveResolveStreams] unlock ${ref.source}/${ref.id}: $e');
      return null;
    }
    for (final row in rows) {
      if (row['webviewOnly'] == true) continue;
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty || !iptvLiveEnginePlayUrlReady(url)) continue;
      final pluginSource = stream.source.trim().isNotEmpty
          ? stream.source.trim().toLowerCase()
          : LivePluginEngine.cachedResolveSourceToken(pluginId);
      final hit = _streamFromResolveRow(
        row: row,
        source: ref,
        match: match,
        pluginSource: pluginSource,
        meta: stream,
        index: 0,
      );
      return _resolveStreamToEnginePlaySource(
        match,
        hit,
        onProgress: onProgress,
        allowSourceRefFallback: false,
      );
    }
    return null;
  }

  static IptvPlaySource _liveEnginePlaySource({
    required MatchEvent match,
    required MatchStream stream,
    required String url,
    Map<String, String> headers = const {},
    bool resolved = false,
  }) {
    final embed = stream.embedUrl.trim();
    final sourceLabel = _sourceLabel(stream.source);
    final title = _streamTitle(stream, sourceLabel);
    return IptvPlaySource(
      url: url,
      label: title.isNotEmpty
          ? title
          : (sourceLabel.isNotEmpty
              ? sourceLabel
              : _serverLabelFor(match)),
      detail: _streamDetail(stream),
      headers: headers,
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _serverLabelFor(match),
      liveViewerCount: effectiveMatchStreamViewers(stream, match),
      liveStreamHd: stream.hd,
      liveEngineEmbedUrl: resolved
          ? null
          : (embed.isEmpty || iptvLiveEnginePlayUrlReady(embed) ? null : embed),
      liveEngineResolveParams: _liveEngineResolveParams(match, stream),
    );
  }

  static const _ua = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  static Map<String, String> _tokenizedEmbedStreamHeaders(String embedUrl) {
    final uri = Uri.tryParse(embedUrl.trim());
    final origin = uri?.origin ?? 'https://embedindia.st';
    final referer = (uri != null && uri.hasScheme && uri.path.isNotEmpty)
        ? '$origin${uri.path}'
        : embedUrl.trim();
    return {
      'User-Agent': _ua['User-Agent']!,
      'Referer': referer,
      'Origin': origin,
    };
  }

  static Map<String, String> _liveEmbedStreamHeaders(
    String embedUrl, {
    String? catalogReferer,
  }) {
    final uri = Uri.tryParse(embedUrl);
    final origin = uri?.origin ?? '';
    final catalog = (catalogReferer ?? '').trim();
    final catalogRoot = catalog.isEmpty
        ? null
        : (catalog.endsWith('/') ? catalog : '$catalog/');
    final catalogOrigin =
        catalogRoot == null ? null : Uri.tryParse(catalogRoot)?.origin;
    final referer = catalogRoot ?? (origin.isNotEmpty ? '$origin/' : embedUrl);
    final headerOrigin = catalogOrigin ?? (origin.isNotEmpty ? origin : null);
    return {
      'User-Agent': _ua['User-Agent']!,
      'Referer': referer,
      if (headerOrigin != null && headerOrigin.isNotEmpty)
        'Origin': headerOrigin,
    };
  }

  static String? _forjaLiveCdnReferer(String embedUrl) {
    final uri = Uri.tryParse(embedUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('wfty.st')) {
      return LiveGoatUnlock.sportsEmbedRefererFromWftyPlaylist(embedUrl) ??
          'https://sportsembed.su/';
    }
    return '${uri.origin}/';
  }

  static Future<bool> _runWithCancellableLoading(
    BuildContext context,
    String message,
    Future<void> Function(void Function(String) setMessage) action,
  ) async {
    if (!context.mounted) return false;
    var cancelled = false;
    var closingOurselves = false;
    final messageNotifier = ValueNotifier(message);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !closingOurselves) cancelled = true;
        },
        child: AlertDialog(
          backgroundColor: ForjaShellColors.surfaceElevated,
          content: ValueListenableBuilder<String>(
            valueListenable: messageNotifier,
            builder: (_, msg, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(height: 16),
                Text(msg, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await action((next) {
        if (messageNotifier.value != next) messageNotifier.value = next;
      });
    } finally {
      if (context.mounted && !cancelled) {
        closingOurselves = true;
        try {
          FocusManager.instance.primaryFocus?.unfocus();
        } catch (_) {}
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
      messageNotifier.dispose();
    }
    return !cancelled && context.mounted;
  }
}

class _ProvidersCacheEntry {
  const _ProvidersCacheEntry({
    required this.expiresAt,
    required this.sources,
  });
  final DateTime expiresAt;
  final List<IptvPlaySource> sources;
}

class _StreamChoice {
  const _StreamChoice({required this.match, required this.stream});
  final MatchEvent match;
  final MatchStream stream;
}
