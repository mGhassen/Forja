import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidsrcsbs`.
///
/// `vidsrc.sbs/embed/…` is a multi-server dropdown (Star → 1embed, PRO Multi →
/// nxsha, Cinesrc, Vlux). The page boots on Star, which often emits dead
/// proxy playlists; working streams come from later servers. Prefer those
/// labels, rotate the dropdown, and do not early-complete on Star's first hit.
const vidsrcsbsExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  // Prefer working mirrors before the default Star/1embed entry.
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
