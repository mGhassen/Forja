import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `autoembed`.
const autoembedExtractProfile = EmbedExtractProfile(
  id: 'autoembed',
  timeout: Duration(seconds: 60),
);
