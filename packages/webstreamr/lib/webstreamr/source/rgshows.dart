/// Port of webstreamr/src/source/RgShows.ts
library;

import '../types.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

class RgShowsSource extends Source {
  RgShowsSource(super.fetcher);

  @override
  String get id => 'rgshows';
  @override
  String get label => 'RgShows';
  @override
  int? get useOnlyWithMaxUrlsFound => 1;
  @override
  List<String> get contentTypes => const ['movie', 'series'];
  @override
  List<CountryCode> get countryCodes => const [CountryCode.multi];
  @override
  String get baseUrl => 'https://rgshows.ru';
  @override
  int get priority => -1;

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final ny = await getTmdbNameAndYear(ctx, fetcher, tmdbId);
    final name = ny[0] as String;
    final year = ny[1] as int;

    return requireRustResolveSource(
      'rgshows',
      type,
      tmdbId,
      title: name,
      year: year,
    );
  }
}
