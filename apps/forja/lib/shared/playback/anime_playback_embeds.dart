import 'package:forja/shared/playback/anime_embed.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _animeProviderDisplayName(String key) {
  if (key.startsWith('miruro:')) {
    return miruroUpstreamLabel(key.substring('miruro:'.length));
  }
  if (key.startsWith('allanime:')) {
    return key.substring('allanime:'.length);
  }
  if (key.startsWith('vidnest:')) {
    final prov = key.substring('vidnest:'.length);
    return vidnestUpstreamLabels[prov] ?? prov;
  }
  return StreamProviderDisplay.playerLabel(key, fallbackName: key);
}

String _vidlinkAnimeEmbed({
  required int malId,
  required int episode,
  required String lang,
}) {
  return 'https://vidlink.pro/anime/$malId/$episode/$lang?fallback=true';
}

/// Build legacy anime panel embed URLs (engine playback — not catalog browse).
List<AnimeEmbed> buildAnimePlaybackEmbeds({
  required int anilistId,
  required int episode,
  AnikotoSeries? series,
  String? category,
  List<String> animeTitles = const [],
  bool isAdult = false,
  int? malId,
}) {
  final mega = ProviderRuntimeConfig.instance.megaplay;
  final all = <AnimeEmbed>[
    for (final cat in const ['sub', 'dub'])
      AnimeEmbed(
        label: _animeProviderDisplayName('megaplay'),
        server: 'megaplay',
        category: cat,
        url: mega.buildAniUrl(
          anilistId: anilistId,
          episode: episode,
          lang: cat,
        ),
      ),
  ];
  final mal = malId ?? 0;
  if (mal > 0) {
    for (final cat in const ['sub', 'dub']) {
      all.add(
        AnimeEmbed(
          label: _animeProviderDisplayName('megaplay'),
          server: 'megaplay',
          category: cat,
          url: mega.buildMalUrl(
            malId: mal,
            episode: episode,
            lang: cat,
          ),
        ),
      );
    }
  }
  final slug = series?.slug.trim() ?? '';
  if (slug.isNotEmpty) {
    for (final cat in const ['sub', 'dub']) {
      all.add(
        AnimeEmbed(
          label: _animeProviderDisplayName('anikoto'),
          server: 'anikoto',
          category: cat,
          url: 'anikoto://watch/$slug/$episode/$cat',
        ),
      );
    }
  }
  if (mal > 0) {
    for (final cat in const ['sub', 'dub']) {
      all.add(
        AnimeEmbed(
          label: _animeProviderDisplayName('vidlink'),
          server: 'vidlink',
          category: cat,
          url: _vidlinkAnimeEmbed(malId: mal, episode: episode, lang: cat),
        ),
      );
    }
  }
  for (final cat in const ['sub', 'dub']) {
    for (final prov in miruroKnownProviders) {
      all.add(
        AnimeEmbed(
          label: _animeProviderDisplayName('miruro:$prov'),
          server: 'miruro',
          category: cat,
          url: 'miruro://anilist/$anilistId/$episode/$cat/$prov',
        ),
      );
    }
  }
  final titles = animeTitles
      .where((t) => t.trim().isNotEmpty)
      .map((t) => Uri.encodeComponent(t.trim()))
      .join(',');
  if (titles.isNotEmpty) {
    for (final cat in const ['sub', 'dub']) {
      for (final prov in allAnimeKnownProviders) {
        all.add(
          AnimeEmbed(
            label: _animeProviderDisplayName('allanime:$prov'),
            server: 'allanime',
            category: cat,
            url: 'allanime://search/$episode/$cat/$prov?t=$titles',
          ),
        );
      }
    }
  }
  for (final cat in const ['sub', 'dub']) {
    for (final prov in vidnestKnownProviders) {
      all.add(
        AnimeEmbed(
          label: _animeProviderDisplayName('vidnest:$prov'),
          server: 'vidnest',
          category: cat,
          url: 'vidnest://anilist/$anilistId/$episode/$cat/$prov',
        ),
      );
    }
  }
  if (isAdult && titles.isNotEmpty) {
    all.add(
      AnimeEmbed(
        label: _animeProviderDisplayName('watchhentai'),
        server: 'watchhentai',
        category: 'sub',
        url: 'watchhentai://discover/$episode?t=$titles',
      ),
    );
    all.add(
      AnimeEmbed(
        label: _animeProviderDisplayName('hentaini'),
        server: 'hentaini',
        category: 'sub',
        url: 'hentaini://discover/$episode?t=$titles',
      ),
    );
  }
  if (category == null) return all;
  return all.where((e) => e.category == category).toList();
}

Future<void> clearLegacyAnimeStreamPrefs() async {
  final p = await SharedPreferences.getInstance();
  await p.remove('enma_anime_stream_cache_v1');
  await p.remove('enma_anime_source_v1');
}
