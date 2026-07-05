import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    await initRustForTests();
    tmp = await Directory.systemTemp.createTemp('forja_storage_test_');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  test('storage round-trip', () {
    final path = '${tmp.path}/store.json';
    final open = jsonDecode(ForjaRust.instance.storageOpen(path))
        as Map<String, dynamic>;
    expect(open['ok'], isTrue);

    final set = jsonDecode(
      ForjaRust.instance.storageSetJson(
        'forja_provider_order',
        jsonEncode(['videasy', 'vidsrc']),
      ),
    ) as Map<String, dynamic>;
    expect(set['ok'], isTrue);

    final got = jsonDecode(
      ForjaRust.instance.storageGetJson('forja_provider_order'),
    ) as List;
    expect(got, ['videasy', 'vidsrc']);
  });
}
