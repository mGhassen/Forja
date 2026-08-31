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

  test('legacy embed registry is empty', () {
    expect(ProviderRegistry.all, isEmpty);
    expect(ProviderRegistry.catalog, isEmpty);
    expect(ProviderRegistry.byId('vidlink'), isNull);
  });

  test('Rust buildMovieUrl returns none without overlay template', () {
    expect(RustLib.instance.buildMovieUrl('vidlink', 550), '');
  });
}
