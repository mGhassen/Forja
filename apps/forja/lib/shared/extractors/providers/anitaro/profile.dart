import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `anitaro`.
const anitaroExtractProfile = EmbedExtractProfile(
  id: 'anitaro',
  timeout: Duration(seconds: 60),
  deferUntilStrongStream: true,
  completeOnlyWithAudio: true,
);
