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

/// Legacy built-in embed registry — retired; playback uses `engine:*` plugins.
class ProviderRegistry {
  static const List<StreamProviderDef> all = [];

  static Map<String, dynamic> get catalog => const {};

  static StreamProviderDef? byId(String id) => null;

  static List<StreamProviderDef> ordered(
    List<String> order,
    List<String> enabled,
  ) =>
      const [];
}
