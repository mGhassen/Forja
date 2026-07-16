import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';

void main() {
  test('episode URL uses the selected KissKh mirror', () {
    final url = KissKhService.episodePageUrl(
      baseUrl: 'https://kisskh.nl',
      dramaId: 10633,
      title: 'Blossoms of Power',
      episodeId: 217295,
      episodeNumber: 1,
    );

    expect(url, startsWith('https://kisskh.nl/Drama/'));
    expect(url, contains('id=10633'));
    expect(url, contains('ep=217295'));
  });

  test('playback headers preserve the selected KissKh mirror', () {
    final headers = KissKhExtractor.playbackHeaders('https://kisskh.ovh');

    expect(headers['Referer'], 'https://kisskh.ovh/');
    expect(headers['Origin'], 'https://kisskh.ovh');
  });

  test('settings catalog lists verified KissKH mirrors', () {
    expect(KissKhService.mirrorHosts, containsAll(['kisskh.co', 'kisskh.nl']));
    expect(KissKhService.settingsCatalog.keys, KissKhService.mirrorHosts);
    expect(KissKhService.normalizeMirrorId('kisskh'), 'kisskh.co');
    expect(KissKhService.isMirrorHost('kisskh.ovh'), isTrue);
    expect(KissKhService.isMirrorHost('kisskh.buzz'), isFalse);
  });

  test('mirror health model tracks healthy hosts', () {
    const health = KissKhMirrorHealth(
      selected: 'kisskh.nl',
      healthyHosts: ['kisskh.nl', 'kisskh.ovh'],
      unhealthyHosts: ['kisskh.co'],
    );
    expect(health.isHealthy('kisskh.nl'), isTrue);
    expect(health.isHealthy('https://kisskh.co'), isFalse);
  });

  test('probeMirrors deadline marks hung hosts DOWN and keeps order', () async {
    final health = await KissKhService.probeMirrors(
      hosts: const ['kisskh.co', 'kisskh.nl', 'kisskh.ovh'],
      deadline: const Duration(milliseconds: 40),
      probe: (host) async {
        if (host == 'kisskh.nl') {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return true;
        }
        if (host == 'kisskh.ovh') {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return true;
        }
        // Preferred host never answers — old Future.wait would hang forever.
        await Completer<void>().future;
        return true;
      },
    );

    expect(health.healthyHosts, ['kisskh.nl', 'kisskh.ovh']);
    expect(health.unhealthyHosts, ['kisskh.co']);
    expect(health.selected, 'kisskh.nl');
  });
}
