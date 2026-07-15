import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for the multi-server player behind `vidsrc.win`.
const vidsrcwinExtractProfile = EmbedExtractProfile(
  id: 'vidsrcwin',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  serverChipLabels: ['alpha', 'blaze'],
);
