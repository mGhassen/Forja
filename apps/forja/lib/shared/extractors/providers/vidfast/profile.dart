import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidfast`.
///
/// Player is HLS.js / MSE: `video.src` becomes `blob:` while the real playlist
/// is only passed to `Hls.loadSource`. Load top-level (no iframe wrapper) and
/// wait for a strong playlist from the HLS hook / body sniff.
const vidfastExtractProfile = EmbedExtractProfile(
  id: 'vidfast',
  forceDirect: true,
  timeout: Duration(seconds: 60),
  deferUntilStrongStream: true,
  acceptProxyPlaylistBodies: true,
);
