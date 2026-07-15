import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidsrcsbs`.
const vidsrcsbsExtractProfile = EmbedExtractProfile(
  id: 'vidsrcsbs',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  acceptProxyPlaylistBodies: true,
  cdnHostsPreferEmbedReferer: ['cinezo', 'goodstream', '1embed'],
);
