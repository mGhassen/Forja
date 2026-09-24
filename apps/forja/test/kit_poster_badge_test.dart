import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja_foundation/protocol/protocol.dart';

MetaItem _item({String? badge, String type = 'movie'}) => MetaItem(
      id: 'tt1',
      type: type,
      name: 'Title',
      releaseInfo: '2024',
      badge: badge,
    );

void main() {
  test('kitPosterBadge omits FILM/TV media-type chips', () {
    expect(kitPosterBadge(_item(badge: 'FILM')), isNull);
    expect(kitPosterBadge(_item(badge: 'MOVIE')), isNull);
    expect(kitPosterBadge(_item(badge: 'HOLLYWOOD')), isNull);
    expect(kitPosterBadge(_item(badge: 'TV', type: 'tv')), isNull);
    expect(kitPosterBadge(_item(badge: 'SERIES', type: 'tv')), isNull);
  });

  test('kitPosterBadge keeps non-type labels', () {
    expect(kitPosterBadge(_item(badge: 'REMAKE')), 'REMAKE');
    expect(kitPosterBadge(_item(badge: 'NOW')), 'NOW');
  });

  test('kitPosterSubtitle still carries FILM under the title', () {
    expect(kitPosterSubtitle(_item(badge: 'FILM')), '2024 • FILM');
  });

  test('kitPosterSubtitle prefers drama kind over tmdbMediaType tv', () {
    final item = MetaItem(
      id: 'drama:1',
      type: 'drama',
      name: 'True Beauty',
      releaseInfo: '2020',
      tmdbMediaType: 'tv',
      open: const MetaOpen(surface: 'drama', id: '975'),
    );
    expect(kitPosterSubtitle(item), '2020 • DRAMA');
  });

  test('metaReleaseYear falls back to premiereDate', () {
    final item = MetaItem(
      id: 'drama:2',
      type: 'drama',
      name: 'Heard',
      premiereDate: '2013-06-05',
    );
    expect(metaReleaseYear(item), '2013');
    expect(kitPosterSubtitle(item), '2013 • DRAMA');
  });
}
