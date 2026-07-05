/// Dart reference torrent title filter — Rust-off fallback and parity tests.
abstract final class TorrentFilterDart {
  static String normalizeTitle(String title) {
    if (title.isEmpty) return '';
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[",.:!?;_+\-\[\]\(\)]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, dynamic> parseSceneInfo(String title) {
    final t = title.toLowerCase();

    int? season;
    int? episode;
    var isMultiEpisode = false;
    var isSeasonPack = false;
    var isMultiSeason = false;
    var matchIndex = -1;

    if (RegExp(r's(\d+)\s*-\s*s?(\d+)', caseSensitive: false).hasMatch(t) ||
        RegExp(r'season\s*\d+\s*-\s*\d+', caseSensitive: false).hasMatch(t) ||
        RegExp(r'complete\s+series', caseSensitive: false).hasMatch(t) ||
        t.contains('collection') ||
        t.contains('anthology')) {
      isMultiSeason = true;
    }

    final multiSxE = RegExp(
      r's(\d{1,2})[ ._-]*e(\d{1,3})[ ._-]*-[ ._-]*e?(\d{1,3})',
      caseSensitive: false,
    );
    final multiX = RegExp(
      r'(\d{1,2})x(\d{1,3})[ ._-]*-[ ._-]*x?(\d{1,3})',
      caseSensitive: false,
    );

    if (multiSxE.hasMatch(t) || multiX.hasMatch(t)) {
      isMultiEpisode = true;
    }

    final sXe = RegExp(r's(\d{1,2})[ ._-]*e(\d{1,3})', caseSensitive: false);
    final x = RegExp(r'\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false);
    final written =
        RegExp(r'season\s*(\d{1,2})\s*episode\s*(\d{1,3})', caseSensitive: false);

    var match = sXe.firstMatch(t);
    if (match != null) {
      season = int.tryParse(match.group(1)!);
      episode = int.tryParse(match.group(2)!);
      matchIndex = match.start;
    } else {
      match = x.firstMatch(t);
      if (match != null) {
        season = int.tryParse(match.group(1)!);
        episode = int.tryParse(match.group(2)!);
        matchIndex = match.start;
      } else {
        match = written.firstMatch(t);
        if (match != null) {
          season = int.tryParse(match.group(1)!);
          episode = int.tryParse(match.group(2)!);
          matchIndex = match.start;
        }
      }
    }

    if (season == null) {
      final sOnly = RegExp(r'\bs(\d{1,2})\b', caseSensitive: false);
      final sWritten = RegExp(r'season\s*(\d{1,2})\b', caseSensitive: false);

      var sMatch = sOnly.firstMatch(t);
      if (sMatch != null) {
        season = int.tryParse(sMatch.group(1)!);
        isSeasonPack = true;
        matchIndex = sMatch.start;
      } else {
        sMatch = sWritten.firstMatch(t);
        if (sMatch != null) {
          season = int.tryParse(sMatch.group(1)!);
          isSeasonPack = true;
          matchIndex = sMatch.start;
        }
      }
    }

    if (t.contains('complete') || t.contains('season pack') || t.contains('batch')) {
      if (season != null && episode == null) isSeasonPack = true;
      if (season != null && episode != null) isMultiEpisode = true;
    }

    if (season != null && episode == null && !isSeasonPack) {
      isSeasonPack = true;
    }

    return {
      'season': season,
      'episode': episode,
      'isSeasonPack': isSeasonPack,
      'isMultiEpisode': isMultiEpisode,
      'isMultiSeason': isMultiSeason,
      'matchIndex': matchIndex,
    };
  }
}
