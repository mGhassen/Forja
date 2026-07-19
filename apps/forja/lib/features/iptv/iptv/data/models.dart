// Models ported from Forja TV (Kotlin) IPTV system.
// Pure data classes - no Flutter dependencies.

/// Raw scraped Xtream-Codes portal credentials (unverified).
class IptvPortal {
  final String url;
  final String username;
  final String password;
  final String source;

  const IptvPortal({
    required this.url,
    required this.username,
    required this.password,
    this.source = '',
  });

  String get key => '$url|$username|$password'.toLowerCase();

  /// Identity for duplicate-portal checks: ignores URL, since the same
  /// account can be exposed on multiple host names.
  String get credKey => '$username|$password'.toLowerCase();

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'source': source,
      };

  factory IptvPortal.fromJson(Map<String, dynamic> j) => IptvPortal(
        url: j['url'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        source: j['source'] as String? ?? '',
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

  /// Favorites + Already watched stay pinned above portal groups.
  static bool isPinnedId(String id) => isSyntheticId(id);

  static List<IptvCategory> withPins(List<IptvCategory> apiCategories) => [
        favorites,
        watched,
        ...apiCategories,
      ];
}

enum IptvSection { live, vod, series }

/// Live catalog sort — playlist = API order; nameAsc/nameDesc by display name.
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

/// Live catalog channel pane layout — cards (default) or EPG timeline guide.
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
  /// Xtream `epg_channel_id` — empty when the panel doesn't ship EPG for this
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
