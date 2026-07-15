import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidnest` (WebView fallback when API extract fails).
const vidnestExtractProfile = EmbedExtractProfile(
  id: 'vidnest',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
);
