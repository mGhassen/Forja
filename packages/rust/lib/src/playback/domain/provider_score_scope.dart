/// Which title/episode/anime a provider reliability score belongs to.
enum ProviderScoreContentKind { movie, tv, anime }

/// Scoped key for [ProviderScoreMemory] — films, TV episodes, and anime only.
class ProviderScoreScope {
  const ProviderScoreScope._({
    required this.kind,
    required this.contentId,
    this.season,
    this.episode,
  });

  final ProviderScoreContentKind kind;
  final int contentId;
  final int? season;
  final int? episode;

  factory ProviderScoreScope.movie({required int tmdbId}) =>
      ProviderScoreScope._(
        kind: ProviderScoreContentKind.movie,
        contentId: tmdbId,
      );

  factory ProviderScoreScope.tv({
    required int tmdbId,
    required int season,
    required int episode,
  }) => ProviderScoreScope._(
    kind: ProviderScoreContentKind.tv,
    contentId: tmdbId,
    season: season,
    episode: episode,
  );

  factory ProviderScoreScope.anime({
    required int anilistId,
    required int episode,
  }) => ProviderScoreScope._(
    kind: ProviderScoreContentKind.anime,
    contentId: anilistId,
    episode: episode,
  );

  String memoryKey(String normalizedProviderId) {
    return switch (kind) {
      ProviderScoreContentKind.movie =>
        'movie:$contentId:$normalizedProviderId',
      ProviderScoreContentKind.tv =>
        'tv:$contentId:s${season ?? 1}e${episode ?? 1}:$normalizedProviderId',
      ProviderScoreContentKind.anime =>
        'anime:$contentId:e${episode ?? 1}:$normalizedProviderId',
    };
  }
}
