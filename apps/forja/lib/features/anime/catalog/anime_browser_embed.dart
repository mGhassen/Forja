import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';

/// Public browser player page for an anime embed (Megaplay / Vidwish / VidNest).
///
/// Used when native extract→mpv/Exo fails — same pages that work in Chrome.
class AnimeBrowserEmbed {
  const AnimeBrowserEmbed({
    required this.url,
    required this.label,
    required this.referer,
    required this.origin,
    this.loadInMainFrame = false,
  });

  final String url;
  final String label;
  final String referer;
  final String origin;

  /// Sites with `X-Frame-Options: SAMEORIGIN` (e.g. anikoto.cz) cannot sit in
  /// our iframe wrapper — navigate the WebView to [url] directly.
  final bool loadInMainFrame;
}

/// Resolve a top-level / iframe player URL from [embed], or null if none.
AnimeBrowserEmbed? animeBrowserEmbedFor(AnimeEmbed embed) {
  final server = embed.server.trim().toLowerCase();
  if (server == 'megaplay' || server == 'vidwish') {
    final url = embed.url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }
    // Megaplay/Vidwish `/stream/ani/` HTML is often a hard 410 shell while
    // getSources still works natively — do not open that dead page in WebView.
    if (url.contains('/stream/ani/')) return null;
    final origin = Uri.tryParse(url)?.origin ??
        (server == 'vidwish'
            ? 'https://vidwish.live'
            : 'https://${ProviderRuntimeConfig.instance.megaplay.host}');
    return AnimeBrowserEmbed(
      url: url,
      label: embed.displayName,
      referer: '$origin/',
      origin: origin,
    );
  }
  if (server == 'vidnest') {
    final m = RegExp(r'^vidnest://anilist/(\d+)/(\d+)/(sub|dub)/([a-z0-9]+)$')
        .firstMatch(embed.url.trim());
    if (m == null) return null;
    final anilistId = m.group(1)!;
    final episode = m.group(2)!;
    final lang = m.group(3)!;
    final prov = m.group(4)!;
    final base =
        ProviderRuntimeConfig.instance.api('vidnestEmbed') ?? 'https://vidnest.fun';
    final path = prov == 'animepahe' ? 'animepahe' : 'anime';
    final url = '$base/$path/$anilistId/$episode/$lang';
    return AnimeBrowserEmbed(
      url: url,
      label: embed.displayName,
      referer: '$base/',
      origin: base,
    );
  }
  return null;
}

/// Prefer VidNest public pages first (site JS decrypt + play), then Megaplay
/// `/stream/s-2/…`, Vidwish, then Anikoto.cz. Megaplay `/stream/ani/` omitted.
List<AnimeBrowserEmbed> animeBrowserEmbedFallbacks({
  required List<AnimeEmbed> embeds,
  required String category,
  String? anikotoSlug,
  int? episode,
}) {
  final cat = category.trim().toLowerCase();
  final ordered = <AnimeEmbed>[
    ...embeds.where((e) => e.server == 'vidnest' && e.category == cat),
    ...embeds.where((e) => e.server == 'megaplay' && e.category == cat),
    ...embeds.where((e) => e.server == 'vidwish' && e.category == cat),
  ];
  final out = <AnimeBrowserEmbed>[];
  final seen = <String>{};

  AnimeBrowserEmbed? anikotoPage;
  final slug = anikotoSlug?.trim() ?? '';
  final ep = episode ?? 0;
  if (slug.isNotEmpty && ep > 0) {
    anikotoPage = AnimeBrowserEmbed(
      url: 'https://anikoto.cz/watch/$slug/ep-$ep',
      label: 'AniKoto',
      referer: 'https://anikoto.cz/',
      origin: 'https://anikoto.cz',
      loadInMainFrame: true,
    );
  }

  void add(AnimeBrowserEmbed? b) {
    if (b == null || !seen.add(b.url)) return;
    out.add(b);
  }

  for (final e in ordered) {
    add(animeBrowserEmbedFor(e));
  }
  add(anikotoPage);
  return out;
}
