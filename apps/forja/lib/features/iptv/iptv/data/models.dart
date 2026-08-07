// Models ported from Forja TV (Kotlin) IPTV system.
// Pure data classes - no Flutter dependencies.

import 'dart:math';

/// Random display names for portals (add-dialog dice button).
abstract final class IptvPortalName {
  static final _random = Random();

  static const _adjectives = [
    'France',
    'Nordic',
    'Pacific',
    'Atlas',
    'Aurora',
    'Cascade',
    'Delta',
    'Ember',
    'Horizon',
    'Lumen',
    'Nova',
    'Orbit',
    'Pulse',
    'Summit',
    'Velvet',
  ];

  static const _nouns = [
    'IPTV',
    'Stream',
    'Channels',
    'Playlist',
    'TV',
    'Live',
  ];

  static String generate() {
    final a = _adjectives[_random.nextInt(_adjectives.length)];
    final n = _nouns[_random.nextInt(_nouns.length)];
    return '$a $n';
  }
}

/// Portal subscription end — matches admin `formatPortalExpiry` / UI tone.
abstract final class IptvPortalExpiry {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _monthIndex = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  /// Normalize raw Xtream/Stalker/scrape expiry to `dd MMM yyyy`, or `Unknown`.
  static String format(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s.toLowerCase() == 'unknown') return 'Unknown';
    final d = parse(s);
    if (d == null) {
      if (RegExp(r'\b1970\b').hasMatch(s)) return 'Unknown';
      return s;
    }
    if (d.year <= 1970) return 'Unknown';
    final day = d.day.toString().padLeft(2, '0');
    return '$day ${_months[d.month - 1]} ${d.year}';
  }

  static DateTime? parse(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s.toLowerCase() == 'unknown') return null;

    if (RegExp(r'^\d+$').hasMatch(s)) {
      final n = int.tryParse(s);
      if (n == null) return null;
      final ms = n > 1000000000000 ? n : n * 1000;
      try {
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        return d.year <= 1970 ? null : d;
      } catch (_) {
        return null;
      }
    }

    // Reddit / dump cards: `24/01/2027 19:55:57` (DD/MM/YYYY).
    final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1)!);
      final month = int.tryParse(dmy.group(2)!);
      final year = int.tryParse(dmy.group(3)!);
      if (day != null &&
          month != null &&
          year != null &&
          year > 1970 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // `16 Feb 2027` / `16 February 2027`
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = _monthIndex[parts[1].toLowerCase()];
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null && year > 1970) {
        return DateTime(year, month, day);
      }
    }

    // `February 16, 2027` / `Feb 16 2027`
    final eng = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})',
    ).firstMatch(s);
    if (eng != null) {
      final month = _monthIndex[eng.group(1)!.toLowerCase()];
      final day = int.tryParse(eng.group(2)!);
      final year = int.tryParse(eng.group(3)!);
      if (day != null && month != null && year != null && year > 1970) {
        return DateTime(year, month, day);
      }
    }

    // ISO `2027-02-16` / `2027-02-16T…`
    final iso = DateTime.tryParse(s);
    if (iso != null && iso.year > 1970) return iso;
    return null;
  }
}

/// Helpers for the MAC address a Stalker/Ministra portal authenticates
/// against — MAG-style set-top-box MACs.
abstract final class StalkerMac {
  /// The MAG vendor OUI prefix portals expect. The trailing three octets
  /// identify the (virtual) device and are what the provider binds the
  /// subscription to.
  static const prefix = '00:1A:79';

  static final _random = Random.secure();

  /// Generates a random MAG-style MAC, e.g. `00:1A:79:3F:A2:0B`. Offered as
  /// the add-portal default so a user without a provider-issued MAC still
  /// gets a well-formed one.
  static String generate() {
    final octets = List.generate(
      3,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase(),
    );
    return '$prefix:${octets.join(':')}';
  }

  /// Whether a string is a syntactically valid `XX:XX:XX:XX:XX:XX` MAC.
  /// Accepts upper- or lower-case hex; the portal is case-insensitive.
  static bool isValid(String mac) =>
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(mac.trim());
}

/// Portal protocol — xtream player_api, M3U playlist, or Stalker/Ministra.
enum IptvPortalPlatform {
  xtream,
  m3u,
  stalker;

  static const m3uUsernameSentinel = '__m3u__';

  static IptvPortalPlatform fromString(String? raw) => switch (raw?.trim().toLowerCase()) {
        'm3u' => m3u,
        'stalker' => stalker,
        _ => xtream,
      };

  String get wire => name;

  bool get supportsVodSeries => this == xtream || this == stalker;
}

/// Raw scraped Xtream-Codes portal credentials (unverified).
class IptvPortal {
  final String url;
  final String username;
  final String password;
  final String source;
  final IptvPortalPlatform platform;
  /// Optional User-Agent for M3U fetch / play.
  final String userAgent;

  const IptvPortal({
    required this.url,
    required this.username,
    required this.password,
    this.source = '',
    this.platform = IptvPortalPlatform.xtream,
    this.userAgent = '',
  });

  String get key =>
      '${platform.wire}|$url|$username|$password'.toLowerCase();

  /// Identity for duplicate-portal checks.
  /// Xtream / Stalker: ignores URL (same account can live on multiple hosts).
  /// M3U: includes URL — every playlist shares the `__m3u__` sentinel, so
  /// username|password alone would collapse all playlists into one identity.
  String get credKey {
    final base = '${platform.wire}|$username|$password'.toLowerCase();
    if (platform == IptvPortalPlatform.m3u) {
      return '$base|${url.trim().toLowerCase()}';
    }
    return base;
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'source': source,
        'platform': platform.wire,
        if (userAgent.isNotEmpty) 'userAgent': userAgent,
      };

  factory IptvPortal.fromJson(Map<String, dynamic> j) => IptvPortal(
        url: j['url'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        source: j['source'] as String? ?? '',
        platform: IptvPortalPlatform.fromString(j['platform'] as String?),
        userAgent: j['userAgent'] as String? ?? j['user_agent'] as String? ?? '',
      );
}

/// Portal that successfully authenticated against /player_api.php.
class VerifiedPortal {
  final IptvPortal portal;
  /// User-chosen display name (optional). Empty falls back via [displayLabel].
  final String label;
  final String name;
  final String expiry;
  final String maxConnections;
  final String activeConnections;

  const VerifiedPortal({
    required this.portal,
    this.label = '',
    required this.name,
    required this.expiry,
    required this.maxConnections,
    required this.activeConnections,
  });

  String get key => portal.key;
  String get credKey => portal.credKey;

  /// Prefer user [label], then Xtream [name], then username.
  String get displayLabel {
    final l = label.trim();
    if (l.isNotEmpty) return l;
    final n = name.trim();
    if (n.isNotEmpty) return n;
    final u = portal.username.trim();
    return u.isEmpty ? 'Portal' : u;
  }

  IptvPortalPlatform get platform => portal.platform;

  VerifiedPortal withLabel(String label) => VerifiedPortal(
        portal: portal,
        label: label.trim(),
        name: name,
        expiry: expiry,
        maxConnections: maxConnections,
        activeConnections: activeConnections,
      );

  /// Keep credentials + user [label]; refresh account fields from a login probe.
  VerifiedPortal withAccountFrom(VerifiedPortal fresh) => VerifiedPortal(
        portal: portal,
        label: label,
        name: fresh.name,
        expiry: fresh.expiry,
        maxConnections: fresh.maxConnections,
        activeConnections: fresh.activeConnections,
      );

  bool sameAccountFields(VerifiedPortal other) =>
      name == other.name &&
      expiry == other.expiry &&
      maxConnections == other.maxConnections &&
      activeConnections == other.activeConnections;
}

class IptvCategory {
  final String id;
  final String name;
  const IptvCategory({required this.id, required this.name});
}

/// Synthetic Live sidebar rows (not from the portal API).
abstract final class IptvLiveCatalog {
  static const favoritesId = '__favorites__';
  static const watchedId = '__watched__';
  static const watchedLimit = 30;

  static const favorites = IptvCategory(id: favoritesId, name: 'Favorites');
  static const watched =
      IptvCategory(id: watchedId, name: 'Already watched');

  static bool isSyntheticId(String id) =>
      id == favoritesId || id == watchedId;

  /// Synthetic Favorites / Already watched (not user-pinned API groups).
  static bool isPinnedId(String id) => isSyntheticId(id);

  static List<IptvCategory> withPins(List<IptvCategory> apiCategories) => [
        favorites,
        watched,
        ...apiCategories,
      ];
}

/// Portal group ids synthesized by the Rust Xtream client when categories
/// are missing. Host keeps the id constant for sidebar filtering.
abstract final class IptvCatalogOrphans {
  static const uncategorizedId = '__uncategorized__';

  static bool isUncategorizedId(String id) => id == uncategorizedId;

  static bool streamMatchesCategory(IptvStream stream, String categoryId) {
    if (isUncategorizedId(categoryId)) return stream.categoryId.isEmpty;
    return stream.categoryId == categoryId;
  }
}

enum IptvSection { live, vod, series }

/// How the browser shows catalog fetch progress.
enum IptvCatalogLoadStyle {
  /// Idle / cache hit applied instantly. Reload uses [IptvController.isLoading] spinner.
  none,

  /// Cold portal/shelf load - progress bar + live counts.
  verbose,
}

/// Active step while [IptvCatalogLoadStyle.verbose] is showing.
enum IptvCatalogLoadStep {
  categories,
  channels,
  movies,
  series,
  finished,
}

/// Live counts shown on the catalog loading panel.
class IptvCatalogLoadProgress {
  const IptvCatalogLoadProgress({
    this.categoryCount = 0,
    this.channelCount = 0,
    this.movieCount = 0,
    this.seriesCount = 0,
    this.fraction = 0,
    this.finished = false,
  });

  final int categoryCount;
  final int channelCount;
  final int movieCount;
  final int seriesCount;

  /// 0–1 overall progress.
  final double fraction;
  final bool finished;

  static const empty = IptvCatalogLoadProgress();

  Map<String, dynamic> toStatsJson() => {
        'categories': categoryCount,
        'channels': channelCount,
        'movies': movieCount,
        'series': seriesCount,
      };

  factory IptvCatalogLoadProgress.fromStatsJson(Map<String, dynamic> json) =>
      IptvCatalogLoadProgress(
        categoryCount: (json['categories'] as num?)?.toInt() ?? 0,
        channelCount: (json['channels'] as num?)?.toInt() ?? 0,
        movieCount: (json['movies'] as num?)?.toInt() ?? 0,
        seriesCount: (json['series'] as num?)?.toInt() ?? 0,
        fraction: 1,
        finished: true,
      );

  bool get hasAnyCount =>
      categoryCount > 0 ||
      channelCount > 0 ||
      movieCount > 0 ||
      seriesCount > 0;

  IptvCatalogLoadProgress copyWith({
    int? categoryCount,
    int? channelCount,
    int? movieCount,
    int? seriesCount,
    double? fraction,
    bool? finished,
  }) =>
      IptvCatalogLoadProgress(
        categoryCount: categoryCount ?? this.categoryCount,
        channelCount: channelCount ?? this.channelCount,
        movieCount: movieCount ?? this.movieCount,
        seriesCount: seriesCount ?? this.seriesCount,
        fraction: fraction ?? this.fraction,
        finished: finished ?? this.finished,
      );
}

/// Live catalog sort - playlist = API order; nameAsc/nameDesc by display name.
enum IptvCatalogSort {
  playlist,
  nameAsc,
  nameDesc;

  static IptvCatalogSort fromPrefs(String? raw) => switch (raw) {
        'nameAsc' => nameAsc,
        'nameDesc' => nameDesc,
        _ => playlist,
      };

  String get prefsValue => name;
}

/// Live catalog channel pane layout - cards (default) or EPG timeline guide.
enum IptvLiveBrowseLayout {
  cards,
  guide;

  static IptvLiveBrowseLayout fromPrefs(String? raw) =>
      raw == 'guide' ? guide : cards;

  String get prefsValue => name;
}

/// Single playable stream entry. `kind` = "live" / "vod" / "series".
class IptvStream {
  final String streamId;
  final String name;
  final String icon;
  final String categoryId;
  final String containerExt;
  final String kind;
  /// Xtream `epg_channel_id` - empty when the panel doesn't ship EPG for this
  /// channel. We don't actually need it for `get_short_epg` (that endpoint is
  /// indexed by stream_id) but it's a useful "has EPG?" hint to skip cards.
  final String epgChannelId;

  const IptvStream({
    required this.streamId,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.containerExt,
    required this.kind,
    this.epgChannelId = '',
  });
}

/// Single EPG programme entry returned by Xtream `get_short_epg`.
class EpgEntry {
  final String title;
  final String description;
  final DateTime start;
  final DateTime stop;
  const EpgEntry({
    required this.title,
    required this.description,
    required this.start,
    required this.stop,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }
}

class IptvEpisode {
  final String id;
  final String title;
  final String containerExt;
  final int season;
  final int episode;
  final String plot;
  final String image;

  const IptvEpisode({
    required this.id,
    required this.title,
    required this.containerExt,
    required this.season,
    required this.episode,
    required this.plot,
    required this.image,
  });
}

/// A single alive stream found while resolving a HardcodedChannel.
class ChannelHit {
  final VerifiedPortal portal;
  final IptvStream stream;
  final String streamUrl;

  const ChannelHit({
    required this.portal,
    required this.stream,
    required this.streamUrl,
  });
}

class ScrapePage {
  final List<IptvPortal> portals;
  final String? nextAfter;
  const ScrapePage({required this.portals, this.nextAfter});
  bool get hasMore => nextAfter != null && nextAfter!.isNotEmpty;
}
