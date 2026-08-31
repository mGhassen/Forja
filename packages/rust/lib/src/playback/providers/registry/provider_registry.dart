import 'package:rust/rust.dart';

enum ProviderKind { template, extractor, api }

class ResolveContext {
  const ResolveContext({
    required this.tmdbId,
    required this.isMovie,
    this.season,
    this.episode,
    this.imdbId,
  });

  final String tmdbId;
  final bool isMovie;
  final int? season;
  final int? episode;
  final String? imdbId;
}

class ResolvedStream {
  const ResolvedStream({
    required this.providerId,
    required this.url,
    this.headers = const {},
    this.sources,
    this.externalSubtitles,
  });

  final String providerId;
  final String url;
  final Map<String, String> headers;
  final List<StreamSource>? sources;
  final List<Map<String, dynamic>>? externalSubtitles;
}

class StreamProviderDef {
  const StreamProviderDef({
    required this.id,
    required this.displayName,
    required this.kind,
    this.enabledByDefault = true,
    this.movieUrl,
    this.tvUrl,
  });

  final String id;
  final String displayName;
  final ProviderKind kind;
  final bool enabledByDefault;
  final String Function(String tmdbId)? movieUrl;
  final String Function(String tmdbId, int s, int e)? tvUrl;
}

class ProviderRegistry {
  static final List<StreamProviderDef> all = [
    StreamProviderDef(
      id: 'videasy',
      displayName: 'Videasy',
      kind: ProviderKind.extractor,
    ),
    StreamProviderDef(
      id: 'vidsrc',
      displayName: 'VSEmbed',
      kind: ProviderKind.extractor,
    ),
    StreamProviderDef(
      id: 'vidsrcwin',
      displayName: 'VidSrc',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidsrcwin', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidsrcwin', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidnest',
      displayName: 'Vidnest',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidnest', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidnest', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidlink',
      displayName: 'VidLink',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidlink', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidlink', id, s, e),
    ),
    StreamProviderDef(
      id: 'vixsrc',
      displayName: 'VixSrc',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vixsrc', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vixsrc', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidzee',
      displayName: 'Vidzee',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidzee', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidzee', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidrock',
      displayName: 'VidRock',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidrock', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidrock', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidfast',
      displayName: 'VidFast',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidfast', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidfast', id, s, e),
    ),
    StreamProviderDef(
      id: '2embed',
      displayName: '2Embed',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('2embed', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('2embed', id, s, e),
    ),
    StreamProviderDef(
      id: 'autoembed',
      displayName: 'AutoEmbed',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('autoembed', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('autoembed', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidlove',
      displayName: 'VidLove',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidlove', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidlove', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidsrcsbs',
      displayName: 'VidSrc.sbs',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidsrcsbs', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidsrcsbs', id, s, e),
    ),
    StreamProviderDef(
      id: '111movies',
      displayName: '111Movies',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('111movies', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('111movies', id, s, e),
    ),
    StreamProviderDef(
      id: 'moviesapi',
      displayName: 'MoviesAPI',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('moviesapi', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('moviesapi', id, s, e),
    ),
    StreamProviderDef(
      id: 'vidapi',
      displayName: 'VidAPI',
      kind: ProviderKind.template,
      movieUrl: (id) => Engine.requireMovieUrl('vidapi', id),
      tvUrl: (id, s, e) => Engine.requireTvUrl('vidapi', id, s, e),
    ),
    StreamProviderDef(
      id: 'service111477',
      displayName: '111477',
      kind: ProviderKind.api,
    ),
  ];

  /// Legacy map shape used by player/settings UI (`name`, `movie`, `tv`).
  static Map<String, dynamic> get catalog => {
    for (final p in all)
      p.id: {'name': p.displayName, 'movie': p.movieUrl, 'tv': p.tvUrl},
  };

  static StreamProviderDef? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<StreamProviderDef> ordered(
    List<String> order,
    List<String> enabled,
  ) {
    final map = {for (final p in all) p.id: p};
    final out = <StreamProviderDef>[];
    for (final id in order) {
      final p = map[id];
      if (p != null && enabled.contains(id)) out.add(p);
    }
    for (final p in all) {
      if (enabled.contains(p.id) && !out.any((x) => x.id == p.id)) {
        out.add(p);
      }
    }
    return out;
  }
}
