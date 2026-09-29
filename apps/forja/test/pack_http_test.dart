import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/pack_http.dart';

void main() {
  tearDown(() {
    PackHttp.debugClient = null;
  });

  group('humanizeError', () {
    test('dns failed host lookup', () {
      final msg = PackHttp.humanizeError(
        SocketException(
          'Failed host lookup: raw.githubusercontent.com',
          osError: const OSError('No address associated with hostname', 7),
        ),
        'https://raw.githubusercontent.com/mGhassen/forja-packs/main/hubs/home/manifest.json',
      );
      expect(msg, contains('Cannot resolve raw.githubusercontent.com'));
      expect(msg, contains('DNS'));
      expect(msg, contains('local path'));
    });

    test('timeout', () {
      final msg = PackHttp.humanizeError(
        TimeoutException('plugin fetch'),
        'https://raw.githubusercontent.com/x/y/main/manifest.json',
      );
      expect(msg, contains('timed out'));
      expect(msg, contains('raw.githubusercontent.com'));
    });

    test('manifest gone local path', () {
      final msg = PackHttp.humanizeError(
        ManifestGoneException('/tmp/forja-packs/live/manifest.json'),
      );
      expect(msg, contains('Manifest not found'));
      expect(msg, contains('/tmp/forja-packs/live/manifest.json'));
    });
  });
}
