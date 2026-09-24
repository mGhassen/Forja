import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/runtime/open/host_engine_request.dart';

void main() {
  group('HostEngineRequest stremio', () {
    test('unknown action returns ok false', () async {
      final r = await HostEngineRequest.run(
        kind: 'stremio',
        body: {'action': 'nope'},
      );
      expect(r['ok'], isFalse);
      expect(r['error'], 'unknown_action');
    });

    test('catalog without baseUrl/type/id fails', () async {
      final r = await HostEngineRequest.run(
        kind: 'stremio',
        body: {'action': 'catalog'},
      );
      expect(r['ok'], isFalse);
      expect(r['error'], 'missing_params');
    });

    test('search empty query returns empty items', () async {
      final r = await HostEngineRequest.run(
        kind: 'stremio',
        body: {'action': 'search', 'query': '   '},
      );
      expect(r['ok'], isTrue);
      expect(r['items'], isEmpty);
    });

    test('list returns ok with catalogs list', () async {
      final r = await HostEngineRequest.run(
        kind: 'stremio',
        body: {'action': 'list'},
      );
      expect(r['ok'], isTrue);
      expect(r['catalogs'], isA<List>());
    });
  });

  group('needsStremioCatalogHost', () {
    test('stremio type kit plugin needs host bridge', () {
      final p = EnginePlugin.fromJson({
        'id': 'test-stremio-hub',
        'name': 'Test',
        'entry': 'x.js',
        'kind': 'catalog',
        'types': ['stremio'],
        'capabilities': ['nav', 'layout', 'rail', 'search'],
      });
      expect(p.needsStremioCatalogHost, isTrue);
      expect(p.needsHostBridge, isTrue);
    });

    test('movie hub does not need stremio catalog host', () {
      final p = EnginePlugin.fromJson({
        'id': 'test-movie-hub',
        'name': 'Test',
        'entry': 'x.js',
        'kind': 'catalog',
        'types': ['movie', 'tv'],
        'capabilities': ['nav', 'layout', 'rail'],
      });
      expect(p.needsStremioCatalogHost, isFalse);
    });
  });
}
