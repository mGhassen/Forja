import 'package:forja/features/anime/catalog/allanime_extractor.dart';
import 'package:forja/features/anime/catalog/animerealms_extractor.dart';
import 'package:forja/features/anime/catalog/miruro_extractor.dart';

/// Flat catalog of every anime stream source the player can race.
///
/// Keys match [AnimeEmbed.sourceKey]. Display names are real upstream labels
/// (no player nicknames) — used in Settings → Playback → Anime provider order.
class AnimeStreamProviders {
  AnimeStreamProviders._();

  /// Default try order (Anikoto first, then Miruro, AllAnime, AnimeRealms, adult).
  static const List<String> defaultOrder = [
    'megaplay',
    'vidwish',
    // Miruro pipes
    'miruro:zoro',
    'miruro:kiwi',
    'miruro:bee',
    'miruro:hop',
    'miruro:bonk',
    'miruro:ally',
    'miruro:moo',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    // AllAnime
    'allanime:Default',
    'allanime:S-mp4',
    'allanime:Yt-mp4',
    'allanime:Luf-Mp4',
    'allanime:Uv-mp4',
    // AnimeRealms
    'animerealms:hianime',
    'animerealms:allmanga',
    'animerealms:gogoanime',
    'animerealms:zencloud',
    'animerealms:animepahe',
    'animerealms:animez',
    'animerealms:animekai',
    'animerealms:kickassanime',
    'animerealms:anizone',
    'animerealms:febbox',
    'animerealms:hanime-tv',
    // Adult
    'watchhentai',
    'hentaini',
  ];

  /// key → display name for settings (real names, no nicknames).
  static Map<String, String> get catalog {
    final out = <String, String>{
      'megaplay': 'Megaplay',
      'vidwish': 'Vidwish',
      'watchhentai': 'WatchHentai',
      'hentaini': 'Hentaini',
    };
    for (final p in MiruroExtractor.knownProviders) {
      out['miruro:$p'] =
          MiruroExtractor.upstreamSources[p] ?? p;
    }
    for (final p in AllAnimeExtractor.knownProviders) {
      out['allanime:$p'] = p;
    }
    for (final p in AnimeRealmsExtractor.defaultProviders) {
      out['animerealms:$p'] = _titleCaseProvider(p);
    }
    return out;
  }

  static String displayName(String key) => catalog[key] ?? key;

  static String _titleCaseProvider(String raw) {
    return raw
        .split('-')
        .map((part) {
          if (part.isEmpty) return part;
          if (part.toLowerCase() == 'tv') return 'TV';
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join('-');
  }

  /// Sort [keys] by [order], appending any missing keys at the end.
  static List<String> sortKeys(List<String> keys, List<String> order) {
    final set = keys.toSet();
    final out = <String>[];
    for (final k in order) {
      if (set.remove(k)) out.add(k);
    }
    out.addAll(keys.where(set.contains));
    return out;
  }
}
