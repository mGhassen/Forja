import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  setUp(() {
    TorrentSearchCatalog.update(const [
      TorrentSearchProviderMeta(id: 'knaben', label: 'Knaben', resultSource: 'Knaben'),
      TorrentSearchProviderMeta(id: 'yts', label: 'YTS', resultSource: 'YTS'),
      TorrentSearchProviderMeta(id: 'nyaa', label: 'Nyaa', resultSource: 'Nyaa'),
    ]);
  });

  tearDown(TorrentSearchCatalog.clear);

  test('none chip queries no providers; all chip queries every enabled', () {
    const enabled = ['knaben', 'yts', 'nyaa'];
    expect(
      TorrentSearchProviders.enabledForChip(
        TorrentSearchProviders.noneId,
        enabled,
      ),
      isEmpty,
    );
    expect(
      TorrentSearchProviders.enabledForChip(
        TorrentSearchProviders.allId,
        enabled,
      ),
      enabled,
    );
  });

  test('mergeSearchRows keeps one row per indexer for the same magnet', () {
    final into = <String, Map<String, dynamic>>{};
    TorrentSearchProviders.mergeSearchRows(into, [
      {
        'name': 'a',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '10',
        'size': '1 GB',
        'source': 'ThePirateBay',
      },
    ]);
    TorrentSearchProviders.mergeSearchRows(into, [
      {
        'name': 'a-better',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '40',
        'size': '1 GB',
        'source': 'Knaben',
      },
    ]);
    expect(into.length, 2);
    expect(
      into.values.map((r) => r['source']).toSet(),
      {'ThePirateBay', 'Knaben'},
    );
  });

  test('mergeByMagnet keeps the higher-seeder copy', () {
    final into = <String, Map<String, dynamic>>{};
    TorrentSearchProviders.mergeByMagnet(into, [
      {
        'name': 'a',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '10',
        'size': '1 GB',
        'source': 'YTS',
      },
    ]);
    TorrentSearchProviders.mergeByMagnet(into, [
      {
        'name': 'a-better',
        'magnet': 'magnet:?xt=urn:btih:abc',
        'seeders': '40',
        'size': '1 GB',
        'source': 'Knaben',
      },
      {
        'name': 'b',
        'magnet': 'magnet:?xt=urn:btih:def',
        'seeders': '2',
        'size': '2 GB',
        'source': 'Nyaa',
      },
    ]);
    expect(into.length, 2);
    expect(into['magnet:?xt=urn:btih:abc']!['source'], 'Knaben');
    expect(into['magnet:?xt=urn:btih:abc']!['seeders'], '40');
    expect(into['magnet:?xt=urn:btih:def']!['name'], 'b');
  });

  test('mergeByMagnet skips empty magnets', () {
    final into = <String, Map<String, dynamic>>{};
    TorrentSearchProviders.mergeByMagnet(into, [
      {'name': 'x', 'magnet': '', 'seeders': '9', 'size': '1 GB', 'source': 'YTS'},
    ]);
    expect(into, isEmpty);
  });

  test('All tap clears every chip when All is already selected', () {
    expect(
      TorrentSearchProviders.nextIdAfterAllTap(TorrentSearchProviders.allId),
      TorrentSearchProviders.noneId,
    );
    expect(
      TorrentSearchProviders.nextIdAfterAllTap('forja'),
      TorrentSearchProviders.noneId,
    );
    expect(
      TorrentSearchProviders.nextIdAfterAllTap(TorrentSearchProviders.noneId),
      TorrentSearchProviders.allId,
    );
    expect(
      TorrentSearchProviders.nextIdAfterAllTap(TorrentSearchProviders.yts),
      TorrentSearchProviders.allId,
    );
  });

  test('enabledForChip is the selected indexer only, not every Settings provider', () {
    const settings = [
      TorrentSearchProviders.knaben,
      TorrentSearchProviders.yts,
      TorrentSearchProviders.nyaa,
    ];
    expect(
      TorrentSearchProviders.enabledForChip(
        TorrentSearchProviders.yts,
        settings,
      ),
      [TorrentSearchProviders.yts],
    );
    expect(
      TorrentSearchProviders.enabledForChip(
        TorrentSearchProviders.allId,
        settings,
      ),
      [
        TorrentSearchProviders.knaben,
        TorrentSearchProviders.yts,
        TorrentSearchProviders.nyaa,
      ],
    );
    expect(
      TorrentSearchProviders.enabledForChip(
        TorrentSearchProviders.noneId,
        settings,
      ),
      isEmpty,
    );
    expect(
      TorrentSearchProviders.defaultChipId(settings),
      TorrentSearchProviders.knaben,
    );
    expect(
      TorrentSearchProviders.missingEnabledForChip(
        chipId: TorrentSearchProviders.yts,
        settingsEnabled: settings,
        fetchedProviderIds: const [],
      ),
      [TorrentSearchProviders.yts],
    );
    expect(
      TorrentSearchProviders.missingEnabledForChip(
        chipId: TorrentSearchProviders.allId,
        settingsEnabled: settings,
        fetchedProviderIds: const [TorrentSearchProviders.yts],
      ),
      [TorrentSearchProviders.knaben, TorrentSearchProviders.nyaa],
    );
  });

  test('none chip matches no result sources', () {
    expect(
      TorrentSearchProviders.matchesResultSource(
        TorrentSearchProviders.noneId,
        'YTS',
      ),
      isFalse,
    );
    expect(
      TorrentSearchProviders.matchesResultSource(
        TorrentSearchProviders.allId,
        'YTS',
      ),
      isTrue,
    );
  });
}
