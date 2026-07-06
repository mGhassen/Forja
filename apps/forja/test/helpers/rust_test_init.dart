import 'dart:io';

import 'package:rust/rust.dart';

Future<void> initEngineForTests() async {
  if (Engine.isReady) return;
  final dir = await Directory.systemTemp.createTemp('forja_engine_smoke_');
  await Engine.init(storagePath: '${dir.path}/store.json');
}
