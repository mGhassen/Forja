import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/packs/registry/plugin_contract.dart';

Map<String, dynamic> _manifest({
  String id = 'test-provider-a',
  String entry = 'provider_a.js',
  String? prelude,
  String? packPrelude,
  List<String>? bundle,
}) => {
  'schema': 1,
  'name': 'Synthetic Pack',
  'version': '1.0.0',
  'prelude': ?packPrelude,
  'bundle': ?bundle,
  'plugins': [
    {
      'id': id,
      'name': 'Provider A',
      'entry': entry,
      'kind': 'http',
      'prelude': ?prelude,
    },
  ],
};

void main() {
  group('PluginContract.isValidPluginId', () {
    test('accepts letters, digits, dot, dash, underscore', () {
      for (final id in ['a', 'test-provider-a', 'hub.v2_beta', 'X9', '0abc']) {
        expect(PluginContract.isValidPluginId(id), isTrue, reason: id);
      }
    });

    test('rejects traversal, separators, empty, unicode, leading symbols', () {
      for (final id in [
        '../x',
        '../../other/plugins/x',
        'a/b',
        'a\\b',
        '',
        '   ',
        'épée',
        'ani☃me',
        '.hidden',
        '-dash',
        'a..b',
        'a b',
      ]) {
        expect(PluginContract.isValidPluginId(id), isFalse, reason: id);
      }
    });
  });

  group('PluginContract.validateManifest', () {
    test('valid synthetic manifest passes', () {
      expect(
        () => PluginContract.validateManifest(_manifest()),
        returnsNormally,
      );
    });

    test('plugin id with ../ is refused with user-facing copy', () {
      expect(
        () => PluginContract.validateManifest(_manifest(id: '../x')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('invalid plugin id'),
          ),
        ),
      );
    });

    test('plugin id with slash, empty, or unicode is refused', () {
      for (final id in ['a/b', ' ', 'ünicode']) {
        expect(
          () => PluginContract.validateManifest(_manifest(id: id)),
          throwsA(isA<FormatException>()),
          reason: id,
        );
      }
    });

    test('entry outside the pack folder is refused', () {
      for (final entry in [
        '../evil.js',
        '/etc/passwd',
        'a/../../b.js',
        'C:\\x.js',
      ]) {
        expect(
          () => PluginContract.validateManifest(_manifest(entry: entry)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('not installed'),
            ),
          ),
          reason: entry,
        );
      }
    });

    test('plain-http entry is refused; https and nested relative pass', () {
      expect(
        () => PluginContract.validateManifest(
          _manifest(entry: 'http://cdn.example/x.js'),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('https://'),
          ),
        ),
      );
      expect(
        () => PluginContract.validateManifest(
          _manifest(entry: 'https://cdn.example/x.js'),
        ),
        returnsNormally,
      );
      expect(
        () => PluginContract.validateManifest(_manifest(entry: 'hops/mega.js')),
        returnsNormally,
      );
    });

    test('prelude parts and bundle rows are checked too', () {
      expect(
        () => PluginContract.validateManifest(
          _manifest(prelude: '_kit.js,../_shared.js'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginContract.validateManifest(
          _manifest(packPrelude: '_kit.js,_search.js'),
        ),
        returnsNormally,
      );
      expect(
        () => PluginContract.validateManifest(
          _manifest(bundle: ['a.js', '../b.js']),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
