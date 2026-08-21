import 'dart:convert';

import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted config for Live Matches → Forja Sports (RFC-062).
class LiveMatchesIptvSportsConfig {
  const LiveMatchesIptvSportsConfig({
    this.enabled = false,
    this.portalKey = '',
    this.timezone = '',
    this.leagues = const [],
    this.sportCategories = const {},
  });

  final bool enabled;
  /// [VerifiedPortal.key] of the chosen Xtream portal.
  /// Empty → fall back to IPTV’s last-selected portal ([resolvePortalKey]).
  final String portalKey;
  /// IANA timezone; empty → device local date for ESPN.
  final String timezone;
  final List<String> leagues;
  /// Sport-family / GLOBAL → Xtream live category ids.
  /// Keys: [sportFamilies] + `GLOBAL` (not per-league).
  final Map<String, List<String>> sportCategories;

  static const prefsKey = 'live_matches_iptv_sports_v1';

  static const allLeagues = <String>[
    'NBA',
    'NFL',
    'MLB',
    'NHL',
    'WNBA',
    'NCAAMB',
    'NCAAWB',
    'NCAAFB',
    'EPL',
    'MLS',
    'LALIGA',
    'WORLDCUP',
    'UFC',
  ];

  static const leagueLabels = <String, String>{
    'NBA': 'NBA',
    'NFL': 'NFL',
    'MLB': 'MLB',
    'NHL': 'NHL',
    'WNBA': 'WNBA',
    'NCAAMB': "NCAA Men's Basketball",
    'NCAAWB': "NCAA Women's Basketball",
    'NCAAFB': 'NCAA Football',
    'EPL': 'Premier League',
    'MLS': 'MLS',
    'LALIGA': 'La Liga',
    'WORLDCUP': 'FIFA World Cup',
    'UFC': 'UFC',
  };

  /// Folder-mapping buckets that match typical IPTV layouts (Soccer, NFL…).
  static const sportFamilies = <String>[
    'SOCCER',
    'BASKETBALL',
    'FOOTBALL',
    'BASEBALL',
    'HOCKEY',
    'MMA',
  ];

  static const _leagueToFamily = <String, String>{
    'NBA': 'BASKETBALL',
    'WNBA': 'BASKETBALL',
    'NCAAMB': 'BASKETBALL',
    'NCAAWB': 'BASKETBALL',
    'NFL': 'FOOTBALL',
    'NCAAFB': 'FOOTBALL',
    'MLB': 'BASEBALL',
    'NHL': 'HOCKEY',
    'EPL': 'SOCCER',
    'MLS': 'SOCCER',
    'LALIGA': 'SOCCER',
    'WORLDCUP': 'SOCCER',
    'UFC': 'MMA',
  };

  static String familyForLeague(String league) =>
      _leagueToFamily[league.toUpperCase()] ?? 'GLOBAL';

  bool get isReady =>
      enabled && portalKey.isNotEmpty && leagues.isNotEmpty;

  /// Portal resolved (config or IPTV last) and leagues to query (empty → all).
  Future<({String portalKey, List<String> leagues})?> resolveForFetch() async {
    final portal = await resolvePortalKey(this);
    if (portal.isEmpty) return null;
    final leagues = this.leagues.isEmpty
        ? List<String>.from(allLeagues)
        : List<String>.from(this.leagues);
    return (portalKey: portal, leagues: leagues);
  }

  /// True when a portal is available (Settings Enable is not required).
  Future<bool> isEffectivelyReady() async {
    return (await resolveForFetch()) != null;
  }

  /// Persist Enable + portal + default leagues so Settings matches the top bar.
  static Future<LiveMatchesIptvSportsConfig> ensureArmed({
    String? portalKey,
  }) async {
    final config = await load();
    final resolved = portalKey?.isNotEmpty == true
        ? portalKey!
        : await resolvePortalKey(config);
    var next = config.copyWith(enabled: true);
    if (resolved.isNotEmpty) {
      next = next.copyWith(portalKey: resolved);
    }
    if (next.leagues.isEmpty) {
      next = next.copyWith(leagues: List<String>.from(allLeagues));
    }
    if (next.enabled == config.enabled &&
        next.portalKey == config.portalKey &&
        _sameLeagues(next.leagues, config.leagues)) {
      return next;
    }
    await save(next);
    return next;
  }

  static bool _sameLeagues(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Configured override, else IPTV’s last-selected **Xtream** portal.
  static Future<String> resolvePortalKey([
    LiveMatchesIptvSportsConfig? config,
  ]) async {
    final c = config ?? await load();
    if (c.portalKey.isNotEmpty) return c.portalKey;
    final last = await IptvStore.loadLastPortalKey();
    if (last == null || last.isEmpty) return '';
    final portals = await IptvStore.load();
    for (final p in portals) {
      if (p.key == last &&
          p.portal.platform == IptvPortalPlatform.xtream) {
        return last;
      }
    }
    return '';
  }

  /// Category ids to search for an ESPN league code (e.g. `NBA`).
  List<String> categoryIdsForGame(String leagueOrSport) {
    final key = leagueOrSport.trim().toUpperCase();
    final family = _leagueToFamily[key] ??
        (sportFamilies.contains(key) ? key : familyForLeague(key));
    final sportIds = sportCategories[family] ?? const [];
    final global = sportCategories['GLOBAL'] ?? const [];
    return {...sportIds, ...global}.toList();
  }

  LiveMatchesIptvSportsConfig copyWith({
    bool? enabled,
    String? portalKey,
    String? timezone,
    List<String>? leagues,
    Map<String, List<String>>? sportCategories,
  }) {
    return LiveMatchesIptvSportsConfig(
      enabled: enabled ?? this.enabled,
      portalKey: portalKey ?? this.portalKey,
      timezone: timezone ?? this.timezone,
      leagues: leagues ?? this.leagues,
      sportCategories: sportCategories ?? this.sportCategories,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'portalKey': portalKey,
        'timezone': timezone,
        'leagues': leagues,
        'sportCategories': {
          for (final e in sportCategories.entries) e.key: e.value,
        },
      };

  /// Collapse legacy per-league keys (NBA, EPL, …) into sport families.
  static Map<String, List<String>> _normalizeCategoryMap(
    Map<String, List<String>> raw,
  ) {
    final out = <String, List<String>>{};
    void add(String key, Iterable<String> ids) {
      final bucket = out.putIfAbsent(key, () => <String>[]);
      for (final id in ids) {
        if (id.isNotEmpty && !bucket.contains(id)) bucket.add(id);
      }
    }

    for (final e in raw.entries) {
      final key = e.key.toUpperCase();
      if (key == 'GLOBAL' || sportFamilies.contains(key)) {
        add(key, e.value);
        continue;
      }
      // Old per-league storage → family.
      add(familyForLeague(key), e.value);
    }
    return out;
  }

  factory LiveMatchesIptvSportsConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LiveMatchesIptvSportsConfig();
    final leaguesRaw = j['leagues'];
    final leagues = <String>[];
    if (leaguesRaw is List) {
      for (final x in leaguesRaw) {
        final s = x?.toString().trim().toUpperCase() ?? '';
        if (s.isNotEmpty) leagues.add(s);
      }
    }
    final cats = <String, List<String>>{};
    final catsRaw = j['sportCategories'];
    if (catsRaw is Map) {
      for (final e in catsRaw.entries) {
        final key = e.key.toString().trim().toUpperCase();
        final ids = <String>[];
        final raw = e.value;
        if (raw is List) {
          for (final x in raw) {
            final id = x?.toString().trim() ?? '';
            if (id.isNotEmpty) ids.add(id);
          }
        }
        if (key.isNotEmpty) cats[key] = ids;
      }
    }
    return LiveMatchesIptvSportsConfig(
      enabled: j['enabled'] == true,
      portalKey: (j['portalKey'] ?? '').toString(),
      timezone: (j['timezone'] ?? '').toString(),
      leagues: leagues,
      sportCategories: _normalizeCategoryMap(cats),
    );
  }

  static Future<LiveMatchesIptvSportsConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return const LiveMatchesIptvSportsConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return LiveMatchesIptvSportsConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return LiveMatchesIptvSportsConfig.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return const LiveMatchesIptvSportsConfig();
  }

  static Future<void> save(LiveMatchesIptvSportsConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(config.toJson()));
  }
}
