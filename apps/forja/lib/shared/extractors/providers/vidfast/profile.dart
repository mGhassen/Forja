import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `vidfast`.
///
/// Player is HLS.js / MSE: `video.src` becomes `blob:` while the real playlist
/// is only passed to `Hls.loadSource` (bundled — not always `window.Hls`).
/// Session media often arrives via opaque `/w/{uuid}/…` bodies. Load top-level,
/// scan proxy bodies, hook bundled HLS, and rotate Server chips for collect-all.
const vidfastExtractProfile = EmbedExtractProfile(
  id: 'vidfast',
  forceDirect: true,
  timeout: Duration(seconds: 90),
  deferUntilStrongStream: true,
  acceptProxyPlaylistBodies: true,
  rotateServerChips: true,
);
