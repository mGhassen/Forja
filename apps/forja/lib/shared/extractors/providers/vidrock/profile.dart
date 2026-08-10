import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidrock`.
///
/// SPA + HLS.js with a Servers list (`[data-server-list]`). Empty chip labels
/// → click every row in that list (and generic Server N heuristics).
const vidrockExtractProfile = EmbedExtractProfile(
  id: 'vidrock',
  timeout: Duration(seconds: 90),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  acceptProxyPlaylistBodies: true,
  // Dynamic names from `/api/movie|tv/…` — do not hardcode.
  serverChipLabels: [],
  cdnHostsPreferEmbedReferer: ['vidrock'],
);
