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
  /// Order matters when [rotateBeforeComplete] is true — earlier labels are
  /// preferred (e.g. VidSrc.sbs `pro multi` before default `star`).
  final List<String> serverChipLabels;

  /// Do not early-complete on the default server's first `.m3u8`. Keep rotating
  /// chips and only finish after a server switch (or timeout with best capture).
  /// Used when the site default (e.g. VidSrc.sbs Star/1embed) emits dead streams.
  final bool rotateBeforeComplete;

  /// Accept `/api/proxy?…` URLs whose response body was `#EXTM3U`.
  final bool acceptProxyPlaylistBodies;

  /// If FRAME host contains one of these, use the canonical embed as Referer.
  final List<String> cdnHostsPreferEmbedReferer;

  /// Attach WebView cookies to playback headers before probe/open.
  final bool harvestCookies;

  /// Do not complete until an audio URL was also sniffed (legacy Anitaro).
  final bool completeOnlyWithAudio;
}
