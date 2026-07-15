import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidsrc`.
const vidsrcExtractProfile = EmbedExtractProfile(
  id: 'vidsrc',
  timeout: Duration(seconds: 60),
);
