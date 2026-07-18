import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for the outer `vidsrc.sbs/embed/…` shell (fallback only).
///
/// Prefer [vidsrcsbsNestedExtractProfile] on each CFG mirror — see
/// [VidsrcsbsExtractor]. Outer dropdown rotation is a last resort.
const vidsrcsbsExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 45),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: ['pro multi', 'cinesrc', 'vlux', 'star'],
  rotateBeforeComplete: true,
  acceptProxyPlaylistBodies: true,
  cdnHostsPreferEmbedReferer: [
    'cinezo',
    'goodstream',
    '1embed',
    'nxsha',
    'cinesrc',
    'vidlux',
  ],
);

/// Sniff one nested mirror (`web.nxsha.app`, `cinesrc.st`, `vidlux.xyz`, …)
/// loaded as the WebView top-level document — no dropdown UI.
const vidsrcsbsNestedExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 22),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: false,
  rotateBeforeComplete: false,
  acceptProxyPlaylistBodies: true,
  cdnHostsPreferEmbedReferer: [
    'cinezo',
    'goodstream',
    '1embed',
    'nxsha',
    'cinesrc',
    'vidlux',
  ],
);
