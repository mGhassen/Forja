import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/models.dart';

void main() {
  PortalCategory cat(String id, [String? name]) =>
      PortalCategory(id: id, name: name ?? id);

  test('firstPortalCategoryId skips Favorites / Already watched', () {
    final input = PortalLiveCatalog.withPins([
      cat('sports'),
      cat('news'),
    ]);
    expect(
      PortalLiveCatalog.firstPortalCategoryId(input),
      'sports',
    );
  });

  test('firstPortalCategoryId uses pinned top', () {
    final input = PortalLiveCatalog.withPins([
      cat('sports'),
      cat('news'),
      cat('movies'),
    ]);
    expect(
      PortalLiveCatalog.firstPortalCategoryId(
        input,
        userPinnedIds: const ['news'],
      ),
      'news',
    );
  });

  test('firstPortalCategoryId uses dragged categoryOrder top', () {
    final input = PortalLiveCatalog.withPins([
      cat('sports'),
      cat('news'),
      cat('movies'),
    ]);
    expect(
      PortalLiveCatalog.firstPortalCategoryId(
        input,
        customOrderIds: const ['movies', 'sports', 'news'],
      ),
      'movies',
    );
  });

  test('playlist categoryOrder wins over pin bucket', () {
    final input = PortalLiveCatalog.withPins([
      cat('a'),
      cat('b'),
      cat('c'),
    ]);
    final ordered = PortalLiveCatalog.sortCategories(
      input,
      userPinnedIds: const ['c'],
      customOrderIds: const ['b', 'a', 'c'],
    );
    expect(
      ordered.map((e) => e.id).toList(),
      [
        PortalLiveCatalog.favoritesId,
        PortalLiveCatalog.watchedId,
        'b',
        'a',
        'c',
      ],
    );
    expect(
      PortalLiveCatalog.firstPortalCategoryId(
        input,
        userPinnedIds: const ['c'],
        customOrderIds: const ['b', 'a', 'c'],
      ),
      'b',
    );
  });
}
