import 'package:flutter/foundation.dart';

/// One provider result section (TMDB or Stremio addon).
class HostSearchSection {
  const HostSearchSection({
    required this.key,
    required this.title,
    this.icon,
    this.isTmdb = false,
    this.results = const [],
  });

  final String key;
  final String title;
  final String? icon;
  final bool isTmdb;
  final List<dynamic> results;
}

@immutable
class HostSearchState {
  const HostSearchState({
    required this.query,
    this.sections = const [],
    this.tmdbDone = false,
    this.addonsDone = false,
    this.tmdbPage = 0,
    this.canLoadMore = false,
  });

  static const empty = HostSearchState(query: '');

  /// Cap for scroll-loaded TMDB pages (not infinite).
  static const maxTmdbPages = 5;

  final String query;
  final List<HostSearchSection> sections;
  final bool tmdbDone;
  final bool addonsDone;

  /// Last TMDB page fetched for [query] (0 = none yet).
  final int tmdbPage;

  /// True when another TMDB page (≤ [maxTmdbPages]) can be requested on scroll.
  final bool canLoadMore;

  bool get isSearching =>
      query.isNotEmpty && (!tmdbDone || !addonsDone);

  bool get done => tmdbDone && addonsDone;

  HostSearchState copyWith({
    String? query,
    List<HostSearchSection>? sections,
    bool? tmdbDone,
    bool? addonsDone,
    int? tmdbPage,
    bool? canLoadMore,
  }) {
    return HostSearchState(
      query: query ?? this.query,
      sections: sections ?? this.sections,
      tmdbDone: tmdbDone ?? this.tmdbDone,
      addonsDone: addonsDone ?? this.addonsDone,
      tmdbPage: tmdbPage ?? this.tmdbPage,
      canLoadMore: canLoadMore ?? this.canLoadMore,
    );
  }
}
