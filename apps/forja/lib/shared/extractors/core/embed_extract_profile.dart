/// Per-provider WebView sniff policy for HostRequired embeds.
///
/// Rust already has one plugin file per provider; this is the matching host
/// policy so VidLove chip rotation / VidSrc.sbs proxy rules never leak into
/// unrelated servers via a shared if-ladder in [StreamExtractor].
class EmbedExtractProfile {
  const EmbedExtractProfile({
    required this.id,
    this.forceDirect = false,
    this.timeout = const Duration(seconds: 60),
    this.deferUntilStrongStream = false,
    this.rotateServerChips = false,
    this.serverChipLabels = const [],
    this.rotateBeforeComplete = false,
    this.acceptProxyPlaylistBodies = false,
    this.cdnHostsPreferEmbedReferer = const [],
    this.harvestCookies = true,
    this.completeOnlyWithAudio = false,
    this.waitForCloudflare = false,
  });

  final String id;

  /// Load embed as WebView top-level document (no iframe wrapper).
  final bool forceDirect;

  final Duration timeout;

  /// Wait for a strong `.m3u8`/`.mpd`/etc. before completing (SPA / multi-server).
  final bool deferUntilStrongStream;

  /// Click internal server chips when the default source is stuck loading.
  final bool rotateServerChips;

  /// Exact chip labels (lowercased match), e.g. `neta`, `gogo`. Empty = generic
  /// `server N` / class heuristics only when [rotateServerChips] is true.
  /// Labels are visited in list order during rotation; every responsive chip's
  /// streams are kept until the sniff timeout (no first-hit early complete).
  final List<String> serverChipLabels;

  /// Hold completion until at least one chip switch when [rotateServerChips]
  /// is false but multi-server rotation still applies. Prefer enabling
  /// [rotateServerChips] so every chip is collected until timeout.
  final bool rotateBeforeComplete;

  /// Accept `/api/proxy?…` URLs whose response body was `#EXTM3U`.
  final bool acceptProxyPlaylistBodies;

  /// If FRAME host contains one of these, use the canonical embed as Referer.
  final List<String> cdnHostsPreferEmbedReferer;

  /// Attach WebView cookies to playback headers before probe/open.
  final bool harvestCookies;

  /// Do not complete until an audio URL was also sniffed (legacy Anitaro).
  final bool completeOnlyWithAudio;

  /// Poll until Cloudflare interstitial / error shell clears (Miruro-style).
  /// Does not bypass hard CF gates (Turnstile / 522); only waits for JS clear.
  final bool waitForCloudflare;
}
