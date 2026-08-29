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

  test('live-named tv catalogs default to live only', () {
    expect(
      StremioAddonFeatures.catalogLooksLive({
        'type': 'tv',
        'id': 'essential-live-events',
        'name': 'Essential Live Events',
      }),
      isTrue,
    );
    expect(
      StremioAddonFeatures.inferFromManifest({
        'types': ['tv'],
        'catalogs': [
          {'type': 'tv', 'id': 'essential-live-events', 'name': 'Live'},
          {'type': 'tv', 'id': 'dlstreams-live', 'name': 'DL Streams Live'},
        ],
      }),
      [StremioAddonFeatures.live],
    );
  });

  test('movie plus live-named tv → vod + live', () {
    expect(
      StremioAddonFeatures.inferFromManifest({
        'types': ['movie', 'tv'],
        'catalogs': [
          {'type': 'movie', 'id': 'top', 'name': 'Top'},
          {'type': 'tv', 'id': 'sports_live', 'name': 'Sports Live'},
        ],
      }),
      [StremioAddonFeatures.vod, StremioAddonFeatures.live],
    );
  });

  test('isEnabled defaults true; false only when explicitly disabled', () {
    expect(StremioAddonFeatures.isEnabled({}), isTrue);
    expect(StremioAddonFeatures.isEnabled({'enabled': true}), isTrue);
    expect(StremioAddonFeatures.isEnabled({'enabled': false}), isFalse);
    expect(StremioAddonFeatures.normalizeEnabled(null), isTrue);
    expect(StremioAddonFeatures.normalizeEnabled(false), isFalse);
  });
}
