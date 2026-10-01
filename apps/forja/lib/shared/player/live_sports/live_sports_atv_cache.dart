/// ATV MediaKit demuxer tiers for Live Sports only (pre–RFC-113 / v1.5.36).
///
/// IPTV live keeps the RFC-113 `live/forja` cushion in
/// `pt_player_mk_tunables.dart` — do not call these helpers from IPTV paths.
///
/// UHD shares the FHD byte cap. 150 MB + 4K MediaCodec surfaces OOMs physical
/// leanback on open (issue 155).
({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes})
liveSportsAtvCacheTierForHeight(int height) {
  if (height >= 2160) {
    return (
      tier: 'uhd',
      cacheSecs: 20,
      readaheadSecs: 15,
      demuxerMaxBytes: 96 * 1024 * 1024,
    );
  }
  if (height >= 1080) {
    return (
      tier: 'fhd',
      cacheSecs: 20,
      readaheadSecs: 15,
      demuxerMaxBytes: 96 * 1024 * 1024,
    );
  }
  return (
    tier: 'hd',
    cacheSecs: 15,
    readaheadSecs: 10,
    demuxerMaxBytes: 48 * 1024 * 1024,
  );
}

({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes})
liveSportsBumpAtvCacheTier(
  ({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes}) t,
) {
  switch (t.tier) {
    case 'hd':
      return liveSportsAtvCacheTierForHeight(1080);
    default:
      return t;
  }
}
