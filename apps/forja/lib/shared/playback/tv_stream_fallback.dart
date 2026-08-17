import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Resolves streams on Android TV without headless WebView sniffers.
abstract final class TvStreamFallback {
  static const rustProviderKeys = ['webstreamr', 'vidsrc', 'service111477'];

  /// WebView / WASM extractors that must not run on Android TV.
  static bool isSkippedOnTv(String key, Map<String, dynamic> providers) {
    if (!PlatformInfo.isAndroidTv) return false;
    if (SettingsService.allowAndroidTvHeadlessWebViewExtractors) return false;
    if (rustProviderKeys.contains(key)) return false;
    // STREAMCRYPTO HTTP (Dart or JS host) — not a page sniff. Native decrypt
    // works on TV; WebView decrypt still fails inside the extractor.
    if (key == 'videasy' || key == 'vidsrcsbs') return false;
    final provider = providers[key];
    if (provider is Map &&
        provider['movie'] != null &&
        provider['tv'] != null) {
      return true;
    }
    return false;
  }

  /// Reorders providers using the shared Source Engine effective-order contract.
  static Map<String, dynamic> prioritizeProviders(
    Map<String, dynamic> providers, {
    SourceDomain domain = SourceDomain.movies,
    List<String> settingsOrder = const [],
  }) {
    if (!PlatformInfo.isAndroidTv) return providers;
    return SourceEngine.orderProvidersMap(
      domain: domain,
      providers: providers,
      settingsOrder: settingsOrder,
    );
  }

  static Future<StreamProviderResolveResult?> resolve({
    required Movie movie,
    required int season,
    required int episode,
    Map<String, dynamic>? providers,
    List<String> settingsOrder = const [],
    bool Function()? isCancelled,
  }) async {
    if (!PlatformInfo.isAndroidTv) return null;

    final catalog = providers ?? StreamProviders.providers;
    final domain = SourceDomain.fromMediaType(movie.mediaType);
    final ordered = SourceEngine.orderProviderIds(
      domain: domain,
      candidateIds: catalog.keys,
      settingsOrder: settingsOrder,
    );
    final keys = ordered.where(rustProviderKeys.contains).toList(growable: false);
    for (final key in keys) {
      if (isCancelled?.call() ?? false) return null;
      try {
        final filtered = {key: catalog[key]!};
        final hit = await PlaybackService.resolveWebstreaming(
          movie: movie,
          providers: filtered,
          season: season,
          episode: episode,
          preferredProvider: key,
          settingsOrder: settingsOrder,
          isCancelled: isCancelled,
        );
        if (hit != null && hit.streamUrl.isNotEmpty) {
          debugPrint('[TvStreamFallback] resolved via $key');
          return StreamProviderResolveResult(
            streamUrl: hit.streamUrl,
            audioUrl: hit.audioUrl,
            headers: hit.headers,
            sources: hit.streamSources,
            subtitles: hit.subtitles,
          );
        }
      } catch (e) {
        debugPrint('[TvStreamFallback] $key failed: $e');
      }
    }
    return null;
  }
}
