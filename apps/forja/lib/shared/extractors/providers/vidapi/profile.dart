import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidapi`.
const vidapiExtractProfile = EmbedExtractProfile(
  id: 'vidapi',
  timeout: Duration(seconds: 60),
);
