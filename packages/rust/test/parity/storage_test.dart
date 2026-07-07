import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initRustForTests();
    tmp = await Directory.systemTemp.createTemp('forja_storage_test_');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  test('storage round-trip', () {
    final path = '${tmp.path}/store.json';
    final open = jsonDecode(RustLib.instance.storageOpen(path))
        as Map<String, dynamic>;
    expect(open['ok'], isTrue);

    final set = jsonDecode(
      RustLib.instance.storageSetJson(
        'forja_provider_order',
        jsonEncode(['videasy', 'vidsrc']),
      ),
    ) as Map<String, dynamic>;
    expect(set['ok'], isTrue);

    final got = jsonDecode(
      RustLib.instance.storageGetJson('forja_provider_order'),
    ) as List;
    expect(got, ['videasy', 'vidsrc']);
  });

  test('storage stremio addons map list round-trip', () {
    final path = '${tmp.path}/store_stremio.json';
    final open = jsonDecode(RustLib.instance.storageOpen(path))
        as Map<String, dynamic>;
    expect(open['ok'], isTrue);

    const addons = [
      {'baseUrl': 'https://addon.example/manifest.json', 'name': 'Test'},
    ];
    final set = jsonDecode(
      RustLib.instance.storageSetJson(
        'stremio_addons',
        jsonEncode(addons),
      ),
    ) as Map<String, dynamic>;
    expect(set['ok'], isTrue);

    final got = jsonDecode(
      RustLib.instance.storageGetJson('stremio_addons'),
    ) as List;
    expect(got, hasLength(1));
    expect(got.first['baseUrl'], 'https://addon.example/manifest.json');
  });

  test('storage string list round-trip', () {
    final path = '${tmp.path}/store_order.json';
    jsonDecode(RustLib.instance.storageOpen(path));
    RustLib.instance.storageSetJson(
      'stream_provider_order',
      jsonEncode(['videasy', 'vidsrc', 'webstreamr']),
    );
    final got = jsonDecode(
      RustLib.instance.storageGetJson('stream_provider_order'),
    ) as List;
    expect(got, ['videasy', 'vidsrc', 'webstreamr']);
  });

  test('Engine storage facade helpers', () async {
    final path = '${tmp.path}/facade_store.json';
    await Engine.init(storagePath: path);
    expect(Engine.isReady, isTrue);
    Engine.storageWriteStringList('forja_provider_order', ['vidsrc']);
    expect(
      Engine.storageReadStringList(
        'forja_provider_order',
        fallback: const [],
      ),
      ['vidsrc'],
    );
    Engine.storageWriteMapList('stremio_addons', [
      {'baseUrl': 'https://x/manifest.json', 'name': 'X'},
    ]);
    expect(Engine.storageReadMapList('stremio_addons'), hasLength(1));
    Engine.storageWrite('watch_history', [
      {'uniqueId': '550', 'title': 'Fight Club'},
    ]);
    final hist = Engine.storageRead('watch_history') as List;
    expect(hist, hasLength(1));
  });
}
