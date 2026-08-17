/// Same-brand TMDB ids for a Home service chip.
///
/// JustWatch splits rebrands / regions / SKUs (Max vs HBO Max, Prime 9 vs 119).
/// New originals are often tagged as a TV *network* before watch-providers exist.
class WatchProviderFamily {
  const WatchProviderFamily({
    required this.watchIds,
    this.tvNetworkIds = const [],
  });

  /// JustWatch `with_watch_providers` — OR together. No Amazon/Apple channels.
  final List<int> watchIds;

  /// TMDB TV `with_networks` — OR in a *separate* discover (AND would miss
  /// shows that are not watch-provider-tagged yet).
  final List<int> tvNetworkIds;

  static const int netflix = 8;
  static const int disneyPlus = 337;
  static const int primeVideo = 9;
  static const int appleTvPlus = 350;
  static const int max = 1899;
  static const int hulu = 15;
  static const int paramountPlus = 2303;
  static const int peacock = 386;
  static const int crunchyroll = 283;
  static const int tubi = 73;

  static const Map<int, WatchProviderFamily> _byChip = {
    netflix: WatchProviderFamily(
      watchIds: [8, 1796, 175],
      tvNetworkIds: [213],
    ),
    disneyPlus: WatchProviderFamily(
      watchIds: [337, 122, 619],
      tvNetworkIds: [2739],
    ),
    primeVideo: WatchProviderFamily(
      watchIds: [9, 119],
      tvNetworkIds: [1024],
    ),
    appleTvPlus: WatchProviderFamily(
      watchIds: [350],
      tvNetworkIds: [2552],
    ),
    max: WatchProviderFamily(
      watchIds: [1899, 384, 118, 27, 425, 616, 483],
      tvNetworkIds: [49, 6783, 8304],
    ),
    hulu: WatchProviderFamily(
      watchIds: [15],
      tvNetworkIds: [453],
    ),
    paramountPlus: WatchProviderFamily(
      watchIds: [2303, 531, 1770],
      tvNetworkIds: [4330],
    ),
    peacock: WatchProviderFamily(
      watchIds: [386, 387],
      tvNetworkIds: [3353],
    ),
    crunchyroll: WatchProviderFamily(
      watchIds: [283],
      tvNetworkIds: [1112],
    ),
    tubi: WatchProviderFamily(
      watchIds: [73],
    ),
  };

  static WatchProviderFamily of(int id) {
    final direct = _byChip[id];
    if (direct != null) return direct;
    for (final family in _byChip.values) {
      if (family.watchIds.contains(id) || family.tvNetworkIds.contains(id)) {
        return family;
      }
    }
    return WatchProviderFamily(watchIds: [id]);
  }

  static List<int> watchIdsFor(int id) => of(id).watchIds;

  static List<int> tvNetworkIdsFor(int id) => of(id).tvNetworkIds;

  /// TMDB OR list (`|` must be `%7C`).
  static String orQuery(Iterable<int> ids) =>
      ids.where((id) => id > 0).toSet().join('%7C');
}
