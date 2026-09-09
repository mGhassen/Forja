import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:rust/rust.dart';

void main() {
  group('StreamDrmConfig + mapEngineStream', () {
    test('parses widevine drm from synthetic extract row', () {
      final drm = StreamDrmConfig.tryParse({
        'scheme': 'widevine',
        'licenseUrl': 'https://lic.example/wv',
        'licenseHeaders': {'User-Agent': 'ForjaTest'},
      });
      expect(drm, isNotNull);
      expect(drm!.isWidevine, isTrue);
      expect(drm.licenseUrl, 'https://lic.example/wv');
      expect(drm.licenseHeaders['User-Agent'], 'ForjaTest');
    });

    test('mapEngineStream passes drm through', () {
      final plugin = EnginePlugin.fromJson({
        'id': 'test-provider-drm',
        'name': 'DRM Test',
        'entry': 'a.js',
        'kind': 'http',
        'types': ['movie'],
      });
      final mapped = mapEngineStream(
        raw: {
          'url': 'https://cdn.example/Manifest',
          'title': 'Ep 1',
          'drm': {
            'scheme': 'widevine',
            'licenseUrl': 'https://lic.example/wv',
            'licenseHeaders': {'origin': 'https://example.com'},
          },
        },
        plugin: plugin,
        mediaTitle: 'Show',
      );
      expect(mapped, isNotNull);
      expect(mapped!['drm'], isA<Map>());
      final drm = StreamDrmConfig.tryParse(mapped['drm']);
      expect(drm?.licenseUrl, 'https://lic.example/wv');
      final src = StreamSource.fromJson(mapped);
      expect(src.hasDrm, isTrue);
      expect(src.drm?.scheme, 'widevine');
    });

    test('tryParse rejects empty licenseUrl', () {
      expect(StreamDrmConfig.tryParse({'scheme': 'widevine'}), isNull);
      expect(StreamDrmConfig.tryParse(null), isNull);
    });
  });
}
