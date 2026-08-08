import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_catalog_recs.dart';
import 'package:rust/rust.dart';

Movie _movie({
  required int id,
  required String title,
  String releaseDate = '',
  String mediaType = 'movie',
}) {
  return Movie(
    id: id,
    title: title,
    posterPath: '',
    backdropPath: '',
    voteAverage: 0,
    releaseDate: releaseDate,
    mediaType: mediaType,
  );
}

IptvStream _stream({
  required String id,
  required String name,
  required String kind,
}) {
  return IptvStream(
    streamId: id,
    name: name,
    icon: '',
    categoryId: '1',
    containerExt: 'mp4',
    kind: kind,
  );
}

void main() {
  test('keeps only exact cleaned title matches in catalog', () {
    final hits = filterIptvCatalogRecommendations(
      recommendations: [
        _movie(id: 1, title: 'Dune', releaseDate: '2021-10-22'),
        _movie(id: 2, title: 'Not In Portal'),
      ],
      catalog: [
        _stream(id: 'a', name: 'EN-NETFLIX-Dune 2021 1080p', kind: 'vod'),
        _stream(id: 'b', name: 'Other Film', kind: 'vod'),
      ],
    );
    expect(hits, hasLength(1));
    expect(hits.single.tmdb.id, 1);
    expect(hits.single.stream.streamId, 'a');
  });

  test('rejects year mismatch when both sides have a year', () {
    final hits = filterIptvCatalogRecommendations(
      recommendations: [
        _movie(id: 1, title: 'Dune', releaseDate: '2021-10-22'),
      ],
      catalog: [
        _stream(id: 'a', name: 'Dune 2010', kind: 'vod'),
      ],
    );
    expect(hits, isEmpty);
  });

  test('maps tv recommendations to series rows', () {
    final hits = filterIptvCatalogRecommendations(
      recommendations: [
        _movie(
          id: 9,
          title: 'Breaking Bad',
          releaseDate: '2008-01-20',
          mediaType: 'tv',
        ),
      ],
      catalog: [
        _stream(id: 's1', name: 'FR-Breaking.Bad.2008', kind: 'series'),
      ],
    );
    expect(hits, hasLength(1));
    expect(hits.single.stream.kind, 'series');
  });

  test('excludes the current stream id', () {
    final hits = filterIptvCatalogRecommendations(
      recommendations: [
        _movie(id: 1, title: 'Dune', releaseDate: '2021-10-22'),
      ],
      catalog: [
        _stream(id: 'self', name: 'Dune 2021', kind: 'vod'),
      ],
      excludeStreamId: 'self',
    );
    expect(hits, isEmpty);
  });

  test('ignores live catalog rows', () {
    final hits = filterIptvCatalogRecommendations(
      recommendations: [
        _movie(id: 1, title: 'CNN'),
      ],
      catalog: [
        _stream(id: 'l1', name: 'CNN', kind: 'live'),
      ],
    );
    expect(hits, isEmpty);
  });
}
