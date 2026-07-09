import 'package:forja/features/anime/catalog/allanime_extractor.dart';
import 'package:forja/features/anime/catalog/animerealms_extractor.dart';
import 'package:forja/features/anime/catalog/miruro_extractor.dart';

/// Flat catalog of every anime stream source the player can race.
///
/// Keys match [AnimeEmbed.sourceKey]. Display names are real upstream labels
/// (no player nicknames) — used in Settings → Playback → Anime provider order.
class AnimeStreamProviders {
  AnimeStreamProviders._();

  /// Default try order — strongest / most reliable first.
  static const List<String> defaultOrder = [
    // Tofu (Miruro bee / AniKoto) — preferred first
    'miruro:bee',
    // AllAnime direct CDNs
    'allanime:Default',
    'allanime:S-mp4',
    // Anikoto HD embeds
    'megaplay',
    'vidwish',
    // HiAnime / AnimePahe (Miruro + AnimeRealms mirrors)
    'miruro:zoro',
    'animerealms:hianime',
    'miruro:kiwi',
    'animerealms:animepahe',
    // Remaining AllAnime
    'allanime:Yt-mp4',
    'allanime:Luf-Mp4',
    'allanime:Uv-mp4',
    // Strong Miruro pipes
    'miruro:ally',
    'animerealms:allmanga',
    'miruro:hop',
    'miruro:bonk',
    'animerealms:gogoanime',
    'miruro:moo',
    'animerealms:zencloud',
    'animerealms:animekai',
    // Mid AnimeRealms
    'animerealms:animez',
    'animerealms:kickassanime',
    'animerealms:anizone',
    'animerealms:febbox',
    // Weaker Miruro internals / regional
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'animerealms:hanime-tv',
    // Adult last
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
