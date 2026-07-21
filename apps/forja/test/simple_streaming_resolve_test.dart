import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/simple_streaming_resolve.dart';
import 'package:rust/rust.dart';

void main() {
  final movie = Movie(
    id: 94997,
    title: 'House of the Dragon',
    posterPath: '',
    backdropPath: '',
    voteAverage: 0,
    releaseDate: '2022-08-21',
    mediaType: 'tv',
  );

  StreamSource src(String title, {String url = 'https://cdn.example/a.m3u8'}) =>
      StreamSource(url: url, title: title, type: 'hls');

  test('keeps matching S/E and unlabeled titles', () {
    final out = SimpleStreamingResolve.filterSources(
      [
        src('VSEmbed'),
        src('House.of.the.Dragon.S01E01.720p'),
        src('1x01 HotD'),
      ],
      movie: movie,
      season: 1,
      episode: 1,
    );
    expect(out.map((s) => s.title), [
      'VSEmbed',
      'House.of.the.Dragon.S01E01.720p',
      '1x01 HotD',
    ]);
  });

  test('drops wrong episode, season packs, zip', () {
    final out = SimpleStreamingResolve.filterSources(
      [
        src('House.of.the.Dragon.S01E06.1080p'),
        src('House.Of.The.Dragon.S01.1080p.zip', url: 'https://x/a.zip'),
        src('House.Of.The.Dragon.S01.1080p.WEB'),
        src('ok', url: 'magnet:foo'),
      ],
      movie: movie,
      season: 1,
      episode: 1,
    );
    expect(out, isEmpty);
  });

  test('preferFastProviders puts natives before embeds', () {
    final ordered = SimpleStreamingResolve.preferFastProviders(const [
      'vidlink',
      'videasy',
      'vixsrc',
      'vidsrc',
      'webstreamr',
    ]);
    expect(ordered, [
      'vidsrc',
      'webstreamr',
      'videasy',
      'vidlink',
      'vixsrc',
    ]);
  });

  test('timeoutFor gives WebStreamr and embeds enough budget', () {
    expect(SimpleStreamingResolve.timeoutFor('vidsrc').inSeconds, 25);
    expect(SimpleStreamingResolve.timeoutFor('webstreamr').inSeconds, 90);
    expect(SimpleStreamingResolve.timeoutFor('videasy').inSeconds, 35);
    expect(SimpleStreamingResolve.timeoutFor('vidlink').inSeconds, 75);
    expect(SimpleStreamingResolve.timeoutFor('vidsrcsbs').inSeconds, 75);
  });
}
