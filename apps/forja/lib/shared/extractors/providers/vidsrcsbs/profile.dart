import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for the outer `vidsrc.sbs/embed/…` shell (fallback only).
///
/// Prefer [vidsrcsbsNestedExtractProfile] on each CFG mirror - see
/// [VidsrcsbsExtractor]. Outer dropdown rotation is a last resort.
const vidsrcsbsExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 75),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: ['pro multi', 'cinesrc', '4k', 'vlux', 'star'],
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

/// Sniff one nested mirror (`web.nxsha.app`, `cinesrc.st`, …) as the WebView
/// top-level document. Rotates that mirror's own Servers chips (Pro Multi's
/// internals, etc.) and keeps every playlist until timeout.
const vidsrcsbsNestedExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 75),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  // Empty = click every server / source chip the nested player exposes.
  serverChipLabels: [],
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
