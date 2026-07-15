import 'package:forja/shared/extractors/core/embed_extract_profile.dart';

/// Host sniff policy for `autoembed`.
///
/// Outer `autoembed.co` only iframes `player.autoembed.co`. That player dies
/// (blank / `asb.html` "Playback blocked") when nested under a sandboxed
/// iframe — including Forja's optional Embed wrapper. Load the player URL
/// top-level and wait for the nested CloudFabric stream.
const autoembedExtractProfile = EmbedExtractProfile(
  id: 'autoembed',
  timeout: Duration(seconds: 60),
  forceDirect: true,
  deferUntilStrongStream: true,
  cdnHostsPreferEmbedReferer: ['nextgencloudfabric', 'cloudfabric'],
);
