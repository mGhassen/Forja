import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `videasy`.
const videasyExtractProfile = EmbedExtractProfile(
  id: 'videasy',
  timeout: Duration(seconds: 60),
  deferUntilStrongStream: true,
);
