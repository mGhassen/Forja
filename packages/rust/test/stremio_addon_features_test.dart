import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('sport-only manifest defaults to live', () {
    expect(
      StremioAddonFeatures.inferFromManifest({
        'types': ['sport'],
        'catalogs': [
          {'type': 'sport', 'id': 'sports_live'},
        ],
      }),
      [StremioAddonFeatures.live],
    );
  });

  test('movie manifest defaults to vod', () {
    expect(
      StremioAddonFeatures.inferFromManifest({
        'types': ['movie', 'series'],
      }),
      [StremioAddonFeatures.vod],
    );
  });

  test('toggle keeps at least one feature', () {
    expect(
      StremioAddonFeatures.toggle([StremioAddonFeatures.live], StremioAddonFeatures.live),
      [StremioAddonFeatures.live],
    );
    expect(
      StremioAddonFeatures.toggle(
        [StremioAddonFeatures.vod, StremioAddonFeatures.live],
        StremioAddonFeatures.vod,
      ),
      [StremioAddonFeatures.live],
    );
  });

  test('normalize infers when features missing', () {
    expect(
      StremioAddonFeatures.normalize(null, manifest: {'types': ['sport']}),
      [StremioAddonFeatures.live],
    );
  });
}
