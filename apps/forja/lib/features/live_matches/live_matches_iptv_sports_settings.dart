import 'dart:convert';

import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/live_matches/live_matches_sport_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted config for Live Matches → Forja Sports (RFC-062).
class LiveMatchesIptvSportsConfig {
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
    'SERIEA',
    'BUNDESLIGA',
    'LIGUE1',
    'UCL',
    'EUROPA',
    'EREDIVISIE',
    'LIGAPORTUGAL',
    'LIGAMX',
    'WORLDCUP',
    'UFC',
  ];

  const LiveMatchesIptvSportsConfig({
    this.enabled = true,
    this.forjaLiveEnabled = true,
    this.portalKey = '',
    this.timezone = '',
    this.leagues = allLeagues,
    this.sportCategories = const {},
  });

  final bool enabled;
  /// Live Matches → **Forja Live** server (engine catalogs + resolve).
  final bool forjaLiveEnabled;
  /// [VerifiedPortal.key] of the chosen Xtream/Stalker portal.
  /// Empty → fall back to IPTV’s last-selected portal ([resolvePortalKey]).
  final String portalKey;
  /// IANA timezone; empty → device local date for ESPN.
  final String timezone;
  final List<String> leagues;
  /// Sport-family / GLOBAL → Xtream live category ids.
  /// Keys: [sportFamilies] + `GLOBAL` (not per-league).
  final Map<String, List<String>> sportCategories;

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
    'SERIEA': 'Serie A',
    'BUNDESLIGA': 'Bundesliga',
    'LIGUE1': 'Ligue 1',
    'UCL': 'Champions League',
    'EUROPA': 'Europa League',
    'EREDIVISIE': 'Eredivisie',
    'LIGAPORTUGAL': 'Primeira Liga',
    'LIGAMX': 'Liga MX',
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
    'MOTORSPORTS',
    'GOLF',
    'TENNIS',
    'COMBAT',
    'RUGBY',
    'CRICKET',
    'LACROSSE',
  ];

  /// Live Matches catalog sport chip → IPTV portal folder bucket.
  static const catalogSportToFamily = <String, String>{
    'motor-sports': 'MOTORSPORTS',
    'motorsports': 'MOTORSPORTS',
    'formula-1': 'MOTORSPORTS',
    'f1': 'MOTORSPORTS',
    'racing': 'MOTORSPORTS',
    'nascar': 'MOTORSPORTS',
    'golf': 'GOLF',
    'tennis': 'TENNIS',
    'fight': 'COMBAT',
    'combat-sports': 'COMBAT',
    'boxing': 'COMBAT',
    'wrestling': 'COMBAT',
    'wwe': 'COMBAT',
    'aew': 'COMBAT',
    'rugby': 'RUGBY',
    'cricket': 'CRICKET',
    'lacrosse': 'LACROSSE',
    'australian-football': 'FOOTBALL',
    'american-football': 'FOOTBALL',
    'football': 'SOCCER',
    'basketball': 'BASKETBALL',
    'hockey': 'HOCKEY',
    'baseball': 'BASEBALL',
    'other': 'GLOBAL',
  };

  static const sportFamilyLabels = <String, String>{
    'SOCCER': 'Soccer',
    'BASKETBALL': 'Basketball',
    'FOOTBALL': 'Football',
    'BASEBALL': 'Baseball',
    'HOCKEY': 'Hockey',
    'MMA': 'MMA',
    'MOTORSPORTS': 'Motorsports',
    'GOLF': 'Golf',
    'TENNIS': 'Tennis',
    'COMBAT': 'Combat',
    'RUGBY': 'Rugby',
    'CRICKET': 'Cricket',
    'LACROSSE': 'Lacrosse',
    'GLOBAL': 'Global (all live)',
  };

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
    'SERIEA': 'SOCCER',
    'BUNDESLIGA': 'SOCCER',
    'LIGUE1': 'SOCCER',
    'UCL': 'SOCCER',
    'EUROPA': 'SOCCER',
    'EREDIVISIE': 'SOCCER',
    'LIGAPORTUGAL': 'SOCCER',
    'LIGAMX': 'SOCCER',
    'WORLDCUP': 'SOCCER',
    'UFC': 'MMA',
  };

  static String familyForLeague(String league) =>
      _leagueToFamily[league.toUpperCase()] ?? 'GLOBAL';

  static String familyForCatalogSport(String raw) {
    final slug = normalizeLiveSportId(raw);
    return catalogSportToFamily[slug] ??
        catalogSportToFamily[raw.trim().toLowerCase()] ??
        'GLOBAL';
  }

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

  /// Persist portal + default leagues for Xtream matching (does not toggle Enable).
  static Future<LiveMatchesIptvSportsConfig> ensureArmed({
    String? portalKey,
  }) async {
    final config = await load();
    final resolved = portalKey?.isNotEmpty == true
        ? portalKey!
        : await resolvePortalKey(config);
    var next = config;
    if (resolved.isNotEmpty) {
      next = next.copyWith(portalKey: resolved);
    }
    if (next.leagues.isEmpty) {
      next = next.copyWith(leagues: List<String>.from(allLeagues));
    }
    if (next.portalKey == config.portalKey &&
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

  /// Configured override, else IPTV’s last-selected Xtream/Stalker portal.
  static Future<String> resolvePortalKey([
    LiveMatchesIptvSportsConfig? config,
  ]) async {
    final c = config ?? await load();
    if (c.portalKey.isNotEmpty) return c.portalKey;
    final last = await IptvStore.loadLastPortalKey();
    if (last == null || last.isEmpty) return '';
    final portals = await IptvStore.load();
    for (final p in portals) {
      if (p.key == last && p.portal.platform.supportsForjaSports) {
        return last;
      }
    }
    return '';
  }

  /// Category ids to search for an ESPN league code or Live Matches sport chip.
  List<String> categoryIdsForGame(String leagueOrSport) {
    final key = leagueOrSport.trim().toUpperCase();
    final slug = normalizeLiveSportId(leagueOrSport);
    final family = _leagueToFamily[key] ??
        catalogSportToFamily[slug] ??
        (sportFamilies.contains(key) ? key : familyForCatalogSport(leagueOrSport));
    final sportIds = sportCategories[family] ?? const [];
    final global = sportCategories['GLOBAL'] ?? const [];
    return {...sportIds, ...global}.toList();
  }

  LiveMatchesIptvSportsConfig copyWith({
    bool? enabled,
    bool? forjaLiveEnabled,
    String? portalKey,
    String? timezone,
    List<String>? leagues,
    Map<String, List<String>>? sportCategories,
  }) {
    return LiveMatchesIptvSportsConfig(
      enabled: enabled ?? this.enabled,
      forjaLiveEnabled: forjaLiveEnabled ?? this.forjaLiveEnabled,
      portalKey: portalKey ?? this.portalKey,
      timezone: timezone ?? this.timezone,
      leagues: leagues ?? this.leagues,
      sportCategories: sportCategories ?? this.sportCategories,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'forjaLiveEnabled': forjaLiveEnabled,
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
      forjaLiveEnabled: j['forjaLiveEnabled'] != false,
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
      return const LiveMatchesIptvSportsConfig(
        enabled: true,
        forjaLiveEnabled: true,
        leagues: allLeagues,
      );
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
