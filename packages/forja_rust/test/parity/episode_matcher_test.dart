import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:forja_rust/forja_rust.dart';
import 'dart_baseline/dart_baseline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<dynamic> cases;

  setUpAll(() async {
    await initRustForTests();
    final fixture = File(
      '${_repoRoot()}/crates/forja-utils/tests/fixtures/episode_matcher.json',
    );
    cases = jsonDecode(fixture.readAsStringSync()) as List;
  });

  test('matches golden fixtures — Rust vs Dart', () {
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final file = c['file'] as String;
      final season = c['season'] as int;
      final episode = c['episode'] as int;
      final expected = c['expected'] as bool;

      expect(
        ForjaRust.instance.episodeMatches(file, season, episode),
        expected,
        reason: 'rust: $file S${season}E$episode',
      );
      expect(
        EpisodeMatcherDart.matches(file, season, episode),
        expected,
        reason: 'dart: $file S${season}E$episode',
      );
      expect(
        ForjaRust.instance.episodeMatches(file, season, episode),
        EpisodeMatcherDart.matches(file, season, episode),
        reason: 'parity: $file',
      );
    }
  });
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/forja-ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}
