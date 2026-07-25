import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidzee`.
const vidzeeExtractProfile = EmbedExtractProfile(
  id: 'vidzee',
  timeout: Duration(seconds: 60),
  // HLS lives on 1shows / similar - must keep embed Referer (CDN 403 otherwise).
  cdnHostsPreferEmbedReferer: ['1shows', 'vidzee'],
);
