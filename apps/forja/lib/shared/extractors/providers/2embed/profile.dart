import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `2embed`.
///
/// Docs: https://www.2embed.online/ — embed URLs redirect to `2embed.stream`.
/// Legacy `www.2embed.cc` is iframe-oriented (top-level → `.skin`) and fails
/// Forja sniff. Load the stream player top-level; rotate Server N chips when
/// the default source stalls.
const p2embedExtractProfile = EmbedExtractProfile(
  id: '2embed',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  rotateServerChips: true,
  // Empty labels → generic "Server N" / class heuristics in StreamExtractor.
  serverChipLabels: const [],
  cdnHostsPreferEmbedReferer: ['streamsrcs', '2embed'],
);
