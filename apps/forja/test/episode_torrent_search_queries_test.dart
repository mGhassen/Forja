import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/player/resolvers/episode_torrent_resolver.dart';
import 'package:rust/rust.dart';

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
      final open = MetaOpen.fromJson({'surface': 'hub-x', 'id': '1'});
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

  group('torrentSearchBaseTitle', () {
    test('strips ordinal season and part fluff', () {
      expect(
        torrentSearchBaseTitle(
          'Tensei Shitara Slime Datta Ken 4th Season Part 1 & 2',
        ),
        'Tensei Shitara Slime Datta Ken',
      );
    });

    test('strips Season N', () {
      expect(torrentSearchBaseTitle('Show Title Season 2'), 'Show Title');
    });

    test('leaves plain titles alone', () {
      expect(torrentSearchBaseTitle('One Piece'), 'One Piece');
    });
  });

  group('torrentSearchSeason', () {
    test('chip Season N wins over media-local season', () {
      expect(
        torrentSearchSeason(
          season: 1,
          seasonLabel: 'Season 4',
          title: 'Anything',
        ),
        4,
      );
    });

    test('parses 4th Season from title', () {
      expect(
        torrentSearchSeason(
          season: 1,
          title: 'Tensei Shitara Slime Datta Ken 4th Season Part 1 & 2',
        ),
        4,
      );
    });

    test('falls back to host season', () {
      expect(torrentSearchSeason(season: 2, title: 'Plain Show'), 2);
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

    test('torrentEp uses short base + SxxExx then absolute ep', () {
      final passes = tvTorrentSearchPasses(
        title: 'Tensei Shitara Slime Datta Ken 4th Season Part 1 & 2',
        season: 1,
        episode: 1,
        torrentEp: true,
        seasonLabel: 'Season 4',
      );
      expect(passes.map((p) => p.query).toList(), [
        'Tensei Shitara Slime Datta Ken S04E01',
        'Tensei Shitara Slime Datta Ken 01',
        'Tensei Shitara Slime Datta Ken - 01',
      ]);
      expect(passes.every((p) => p.season == 4 && p.episode == 1), isTrue);
    });

    test('torrentEp without chip still parses title season', () {
      final passes = tvTorrentSearchPasses(
        title: 'Show Title',
        season: 1,
        episode: 5,
        torrentEp: true,
      );
      expect(passes.map((p) => p.query).toList(), [
        'Show Title S01E05',
        'Show Title 05',
        'Show Title - 05',
      ]);
    });
  });

  group('filterTorrentsForEpisode', () {
    TorrentResult row(String name) => TorrentResult(
      name: name,
      magnet: 'magnet:?xt=urn:btih:${name.hashCode.abs()}',
      seeders: '1',
      size: '1 GiB',
      source: 'test',
    );

    test('keeps matching SxxExx and ranges; drops wrong season', () {
      final kept = filterTorrentsForEpisode(
        [
          row('[A] Show S04E01 1080p'),
          row('[B] Show S04E01-E24 batch'),
          row('[C] Show S03E01 1080p'),
          row('[D] Show - 01 [1080p]'),
        ],
        season: 4,
        episode: 1,
      );
      expect(kept.map((r) => r.name).toList(), [
        '[A] Show S04E01 1080p',
        '[B] Show S04E01-E24 batch',
        '[D] Show - 01 [1080p]',
      ]);
    });
  });
}
