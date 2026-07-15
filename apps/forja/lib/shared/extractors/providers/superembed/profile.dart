import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `superembed`.
const superembedExtractProfile = EmbedExtractProfile(
  id: 'superembed',
  timeout: Duration(seconds: 60),
);
