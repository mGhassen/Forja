import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/components/chrome/kit_category_circle_meta.dart';

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

  group('catalogKitCategoryCircleMeta', () {
    test('maps american-football before generic football', () {
      final american = catalogKitCategoryCircleMeta('american-football');
      final soccer = catalogKitCategoryCircleMeta('football');
      expect(american.icon, Icons.sports_football_rounded);
      expect(soccer.icon, Icons.sports_soccer_rounded);
    });

    test('maps 24-7 and combat', () {
      expect(
        catalogKitCategoryCircleMeta('24-7').icon,
        Icons.live_tv_rounded,
      );
      expect(
        catalogKitCategoryCircleMeta('combat-sports').icon,
        Icons.sports_mma_rounded,
      );
    });
  });
}
