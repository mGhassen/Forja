/// ATV MediaKit live demuxer tiers (issue 150 / 155).
///
/// UHD shares the FHD byte cap. 150 MB + 4K MediaCodec surfaces OOMs physical
/// leanback on open (issue 155). Admin **30 seconds** override still uses 150 MB.
({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes})
iptvAtvLiveCacheTierForHeight(int height) {
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
iptvBumpAtvLiveCacheTier(
  ({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes}) t,
) {
  switch (t.tier) {
    case 'hd':
      return iptvAtvLiveCacheTierForHeight(1080);
    default:
      return t;
  }
}
