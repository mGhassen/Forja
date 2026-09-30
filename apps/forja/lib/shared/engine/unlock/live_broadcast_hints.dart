/// Channel names seen on provider rows, reused when Live TV has no guide list.
class LiveBroadcastHints {
  LiveBroadcastHints._();

  static final Map<String, List<String>> _byFixture = {};

  static void remember({
    required String title,
    String home = '',
    String away = '',
    required Iterable<String> labels,
  }) {
    final key = fixtureKey(title: title, home: home, away: away);
    if (key.isEmpty) return;
    final found = <String>[
      for (final label in labels) ...channelNamesFromLabel(label),
    ];
    if (found.isEmpty) return;
    final list = _byFixture.putIfAbsent(key, () => <String>[]);
    for (final name in found) {
      if (list.any((e) => e.toLowerCase() == name.toLowerCase())) continue;
      list.add(name);
      if (list.length >= 24) break;
    }
  }

  static List<String> lookup({
    required String title,
    String home = '',
    String away = '',
  }) {
    final key = fixtureKey(title: title, home: home, away: away);
    if (key.isEmpty) return const [];
    return List<String>.from(_byFixture[key] ?? const []);
  }

  static String fixtureKey({
    required String title,
    String home = '',
    String away = '',
  }) {
    final t = _norm(title);
    if (t.isNotEmpty) return t;
    return '${_norm(home)} ${_norm(away)}'.trim();
  }

  /// Pieces of a provider row label that look like a TV channel.
  static List<String> channelNamesFromLabel(String raw) {
    final out = <String>[];
    for (final part in raw.split(RegExp(r'[|·•/]'))) {
      final name = _stripQuality(part.trim());
      if (name.length < 4) continue;
      final words = name
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) continue;
      if (words.every(_isStopWord)) continue;
      if (!words.any((w) => w.length >= 4 || _hasDigit(w))) continue;
      if (out.any((e) => e.toLowerCase() == name.toLowerCase())) continue;
      out.add(name);
    }
    return out;
  }

  static String _stripQuality(String s) {
    return s
        .replaceAll(
          RegExp(r'\b(FHD|UHD|HD|SD|4K)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _hasDigit(String w) => w.contains(RegExp(r'\d'));

  static bool _isStopWord(String word) {
    final w = word
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('è', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (w.isEmpty) return true;
    return _stop.contains(w);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static const _stop = {
    'hd',
    'sd',
    'fhd',
    'uhd',
    '4k',
    'live',
    'sport',
    'sports',
    'sportowe',
    'tennis',
    'tenis',
    'football',
    'soccer',
    'pl',
    'pt',
    'en',
    'de',
    'fr',
    'ar',
    'es',
    'eu',
    'uk',
    'us',
    'polski',
    'portugues',
    'portuguese',
    'english',
    'spanish',
    'french',
    'francais',
    'german',
    'deutsch',
    'arabic',
    'italiano',
    'italian',
    'nederlands',
    'dutch',
    'turkish',
    'stream',
    'source',
  };
}
