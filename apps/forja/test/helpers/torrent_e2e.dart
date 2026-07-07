import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

/// Magnet → librqbit → localhost URL → HTTP range fetch (shared desktop/mobile E2E).
Future<void> runMagnetStreamE2e(String magnet) async {
  RustLib.instance.torrentSetPeerLimit(50);
  expect(RustLib.instance.torrentEngineStart(0), greaterThan(0));

  final listJson = RustLib.instance.torrentListFilesJson(magnet);
  final listParsed = jsonDecode(listJson) as Map<String, dynamic>;
  expect(listParsed['error'], isNull, reason: '${listParsed['error']}');
  final files = listParsed['files'] as List?;
  expect(files, isNotEmpty);

  final json = RustLib.instance.torrentStreamJson(magnet);
  final parsed = jsonDecode(json) as Map<String, dynamic>;
  expect(parsed['error'], isNull, reason: '${parsed['error']}');
  final url = parsed['url'] as String?;
  expect(url, isNotEmpty);
  expect(url, startsWith('http://127.0.0.1:'));

  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url!));
    req.headers.set('Range', 'bytes=0-1023');
    final resp = await req.close();
    expect(resp.statusCode, anyOf(200, 206));
    final bytes = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(bytes.length, greaterThan(0));
  } finally {
    client.close();
  }
}

/// Default test magnet (Big Buck Bunny, public domain) when TORRENT_MAGNET unset.
const kDefaultTorrentE2eMagnet =
    'magnet:?xt=urn:btih:dd8255ecdd7faa5fb887f54fb303487061a6e1f6&dn=Big+Buck+Bunny';

String? torrentE2eMagnet() {
  if (Platform.environment['TORRENT_E2E'] != '1') return null;
  final env = Platform.environment['TORRENT_MAGNET'];
  if (env != null && env.isNotEmpty) return env;
  return kDefaultTorrentE2eMagnet;
}

bool get isMobilePlatform =>
    Platform.isAndroid || Platform.isIOS;
