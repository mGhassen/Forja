import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `moviesapi`.
const moviesapiExtractProfile = EmbedExtractProfile(
  id: 'moviesapi',
  timeout: Duration(seconds: 60),
);
