import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RFC-106 zone A — UI layers must not import app or Riverpod.
void main() {
  const forbidden = ['package:forja/', 'flutter_riverpod'];
  final root = Directory('lib');
  final zones = [
    Directory('lib/components'),
    Directory('lib/primitives'),
    Directory('lib/widgets'),
    Directory('lib/tokens'),
    Directory('lib/theme'),
  ];

  test('zone A dirs have no forbidden imports', () {
    final violations = <String>[];

    for (final zone in zones) {
      expect(
        zone.existsSync(),
        isTrue,
        reason: 'Expected ${zone.path} under package root',
      );
      for (final entity in zone.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = entity.path.replaceFirst('${root.path}/', '');
        final text = entity.readAsStringSync();
        for (final needle in forbidden) {
          if (text.contains(needle)) {
            violations.add('$rel contains "$needle"');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.join('\n'),
    );
  });
}
