import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  const tmdbId = 550;
  const tvId = 1399;
  const season = 2;
  const episode = 5;

  final providers = <String, ({String movie, String tv})>{
    'vidlink': (
      movie: 'https://vidlink.pro/movie/$tmdbId',
      tv: 'https://vidlink.pro/tv/$tvId/$season/$episode',
    ),
    'vixsrc': (
      movie: 'https://vixsrc.to/movie/$tmdbId/',
      tv: 'https://vixsrc.to/tv/$tvId/$season/$episode/',
    ),
    'vidnest': (
      movie: 'https://vidnest.fun/movie/$tmdbId',
      tv: 'https://vidnest.fun/tv/$tvId/$season/$episode',
    ),
    'vidzee': (
      movie: 'https://vidzee.wtf/movie/$tmdbId',
      tv: 'https://vidzee.wtf/tv/$tvId/$season/$episode',
    ),
    'vidrock': (
      movie: 'https://vidrock.net/movie/$tmdbId',
      tv: 'https://vidrock.net/tv/$tvId/$season/$episode',
    ),
  };

  for (final entry in providers.entries) {
    test('${entry.key} movie URL', () {
      expect(
        RustLib.instance.buildMovieUrl(entry.key, tmdbId),
        entry.value.movie,
      );
    });

    test('${entry.key} tv URL', () {
      expect(
        RustLib.instance.buildTvUrl(entry.key, tvId, season, episode),
        entry.value.tv,
      );
    });
  }

  test('unknown provider returns empty string', () {
    expect(RustLib.instance.buildMovieUrl('unknown', 1), '');
  });

  test('listProvidersJson includes vidlink', () {
    final json = RustLib.instance.listProvidersJson();
    expect(json, contains('vidlink'));
  });
}
