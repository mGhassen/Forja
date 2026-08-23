import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vixsrc`.
///
/// VixSrc HLS is demuxed (separate AUDIO group). Sniffing a video-only
/// variant plays silent — prefer the master playlist.
const vixsrcExtractProfile = EmbedExtractProfile(
  id: 'vixsrc',
  timeout: Duration(seconds: 60),
  preferHlsMaster: true,
  deferUntilStrongStream: true,
);
