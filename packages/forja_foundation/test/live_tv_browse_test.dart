import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/sources/live_tv_browse.dart';

void main() {
  test('live tv rail is the IPTV category, not the portal host', () {
    expect(
      sourcesBrowseRailLabel(
        categoryBrowse: true,
        category: 'FR | CANAL',
        provider: 'tstv8k.com',
      ),
      'FR | CANAL',
    );
    expect(
      sourcesBrowseRailLabel(
        categoryBrowse: true,
        category: '  ',
        provider: 'tstv8k.com',
      ),
      isNull,
    );
    expect(
      sourcesBrowseRailLabel(
        categoryBrowse: false,
        category: 'Sports',
        provider: 'PPV',
      ),
      'PPV',
    );
  });
}
