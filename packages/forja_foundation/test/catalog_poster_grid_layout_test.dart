import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/catalog_poster_grid.dart';

void main() {
  test(
    'poster grid does not shrink cells under the compact subtitle floor',
    () {
      // Leanback My List body ~883px after rail; target film poster 100px.
      const cardW = 100.0;
      const cardH = 150.0;
      const gap = 22.4;
      const leading = 48.0;
      const trailing = 16.0;
      const maxWidth = 883.0;

      final layout = CatalogPosterGridLayout.poster(
        maxWidth: maxWidth,
        cardW: cardW,
        cardH: cardH,
        gap: gap,
        leading: leading,
        trailing: trailing,
      );

      // Old maxWidth ~/ cardW packed 8 columns → ~82px (hid year • type).
      expect(layout.cardW, greaterThanOrEqualTo(85));
      expect(layout.cardW, greaterThanOrEqualTo(cardW - 0.5));
    },
  );
}
