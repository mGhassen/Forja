import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Resolves streams on Android TV without headless WebView sniffers.
abstract final class TvStreamFallback {
  static const _rustKeys = ['webstreamr', 'vidsrc', 'service111477'];

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

    final resolver = StreamProviderResolver();
    final catalog = providers ?? StreamProviders.providers;
    final domain = SourceDomain.fromMediaType(movie.mediaType);
    final ordered = SourceEngine.orderProviderIds(
      domain: domain,
      candidateIds: catalog.keys,
      settingsOrder: settingsOrder,
    );
    final keys = ordered.where(_rustKeys.contains).toList(growable: false);
    for (final key in keys) {
      if (isCancelled?.call() ?? false) return null;
      try {
        final result = await resolver.resolve(
          key: key,
          movie: movie,
          season: season,
          episode: episode,
          providers: catalog,
          isCancelled: isCancelled,
        );
        if (result != null && result.streamUrl.isNotEmpty) {
          debugPrint('[TvStreamFallback] resolved via $key');
          return result;
        }
      } catch (e) {
        debugPrint('[TvStreamFallback] $key failed: $e');
      }
    }
    return null;
  }
}
