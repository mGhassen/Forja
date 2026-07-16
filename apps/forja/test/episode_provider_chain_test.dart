import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';

void main() {
  group('episodeProviderChain', () {
    test('torrent session ignores webstreaming providers map', () {
      expect(
        episodeProviderChain(
          providers: {'videasy': {}, 'vidsrc': {}},
          activeProvider: 'torrent',
          magnetLink: 'magnet:?xt=urn:btih:abc',
        ),
        ['torrent'],
      );
    });

    test('stremio_direct session ignores webstreaming providers map', () {
      expect(
        episodeProviderChain(
          providers: {'videasy': {}},
          activeProvider: 'stremio_direct',
          currentProvider: 'stremio_direct',
        ),
        ['stremio_direct'],
      );
    });

    test('webstreaming rotates from current provider', () {
      expect(
        episodeProviderChain(
          providers: {'a': {}, 'b': {}, 'c': {}},
          activeProvider: 'b',
          currentProvider: 'b',
        ),
        ['b', 'c', 'a'],
      );
    });
  });
}
