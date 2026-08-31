import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/models.dart';

IptvStream _stream({
  required String id,
  required String categoryId,
}) =>
    IptvStream(
      streamId: id,
      name: 'Ch $id',
      icon: '',
      categoryId: categoryId,
      containerExt: 'ts',
      epgChannelId: '',
      kind: 'live',
    );

void main() {
  group('IptvCatalogOrphans.streamMatchesCategory', () {
    test('matches empty streams to Uncategorized bucket', () {
      final empty = _stream(id: 'a', categoryId: '');
      final tagged = _stream(id: 'b', categoryId: '110');
      expect(
        IptvCatalogOrphans.streamMatchesCategory(
          empty,
          IptvCatalogOrphans.uncategorizedId,
        ),
        isTrue,
      );
      expect(
        IptvCatalogOrphans.streamMatchesCategory(
          tagged,
          IptvCatalogOrphans.uncategorizedId,
        ),
        isFalse,
      );
      expect(IptvCatalogOrphans.streamMatchesCategory(tagged, '110'), isTrue);
    });
  });

  test('uncategorized id matches Rust constant', () {
    expect(IptvCatalogOrphans.uncategorizedId, '__uncategorized__');
  });
}
