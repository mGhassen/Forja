import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidlove`.
const vidloveExtractProfile = EmbedExtractProfile(
  id: 'vidlove',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: ['neta', 'gogo', 'mafia', 'fabric'],
  cdnHostsPreferEmbedReferer: ['hydrastreaming', 'goodstream', 'cinezo'],
);
