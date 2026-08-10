import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidzee`.
///
/// Embed is often behind Cloudflare (challenge or error shell). Wait for CF
/// clearance when possible, load top-level, defer for HLS, rotate servers.
/// HLS lives on 1shows / similar — keep embed Referer (CDN 403 otherwise).
const vidzeeExtractProfile = EmbedExtractProfile(
  id: 'vidzee',
  forceDirect: true,
  timeout: Duration(seconds: 90),
  deferUntilStrongStream: true,
  rotateServerChips: true,
  waitForCloudflare: true,
  cdnHostsPreferEmbedReferer: ['1shows', 'vidzee'],
);
