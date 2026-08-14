import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/hubcloud_drive_quota.dart';

void main() {
  group('isHubCloudDriveProxyUrl', () {
    test('matches workers.dev Drive token path', () {
      expect(
        isHubCloudDriveProxyUrl(
          'https://hubloud-downloadcdn.vi-isp.workers.dev/'
          'abc123::def456/1397996166/Reacher.S01E01.mkv',
        ),
        isTrue,
      );
      expect(
        isHubCloudDriveProxyUrl(
          'https://api.netflixmovies.workers.dev/'
          'c2fd::7913/1/Reacher%20S01E01.mkv',
        ),
        isTrue,
      );
    });

    test('ignores other workers.dev and HubCloud pages', () {
      expect(
        isHubCloudDriveProxyUrl('https://cdn.workers.dev/file.mkv'),
        isFalse,
      );
      expect(
        isHubCloudDriveProxyUrl('https://hubcloud.one/drive/abc'),
        isFalse,
      );
      expect(isHubCloudDriveProxyUrl('https://example.com/a::b/c.mkv'), isFalse);
    });
  });

  group('isDriveDownloadQuotaBody', () {
    test('matches Drive usageLimits JSON', () {
      expect(
        isDriveDownloadQuotaBody(
          '{"error":{"code":403,"message":"The download quota for this file '
          'has been exceeded.","errors":[{"reason":"downloadQuotaExceeded"}]}}',
        ),
        isTrue,
      );
    });

    test('ignores unrelated bodies', () {
      expect(isDriveDownloadQuotaBody(''), isFalse);
      expect(isDriveDownloadQuotaBody('\x1aE\xdf\xa3'), isFalse);
      expect(isDriveDownloadQuotaBody('{"error":{"code":404}}'), isFalse);
    });
  });

  test('dropHubCloudDriveQuotaRows keeps non-proxy and live proxy', () async {
    final rows = [
      {'url': 'https://cdn.example/ok.m3u8'},
      {
        'url':
            'https://hubloud-downloadcdn.vi-isp.workers.dev/dead::key/1/a.mkv',
      },
      {
        'url':
            'https://misty-queen.workers.dev/live::key/1/b.mkv',
      },
    ];
    final out = await dropHubCloudDriveQuotaRows(
      rows: rows,
      urlOf: (m) => m['url']!,
      quotaCheck: (url, _) async => url.contains('dead::'),
    );
    expect(out.map((m) => m['url']), [
      'https://cdn.example/ok.m3u8',
      'https://misty-queen.workers.dev/live::key/1/b.mkv',
    ]);
  });
}
