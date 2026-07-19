import 'dart:async';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

typedef AnimeResolvedHit = ({AnimeEmbed embed, ExtractedMedia media});

/// Shared anime resolve/scoring — same pipeline as movies via [DomainPlaybackResolve].
abstract final class AnimePlaybackBridge {
  /// Keys are [AnimeEmbed.sourceKey] so Rust [SourceEngine] can order and pin providers.
  static Map<String, dynamic> embedsToProviders(List<AnimeEmbed> embeds) {
    final out = <String, dynamic>{};
    for (final embed in embeds) {
      out.putIfAbsent(embed.sourceKey, () => embed);
    }
    return out;
  }

  /// One map entry per embed — sub and dub rows stay separate in the player panel.
  static Map<String, dynamic> embedsToPanelProviders(List<AnimeEmbed> embeds) {
    return {for (final embed in embeds) embed.panelKey: embed};
  }

  static Future<List<AnimeResolvedHit>> raceEmbeds({
    required List<AnimeEmbed> embeds,
    required Movie hubMovie,
    required List<String> settingsOrder,
    required AnimeService animeService,
    String preferredProvider = SourceEngine.auto,
    bool Function()? isCancelled,
    void Function(List<AnimeResolvedHit> hits)? onHitsUpdated,
    void Function(String providerId, String status)? onProgress,
    int maxInFlight = 1,
  }) async {
    if (embeds.isEmpty) return const [];

    final providers = embedsToProviders(embeds);
    var latestHits = <PlaybackResolveHit>[];

    final first = await DomainPlaybackResolve.resolve(
      domain: SourceDomain.anime,
      providers: providers,
      movie: hubMovie,
      preferredProvider: preferredProvider,
      settingsOrder: settingsOrder,
      animeService: animeService,
      isCancelled: isCancelled,
      onProgress: onProgress,
      maxInFlight: maxInFlight,
      // First playable wins — do not keep scanning siblings in the background
      // once a stream is ready to open.
      fillBackgroundHits: false,
      onHitsUpdated: (batch) {
        latestHits = batch;
        unawaited(() async {
          final scored = await scoreAndRankHits(
            embeds: embeds,
            hits: batch,
            settingsOrder: settingsOrder,
          );
          onHitsUpdated?.call(scored);
        }());
      },
    );
    if (latestHits.isEmpty && first != null) {
      latestHits = [first];
    }
    if (latestHits.isEmpty) return const [];

    return scoreAndRankHits(
      embeds: embeds,
      hits: latestHits,
      settingsOrder: settingsOrder,
    );
  }

  static List<AnimeResolvedHit> convertHits(
    List<AnimeEmbed> embeds,
    List<PlaybackResolveHit> hits,
  ) {
    final providers = embedsToProviders(embeds);
    final out = <AnimeResolvedHit>[];
    for (final hit in hits) {
      final embed = providers[hit.providerId];
      if (embed is! AnimeEmbed) continue;
      out.add((
        embed: embed,
        media: ExtractedMedia(
          url: hit.streamUrl,
          headers: hit.headers ?? const {},
          provider: embed.server,
          sources: hit.streamSources,
          externalSubtitles: hit.subtitles,
        ),
      ));
    }
    return out;
  }

  static Future<List<AnimeResolvedHit>> scoreAndRankHits({
    required List<AnimeEmbed> embeds,
    required List<PlaybackResolveHit> hits,
    required List<String> settingsOrder,
    String? preferredKey,
    String? preferredTitle,
  }) async {
    if (hits.isEmpty) return const [];

    final providers = embedsToProviders(embeds);
    final sourceKeys = hits
        .map((h) {
          final embed = providers[h.providerId];
          return embed is AnimeEmbed ? embed.sourceKey : h.providerId;
        })
        .toSet();
    final order = SourceEngine.orderProviders(
      domain: SourceDomain.anime,
      candidateIds: sourceKeys,
      settingsOrder: settingsOrder,
    );
    final rankByKey = {
      for (final row in order.rows) row.id: row.effectiveRank,
    };

    final scored = <AnimeResolvedHit>[];
    for (final hit in hits) {
      final embed = providers[hit.providerId];
      if (embed is! AnimeEmbed) continue;
      final rank = rankByKey[embed.sourceKey] ?? hit.providerRank;
      final rankedSources = await PlaybackSelection.rankLegacySources(
        sources: hit.streamSources,
        providerId: embed.sourceKey,
        providerRank: rank,
      );
      if (rankedSources.isEmpty) continue;
      final rankedHdrs = rankedSources.first.headers;
      final fallbackHdrs = hit.headers ?? const <String, String>{};
      final rawHdrs =
          rankedHdrs.isNotEmpty ? rankedHdrs : Map<String, String>.from(fallbackHdrs);
      final headers = resolvePlaybackHttpHeaders(
        rawHdrs.isEmpty ? null : rawHdrs,
        streamUrl: rankedSources.first.url,
      );
      scored.add((
        embed: embed,
        media: ExtractedMedia(
          url: rankedSources.first.url,
          headers: headers,
          provider: embed.server,
          sources: playableSourcesToStreamSources(rankedSources),
          externalSubtitles: hit.subtitles,
        ),
      ));
    }

    if (preferredKey != null) {
      scored.sort((a, b) {
        int weight(AnimeResolvedHit h) {
          if (h.embed.sourceKey != preferredKey) return 1000;
          final title = h.media.sources?.first.title ?? '';
          if (preferredTitle != null &&
              preferredTitle.isNotEmpty &&
              title == preferredTitle) {
            return -2;
          }
          return -1;
        }

        final wa = weight(a);
        final wb = weight(b);
        if (wa != wb) return wa.compareTo(wb);
        final ia = rankByKey[a.embed.sourceKey] ?? 1000;
        final ib = rankByKey[b.embed.sourceKey] ?? 1000;
        return ia.compareTo(ib);
      });
    } else {
      scored.sort((a, b) {
        final ia = rankByKey[a.embed.sourceKey] ?? 1000;
        final ib = rankByKey[b.embed.sourceKey] ?? 1000;
        if (ia != ib) return ia.compareTo(ib);
        return a.embed.sourceKey.compareTo(b.embed.sourceKey);
      });
    }
    return scored;
  }

  static Future<List<StreamSource>?> reloadStreams({
    required AnimeService service,
    required List<AnimeEmbed> allEmbeds,
    required String category,
    required Movie hubMovie,
    List<String> providerOrder = const [],
  }) async {
    final pair = allEmbeds.where((e) => e.category == category).toList();
    if (pair.isEmpty) return null;

    final order = providerOrder.isEmpty
        ? await SettingsService().getAnimeProviderOrder()
        : providerOrder;
    final sortedKeys = SourceEngine.orderProviderIds(
      domain: SourceDomain.anime,
      candidateIds: pair.map((e) => e.sourceKey).toSet(),
      settingsOrder: order,
    );
    final byKey = <String, List<AnimeEmbed>>{};
    for (final e in pair) {
      byKey.putIfAbsent(e.sourceKey, () => []).add(e);
    }
    final sorted = <AnimeEmbed>[];
    for (final k in sortedKeys) {
      sorted.addAll(byKey[k] ?? const []);
    }

    final hits = await raceEmbeds(
      embeds: sorted,
      hubMovie: hubMovie,
      settingsOrder: order,
      animeService: service,
      maxInFlight: 1,
    );
    if (hits.isEmpty) return null;
    return _hitsToStreamSources(hits);
  }

  static List<StreamSource> _hitsToStreamSources(List<AnimeResolvedHit> hits) {
    final sources = <StreamSource>[];
    for (final h in hits) {
      final headers = resolvePlaybackHttpHeaders(
        h.media.headers.isEmpty ? null : Map<String, String>.from(h.media.headers),
        streamUrl: h.media.url,
      );
      if (!headers.containsKey('Referer') || headers['Referer']!.isEmpty) {
        final origin = h.embed.refererOrigin;
        if (origin.isNotEmpty) {
          headers['Referer'] = '$origin/';
          headers.putIfAbsent('Origin', () => origin);
        }
      }
      sources.add(StreamSource(
        url: h.media.url,
        title: h.media.sources?.first.title ?? 'Stream',
        type: h.media.url.contains('.m3u8') ? 'hls' : 'video',
        headers: headers,
      ));
    }
    return sources;
  }
}
