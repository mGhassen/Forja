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
  final List<String> serverChipLabels;

  /// Accept `/api/proxy?…` URLs whose response body was `#EXTM3U`.
  final bool acceptProxyPlaylistBodies;

  /// If FRAME host contains one of these, use the canonical embed as Referer.
  final List<String> cdnHostsPreferEmbedReferer;

  /// Attach WebView cookies to playback headers before probe/open.
  final bool harvestCookies;

  /// Do not complete until an audio URL was also sniffed (legacy Anitaro).
  final bool completeOnlyWithAudio;
}

/// Registry — one profile per HostRequired template provider (plus shared default).
abstract final class EmbedExtractProfiles {
  static const generic = EmbedExtractProfile(
    id: '_generic',
    timeout: Duration(seconds: 45),
  );

  static const _templateTimeout = Duration(seconds: 60);

  static final Map<String, EmbedExtractProfile> catalog = {
    'vidlink': const EmbedExtractProfile(
      id: 'vidlink',
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
    ),
    'vixsrc': const EmbedExtractProfile(
      id: 'vixsrc',
      timeout: _templateTimeout,
    ),
    'vidnest': const EmbedExtractProfile(
      id: 'vidnest',
      timeout: _templateTimeout,
    ),
    'vidzee': const EmbedExtractProfile(
      id: 'vidzee',
      timeout: _templateTimeout,
    ),
    'vidrock': const EmbedExtractProfile(
      id: 'vidrock',
      timeout: _templateTimeout,
    ),
    'vidfast': const EmbedExtractProfile(
      id: 'vidfast',
      timeout: _templateTimeout,
    ),
    '2embed': const EmbedExtractProfile(
      id: '2embed',
      timeout: _templateTimeout,
    ),
    'superembed': const EmbedExtractProfile(
      id: 'superembed',
      timeout: _templateTimeout,
    ),
    'autoembed': const EmbedExtractProfile(
      id: 'autoembed',
      timeout: _templateTimeout,
    ),
    'vidlove': const EmbedExtractProfile(
      id: 'vidlove',
      forceDirect: true,
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
      rotateServerChips: true,
      serverChipLabels: ['neta', 'gogo', 'mafia', 'fabric'],
      cdnHostsPreferEmbedReferer: [
        'hydrastreaming',
        'goodstream',
        'cinezo',
      ],
    ),
    '111movies': const EmbedExtractProfile(
      id: '111movies',
      forceDirect: true,
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
      rotateServerChips: true,
      serverChipLabels: ['neta', 'gogo', 'mafia', 'fabric'],
      cdnHostsPreferEmbedReferer: [
        'hydrastreaming',
        'goodstream',
        'cinezo',
      ],
    ),
    'vidsrcsbs': const EmbedExtractProfile(
      id: 'vidsrcsbs',
      forceDirect: true,
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
      acceptProxyPlaylistBodies: true,
      cdnHostsPreferEmbedReferer: [
        'cinezo',
        'goodstream',
        '1embed',
      ],
    ),
    'moviesapi': const EmbedExtractProfile(
      id: 'moviesapi',
      timeout: _templateTimeout,
    ),
    'smashystream': const EmbedExtractProfile(
      id: 'smashystream',
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
    ),
    'primewire': const EmbedExtractProfile(
      id: 'primewire',
      timeout: _templateTimeout,
    ),
    // Host sniff fallback for Videasy when HTTP mirrors fail.
    'videasy': const EmbedExtractProfile(
      id: 'videasy',
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
    ),
    // Legacy / rare host sniff callers.
    'vidsrc': const EmbedExtractProfile(
      id: 'vidsrc',
      timeout: _templateTimeout,
    ),
    'anitaro': const EmbedExtractProfile(
      id: 'anitaro',
      timeout: _templateTimeout,
      deferUntilStrongStream: true,
      completeOnlyWithAudio: true,
    ),
  };

  static EmbedExtractProfile resolve(String? providerId) {
    if (providerId == null || providerId.trim().isEmpty) return generic;
    return catalog[providerId] ??
        EmbedExtractProfile(
          id: providerId,
          timeout: generic.timeout,
        );
  }

  /// Template HostRequired IDs that must have an explicit catalog entry.
  static const requiredTemplateIds = <String>[
    'vidlink',
    'vixsrc',
    'vidnest',
    'vidzee',
    'vidrock',
    'vidfast',
    '2embed',
    'superembed',
    'autoembed',
    'vidlove',
    'vidsrcsbs',
    '111movies',
    'moviesapi',
    'smashystream',
    'primewire',
  ];
}
