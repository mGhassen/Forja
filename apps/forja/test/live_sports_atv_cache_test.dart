import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/live_sports_atv_cache.dart';

void main() {
  test('Live Sports ATV cache: UHD shares FHD bytes (no 150MB open spike)', () {
    final hd = liveSportsAtvCacheTierForHeight(720);
    expect(hd.tier, 'hd');
    expect(hd.cacheSecs, 15);
    expect(hd.readaheadSecs, 10);
    expect(hd.demuxerMaxBytes, 48 * 1024 * 1024);

    final fhd = liveSportsAtvCacheTierForHeight(1080);
    expect(fhd.tier, 'fhd');
    expect(fhd.cacheSecs, 20);
    expect(fhd.readaheadSecs, 15);
    expect(fhd.demuxerMaxBytes, 96 * 1024 * 1024);

    final uhd = liveSportsAtvCacheTierForHeight(2160);
    expect(uhd.tier, 'uhd');
    expect(uhd.cacheSecs, 20);
    expect(uhd.readaheadSecs, 15);
    expect(uhd.demuxerMaxBytes, fhd.demuxerMaxBytes);
    expect(uhd.demuxerMaxBytes, lessThan(150000000));
  });

  test('Live Sports ATV cache bump never promotes FHD to 150MB UHD', () {
    final fhd = liveSportsAtvCacheTierForHeight(1080);
    final bumped = liveSportsBumpAtvCacheTier(fhd);
    expect(bumped.tier, 'fhd');
    expect(bumped.demuxerMaxBytes, fhd.demuxerMaxBytes);

    final hd = liveSportsAtvCacheTierForHeight(720);
    expect(liveSportsBumpAtvCacheTier(hd).tier, 'fhd');
  });
}
