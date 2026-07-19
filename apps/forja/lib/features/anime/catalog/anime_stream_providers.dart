import 'package:rust/rust.dart';

/// Flat catalog of every anime stream source the player can race.
///
/// Keys match [AnimeEmbed.sourceKey]. Display names are real upstream labels —
/// used in Settings → Playback → Anime provider order and the anime player.
class AnimeStreamProviders {
  AnimeStreamProviders._();

  /// Default try order — strongest / most reliable first.
  ///
  /// AnimeRealms was removed (upstream API gone — domain is a storefront).
  /// AllAnime `Uv-mp4` was removed (upstream no longer returns it).
  /// Megaplay/Vidwish first: direct embed extract (no Miruro CF WebView).
  static const List<String> defaultOrder = [
    'megaplay',
    'vidwish',
    // VidNest — AniList-native HiAnime / AnimePahe
    'vidnest:hianime',
    'vidnest:animepahe',
    // AllAnime — Yt-mp4 is the reliable direct MP4; Default aliases to it first
    'allanime:Default',
    'allanime:Yt-mp4',
    'allanime:S-mp4',
    'allanime:Luf-Mp4',
    // AniKoto (Miruro bee) + other Miruro pipes (CF WebView)
    'miruro:bee',
    'miruro:zoro',
    'miruro:kiwi',
    'miruro:ally',
    'miruro:hop',
    'miruro:bonk',
    'miruro:moo',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    // Adult last
    'watchhentai',
    'hentaini',
  ];

  /// key → display name (real upstream labels).
  static Map<String, String> get catalog {
    final out = <String, String>{
      'megaplay': 'Megaplay',
      'vidwish': 'Vidwish',
      'watchhentai': 'WatchHentai',
      'hentaini': 'Hentaini',
    };
    for (final p in miruroKnownProviders) {
      out['miruro:$p'] = miruroUpstreamLabel(p);
    }
    for (final p in allAnimeKnownProviders) {
      out['allanime:$p'] = p;
    }
    for (final p in vidnestKnownProviders) {
      out['vidnest:$p'] = vidnestUpstreamLabels[p] ?? p;
    }
    return out;
  }

  static String displayName(String key) => catalog[key] ?? key;

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
