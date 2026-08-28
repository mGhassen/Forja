import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initRustForTests();
    tmp = await Directory.systemTemp.createTemp('forja_provider_registry_');
    await Engine.init(storagePath: '${tmp.path}/store.json');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  test('ProviderRegistry catalog matches Rust build URLs', () {
    const tmdbId = '550';
    const tvId = '1399';
    const season = 2;
    const episode = 5;

    for (final p in ProviderRegistry.all) {
      if (p.movieUrl == null) continue;
      final id = int.parse(tmdbId);
      final rustMovie = RustLib.instance.buildMovieUrl(p.id, id);
      expect(p.movieUrl!(tmdbId), rustMovie, reason: p.id);
      if (p.tvUrl != null) {
        final rustTv = RustLib.instance.buildTvUrl(
          p.id,
          int.parse(tvId),
          season,
          episode,
        );
        expect(p.tvUrl!(tvId, season, episode), rustTv, reason: p.id);
      }
    }
  });

  test('catalog includes webstreamr and videasy', () {
    expect(ProviderRegistry.catalog.containsKey('webstreamr'), isTrue);
    expect(ProviderRegistry.catalog.containsKey('videasy'), isTrue);
    expect(ProviderRegistry.catalog['vidlink']?['movie'], isNotNull);
  });
}
