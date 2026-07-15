import 'dart:convert';

import '../helpers/rust_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUpAll(() async {
    await initRustForTests();
  });

  test('anilistQueryJson fetches trending', () async {
    const q =
        'query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }';
    final raw = RustLib.instance.anilistQueryJson(q);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['data'], isNotNull);
  });

  test('engine cancel must not break anilist catalog queries', () async {
    const q =
        'query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }';
    final fut = Future(() => RustLib.instance.anilistQueryJson(q));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    RustLib.instance.engineCancelPending();
    final raw = await fut;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(
      decoded['data'],
      isNotNull,
      reason: 'catalog fetch should ignore playback cancel: $decoded',
    );
  });

  test('engine cancel must not break worker-pool anilist queries', () async {
    const q =
        'query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }';
    final fut = runAnilistQueryJson(q);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    RustLib.instance.engineCancelPending();
    final raw = await fut;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(
      decoded['data'],
      isNotNull,
      reason: 'worker catalog fetch should ignore playback cancel: $decoded',
    );
  });

  test('engine prepare shutdown aborts worker-pool anilist queries', () async {
    const q =
        'query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }';
    final fut = runAnilistQueryJson(q);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    RustLib.instance.enginePrepareShutdown();
    final raw = await fut;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(
      decoded['error'],
      isNotNull,
      reason: 'shutdown must abort catalog HTTP so isolates can exit: $decoded',
    );
    RustLib.instance.engineClearShutdown();
  });

  test('mangaFetchHtml rejects invalid url', () {
    final raw = RustLib.instance.mangaFetchHtml('not-a-url');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['error'], isNotNull);
  });
}
