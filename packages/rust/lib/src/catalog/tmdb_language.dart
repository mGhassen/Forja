/// TMDB `language` — titles, overviews, taglines and genres in the app language.
class TmdbLanguage {
  TmdbLanguage._();

  /// TMDB's own default; requests in this language carry no `language=`.
  static const String fallback = 'en-US';

  /// App hook — returns a BCP 47 tag such as `fr-FR`.
  static String Function()? resolve;

  /// `ll` or `ll-CC` as TMDB spells it, or [fallback] for anything else.
  static String normalize(String? tag) {
    final t = (tag ?? '').trim().replaceAll('_', '-');
    final m = RegExp(r'^([A-Za-z]{2})(?:-([A-Za-z]{2}))?$').firstMatch(t);
    if (m == null) return fallback;
    final lang = m.group(1)!.toLowerCase();
    final region = m.group(2)?.toUpperCase();
    return region == null ? lang : '$lang-$region';
  }

  static String get current => normalize(resolve?.call());

  /// Primary language subtag: `fr` for `fr-FR`.
  static String get code => current.split('-').first;

  /// `include_image_language` value: the app language first, then English and
  /// untagged images.
  static String get imageLanguages =>
      code == 'en' ? 'en,null' : '$code,en,null';

  static final RegExp _hasLanguage = RegExp(r'(^|[?&])language=');

  /// Adds `language=` to a TMDB resource path. Left alone when the path already
  /// has one, and when the app language is [fallback] (TMDB answers in it anyway).
  static String applyTo(String resourcePath) {
    final tag = current;
    if (tag == fallback || _hasLanguage.hasMatch(resourcePath)) {
      return resourcePath;
    }
    final sep = resourcePath.contains('?') ? '&' : '?';
    return '$resourcePath${sep}language=$tag';
  }
}
