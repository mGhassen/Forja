/// TMDB `watch_region` / provider country — ISO 3166-1 alpha-2 (FR, US, …).
class TmdbWatchRegion {
  TmdbWatchRegion._();

  static const String fallback = 'US';

  /// App hook — e.g. Flutter reads `PlatformDispatcher.locale.countryCode`.
  static String Function()? resolve;

  /// Normalize to uppercase ISO 3166-1 alpha-2 or [fallback].
  static String normalize(String? code) {
    if (code == null || code.trim().isEmpty) return fallback;
    final upper = code.trim().toUpperCase();
    if (upper.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(upper)) {
      return fallback;
    }
    return upper;
  }

  static String get current => normalize(resolve?.call());
}
