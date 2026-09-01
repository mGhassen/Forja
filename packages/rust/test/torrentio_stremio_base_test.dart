import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('isTorrentioStremioAddon matches host and name', () {
    expect(
      SettingsService.isTorrentioStremioAddon({
        'baseUrl': 'https://torrentio.strem.fun/sort=seeders|limit=70',
        'name': 'Streams',
      }),
      isTrue,
    );
    expect(
      SettingsService.isTorrentioStremioAddon({
        'baseUrl': 'https://yts.strem.fun',
        'name': 'YTS',
      }),
      isFalse,
    );
    expect(
      SettingsService.isTorrentioStremioAddon({
        'baseUrl': 'https://example.strem.fun/custom',
        'manifest': {'name': 'Torrentio RD'},
      }),
      isTrue,
    );
  });
}
