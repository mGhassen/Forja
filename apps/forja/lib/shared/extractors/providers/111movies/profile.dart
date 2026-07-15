import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `111movies`.
const p111moviesExtractProfile = EmbedExtractProfile(
  id: '111movies',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: ['neta', 'gogo', 'mafia', 'fabric'],
  cdnHostsPreferEmbedReferer: ['hydrastreaming', 'goodstream', 'cinezo'],
);
