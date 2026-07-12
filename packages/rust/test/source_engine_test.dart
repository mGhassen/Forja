import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('SourceEngine', () {
    test('auto excludes cross-domain providers', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['videasy', 'miruro:bee', 'kisskh', 'vidlink'],
      );
      expect(ordered, contains('miruro:bee'));
      expect(ordered, contains('kisskh')); // low anime score but supported
      expect(ordered, isNot(contains('videasy')));
      expect(ordered, isNot(contains('vidlink')));
      expect(ordered.first, 'miruro:bee');
    });

    test('movies prefer videasy over webstreamr by profile', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['webstreamr', 'videasy', 'vidnest'],
      );
      expect(ordered.first, 'videasy');
      expect(ordered.last, 'webstreamr');
    });

    test('series prefers vidlink over videasy by profile', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.series,
        candidateIds: ['videasy', 'vidlink'],
      );
      expect(ordered.first, 'vidlink');
    });

    test('settings order is tiebreak only', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['vidsrc', 'vixsrc'],
        settingsOrder: ['vidsrc', 'vixsrc'],
      );
      // vixsrc 75 > vidsrc 70
      expect(ordered.first, 'vixsrc');
    });

    test('preferred pin is strict', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['videasy', 'vidlink', 'webstreamr'],
        preferred: 'webstreamr',
      );
      expect(ordered, ['webstreamr']);
    });

    test('preferred pin rejects unsupported domain', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['videasy', 'miruro:bee'],
        preferred: 'videasy',
      );
      expect(ordered, isEmpty);
    });

    test('nuvio-like unknown ids allowed when in candidate set', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['nuvio:foo', 'videasy'],
      );
      expect(ordered, contains('nuvio:foo'));
      expect(ordered.first, 'videasy');
    });

    test('unknown anime mirrors stay after profiled keys', () {
      final ordered = SourceEngine.orderProviderIds(
        domain: SourceDomain.anime,
        candidateIds: ['miruro:hop', 'miruro:bee'],
      );
      expect(ordered.first, 'miruro:bee');
      expect(ordered, contains('miruro:hop'));
    });

    test('nextProviderIds skips current and follows domain order', () {
      final next = SourceEngine.nextProviderIds(
        domain: SourceDomain.movies,
        candidateIds: ['webstreamr', 'videasy', 'vidnest'],
        currentId: 'videasy',
      );
      expect(next.first, 'vidnest');
      expect(next, isNot(contains('videasy')));
    });
  });
}
