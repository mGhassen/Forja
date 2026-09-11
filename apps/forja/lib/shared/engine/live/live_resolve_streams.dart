import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/foundation/services/registry/kit_iptv_play_hooks.dart';

import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/iptv/channel_search/iptv_channel_search.dart';
import 'package:forja/shared/engine/live/live_fixture_match.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/lib/schedule_sport_filter.dart';
import 'package:rust/rust.dart'
    show BuiltInPlayerContext, SettingsService, StremioService;
import 'package:forja/shared/foundation/primitives/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Live resolve + Stremio providers + native play (RFC-091).
/// Live TV portal channels: [IptvChannelSearch] (RFC-096).
abstract final class LiveResolveStreams {
  LiveResolveStreams._();

  static const _providersCacheTtl = Duration(minutes: 30);
  static const _stremioProvidersTimeout = Duration(seconds: 12);
  static final Map<String, _ProvidersCacheEntry> _providersCache = {};

  /// Providers rail: every enabled resolve pack searches the fixture + Stremio.
  ///
  /// Host does **not** soft-match the catalog schedule pool (RFC-105). Packs
  /// own fixture search; UI paints via [onPartial] as each pack returns.
  static Future<List<IptvPlaySource>> loadProviders(
    Map<String, dynamic> legacyRow, {
    bool force = false,
    void Function(List<IptvPlaySource> partial)? onPartial,
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

    await LivePluginEngine.warmPluginMeta();

    // Stremio Catalog chip row — direct /stream only.
    if (match.isStremio) {
      List<IptvPlaySource> stremioOnly = const [];
      try {
        stremioOnly = await _loadStremioProviders(match);
      } catch (e, st) {
        debugPrint('[LiveResolveStreams] Stremio providers error: $e\n$st');
      }
      if (stremioOnly.isNotEmpty) {
        _providersCache[cacheKey] = _ProvidersCacheEntry(
          expiresAt: DateTime.now().add(_providersCacheTtl),
          sources: List<IptvPlaySource>.from(stremioOnly),
        );
      }
      return stremioOnly;
    }

    var forja = <IptvPlaySource>[];
    var stremio = <IptvPlaySource>[];

    List<IptvPlaySource> merged() {
      final out = <IptvPlaySource>[];
      final seen = <String>{};
      for (final s in [...forja, ...stremio]) {
        final key = s.url.trim().isNotEmpty
            ? 'u:${s.url.trim()}'
            : 'l:${s.label}|${s.liveEngineEmbedUrl ?? ''}';
        if (!seen.add(key)) continue;
        out.add(s);
      }
      return out;
    }

    void publish() => onPartial?.call(merged());

    final stremioFuture = _loadStremioProviders(match);
    try {
      forja = await _loadForjaLiveProviders(
        match,
        onPartial: (partial) {
          forja = partial;
          publish();
        },
      );
      publish();
    } catch (e, st) {
      debugPrint('[LiveResolveStreams] Forja Live providers error: $e\n$st');
    }

    try {
      stremio = await stremioFuture.timeout(
        _stremioProvidersTimeout,
        onTimeout: () {
          debugPrint(
            '[LiveResolveStreams] Stremio providers timed out after '
            '${_stremioProvidersTimeout.inSeconds}s',
          );
          return const <IptvPlaySource>[];
        },
      );
      publish();
    } catch (e, st) {
      debugPrint('[LiveResolveStreams] Stremio providers error: $e\n$st');
    }

    final out = merged();
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
      sources: sources,
      picked: picked,
      title: title,
      subtitle: subtitle ?? picked.pickerSubtitle ?? '',
    );
  }

  static String _providersCacheKey(MatchEvent match) {
    final addonRev = SettingsService.addonChangeNotifier.value;
    return 'providers:${matchEventViewerKey(match)}:a$addonRev';
  }

  /// Fan-out every enabled resolve pack — pack searches its own upstream.
  static Future<List<IptvPlaySource>> _loadForjaLiveProviders(
    MatchEvent match, {
    void Function(List<IptvPlaySource> partial)? onPartial,
  }) async {
    final plugins =
        await EngineService.instance.listEnabledLiveResolvePlugins();
    if (plugins.isEmpty) return const [];

    final choices = <_StreamChoice>[];
    final seenUrls = <String>{};

    List<IptvPlaySource> snapshot() {
      final sorted = List<_StreamChoice>.from(choices)
        ..sort(
          (a, b) => effectiveMatchStreamViewers(b.stream, b.match).compareTo(
            effectiveMatchStreamViewers(a.stream, a.match),
          ),
        );
      return [for (final c in sorted) _choiceToPanelSource(c)];
    }

    void publish() => onPartial?.call(snapshot());

    await Future.wait(
      plugins.map((plugin) async {
        try {
          final streams = await _discoverFromResolvePlugin(match, plugin);
          final pluginMatch = match.copyWith(livePluginId: plugin.id);
          var added = false;
          for (final stream in streams) {
            final url = stream.embedUrl.trim();
            if (url.isEmpty || !seenUrls.add(url)) continue;
            choices.add(_StreamChoice(match: pluginMatch, stream: stream));
            added = true;
          }
          if (added) publish();
        } catch (e) {
          debugPrint(
            '[LiveResolveStreams] resolve ${plugin.id}: $e',
          );
        }
      }),
    );

    return snapshot();
  }

  /// Opaque source ref on the opened card that belongs to [plugin], if any.
  static MatchSourceRef? _ownedSourceRef(
    MatchEvent match,
    EnginePlugin plugin,
  ) {
    final token =
        LivePluginEngine.cachedResolveSourceToken(plugin.id).toLowerCase();
    final norm = EngineService.normalizeLiveSportPluginId(plugin.id);
    MatchSourceRef? firstOwned;
    for (final ref in match.sources) {
      final src = ref.source.trim().toLowerCase();
      if (src.isEmpty) continue;
      if (!LivePluginEngine.cachedOwnsSourceToken(plugin.id, src)) continue;
      firstOwned ??= ref;
      // Prefer an opaque slot id when present (goat / stream keys).
      if (ref.id.trim().isNotEmpty) return ref;
    }
    if (firstOwned != null) return firstOwned;
    final cardKey = LivePluginEngine.resolvePluginKey(match.livePluginId);
    if (cardKey.isNotEmpty &&
        cardKey == EngineService.normalizeLiveSportPluginId(plugin.id)) {
      // Prefer first ownedSources[] id on the card before falling back to row id.
      for (final ref in match.sources) {
        final src = ref.source.trim().toLowerCase();
        if (src.isEmpty) continue;
        if (LivePluginEngine.cachedOwnsSourceToken(plugin.id, src) &&
            ref.id.trim().isNotEmpty) {
          return ref;
        }
      }
      final id = LivePluginEngine.cachedResolveRefId(match.id, plugin.id);
      if (id.isNotEmpty) {
        return MatchSourceRef(
          source: token.isNotEmpty ? token : norm,
          id: id,
        );
      }
    }
    return null;
  }

  /// One resolve pack: owned matchId when known, else fixture identity for pack search.
  static Future<List<MatchStream>> _discoverFromResolvePlugin(
    MatchEvent match,
    EnginePlugin plugin,
  ) async {
    final owned = _ownedSourceRef(match, plugin);
    final pluginSource = LivePluginEngine.cachedResolveSourceToken(plugin.id);

    final mid = owned == null
        ? ''
        : LivePluginEngine.cachedResolveRefId(owned.id, plugin.id);
    final sourceToken = owned?.source.trim().isNotEmpty == true
        ? owned!.source
        : pluginSource;

    return _discoverLivePackStreams(
      match: match,
      source: MatchSourceRef(
        source: sourceToken,
        id: mid.isNotEmpty ? mid : match.id,
      ),
      pluginId: plugin.id,
      pluginSource: pluginSource,
      fixtureOnly: owned == null,
    );
  }

  /// Providers list only — real mirrors from live discover. Unlock on play.
  static Future<List<MatchStream>> _discoverLivePackStreams({
    required MatchEvent match,
    required MatchSourceRef source,
    required String pluginId,
    required String pluginSource,
    bool fixtureOnly = false,
  }) async {
    // Live packs: resolve returns real mirrors (embeds or unlocked URLs).
    // Unlock-on-play when the row is still an embed page.
    // Fixture-only: pack searches its own schedule (RFC-105) — no host soft-match.
    List<Map<String, dynamic>> rows = const [];
    try {
      final ownedSource = source.source.trim();
      rows = await EngineService.instance.runLivePlugin(
        pluginId: pluginId,
        action: 'resolve',
        params: {
          if (!fixtureOnly && source.id.trim().isNotEmpty)
            'matchId': source.id.trim(),
          'eventId': match.id,
          // Prefer the card's opaque source token (e.g. goat `admin`) over the
          // plugin slug so packs can list that slot directly.
          'source': ownedSource.isNotEmpty ? ownedSource : pluginSource,
          'category': match.category,
          'title': match.title,
          'homeTeam': match.homeTeam ?? '',
          'awayTeam': match.awayTeam ?? '',
          'dateMs': match.dateMs,
          'stream': '1',
          'viewers': match.viewers,
          'fixtureSearch': fixtureOnly,
        },
      );
    } catch (e) {
      debugPrint('[LiveResolveStreams] discover $pluginId: $e');
      return const [];
    }

    final out = <MatchStream>[];
    final seen = <String>{};
    final ref = MatchSourceRef(
      source: pluginSource.isNotEmpty ? pluginSource : source.source,
      id: source.id.trim().isNotEmpty ? source.id.trim() : match.id,
    );
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row['webviewOnly'] == true) continue;
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty || !seen.add(url)) continue;
      if (url.startsWith('pending:')) continue;
      out.add(
        _streamFromResolveRow(
          row: row,
          source: ref,
          match: match,
          pluginSource: pluginSource,
          index: out.length,
        ),
      );
    }
    return out;
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
        : metaViewers;
    final url = (row['url'] ?? '').toString().trim();
    final rowSource = (row['source'] ?? '').toString().trim();
    final rowId = (row['id'] ?? '').toString().trim();
    final sourceToken = meta?.source.trim().isNotEmpty == true
        ? meta!.source
        : (rowSource.isNotEmpty
            ? rowSource
            : (pluginSource.isNotEmpty ? pluginSource : source.source));
    final streamId = rowId.isNotEmpty
        ? rowId
        : (source.id.trim().isNotEmpty ? source.id.trim() : match.id);
    Map<String, String>? resolvedHeaders;
    final h = row['headers'];
    if (h is Map && h.isNotEmpty) {
      resolvedHeaders = {
        for (final e in h.entries) e.key.toString(): e.value.toString(),
      };
    }
    final rowStreamNo = (row['streamNo'] as num?)?.toInt();
    return MatchStream(
      id: streamId,
      streamNo: meta?.streamNo ?? rowStreamNo ?? index + 1,
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
      liveViewerCount: stream.viewers,
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
    return liveCatalogEventsSoftMatch(
      idA: engine.id,
      titleA: engine.title,
      homeTeamA: engine.homeTeam,
      awayTeamA: engine.awayTeam,
      dateMsA: engine.dateMs,
      idB: stremio.id,
      titleB: stremio.title,
      homeTeamB: stremio.homeTeam,
      awayTeamB: stremio.awayTeam,
      dateMsB: stremio.dateMs,
      alwaysOnA: engine.isAlwaysOn,
      alwaysOnB: stremio.isAlwaysOn,
    );
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

    final portal = await IptvChannelSearch.resolvePortal();
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

  /// Active row first, then the rest of the Providers list (in-player Source).
  static List<IptvPlaySource> _orderedLiveEngineSources({
    required List<IptvPlaySource> sources,
    required IptvPlaySource active,
    IptvPlaySource? picked,
  }) {
    final skip = picked ?? active;
    return [
      active,
      for (final s in sources)
        if (!_sameLiveCatalogRow(s, skip) && !_sameLiveCatalogRow(s, active)) s,
    ];
  }

  static bool _sameLiveCatalogRow(IptvPlaySource a, IptvPlaySource b) {
    if (identical(a, b)) return true;
    final pa = a.liveEngineResolveParams;
    final pb = b.liveEngineResolveParams;
    if (pa != null && pb != null && pa.isNotEmpty && pb.isNotEmpty) {
      final ma =
          '${pa['livePluginId']}|${pa['eventId']}|${pa['matchId']}|${pa['streamNo']}|${pa['source']}';
      final mb =
          '${pb['livePluginId']}|${pb['eventId']}|${pb['matchId']}|${pb['streamNo']}|${pb['source']}';
      if (ma != '||||' && ma == mb) return true;
    }
    final ka = iptvLiveSourceProbeKey(a);
    final kb = iptvLiveSourceProbeKey(b);
    if (ka.isNotEmpty && ka == kb) return true;
    final ua = a.url.trim();
    final ub = b.url.trim();
    return ua.isNotEmpty && ua == ub;
  }

  static Future<void> _playLiveEngine(
    BuildContext context, {
    required List<IptvPlaySource> sources,
    required IptvPlaySource picked,
    required String title,
    required String subtitle,
  }) async {
    final url = picked.url.trim();
    final open = KitIptvPlayHooks.openLiveNativePlayer;
    if (open == null) return;

    Future<void> handOff({
      required IptvPlaySource active,
      required IptvLiveSourceKind kind,
    }) async {
      if (!context.mounted) return;
      await open(
        context,
        sources: List<dynamic>.from(
          _orderedLiveEngineSources(
            sources: sources,
            active: active,
            picked: picked,
          ),
        ),
        title: title,
        subtitle: subtitle,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: kind,
        liveEngineResolveSource: kind == IptvLiveSourceKind.liveEngine
            ? resolveLiveEngineSource
            : null,
      );
    }

    if (picked.liveSourceKind == IptvLiveSourceKind.stremio &&
        iptvLiveEnginePlayUrlReady(url)) {
      await handOff(active: picked, kind: IptvLiveSourceKind.stremio);
      return;
    }

    if (iptvLiveEnginePlayUrlReady(url)) {
      await handOff(active: picked, kind: IptvLiveSourceKind.liveEngine);
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
    await handOff(active: handoff, kind: IptvLiveSourceKind.liveEngine);
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
      final headers = stream.resolvedHeaders ??
            _liveEmbedStreamHeaders(
              embed,
              catalogReferer: match.isForjaLive
                  ? _forjaLiveCdnReferer(embed)
                  : null,
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
      final headers = iframeCatalog
            ? _tokenizedEmbedStreamHeaders(embed)
            : _liveEmbedStreamHeaders(
                embed,
                catalogReferer: match.isForjaLive
                    ? _forjaLiveCdnReferer(embed)
                    : null,
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
          'eventId': match.id,
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

    final headers = result.headers.isNotEmpty
          ? result.headers
          : iframeCatalog
              ? _tokenizedEmbedStreamHeaders(
                  embed.isNotEmpty ? embed : result.url,
                )
              : _liveEmbedStreamHeaders(
                  result.url,
                  catalogReferer: catalogReferer,
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
    // Catalog schedule rows never carry iframes — live packs resolve from
    // matchId / eventId alone.
    onProgress?.call('Unlocking source…');
    List<Map<String, dynamic>> rows = const [];
    try {
      final resolved = await LivePluginEngine.resolve(
        pluginId: pluginId,
        params: {
          'matchId': stream.id.isNotEmpty ? stream.id : ref.id,
          'eventId': match.id,
          'source': stream.source.isNotEmpty ? stream.source : ref.source,
          'category': match.category,
          'title': match.title,
          'stream': stream.streamNo > 0 ? stream.streamNo.toString() : '1',
          if (embed.isNotEmpty) 'embedUrl': embed,
          if (embed.isNotEmpty) 'iframe': embed,
          'viewers': stream.viewers > 0 ? stream.viewers : match.viewers,
        },
      );
      if (resolved == null ||
          !resolved.playable ||
          !iptvLiveEnginePlayUrlReady(resolved.url)) {
        return null;
      }
      rows = [
        {
          'url': resolved.url,
          'headers': resolved.headers,
          'directPlayback': resolved.directPlayback,
        },
      ];
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
      liveViewerCount: stream.viewers,
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
    // Pack resolve owns playback Referer/Origin (incl. sportsembed ↔ wfty).
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
