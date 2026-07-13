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
      movie: 'https://player.vidzee.wtf/embed/movie/$tmdbId',
      tv: 'https://player.vidzee.wtf/embed/tv/$tvId/$season/$episode',
    ),
    'vidrock': (
      movie: 'https://vidrock.ru/movie/$tmdbId',
      tv: 'https://vidrock.ru/tv/$tvId/$season/$episode',
    ),
    'vidfast': (
      movie: 'https://vidfast.vc/movie/$tmdbId?autoPlay=true',
      tv: 'https://vidfast.vc/tv/$tvId/$season/$episode?autoPlay=true',
    ),
    '2embed': (
      movie: 'https://www.2embed.cc/embed/$tmdbId',
      tv: 'https://www.2embed.cc/embedtv/$tvId&s=$season&e=$episode',
    ),
    'superembed': (
      movie: 'https://multiembed.mov/?video_id=$tmdbId&tmdb=1',
      tv: 'https://multiembed.mov/?video_id=$tvId&tmdb=1&s=$season&e=$episode',
    ),
    'autoembed': (
      movie: 'https://autoembed.co/movie/tmdb/$tmdbId',
      tv: 'https://autoembed.co/tv/tmdb/$tvId-$season-$episode',
    ),
    '111movies': (
      movie: 'https://player.vidlove.cc/embed/movie/$tmdbId',
      tv: 'https://player.vidlove.cc/embed/tv/$tvId/$season/$episode',
    ),
    'moviesapi': (
      movie: 'https://moviesapi.to/movie/$tmdbId',
      tv: 'https://moviesapi.to/tv/$tvId-$season-$episode',
    ),
    'smashystream': (
      movie: 'https://anyembed.xyz/embed/tmdb-movie-$tmdbId',
      tv: 'https://anyembed.xyz/embed/tmdb-tv-$tvId-$season-$episode',
    ),
    'primewire': (
      movie: 'https://www.primewire.tf/embed/movie?tmdb=$tmdbId',
      tv:
          'https://www.primewire.tf/embed/tv?tmdb=$tvId&season=$season&episode=$episode',
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
