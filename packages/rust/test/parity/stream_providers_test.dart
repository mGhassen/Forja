import 'dart:convert';

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
      movie: 'https://2embed.stream/embed/movie/$tmdbId',
      tv: 'https://2embed.stream/embed/tv/$tvId/$season/$episode',
    ),
    'autoembed': (
      movie: 'https://player.autoembed.co/embed/movie/$tmdbId',
      tv: 'https://player.autoembed.co/embed/tv/$tvId/$season-$episode/',
    ),
    'vidlove': (
      movie: 'https://player.vidlove.cc/embed/movie/$tmdbId',
      tv: 'https://player.vidlove.cc/embed/tv/$tvId/$season/$episode',
    ),
    'vidsrcsbs': (
      movie: 'https://vidsrc.sbs/embed/movie/$tmdbId',
      tv: 'https://vidsrc.sbs/embed/tv/$tvId/$season/$episode',
    ),
    'vidsrcwin': (
      movie: 'https://video.moviepire.co/embed/movie/$tmdbId',
      tv: 'https://video.moviepire.co/embed/tv/$tvId/$season/$episode',
    ),
    '111movies': (
      movie: 'https://player.vidlove.cc/embed/movie/$tmdbId',
      tv: 'https://player.vidlove.cc/embed/tv/$tvId/$season/$episode',
    ),
    'moviesapi': (
      movie: 'https://moviesapi.to/movie/$tmdbId',
      tv: 'https://moviesapi.to/tv/$tvId-$season-$episode',
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

  test('listProvidersJson distinguishes VSEmbed from VidSrc', () {
    final rows =
        (jsonDecode(RustLib.instance.listProvidersJson()) as List)
            .cast<Map<String, dynamic>>();
    final names = {for (final row in rows) row['id']: row['name']};
    expect(names['vidsrc'], 'VSEmbed');
    expect(names['vidsrcwin'], 'VidSrc');
  });

  test('listProvidersJson excludes retired SmashyStream', () {
    final json = RustLib.instance.listProvidersJson();
    expect(json, isNot(contains('smashystream')));
  });

  test('listProvidersJson excludes retired PrimeWire', () {
    final json = RustLib.instance.listProvidersJson();
    expect(json, isNot(contains('primewire')));
  });
}
