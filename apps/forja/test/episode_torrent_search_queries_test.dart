import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/player/resolvers/episode_torrent_resolver.dart';

void main() {
  group('metaOpenTorrentEp', () {
    test('reads open.torrentEp', () {
      final open = MetaOpen.fromJson({
        'surface': 'hub-x',
        'id': '1',
        'torrentEp': true,
      });
      expect(metaOpenTorrentEp(open), isTrue);
    });

    test('default is SxxExx search', () {
      final open = MetaOpen.fromJson({
        'surface': 'hub-x',
        'id': '1',
      });
      expect(metaOpenTorrentEp(open), isFalse);
      expect(metaOpenTorrentEp(null), isFalse);
    });

    test('surface alone does not enable torrentEp', () {
      final open = MetaOpen.fromJson({
        'surface': 'anime',
        'id': '99',
        'extract': {'resolveType': 'anime', 'panelCategory': 'anime'},
      });
      expect(metaOpenTorrentEp(open), isFalse);
    });
  });

  group('tvTorrentSearchPasses', () {
    test('default uses season then SxxExx', () {
      final passes = tvTorrentSearchPasses(
        title: 'The Bear',
        season: 2,
        episode: 3,
      );
      expect(passes.map((p) => p.query).toList(), [
        'The Bear S02',
        'The Bear S02E03',
      ]);
      expect(passes[0].episode, isNull);
      expect(passes[1].episode, 3);
    });

    test('torrentEp uses Title 05 queries', () {
      final passes = tvTorrentSearchPasses(
        title: 'Show Title',
        season: 1,
        episode: 5,
        torrentEp: true,
      );
      expect(passes.map((p) => p.query).toList(), [
        'Show Title 05',
        'Show Title - 05',
      ]);
      expect(passes.every((p) => p.season == 1 && p.episode == 5), isTrue);
    });
  });
}
