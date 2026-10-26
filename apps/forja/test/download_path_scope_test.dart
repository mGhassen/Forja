import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:path/path.dart' as p;
import 'package:rust/rust.dart' show LocalDataScope;

void main() {
  tearDown(LocalDataScope.resetForTest);

  test('identityRelativePath defaults to guest scope', () {
    expect(
      DownloadPathHelper.identityRelativePath(),
      p.join('accounts', 'local', 'default'),
    );
  });

  test('identityRelativePath isolates account and profile', () {
    expect(
      DownloadPathHelper.identityRelativePath(
        accountId: 'acct-a',
        profileId: 'kids',
      ),
      p.join('accounts', 'acct-a', 'kids'),
    );
    expect(
      DownloadPathHelper.identityRelativePath(
        accountId: 'acct-b',
        profileId: 'adults',
      ),
      p.join('accounts', 'acct-b', 'adults'),
    );
  });
}
