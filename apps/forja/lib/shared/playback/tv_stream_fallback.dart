import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Resolves streams on Android TV without headless WebView sniffers.
abstract final class TvStreamFallback {
  static const _rustKeys = ['webstreamr', 'vidsrc', 'service111477'];

  /// Puts Rust/no-WebView providers first on Android TV.
  static Map<String, dynamic> prioritizeProviders(Map<String, dynamic> providers) {
    if (!PlatformInfo.isAndroidTv) return providers;
    final ordered = <String, dynamic>{};
    for (final key in _rustKeys) {
      if (providers.containsKey(key)) ordered[key] = providers[key];
    }
    for (final entry in providers.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  static Future<StreamProviderResolveResult?> resolve({
    required Movie movie,
    required int season,
    required int episode,
    Map<String, dynamic>? providers,
    bool Function()? isCancelled,
  }) async {
    if (!PlatformInfo.isAndroidTv) return null;

    final resolver = StreamProviderResolver();
    final catalog = providers ?? StreamProviders.providers;
    for (final key in _rustKeys) {
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
