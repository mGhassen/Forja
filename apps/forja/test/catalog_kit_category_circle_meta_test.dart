import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/catalog/kit_category_circle_meta.dart';

void main() {
  group('catalogKitCategoryLabel', () {
    test('title-cases hyphenated kind ids', () {
      expect(
        catalogKitCategoryLabel('american-football'),
        'American Football',
      );
      expect(catalogKitCategoryLabel('24-7'), '24/7');
      expect(catalogKitCategoryLabel('all'), 'All');
    });

    test('keeps explicit label when it differs from id', () {
      expect(
        catalogKitCategoryLabel('football', label: 'Soccer'),
        'Soccer',
      );
    });
  });

  group('kitMoodCircleMeta', () {
    test('uses pack icon tokens — does not infer sports from kind ids', () {
      expect(
        kitMoodCircleMeta(icon: 'soccer').icon,
        Icons.sports_soccer_rounded,
      );
      expect(
        kitMoodCircleMeta(icon: 'football').icon,
        Icons.sports_football_rounded,
      );
      expect(kitMoodCircleMeta(id: 'football').icon, Icons.sports_rounded);
      expect(kitMoodCircleMeta(id: 'all').icon, Icons.grid_view_rounded);
    });

    test('unknown token falls back to sports', () {
      expect(kitMoodIconToken('nope').icon, Icons.sports_rounded);
    });
  });

  test('kitCategoryBarKindIcons lowercases keys', () {
    final map = kitCategoryBarKindIcons({
      'kindIcons': {'Football': 'soccer'},
    });
    expect(map['football'], 'soccer');
  });
}
