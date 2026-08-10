import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidlove`.
///
/// Live player uses MovieBox / VidAPI (and legacy Neta/Gogo/…) chips; media is
/// often a signed `/api?d=&internal_token=` URL with no `.m3u8` suffix.
const vidloveExtractProfile = EmbedExtractProfile(
  id: 'vidlove',
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
