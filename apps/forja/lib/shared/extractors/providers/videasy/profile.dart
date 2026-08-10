import 'package:forja/shared/extractors/core/embed_extract_profile.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';

/// Host sniff policy for `videasy`.
///
/// Rotates the player Servers dropdown (Yoru / Cypher / …) one by one and
/// keeps every playlist — same server list as the API mirrors.
const videasyExtractProfile = EmbedExtractProfile(
  id: 'videasy',
  timeout: Duration(seconds: 75),
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: VideasyExtractor.serverChipLabels,
);
