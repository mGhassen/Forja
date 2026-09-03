import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv_atv_live_cache.dart';

void main() {
  test('ATV live cache: UHD shares FHD bytes (no 150MB open spike)', () {
    final hd = iptvAtvLiveCacheTierForHeight(720);
    expect(hd.tier, 'hd');
    expect(hd.demuxerMaxBytes, 48 * 1024 * 1024);

    final fhd = iptvAtvLiveCacheTierForHeight(1080);
    expect(fhd.tier, 'fhd');
    expect(fhd.cacheSecs, 20);
    expect(fhd.demuxerMaxBytes, 96 * 1024 * 1024);

    final uhd = iptvAtvLiveCacheTierForHeight(2160);
    expect(uhd.tier, 'uhd');
    expect(uhd.cacheSecs, 20);
    expect(uhd.demuxerMaxBytes, fhd.demuxerMaxBytes);
    expect(uhd.demuxerMaxBytes, lessThan(150000000));
  });

  test('ATV live cache bump never promotes FHD to 150MB UHD', () {
    final fhd = iptvAtvLiveCacheTierForHeight(1080);
    final bumped = iptvBumpAtvLiveCacheTier(fhd);
    expect(bumped.tier, 'fhd');
    expect(bumped.demuxerMaxBytes, fhd.demuxerMaxBytes);

    final hd = iptvAtvLiveCacheTierForHeight(720);
    expect(iptvBumpAtvLiveCacheTier(hd).tier, 'fhd');
  });
}
