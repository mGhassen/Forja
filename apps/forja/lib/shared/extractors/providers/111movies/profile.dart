import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `111movies` (same player stack as VidLove).
const p111moviesExtractProfile = EmbedExtractProfile(
  id: '111movies',
  timeout: Duration(seconds: 90),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  acceptProxyPlaylistBodies: true,
  serverChipLabels: [
    'moviebox',
    'vidapi',
    'neta',
    'gogo',
    'mafia',
    'fabric',
  ],
  cdnHostsPreferEmbedReferer: [
    'hydrastreaming',
    'goodstream',
    'cinezo',
    'ballerina',
  ],
);
