import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  tearDown(TorrentSearchCatalog.clear);

  test('catalog starts empty until pack installs', () {
    expect(TorrentSearchCatalog.hasInstalled, isFalse);
    expect(TorrentSearchProviders.all, isEmpty);
  });

  test('TorrentSearchCatalog update replaces installed list', () {
    TorrentSearchCatalog.update(const [
      TorrentSearchProviderMeta(
        id: 'custom',
        label: 'Custom',
        resultSource: 'CustomSrc',
      ),
    ]);
    expect(TorrentSearchProviders.all, ['custom']);
    expect(TorrentSearchProviders.label('custom'), 'Custom');
    TorrentSearchCatalog.clear();
    expect(TorrentSearchProviders.all, isEmpty);
  });
}
