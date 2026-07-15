import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `smashystream`.
const smashystreamExtractProfile = EmbedExtractProfile(
  id: 'smashystream',
  timeout: Duration(seconds: 60),
  deferUntilStrongStream: true,
);
