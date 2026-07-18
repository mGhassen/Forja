import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Experimental path: one provider → filter streams → probe → first playable.
///
/// Detached from the production race / player-reload failover loop.
abstract final class SimpleStreamingResolve {
  /// Rust-native scrapers — fast, no WebView.
  static const nativeIds = {'vidsrc', 'webstreamr'};

  /// Host HTTP APIs (may still fall back to WebView).
  static const hostApiIds = {'videasy', 'service111477'};

  static const _nativeTimeout = Duration(seconds: 25);
  static const _hostTimeout = Duration(seconds: 12);

  /// Walk providers (Auto order or a single pinned id). Returns the first
  /// provider that yields a reachable stream after filter+probe.
  ///
  /// Auto: natives first, then host APIs, then embeds — so CF/WebView hosts
  /// cannot block a working `vidsrc` forever.
  static Future<PlaybackResolveHit?> resolve({
    required Movie movie,
    required Map<String, dynamic> providers,
    required int season,
    required int episode,
    String preferredProvider = SourceEngine.auto,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
    void Function(String providerId, String status)? onProgress,
  }) async {
    final cancelled = isCancelled ?? (() => false);
    final domain = SourceDomain.fromMediaType(movie.mediaType);
    final baseline = SourceEngine.orderProviderIds(
      domain: domain,
      candidateIds: providers.keys,
      preferred: preferredProvider,
      settingsOrder: settingsOrder,
    );
    final ordered = SourceEngine.isAuto(preferredProvider)
        ? preferFastProviders(baseline)
        : baseline;
    if (ordered.isEmpty) return null;

    for (final providerId in ordered) {
      if (cancelled()) return null;
      onProgress?.call(providerId, 'trying');
      final budget = _timeoutFor(providerId);
      debugPrint(
        '[SimpleResolve] resolve $providerId (budget ${budget.inSeconds}s)',
      );

      var timedOut = false;
      final hit = await PlaybackService.resolveWebstreaming(
        movie: movie,
        providers: providers,
        season: season,
        episode: episode,
        preferredProvider: providerId,
        settingsOrder: settingsOrder,
        isCancelled: () => cancelled() || timedOut,
      ).timeout(
        budget,
        onTimeout: () {
          timedOut = true;
          PlaybackEngine.cancelAllPending();
          debugPrint('[SimpleResolve] $providerId — timeout ${budget.inSeconds}s');
          return null;
        },
      );
      if (cancelled()) return null;

      if (hit == null || hit.streamSources.isEmpty) {
        onProgress?.call(providerId, 'failed');
        debugPrint('[SimpleResolve] $providerId — no sources');
        continue;
      }

      final filtered = filterSources(
        hit.streamSources,
        movie: movie,
        season: season,
        episode: episode,
      );
      if (filtered.isEmpty) {
        onProgress?.call(providerId, 'failed');
        debugPrint('[SimpleResolve] $providerId — all sources filtered');
        continue;
      }

      final probed = <StreamSource>[];
      for (final source in filtered) {
        if (cancelled()) return null;
        final ok = await validateStreamSourceForCheck(
          providerId: providerId,
          source: source,
          headers: source.headers ?? hit.headers,
        );
        if (cancelled()) return null;
        if (!ok) {
          debugPrint(
            '[SimpleResolve] $providerId probe fail: ${source.title}',
          );
          continue;
        }
        probed.add(source);
      }

      if (probed.isEmpty) {
        onProgress?.call(providerId, 'failed');
        debugPrint('[SimpleResolve] $providerId — no reachable stream');
        continue;
      }

      final byUrl = {for (final p in hit.sources) p.url: p};
      final ranked = <PlayableSource>[
        for (final s in probed)
          byUrl[s.url] ??
              normalizeLegacyStreamSources(
                sources: [s],
                providerId: providerId,
                providerRank: hit.providerRank,
              ).first,
      ];

      onProgress?.call(providerId, 'success');
      debugPrint(
        '[SimpleResolve] $providerId — play ${probed.first.title} '
        '(${probed.length}/${filtered.length} probed ok)',
      );
      return PlaybackResolveHit(
        providerId: providerId,
        providerRank: hit.providerRank,
        streamUrl: probed.first.url,
        audioUrl: hit.audioUrl,
        headers: probed.first.headers ?? hit.headers,
        sources: ranked,
        subtitles: hit.subtitles,
      );
    }
    return null;
  }

  /// Natives → host APIs → embeds (keeps relative order inside each bucket).
  @visibleForTesting
  static List<String> preferFastProviders(List<String> ordered) {
    if (ordered.length <= 1) return ordered;
    final natives = <String>[];
    final apis = <String>[];
    final rest = <String>[];
    for (final id in ordered) {
      if (nativeIds.contains(id)) {
        natives.add(id);
      } else if (hostApiIds.contains(id)) {
        apis.add(id);
      } else {
        rest.add(id);
      }
    }
    return [...natives, ...apis, ...rest];
  }

  static Duration _timeoutFor(String providerId) {
    if (nativeIds.contains(providerId)) return _nativeTimeout;
    return _hostTimeout;
  }

  /// Drop obvious junk before probing (wrong ep, season packs, zip, unplayable).
  @visibleForTesting
  static List<StreamSource> filterSources(
    List<StreamSource> sources, {
    required Movie movie,
    required int season,
    required int episode,
  }) {
    final isTv = movie.mediaType == 'tv';
    final out = <StreamSource>[];
    for (final s in sources) {
      if (isUnplayableCachedStreamUrl(s.url)) continue;
      final url = s.url.toLowerCase();
      if (url.contains('.zip') || url.endsWith('.rar')) continue;
      final title = s.title.trim();
      if (isTv && !_episodeCompatible(title, season, episode)) continue;
      out.add(s);
    }
    return out;
  }

  /// Reject titles that clearly name a different S/E or a season pack.
  static bool _episodeCompatible(String title, int season, int episode) {
    if (title.isEmpty) return true;
    final lower = title.toLowerCase();

    final se = RegExp(r's0*(\d+)\s*[.\-_ ]?\s*e0*(\d+)').firstMatch(lower);
    if (se != null) {
      final s = int.tryParse(se.group(1) ?? '') ?? -1;
      final e = int.tryParse(se.group(2) ?? '') ?? -1;
      return s == season && e == episode;
    }

    final nx = RegExp(r'(?:^|[^\d])(\d{1,2})\s*[x×]\s*(\d{1,3})(?:[^\d]|$)')
        .firstMatch(lower);
    if (nx != null) {
      final s = int.tryParse(nx.group(1) ?? '') ?? -1;
      final e = int.tryParse(nx.group(2) ?? '') ?? -1;
      return s == season && e == episode;
    }

    final seasonOnly =
        RegExp(r'(?:^|[.\-_ ])s0*(\d+)(?:[.\-_ ]|$)').firstMatch(lower);
    if (seasonOnly != null &&
        !RegExp(r'e0*\d+').hasMatch(lower) &&
        !RegExp(r'\d{1,2}\s*[x×]\s*\d{1,3}').hasMatch(lower)) {
      return false;
    }

    return true;
  }
}
