import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('Max chip unions HBO / HBO Max watch ids and networks', () {
    final family = WatchProviderFamily.of(WatchProviderFamily.max);
    expect(family.watchIds, containsAll([1899, 384, 118]));
    expect(family.tvNetworkIds, containsAll([49, 6783, 8304]));
    expect(family.watchIds, isNot(contains(1825)));
  });

  test('legacy HBO Max id still resolves the Max family', () {
    expect(
      WatchProviderFamily.watchIdsFor(384),
      WatchProviderFamily.watchIdsFor(1899),
    );
    expect(
      WatchProviderFamily.tvNetworkIdsFor(49),
      containsAll([49, 6783, 8304]),
    );
  });

  test('Prime and Paramount include regional / rebrand watch ids', () {
    expect(WatchProviderFamily.watchIdsFor(9), containsAll([9, 119]));
    expect(WatchProviderFamily.watchIdsFor(2303), containsAll([2303, 531]));
  });

  test('Netflix / Disney / Peacock include same-service SKUs', () {
    expect(WatchProviderFamily.watchIdsFor(8), containsAll([8, 1796]));
    expect(WatchProviderFamily.watchIdsFor(337), containsAll([337, 122]));
    expect(WatchProviderFamily.watchIdsFor(386), containsAll([386, 387]));
  });

  test('Apple TV+ does not include the Apple TV store', () {
    expect(WatchProviderFamily.watchIdsFor(350), [350]);
    expect(WatchProviderFamily.watchIdsFor(350), isNot(contains(2)));
  });

  test('unknown id stays a singleton', () {
    expect(WatchProviderFamily.watchIdsFor(99999), [99999]);
    expect(WatchProviderFamily.tvNetworkIdsFor(99999), isEmpty);
  });

  test('orQuery encodes TMDB pipe OR', () {
    expect(WatchProviderFamily.orQuery([1899, 384]), '1899%7C384');
  });
}
