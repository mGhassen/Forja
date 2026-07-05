import 'package:forja_core/forja_core.dart';
import 'package:forja_rust/forja_rust.dart';

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
      displayName: 'Vidsrc',
      kind: ProviderKind.extractor,
    ),
    StreamProviderDef(
      id: 'vidnest',
      displayName: 'Vidnest',
      kind: ProviderKind.template,
      movieUrl: (id) =>
          ForjaEngine.buildMovieUrl('vidnest', id) ??
          'https://vidnest.fun/movie/$id',
      tvUrl: (id, s, e) =>
          ForjaEngine.buildTvUrl('vidnest', id, s, e) ??
          'https://vidnest.fun/tv/$id/$s/$e',
    ),
    StreamProviderDef(
      id: 'vidlink',
      displayName: 'VidLink',
      kind: ProviderKind.template,
      movieUrl: (id) =>
          ForjaEngine.buildMovieUrl('vidlink', id) ??
          'https://vidlink.pro/movie/$id',
      tvUrl: (id, s, e) =>
          ForjaEngine.buildTvUrl('vidlink', id, s, e) ??
          'https://vidlink.pro/tv/$id/$s/$e',
    ),
    StreamProviderDef(
      id: 'vixsrc',
      displayName: 'VixSrc',
      kind: ProviderKind.template,
      movieUrl: (id) =>
          ForjaEngine.buildMovieUrl('vixsrc', id) ??
          'https://vixsrc.to/movie/$id/',
      tvUrl: (id, s, e) =>
          ForjaEngine.buildTvUrl('vixsrc', id, s, e) ??
          'https://vixsrc.to/tv/$id/$s/$e/',
    ),
    StreamProviderDef(
      id: 'vidzee',
      displayName: 'Vidzee',
      kind: ProviderKind.template,
      movieUrl: (id) =>
          ForjaEngine.buildMovieUrl('vidzee', id) ??
          'https://vidzee.wtf/movie/$id',
      tvUrl: (id, s, e) =>
          ForjaEngine.buildTvUrl('vidzee', id, s, e) ??
          'https://vidzee.wtf/tv/$id/$s/$e',
    ),
    StreamProviderDef(
      id: 'vidrock',
      displayName: 'VidRock',
      kind: ProviderKind.template,
      movieUrl: (id) =>
          ForjaEngine.buildMovieUrl('vidrock', id) ??
          'https://vidrock.net/movie/$id',
      tvUrl: (id, s, e) =>
          ForjaEngine.buildTvUrl('vidrock', id, s, e) ??
          'https://vidrock.net/tv/$id/$s/$e',
    ),
    StreamProviderDef(
      id: 'service111477',
      displayName: '111477',
      kind: ProviderKind.api,
    ),
  ];

  static StreamProviderDef? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<StreamProviderDef> ordered(List<String> order, List<String> enabled) {
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
