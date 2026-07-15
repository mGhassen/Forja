import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidfast`.
const vidfastExtractProfile = EmbedExtractProfile(
  id: 'vidfast',
  timeout: Duration(seconds: 60),
);
