import 'dart:convert';
import 'dart:io';

import '../helpers/rust_engine.dart';
import 'package:rust/rust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<dynamic> cases;

  setUpAll(() async {
    await initRustForTests();
    final fixture = File(
      '${_repoRoot()}/crates/utils/tests/fixtures/episode_matcher.json',
    );
    cases = jsonDecode(fixture.readAsStringSync()) as List;
  });

  test('matches golden fixtures', () {
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final file = c['file'] as String;
      final season = c['season'] as int;
      final episode = c['episode'] as int;
      final expected = c['expected'] as bool;

      expect(
        RustLib.instance.episodeMatches(file, season, episode),
        expected,
        reason: '$file S${season}E$episode',
      );
    }
  });

  test('pickEpisodeIndexJson prefers largest matching file', () {
    const files = [
      {'name': 'sample.mkv', 'size': 100},
      {'name': 'Show.S03E07.720p.mkv', 'size': 700},
      {'name': 'Show.S03E07.1080p.mkv', 'size': 1080},
    ];
    final idx = RustLib.instance.pickEpisodeIndexJson(
      jsonEncode(files),
      3,
      7,
    );
    expect(idx, 2);
  });
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/crates/ffi').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent.path;
}
