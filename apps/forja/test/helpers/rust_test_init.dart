import 'dart:io';

import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:rust/rust.dart';

Future<void> initEngineForTests() async {
  if (Engine.isReady) return;
  final dir = await Directory.systemTemp.createTemp('forja_engine_smoke_');
  await Engine.init(storagePath: '${dir.path}/store.json');
  registerTorrentSearchBridge();
}
