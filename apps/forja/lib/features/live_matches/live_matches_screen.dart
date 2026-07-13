import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:rust/rust.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _Sport {
  final String id;
  final String name;
  const _Sport({required this.id, required this.name});
}

class _CdnChannel {
  final String name;
  final String code;
  final String url;
  final String image;
  final String status;
  final int viewers;

  const _CdnChannel({
    required this.name,
    required this.code,
    required this.url,
    required this.image,
    required this.status,
    required this.viewers,
  });

  factory _CdnChannel.fromJson(Map<String, dynamic> j) => _CdnChannel(
    name: (j['name'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    image: (j['image'] ?? '').toString(),
    status: (j['status'] ?? 'offline').toString(),
    viewers: (j['viewers'] as num?)?.toInt() ?? 0,
  );
}

class _CdnSportEvent {
  final String gameID;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamIMG;
  final String awayTeamIMG;
  final String time;
  final String tournament;
  final String country;
  final String countryIMG;
  final String status;
  final String start;
  final String end;
  final List<_CdnChannel> channels;

  const _CdnSportEvent({
    required this.gameID,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamIMG,
    required this.awayTeamIMG,
    required this.time,
    required this.tournament,
    required this.country,
    required this.countryIMG,
    required this.status,
    required this.start,
    required this.end,
    required this.channels,
  });

  factory _CdnSportEvent.fromJson(Map<String, dynamic> j) => _CdnSportEvent(
    gameID: (j['gameID'] ?? '').toString(),
    homeTeam: (j['homeTeam'] ?? '').toString(),
    awayTeam: (j['awayTeam'] ?? '').toString(),
    homeTeamIMG: (j['homeTeamIMG'] ?? '').toString(),
    awayTeamIMG: (j['awayTeamIMG'] ?? '').toString(),
    time: (j['time'] ?? '').toString(),
    tournament: (j['tournament'] ?? '').toString(),
    country: (j['country'] ?? '').toString(),
    countryIMG: (j['countryIMG'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    start: (j['start'] ?? '').toString(),
    end: (j['end'] ?? '').toString(),
    channels: (j['channels'] as List? ?? [])
        .map((c) => _CdnChannel.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  bool get isLive => status.toLowerCase() == 'live';
}

class _DamiTvStream {
  final String id;
  final String name;
  final String poster;
  final int startsAt;
  final int endsAt;
  final String categoryName;
  final String status;
  final String league;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;
  final int viewers;
  final String iframe;

  const _DamiTvStream({
    required this.id,
    required this.name,
    required this.poster,
    required this.startsAt,
    required this.endsAt,
    required this.categoryName,
    required this.status,
    required this.league,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
    required this.viewers,
    required this.iframe,
  });

  factory _DamiTvStream.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;

    String abs(String path) {
      if (path.startsWith('/')) return 'https://ppv.is$path';
      return path;
    }

    final league = (j['league'] ?? j['tag'] ?? j['source_tag'] ?? '')
        .toString();
    final viewersRaw = j['viewers'];
    final viewers = viewersRaw is num
        ? viewersRaw.toInt()
        : int.tryParse(viewersRaw?.toString() ?? '') ?? 0;

    return _DamiTvStream(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      poster: abs((j['poster'] ?? '').toString()),
      startsAt: (j['starts_at'] as num?)?.toInt() ?? 0,
      endsAt: (j['ends_at'] as num?)?.toInt() ?? 0,
      categoryName: (j['category_name'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      league: league,
      homeTeam: home?['name'] as String?,
      homeBadge: abs((home?['badge'] ?? '').toString()),
      awayTeam: away?['name'] as String?,
      awayBadge: abs((away?['badge'] ?? '').toString()),
      viewers: viewers,
      iframe: (j['iframe'] ?? '').toString(),
    );
  }

  bool get isAlwaysOn => startsAt == 0 && endsAt == 0 && iframe.isNotEmpty;

  String get timeLabel {
    if (isAlwaysOn) return 'live';

    final statusLower = status.toLowerCase();
    if (statusLower == 'live') return 'live';

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (startsAt > 0 && endsAt > startsAt && now >= startsAt && now <= endsAt) {
      return 'live';
    }
    if (startsAt > now) {
      final dt = DateTime.fromMillisecondsSinceEpoch(startsAt * 1000);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  bool get isLive {
    if (isAlwaysOn) return true;

    final statusLower = status.toLowerCase();
    if (statusLower == 'live') return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return startsAt > 0 &&
        endsAt > startsAt &&
        now >= startsAt &&
        now <= endsAt;
  }
}

class _StreamedSourceRef {
  final String source;
  final String id;
  const _StreamedSourceRef({required this.source, required this.id});

  factory _StreamedSourceRef.fromJson(Map<String, dynamic> j) =>
      _StreamedSourceRef(
        source: (j['source'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
      );
}

class _StreamedMatch {
  final String id;
  final String title;
  final String category;
  final int dateMs;
  final String poster;
  final bool popular;
  final String? homeTeam;
  final String? homeBadge;
  final String? awayTeam;
  final String? awayBadge;
  final List<_StreamedSourceRef> sources;

  const _StreamedMatch({
    required this.id,
    required this.title,
    required this.category,
    required this.dateMs,
    required this.poster,
    required this.popular,
    this.homeTeam,
    this.homeBadge,
    this.awayTeam,
    this.awayBadge,
    required this.sources,
  });

  factory _StreamedMatch.fromJson(Map<String, dynamic> j) {
    final teams = j['teams'] as Map<String, dynamic>?;
    final home = teams?['home'] as Map<String, dynamic>?;
    final away = teams?['away'] as Map<String, dynamic>?;

    return _StreamedMatch(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      dateMs: (j['date'] as num?)?.toInt() ?? 0,
      poster: (j['poster'] ?? '').toString(),
      popular: j['popular'] == true,
      homeTeam: home?['name'] as String?,
      homeBadge: home?['badge'] as String?,
      awayTeam: away?['name'] as String?,
      awayBadge: away?['badge'] as String?,
      sources: (j['sources'] as List? ?? [])
          .map((s) => _StreamedSourceRef.fromJson(s as Map<String, dynamic>))
          .where((s) => s.source.isNotEmpty && s.id.isNotEmpty)
          .toList(),
    );
  }

  String get categoryLabel =>
      category.isEmpty ? 'Other' : category.replaceAll('-', ' ');

  bool get isAlwaysOn => dateMs == 0 && sources.isNotEmpty;

  String get timeLabel {
    if (isAlwaysOn) return 'live';

    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    if (delta.inMinutes >= 0 && delta.inHours < 6) return 'live';
    if (dt.isAfter(now)) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  bool get isLive {
    if (isAlwaysOn) return true;

    if (dateMs <= 0) return false;
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final now = DateTime.now();
    final delta = now.difference(dt);
    return delta.inMinutes >= 0 && delta.inHours < 6;
  }
}

class _StreamedStream {
  final String id;
  final int streamNo;
  final String language;
  final bool hd;
  final String embedUrl;
  final String source;
  final int viewers;

  const _StreamedStream({
    required this.id,
    required this.streamNo,
    required this.language,
    required this.hd,
    required this.embedUrl,
    required this.source,
    required this.viewers,
  });

  factory _StreamedStream.fromJson(Map<String, dynamic> j) => _StreamedStream(
    id: (j['id'] ?? '').toString(),
    streamNo: (j['streamNo'] as num?)?.toInt() ?? 0,
    language: (j['language'] ?? '').toString(),
    hd: j['hd'] == true,
    embedUrl: (j['embedUrl'] ?? '').toString(),
    source: (j['source'] ?? '').toString(),
    viewers: (j['viewers'] as num?)?.toInt() ?? 0,
  );

  String get label {
    final parts = <String>['Stream ${streamNo > 0 ? streamNo : 1}'];
    if (language.isNotEmpty) parts.add(language);
    if (hd) parts.add('HD');
    if (source.isNotEmpty) parts.add(source);
    if (viewers > 0) parts.add('$viewers viewers');
    return parts.join(' · ');
  }
}

int _liveFirstCompare({
  required bool aLive,
  required bool bLive,
  required int aStart,
  required int bStart,
}) {
  if (aLive != bLive) return aLive ? -1 : 1;
  return aStart.compareTo(bStart);
}

List<_DamiTvStream> _sortDamiTvLiveFirst(List<_DamiTvStream> items) {
  final sorted = List<_DamiTvStream>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.startsAt,
      bStart: b.startsAt,
    ),
  );
  return sorted;
}

List<_StreamedMatch> _sortStreamedLiveFirst(List<_StreamedMatch> items) {
  final sorted = List<_StreamedMatch>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: a.dateMs,
      bStart: b.dateMs,
    ),
  );
  return sorted;
}

int _cdnSportStartKey(_CdnSportEvent event) =>
    int.tryParse(event.start) ?? int.tryParse(event.time) ?? 0;

List<_CdnSportEvent> _sortCdnSportsLiveFirst(List<_CdnSportEvent> items) {
  final sorted = List<_CdnSportEvent>.from(items);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: a.isLive,
      bLive: b.isLive,
      aStart: _cdnSportStartKey(a),
      bStart: _cdnSportStartKey(b),
    ),
  );
  return sorted;
}

bool _gridEntryIsLive(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.isLive,
  _LiveMatchGridEntryStreamed(:final match) => match.isLive,
  _LiveMatchGridEntryCdnSport(:final event) => event.isLive,
};

int _gridEntryStartKey(_LiveMatchGridEntry entry) => switch (entry) {
  _LiveMatchGridEntryPpv(:final stream) => stream.startsAt,
  _LiveMatchGridEntryStreamed(:final match) => match.dateMs,
  _LiveMatchGridEntryCdnSport(:final event) => _cdnSportStartKey(event),
};

List<_LiveMatchGridEntry> _sortGridEntriesLiveFirst(
  List<_LiveMatchGridEntry> entries,
) {
  final sorted = List<_LiveMatchGridEntry>.from(entries);
  sorted.sort(
    (a, b) => _liveFirstCompare(
      aLive: _gridEntryIsLive(a),
      bLive: _gridEntryIsLive(b),
      aStart: _gridEntryStartKey(a),
      bStart: _gridEntryStartKey(b),
    ),
  );
  return sorted;
}

// ─── API helpers ──────────────────────────────────────────────────────────────

const _ua = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json',
  'Origin': 'https://ppv.is',
  'Referer': 'https://ppv.is/',
};

const _ppvStreamApis = [
  'https://api.ppv.st/api/streams',
  'https://api.ppv.cx/api/streams',
];

/// Force play on embed players that gate behind a gesture / big-play overlay.
/// One retry only — repeated clicks restart playback and cause visible stutter.
const _autoplayJs = r'''
(function () {
  function clickPlay() {
    var sels = [
      'video',
      '.vjs-big-play-button',
      '.jw-icon-display',
      '.plyr__control--overlaid',
      'button[aria-label*="Play"]',
      'button[title*="Play"]',
      '.play-button',
      '#big_play_button'
    ];
    for (var i = 0; i < sels.length; i++) {
      try {
        var nodes = document.querySelectorAll(sels[i]);
        for (var j = 0; j < nodes.length; j++) {
          var el = nodes[j];
          if (el.tagName === 'VIDEO') {
            el.setAttribute('autoplay', '');
            el.muted = false;
            var p = el.play();
            if (p && p.catch) {
              p.catch(function () {
                el.muted = true;
                el.play().catch(function () {});
              });
            }
          } else if (typeof el.click === 'function') {
            el.click();
          }
        }
      } catch (_) {}
    }
  }
  clickPlay();
  setTimeout(clickPlay, 1500);
})();
''';

/// Double-click the embed surface → toggle host fullscreen (films / IPTV parity).
const _dblclickFullscreenJs = r'''
(function () {
  if (window.__forjaDblFs) return;
  window.__forjaDblFs = true;
  document.addEventListener('dblclick', function () {
    try {
      window.flutter_inappwebview.callHandler('toggleFullscreen');
    } catch (_) {}
  }, true);
})();
''';

const _ppvReferer = 'https://ppv.is/';
const _streamedBase = 'https://streamed.pk';
const _streamedReferer = 'https://streamed.pk/';

const _streamedUa = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json',
  'Origin': _streamedBase,
  'Referer': _streamedReferer,
};

String _streamedImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '$_streamedBase$path';
  return '$_streamedBase/api/images/badge/$path.webp';
}

/// embedindia JW Player resolves tokenised HLS inside the embed browsing
/// context. The sniffed m3u8 403s in mpv — same as copying the URL into VLC.
bool _ppvEmbedRequiresWebView(String embedUrl) {
  final host = Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '';
  return host.contains('embedindia.st');
}

Map<String, String> _ppvEmbedStreamHeaders(String embedUrl) {
  final origin = Uri.tryParse(embedUrl)?.origin ?? 'https://embedindia.st';
  return {
    'User-Agent': _ua['User-Agent']!,
    'Referer': embedUrl,
    'Origin': origin,
  };
}

/// Sniff the direct HLS/MP4 URL from a PPV embed, proxied so Referer applies
/// to every segment request.
Future<String?> _resolvePpvPlayUrl(String embedUrl) async {
  debugPrint('[LiveMatches] Extracting PPV embed: $embedUrl');
  final extracted = await StreamExtractor().extract(
    embedUrl,
    referer: _ppvReferer,
    iframeWrapperBaseUrl: _ppvReferer,
    timeout: const Duration(seconds: 25),
  );
  if (extracted == null || extracted.url.isEmpty) {
    debugPrint('[LiveMatches] PPV extract failed — WebView fallback');
    return null;
  }

  debugPrint('[LiveMatches] PPV extracted: ${extracted.url}');
  final headers = _ppvEmbedStreamHeaders(embedUrl);

  final proxy = LocalServerService();
  await proxy.start();
  if (proxy.port > 0) {
    return proxy.getHlsProxyUrl(extracted.url, headers);
  }
  return extracted.url;
}

Future<List<_Sport>> _fetchStreamedSports() async {
  final resp = await http
      .get(Uri.parse('$_streamedBase/api/sports'), headers: _streamedUa)
      .timeout(const Duration(seconds: 12));
  if (resp.statusCode != 200) return [];
  final list = jsonDecode(resp.body) as List? ?? [];
  return list
      .map((s) {
        final j = s as Map<String, dynamic>;
        final id = (j['id'] ?? '').toString();
        final name = (j['name'] ?? '').toString();
        if (id.isEmpty || name.isEmpty) return null;
        return _Sport(id: id, name: name);
      })
      .whereType<_Sport>()
      .toList();
}

Future<List<_StreamedMatch>> _fetchStreamedMatches() async {
  final resp = await http
      .get(Uri.parse('$_streamedBase/api/matches/all'), headers: _streamedUa)
      .timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) return [];
  final list = jsonDecode(resp.body) as List? ?? [];
  return list
      .map((m) {
        try {
          return _StreamedMatch.fromJson(m as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      })
      .whereType<_StreamedMatch>()
      .toList();
}

Future<List<_StreamedStream>> _fetchStreamedStreams(
  _StreamedSourceRef sourceRef,
) async {
  final resp = await http
      .get(
        Uri.parse(
          '$_streamedBase/api/stream/${sourceRef.source}/${sourceRef.id}',
        ),
        headers: _streamedUa,
      )
      .timeout(const Duration(seconds: 12));
  if (resp.statusCode != 200) return [];
  final list = jsonDecode(resp.body) as List? ?? [];
  return list
      .map((s) {
        try {
          return _StreamedStream.fromJson(s as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      })
      .whereType<_StreamedStream>()
      .where((s) => s.embedUrl.isNotEmpty)
      .toList();
}

Future<List<_DamiTvStream>> _fetchDamiTvStreams() async {
  for (final endpoint in _ppvStreamApis) {
    try {
      final resp = await http
          .get(Uri.parse(endpoint), headers: _ua)
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) continue;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] != true) continue;

      final result = <_DamiTvStream>[];
      final categories = body['streams'] as List? ?? [];
      for (final cat in categories) {
        final streams = cat['streams'] as List? ?? [];
        for (final s in streams) {
          try {
            result.add(_DamiTvStream.fromJson(s as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      if (result.isNotEmpty) return result;
    } catch (_) {
      continue;
    }
  }
  return [];
}

Future<List<_CdnChannel>> _fetchCdnChannels() async {
  final resp = await http
      .get(
        Uri.parse(
          'https://api.cdn-live.tv/api/v1/channels/?user=cdnlivetv&plan=free',
        ),
        headers: _ua,
      )
      .timeout(const Duration(seconds: 12));
  if (resp.statusCode != 200) return [];
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  return ((body['channels'] as List?) ?? [])
      .map((c) => _CdnChannel.fromJson(c as Map<String, dynamic>))
      .toList();
}

Future<List<_CdnSportEvent>> _fetchCdnSports() async {
  final resp = await http
      .get(
        Uri.parse(
          'https://api.cdn-live.tv/api/v1/events/sports/?user=cdnlivetv&plan=free',
        ),
        headers: _ua,
      )
      .timeout(const Duration(seconds: 12));
  if (resp.statusCode != 200) return [];
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  final cdnData = body['cdn-live-tv'] as Map<String, dynamic>?;
  if (cdnData == null) return [];

  final result = <_CdnSportEvent>[];
  for (final key in ['Soccer', 'NFL', 'NBA', 'NHL']) {
    final events = (cdnData[key] as List?) ?? [];
    for (final e in events) {
      try {
        result.add(_CdnSportEvent.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
  }
  return result;
}

// ═════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class LiveMatchesScreen extends StatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen>
    with TickerProviderStateMixin {
  static const _tabId = 'live_matches';
  static const _topBarRowId = 'live-top-bar';
  static const _chipRowId = 'sport-chips';
  static const _gridRowId = 'grid';

  // tabs: All + each sport
  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;

  // selected sport filter ('all' = no filter)
  String _sportFilter = 'all';

  TabController? _tabController;
  _LiveMatchesServer _server = _LiveMatchesServer.all;
  List<_DamiTvStream> _damiTvStreams = [];
  List<_StreamedMatch> _streamedMatches = [];
  List<_CdnChannel> _cdnChannels = [];
  List<_CdnSportEvent> _cdnSports = [];
  bool _cdnShowChannels = true; // true = channels, false = sports

  static const _topBarServersIndex = 0;
  static const _topBarRefreshIndex = 1;

  final FocusNode _refreshFocusNode = FocusNode(
    debugLabel: 'live-matches-refresh',
  );

  bool _tvFocus(BuildContext context) =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _hasSportChips => _tabController != null && _sports.isNotEmpty;

  int get _chipSortOrder => 1;

  int get _gridSortOrder => _hasSportChips ? 2 : 1;

  static const _matchCardWidthScale = 1.15;
  static const _matchCardHeightScale = 1.32;

  double _matchCardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context) * _matchCardWidthScale;

  double _matchCardHeight(BuildContext context) {
    final height =
        shellContinueWatchingCardHeight(context) * _matchCardHeightScale;
    return height.clamp(190.0, 230.0);
  }

  double _channelCardWidth(BuildContext context) =>
      (_matchCardWidth(context) * 0.9).clamp(210.0, 260.0);

  double _channelCardHeight(BuildContext context) =>
      (_matchCardHeight(context) * 0.88).clamp(130.0, 150.0);

  double _gridGap(BuildContext context) =>
      shellMovieCardRowGap(context).clamp(8.0, 12.0);

  EdgeInsets _gridPadding(BuildContext context) {
    final horizontal = shellHomeSectionHorizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, 4, horizontal, 20);
  }

  int _gridColumns(BoxConstraints constraints, double cardWidth) =>
      (constraints.maxWidth / cardWidth).floor().clamp(1, 8);

  ({IconData icon, Color accent}) _sportCircleMeta(String label) {
    final key = label.toLowerCase();
    if (key == 'all') {
      return (
        icon: Icons.grid_view_rounded,
        accent: ForjaShellColors.sectionAccent,
      );
    }
    if (key.contains('american football') || key.contains('nfl')) {
      return (
        icon: Icons.sports_football_rounded,
        accent: const Color(0xFF22C55E),
      );
    }
    if (key.contains('basketball') || key.contains('nba')) {
      return (
        icon: Icons.sports_basketball_rounded,
        accent: const Color(0xFFF97316),
      );
    }
    if (key.contains('soccer') || key.contains('football')) {
      return (
        icon: Icons.sports_soccer_rounded,
        accent: const Color(0xFF10B981),
      );
    }
    if (key.contains('baseball') || key.contains('mlb')) {
      return (
        icon: Icons.sports_baseball_rounded,
        accent: const Color(0xFFEF4444),
      );
    }
    if (key.contains('hockey') || key.contains('nhl')) {
      return (
        icon: Icons.sports_hockey_rounded,
        accent: const Color(0xFF38BDF8),
      );
    }
    if (key.contains('tennis')) {
      return (
        icon: Icons.sports_tennis_rounded,
        accent: const Color(0xFFA3E635),
      );
    }
    if (key.contains('cricket')) {
      return (
        icon: Icons.sports_cricket_rounded,
        accent: const Color(0xFF84CC16),
      );
    }
    if (key.contains('mma') ||
        key.contains('boxing') ||
        key.contains('fight')) {
      return (icon: Icons.sports_mma_rounded, accent: const Color(0xFFF43F5E));
    }
    if (key.contains('motor') || key.contains('racing') || key.contains('f1')) {
      return (
        icon: Icons.sports_motorsports_rounded,
        accent: const Color(0xFFEAB308),
      );
    }
    if (key.contains('24/7') || key.contains('stream')) {
      return (icon: Icons.live_tv_rounded, accent: const Color(0xFF8B5CF6));
    }
    if (key.contains('misc')) {
      return (icon: Icons.sports_rounded, accent: const Color(0xFF64748B));
    }
    return (icon: Icons.sports_rounded, accent: ForjaShellColors.sectionAccent);
  }

  String _sportLabelAt(int index) =>
      index == 0 ? 'All' : _sports[index - 1].name;

  Widget _buildSportCircleItem({
    required ShellMoodCircleLayout layout,
    required int index,
    required int itemCount,
    required bool tvFocus,
  }) {
    final label = _sportLabelAt(index);
    final meta = _sportCircleMeta(label);
    final selected = _tabController!.index == index;

    return ShellMoodCircleItem(
      layout: layout,
      label: label,
      icon: meta.icon,
      accent: meta.accent,
      selected: selected,
      listIndex: index,
      tvTabId: _tabId,
      tvRowId: _chipRowId,
      onTap: () {
        if (index != _tabController!.index) {
          _tabController!.animateTo(index);
        } else if (tvFocus) {
          ShellTvFocusCoordinator.focusFromChipStripDown(
            tabId: _tabId,
            chipRowId: _chipRowId,
            resultsRowId: _gridRowId,
          );
        }
      },
      onLeftEdge: shellTvChipLeftEdge(
        context,
        tabId: _tabId,
        rowId: _chipRowId,
        index: index,
      ),
      onRightEdge: shellTvChipRightEdge(
        tabId: _tabId,
        rowId: _chipRowId,
        index: index,
        itemCount: itemCount,
      ),
      onDownEdge: shellTvChipDownToRow(
        tabId: _tabId,
        chipRowId: _chipRowId,
        resultsRowId: _gridRowId,
      ),
      onUpEdge: () => _focusTopBarItem(_topBarServersIndex),
    );
  }

  Widget _buildCenteredSportCircles({
    required ShellMoodCircleLayout layout,
    required int itemCount,
    required bool scaleToFit,
    required bool tvFocus,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          if (i > 0) SizedBox(width: layout.horizontalGap),
          _buildSportCircleItem(
            layout: layout,
            index: i,
            itemCount: itemCount,
            tvFocus: tvFocus,
          ),
        ],
      ],
    );

    return SizedBox(
      height: layout.rowHeight,
      width: double.infinity,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: scaleToFit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: row,
              )
            : Center(child: row),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      _tabId,
      restoreFocus: _restoreLiveMatchesTvFocus,
    );
    _load();
  }

  @override
  void dispose() {
    _refreshFocusNode.dispose();
    ShellTvFocusCoordinator.clearTab(_tabId);
    _tabController?.dispose();
    super.dispose();
  }

  void _focusTopBarItem(int index) {
    if (index == _topBarServersIndex) {
      ShellTvFocusCoordinator.focusRowItem(
        _tabId,
        _topBarRowId,
        _topBarServersIndex,
      );
      return;
    }
    if (!_refreshFocusNode.canRequestFocus) return;
    _refreshFocusNode.requestFocus();
    ShellTvFocusCoordinator.saveFocus(
      _tabId,
      ShellTvFocusMemory(zone: ShellTvZone.topBar, node: _refreshFocusNode),
    );
  }

  Future<void> _selectServer(_LiveMatchesServer server) async {
    if (server == _server) return;
    setState(() => _server = server);
    await _load();
  }

  void _openServerPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LiveMatchesServerSheet(
        current: _server,
        onSelected: (server) {
          Navigator.pop(context);
          unawaited(_selectServer(server));
        },
      ),
    );
  }

  Widget _serversTopBarButton() {
    return ForjaShellChip(
      label: 'Servers',
      icon: Icons.dns_rounded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      fontSize: 11.5,
      listIndex: _topBarServersIndex,
      tvTabId: _tabId,
      tvRowId: _topBarRowId,
      onTap: _openServerPicker,
      onLeftEdge: shellTvChipLeftEdge(
        context,
        tabId: _tabId,
        rowId: _topBarRowId,
        index: _topBarServersIndex,
      ),
      onRightEdge: () => _focusTopBarItem(_topBarRefreshIndex),
      onDownEdge: _topBarDownEdge,
    );
  }

  void _topBarDownEdge() {
    if (_hasSportChips) {
      final chip = ShellTvFocusCoordinator.rowHandle(_tabId, _chipRowId);
      if (chip != null && chip.itemCount > 0) {
        final idx = chip.lastFocusedIndex.clamp(0, chip.itemCount - 1);
        ShellTvFocusCoordinator.focusRowItem(_tabId, _chipRowId, idx);
        return;
      }
    }
    _restoreLiveMatchesTvFocus();
  }

  VoidCallback? _gridUpEdge(BuildContext context, int index, int crossCount) {
    if (!_tvFocus(context) || index ~/ crossCount != 0) return null;
    return () => _focusTopBarItem(_topBarServersIndex);
  }

  bool _focusGridItem(int index) {
    final handle = ShellTvFocusCoordinator.rowHandle(_tabId, _gridRowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = index.clamp(0, handle.itemCount - 1);
    return ShellTvFocusCoordinator.focusRowItem(_tabId, _gridRowId, idx);
  }

  bool _restoreLiveMatchesTvFocus() {
    bool tryFocus() {
      final handle = ShellTvFocusCoordinator.rowHandle(_tabId, _gridRowId);
      if (handle == null || handle.itemCount <= 0) return false;
      final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
      return _focusGridItem(idx);
    }

    if (tryFocus()) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ShellTvFocus.currentNavTabId != _tabId) return;
      tryFocus();
    });
    return false;
  }

  void _registerGridRow(int itemCount) {
    shellTvRegisterRow(
      tabId: _tabId,
      rowId: _gridRowId,
      sortOrder: _gridSortOrder,
      itemCount: itemCount,
      onFocusUp: () => _focusTopBarItem(_topBarServersIndex),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sportFilter = 'all';
    });
    if (_server == _LiveMatchesServer.all) {
      await _loadAll();
      return;
    }
    if (_server == _LiveMatchesServer.ppv) {
      await _loadDamiTv();
      return;
    }
    if (_server == _LiveMatchesServer.streamed) {
      await _loadStreamed();
      return;
    }
    if (_server == _LiveMatchesServer.cdnLive) {
      await _loadCdn();
      return;
    }
  }

  void _applySportTabs(List<_Sport> cats) {
    final oldCtrl = _tabController;
    setState(() {
      _tabController = null;
      _sports = cats;
      _loading = false;
    });
    oldCtrl?.dispose();
    if (!mounted) return;
    final newCtrl = TabController(length: cats.length + 1, vsync: this);
    newCtrl.addListener(() {
      if (!newCtrl.indexIsChanging) {
        final idx = newCtrl.index;
        setState(() => _sportFilter = idx == 0 ? 'all' : cats[idx - 1].id);
      }
    });
    setState(() => _tabController = newCtrl);
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _fetchDamiTvStreams().catchError((_) => <_DamiTvStream>[]),
        _fetchStreamedMatches().catchError((_) => <_StreamedMatch>[]),
        _fetchCdnChannels().catchError((_) => <_CdnChannel>[]),
        _fetchCdnSports().catchError((_) => <_CdnSportEvent>[]),
      ]);
      final ppvStreams = results[0] as List<_DamiTvStream>;
      final streamedMatches = results[1] as List<_StreamedMatch>;
      final cdnChannels = results[2] as List<_CdnChannel>;
      final cdnSports = results[3] as List<_CdnSportEvent>;

      final seenCats = <String>{};
      final cats = <_Sport>[];
      void addCat(String id, String name) {
        if (id.isEmpty || !seenCats.add(id)) return;
        cats.add(_Sport(id: id, name: name));
      }

      for (final s in ppvStreams) {
        addCat(s.categoryName, s.categoryName);
      }
      for (final m in streamedMatches) {
        addCat(m.category, m.categoryLabel);
      }
      for (final e in cdnSports) {
        addCat(e.tournament, e.tournament);
      }
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _damiTvStreams = ppvStreams;
        _streamedMatches = streamedMatches;
        _cdnChannels = cdnChannels;
        _cdnSports = cdnSports;
      });
      _applySportTabs(cats);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDamiTv() async {
    try {
      final streams = await _fetchDamiTvStreams();
      final seenCats = <String>{};
      final cats = <_Sport>[];
      for (final s in streams) {
        if (s.categoryName.isNotEmpty && seenCats.add(s.categoryName)) {
          cats.add(_Sport(id: s.categoryName, name: s.categoryName));
        }
      }
      if (mounted) {
        final oldCtrl = _tabController;
        setState(() {
          _tabController = null;
          _damiTvStreams = streams;
          _sports = cats;
          _loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: this);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            setState(() => _sportFilter = idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadStreamed() async {
    try {
      final results = await Future.wait([
        _fetchStreamedSports(),
        _fetchStreamedMatches(),
      ]);
      final sports = results[0] as List<_Sport>;
      final matches = results[1] as List<_StreamedMatch>;

      final catsInMatches = matches.map((m) => m.category).toSet();
      var cats = sports.where((s) => catsInMatches.contains(s.id)).toList();
      if (cats.isEmpty) {
        final seen = <String>{};
        cats = [];
        for (final m in matches) {
          if (m.category.isNotEmpty && seen.add(m.category)) {
            cats.add(_Sport(id: m.category, name: m.categoryLabel));
          }
        }
      }

      if (mounted) {
        final oldCtrl = _tabController;
        setState(() {
          _tabController = null;
          _streamedMatches = matches;
          _sports = cats;
          _loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: this);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            setState(() => _sportFilter = idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadCdn() async {
    try {
      final results = await Future.wait([
        _fetchCdnChannels(),
        _fetchCdnSports(),
      ]);
      final channels = results[0] as List<_CdnChannel>;
      final sports = results[1] as List<_CdnSportEvent>;

      // Build categories from sports
      final seenCats = <String>{};
      final cats = <_Sport>[];
      for (final s in sports) {
        if (s.tournament.isNotEmpty && seenCats.add(s.tournament)) {
          cats.add(_Sport(id: s.tournament, name: s.tournament));
        }
      }

      if (mounted) {
        final oldCtrl = _tabController;
        setState(() {
          _tabController = null;
          _cdnChannels = channels;
          _cdnSports = sports;
          _sports = cats;
          _loading = false;
        });
        oldCtrl?.dispose();
        final newCtrl = TabController(length: cats.length + 1, vsync: this);
        newCtrl.addListener(() {
          if (!newCtrl.indexIsChanging) {
            final idx = newCtrl.index;
            setState(() => _sportFilter = idx == 0 ? 'all' : cats[idx - 1].id);
          }
        });
        if (mounted) setState(() => _tabController = newCtrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<_DamiTvStream> get _filteredDamiTv => _sortDamiTvLiveFirst(
    _sportFilter == 'all'
        ? _damiTvStreams
        : _damiTvStreams.where((s) => s.categoryName == _sportFilter).toList(),
  );

  List<_StreamedMatch> get _filteredStreamed => _sortStreamedLiveFirst(
    _sportFilter == 'all'
        ? _streamedMatches
        : _streamedMatches.where((m) => m.category == _sportFilter).toList(),
  );

  List<_CdnSportEvent> get _filteredCdnSports => _sortCdnSportsLiveFirst(
    _sportFilter == 'all'
        ? _cdnSports
        : _cdnSports.where((s) => s.tournament == _sportFilter).toList(),
  );

  List<_LiveMatchGridEntry> get _allGridEntries => _sortGridEntriesLiveFirst([
    ..._filteredDamiTv.map(_LiveMatchGridEntry.ppv),
    ..._filteredStreamed.map(_LiveMatchGridEntry.streamed),
    ..._filteredCdnSports.map(_LiveMatchGridEntry.cdnSport),
  ]);

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_tabController != null && _sports.isNotEmpty) _buildSportTabs(),
        const SizedBox(height: 2),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final tvFocus = _tvFocus(context);
    if (tvFocus) {
      shellTvRegisterRow(
        tabId: _tabId,
        rowId: _topBarRowId,
        sortOrder: 0,
        itemCount: _topBarRefreshIndex + 1,
      );
    }

    final refresh = tvFocus
        ? shellFocusableTap(
            context: context,
            onTap: _load,
            borderRadius: 24,
            scaleOnFocus: 1.0,
            focusNode: _refreshFocusNode,
            tvTabId: _tabId,
            tvRowId: _topBarRowId,
            tvItemIndex: _topBarRefreshIndex,
            tvZone: ShellTvZone.topBar,
            onDownEdge: _topBarDownEdge,
            onLeftEdge: () => _focusTopBarItem(_topBarServersIndex),
            onFocusChange: (focused) {
              if (focused) {
                ShellTvFocusCoordinator.saveFocus(
                  _tabId,
                  ShellTvFocusMemory(
                    zone: ShellTvZone.topBar,
                    node: _refreshFocusNode,
                  ),
                );
              }
            },
            child: const Tooltip(
              message: 'Refresh',
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh_rounded, color: Colors.white70),
              ),
            ),
          )
        : IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellTokens.compactChromeLeadingInset(context),
        10,
        ShellTokens.bodyHorizontalPadding,
        8,
      ),
      child: Row(children: [_serversTopBarButton(), const Spacer(), refresh]),
    );
  }

  Widget _buildSportTabs() {
    if (_tabController == null || _sports.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = _sports.length + 1;
    final tvFocus = _tvFocus(context);

    return Padding(
      padding: EdgeInsets.only(
        left: ShellTokens.compactChromeLeadingInset(context),
        right: ShellTokens.bodyHorizontalPadding,
        top: 2,
        bottom: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (tvFocus) {
            shellTvRegisterRow(
              tabId: _tabId,
              rowId: _chipRowId,
              sortOrder: _chipSortOrder,
              itemCount: itemCount,
              onFocusUp: () => _focusTopBarItem(_topBarServersIndex),
            );
          }

          final layout = ShellMoodCircleLayout.resolve(
            context,
            itemCount: itemCount,
            maxWidth: constraints.maxWidth,
          );

          if (tvFocus) {
            return _buildCenteredSportCircles(
              layout: layout,
              itemCount: itemCount,
              scaleToFit: true,
              tvFocus: tvFocus,
            );
          }

          if (layout.contentWidth(itemCount) <= constraints.maxWidth) {
            return _buildCenteredSportCircles(
              layout: layout,
              itemCount: itemCount,
              scaleToFit: false,
              tvFocus: tvFocus,
            );
          }

          return FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: HorizontalScroller(
              height: layout.rowHeight,
              padding: EdgeInsets.zero,
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(width: layout.horizontalGap),
              itemBuilder: (context, i) => _buildSportCircleItem(
                layout: layout,
                index: i,
                itemCount: itemCount,
                tvFocus: tvFocus,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
      );
    }
    if (_error != null) {
      return ShellErrorRetryPanel(
        message: _error!,
        onRetry: _load,
        statusIcon: Icons.error_outline,
        buttonIcon: Icons.refresh,
      );
    }
    if (_server == _LiveMatchesServer.all) return _buildAllBody();
    if (_server == _LiveMatchesServer.ppv) return _buildDamiTvBody();
    if (_server == _LiveMatchesServer.streamed) return _buildStreamedBody();
    if (_server == _LiveMatchesServer.cdnLive) return _buildCdnBody();

    return const SizedBox.shrink();
  }

  Widget _buildAllBody() {
    final entries = _allGridEntries;
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _registerGridRow(entries.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            final upEdge = _gridUpEdge(context, i, crossCount);
            return switch (entry) {
              _LiveMatchGridEntryPpv(:final stream) => _DamiTvMatchCard(
                stream: stream,
                gridIndex: i,
                gridColumns: crossCount,
                onUpEdge: upEdge,
                onTap: () => _openDamiTvStream(stream),
              ),
              _LiveMatchGridEntryStreamed(:final match) => _StreamedMatchCard(
                match: match,
                gridIndex: i,
                gridColumns: crossCount,
                onUpEdge: upEdge,
                onTap: () => _openStreamedMatch(match),
              ),
              _LiveMatchGridEntryCdnSport(:final event) => _CdnSportCard(
                event: event,
                gridIndex: i,
                gridColumns: crossCount,
                onUpEdge: upEdge,
                onTap: () => _openCdnSportEvent(event),
              ),
            };
          },
        );
      },
    );
  }

  Widget _buildStreamedBody() {
    final matches = _filteredStreamed;
    if (matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _registerGridRow(matches.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: matches.length,
          itemBuilder: (context, i) => _StreamedMatchCard(
            match: matches[i],
            gridIndex: i,
            gridColumns: crossCount,
            onUpEdge: _gridUpEdge(context, i, crossCount),
            onTap: () => _openStreamedMatch(matches[i]),
          ),
        );
      },
    );
  }

  Widget _buildDamiTvBody() {
    final streams = _filteredDamiTv;
    if (streams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No streams available',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _matchCardWidth(context);
        final cardHeight = _matchCardHeight(context);
        final gap = _gridGap(context);
        final crossCount = _gridColumns(constraints, cardWidth);
        final tvFocus = _tvFocus(context);
        if (tvFocus) {
          _registerGridRow(streams.length);
        }
        return GridView.builder(
          padding: _gridPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          itemCount: streams.length,
          itemBuilder: (context, i) => _DamiTvMatchCard(
            stream: streams[i],
            gridIndex: i,
            gridColumns: crossCount,
            onUpEdge: _gridUpEdge(context, i, crossCount),
            onTap: () => _openDamiTvStream(streams[i]),
          ),
        );
      },
    );
  }

  Widget _buildCdnBody() {
    if (_cdnShowChannels) {
      final channels = _cdnChannels.where((c) => c.status == 'online').toList();
      if (channels.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'No channels available',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shellHomeSectionHorizontalPadding(context),
              4,
              ShellTokens.bodyHorizontalPadding,
              6,
            ),
            child: Row(
              children: [
                ForjaShellChip(
                  label: '📺 Channels',
                  selected: _cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _cdnShowChannels = true),
                ),
                const SizedBox(width: 6),
                ForjaShellChip(
                  label: '⚽ Sports',
                  selected: !_cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _cdnShowChannels = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _channelCardWidth(context);
                final cardHeight = _channelCardHeight(context);
                final gap = _gridGap(context);
                final crossCount = _gridColumns(constraints, cardWidth);
                if (_tvFocus(context)) {
                  _registerGridRow(channels.length);
                }
                return GridView.builder(
                  padding: _gridPadding(context),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, i) => _CdnChannelCard(
                    channel: channels[i],
                    gridIndex: i,
                    gridColumns: crossCount,
                    onUpEdge: _gridUpEdge(context, i, crossCount),
                    onTap: () => _openCdnChannel(channels[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    } else {
      final sports = _filteredCdnSports;
      if (sports.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'No sports events available',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shellHomeSectionHorizontalPadding(context),
              4,
              ShellTokens.bodyHorizontalPadding,
              6,
            ),
            child: Row(
              children: [
                ForjaShellChip(
                  label: '📺 Channels',
                  selected: _cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _cdnShowChannels = true),
                ),
                const SizedBox(width: 6),
                ForjaShellChip(
                  label: '⚽ Sports',
                  selected: !_cdnShowChannels,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => setState(() => _cdnShowChannels = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _matchCardWidth(context);
                final cardHeight = _matchCardHeight(context);
                final gap = _gridGap(context);
                final crossCount = _gridColumns(constraints, cardWidth);
                if (_tvFocus(context)) {
                  _registerGridRow(sports.length);
                }
                return GridView.builder(
                  padding: _gridPadding(context),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemCount: sports.length,
                  itemBuilder: (context, i) => _CdnSportCard(
                    event: sports[i],
                    gridIndex: i,
                    gridColumns: crossCount,
                    onUpEdge: _gridUpEdge(context, i, crossCount),
                    onTap: () => _openCdnSportEvent(sports[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    if (match.sources.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: ForjaShellColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ForjaShellColors.cinematic.borderSubtle,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading streams…',
                  style: TextStyle(color: ForjaShellColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final streams = <_StreamedStream>[];
    try {
      for (final source in match.sources) {
        streams.addAll(await _fetchStreamedStreams(source));
      }
    } catch (e) {
      debugPrint('[LiveMatches] Streamed resolve error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (streams.isEmpty) {
      ForjaToast.info('No streams available for this event');
      return;
    }

    if (streams.length == 1) {
      _openStreamedEmbed(match, streams.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreamedStreamSheet(
        match: match,
        streams: streams,
        onStreamSelected: (stream) {
          Navigator.pop(context);
          _openStreamedEmbed(match, stream);
        },
      ),
    );
  }

  void _openStreamedEmbed(_StreamedMatch match, _StreamedStream stream) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: stream.embedUrl,
          title: match.title,
          subtitle: match.categoryLabel,
          badgeLabel: 'Streamed',
          referer: _streamedReferer,
          origin: _streamedBase,
        ),
      ),
    );
  }

  Future<void> _openDamiTvStream(_DamiTvStream s) async {
    if (s.iframe.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    // embedindia feeds only play inside their embed page (ppv.is uses the same
    // iframe). Native mpv cannot reuse the sniffed m3u8 token.
    if (_ppvEmbedRequiresWebView(s.iframe)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _LiveMatchesEmbedPlayerScreen(
            embedUrl: s.iframe,
            title: s.name,
            subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
            badgeLabel: 'PPV',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: ForjaShellColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ForjaShellColors.cinematic.borderSubtle,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connecting to stream…',
                  style: const TextStyle(color: ForjaShellColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    String? playUrl;
    try {
      playUrl = await _resolvePpvPlayUrl(s.iframe);
    } catch (e) {
      debugPrint('[LiveMatches] PPV resolve error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (playUrl != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IptvPtPlayerScreen(
            sources: [IptvPlaySource(url: playUrl!, label: 'PPV')],
            title: s.name,
            subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
          ),
        ),
      );
      return;
    }

    ForjaToast.info('Opening embed player…');
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: s.iframe,
          title: s.name,
          subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
          badgeLabel: 'PPV',
        ),
      ),
    );
  }

  void _openCdnChannel(_CdnChannel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: channel.url,
          title: channel.name,
          badgeLabel: 'CDN Live',
        ),
      ),
    );
  }

  void _openCdnSportEvent(_CdnSportEvent event) {
    if (event.channels.isEmpty) {
      ForjaToast.info('No channels available for this event');
      return;
    }
    if (event.channels.length == 1) {
      _openCdnChannel(event.channels.first);
      return;
    }
    // Show channel selection
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CdnChannelSheet(
        event: event,
        onChannelSelected: (ch) {
          Navigator.pop(context);
          _openCdnChannel(ch);
        },
      ),
    );
  }
}

enum _LiveMatchesServer { all, ppv, streamed, cdnLive }

sealed class _LiveMatchGridEntry {
  const _LiveMatchGridEntry();

  factory _LiveMatchGridEntry.ppv(_DamiTvStream stream) =
      _LiveMatchGridEntryPpv;

  factory _LiveMatchGridEntry.streamed(_StreamedMatch match) =
      _LiveMatchGridEntryStreamed;

  factory _LiveMatchGridEntry.cdnSport(_CdnSportEvent event) =
      _LiveMatchGridEntryCdnSport;
}

final class _LiveMatchGridEntryPpv extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryPpv(this.stream);
  final _DamiTvStream stream;
}

final class _LiveMatchGridEntryStreamed extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryStreamed(this.match);
  final _StreamedMatch match;
}

final class _LiveMatchGridEntryCdnSport extends _LiveMatchGridEntry {
  const _LiveMatchGridEntryCdnSport(this.event);
  final _CdnSportEvent event;
}

String _liveMatchesServerLabel(_LiveMatchesServer server) => switch (server) {
  _LiveMatchesServer.all => 'All',
  _LiveMatchesServer.ppv => 'PPV',
  _LiveMatchesServer.streamed => 'Streamed',
  _LiveMatchesServer.cdnLive => 'CDN Live',
};

String _liveMatchesServerSubtitle(_LiveMatchesServer server) =>
    switch (server) {
      _LiveMatchesServer.all => 'PPV · Streamed · CDN Live',
      _LiveMatchesServer.ppv => 'ppv.is',
      _LiveMatchesServer.streamed => 'streamed.pk',
      _LiveMatchesServer.cdnLive => 'cdn-live.tv',
    };

// ─── Server picker sheet ────────────────────────────────────────────────────

class _LiveMatchesServerSheet extends StatelessWidget {
  const _LiveMatchesServerSheet({
    required this.current,
    required this.onSelected,
  });

  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Servers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a live match source:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _LiveMatchesServerSheetOption(
            server: _LiveMatchesServer.all,
            current: current,
            onSelected: onSelected,
          ),
          ..._LiveMatchesServer.values
              .where((server) => server != _LiveMatchesServer.all)
              .map(
                (server) => _LiveMatchesServerSheetOption(
                  server: server,
                  current: current,
                  onSelected: onSelected,
                ),
              ),
        ],
      ),
    );
  }
}

class _LiveMatchesServerSheetOption extends StatelessWidget {
  const _LiveMatchesServerSheetOption({
    required this.server,
    required this.current,
    required this.onSelected,
  });

  final _LiveMatchesServer server;
  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: () => onSelected(server),
      borderRadius: 12,
      navLeftAlways: true,
      tvTabId: 'live_matches',
      tvZone: ShellTvZone.row,
      child: ListTile(
        leading: Icon(
          server == _LiveMatchesServer.all
              ? Icons.grid_view_rounded
              : Icons.dns_rounded,
          color: server == current
              ? ForjaShellColors.sectionAccent
              : Colors.white54,
        ),
        title: Text(
          _liveMatchesServerLabel(server),
          style: TextStyle(
            color: Colors.white,
            fontWeight: server == current ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _liveMatchesServerSubtitle(server),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: server == current
            ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
            : const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}

// ─── Chips ────────────────────────────────────────────────────────────────────

class _TeamBadge extends StatelessWidget {
  final String? badge;
  final String name;
  const _TeamBadge({required this.badge, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white12,
          child: badge != null && badge!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: badge!,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 50,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 8.5),
          ),
        ),
      ],
    );
  }
}

class _LiveMatchCornerBadge extends StatelessWidget {
  const _LiveMatchCornerBadge({
    required this.label,
    required this.live,
    this.color,
    this.top = 8,
    this.left,
    this.right = 8,
  });

  final String label;
  final bool live;
  final Color? color;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final fontSize = shellScaled(context, 10).clamp(9.0, 12.0);
    final padH = shellScaled(context, 8).clamp(6.0, 10.0);
    final padV = shellScaled(context, 3).clamp(2.0, 4.0);
    final radius = shellScaled(context, 6).clamp(4.0, 8.0);
    final inset = shellScaled(context, top).clamp(6.0, 10.0);
    final bg = color ?? (live ? Colors.red.shade700 : Colors.black54);

    return Positioned(
      top: inset,
      left: left,
      right: right,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CDN Channel Card ─────────────────────────────────────────────────────────

class _CdnChannelCard extends StatefulWidget {
  final _CdnChannel channel;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  const _CdnChannelCard({
    required this.channel,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
  });

  @override
  State<_CdnChannelCard> createState() => _CdnChannelCardState();
}

class _CdnChannelCardState extends State<_CdnChannelCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
    );
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (c.image.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: c.image,
                        height: 46,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.tv_rounded,
                          color: Colors.white38,
                          size: 38,
                        ),
                      )
                    else
                      const Icon(
                        Icons.tv_rounded,
                        color: Colors.white38,
                        size: 38,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (c.viewers > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${c.viewers} viewers',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ShellCardPlayOverlay(active: active, visible: active),
              _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
                color: Colors.green.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CDN Sport Event Card ─────────────────────────────────────────────────────

class _CdnSportCard extends StatefulWidget {
  final _CdnSportEvent event;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  const _CdnSportCard({
    required this.event,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
  });

  @override
  State<_CdnSportCard> createState() => _CdnSportCardState();
}

class _CdnSportCardState extends State<_CdnSportCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final canPlay = e.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active = canPlay &&
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          if (e.homeTeamIMG.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: e.homeTeamIMG,
                              width: 32,
                              height: 32,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.sports_rounded,
                                color: Colors.white38,
                                size: 26,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sports_rounded,
                              color: Colors.white38,
                              size: 26,
                            ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 50,
                            child: Text(
                              e.homeTeam,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          if (e.awayTeamIMG.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: e.awayTeamIMG,
                              width: 32,
                              height: 32,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.sports_rounded,
                                color: Colors.white38,
                                size: 26,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sports_rounded,
                              color: Colors.white38,
                              size: 26,
                            ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 50,
                            child: Text(
                              e.awayTeam,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.tournament,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: e.isLive ? '● LIVE' : e.status.toUpperCase(),
              live: e.isLive,
              color: e.isLive
                  ? Colors.red.shade700
                  : Colors.orange.shade700,
            ),
          ],
        ),
      ),
    );

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: card,
    );
  }
}

// ─── CDN Channel Sheet ────────────────────────────────────────────────────────

class _CdnChannelSheet extends StatelessWidget {
  final _CdnSportEvent event;
  final void Function(_CdnChannel) onChannelSelected;
  const _CdnChannelSheet({
    required this.event,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${event.homeTeam} vs ${event.awayTeam}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a channel:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...event.channels.map(
            (ch) => shellFocusableTap(
              context: context,
              onTap: () => onChannelSelected(ch),
              borderRadius: 12,
              navLeftAlways: true,
              tvTabId: 'live_matches',
              tvZone: ShellTvZone.row,
              child: ListTile(
                leading: ch.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ch.image,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => Icon(
                          Icons.tv_rounded,
                          color: ForjaShellColors.sectionAccent,
                        ),
                      )
                    : Icon(
                        Icons.tv_rounded,
                        color: ForjaShellColors.sectionAccent,
                      ),
                title: Text(
                  ch.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: ch.viewers > 0
                    ? Text(
                        '${ch.viewers} viewers',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Embed WebView player (PPV / CDN fallback) ───────────────────────────────

class _LiveMatchesEmbedPlayerScreen extends StatefulWidget {
  final String embedUrl;
  final String title;
  final String? subtitle;
  final String badgeLabel;
  final String referer;
  final String origin;

  const _LiveMatchesEmbedPlayerScreen({
    required this.embedUrl,
    required this.title,
    this.subtitle,
    required this.badgeLabel,
    this.referer = _ppvReferer,
    this.origin = 'https://ppv.is',
  });

  @override
  State<_LiveMatchesEmbedPlayerScreen> createState() =>
      _LiveMatchesEmbedPlayerScreenState();
}

class _LiveMatchesEmbedPlayerScreenState
    extends State<_LiveMatchesEmbedPlayerScreen> {
  bool _loading = true;
  bool _isFullscreen = false;

  final FocusNode _backFocusNode = FocusNode(
    debugLabel: 'live-embed-back',
  );

  bool _tvFocus() =>
      ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;

  /// The embed is a native WebView platform view that grabs D-pad input on TV.
  /// Pull focus back to the Flutter back button so it stays reachable.
  void _focusBack() {
    if (!mounted || !_tvFocus() || _isFullscreen) return;
    if (_backFocusNode.canRequestFocus) _backFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusBack());
  }

  Future<void> _enterFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
        await windowManager.setFullScreen(true);
      } catch (_) {}
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    }
    if (mounted) setState(() => _isFullscreen = true);
  }

  Future<void> _exitFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        await windowManager.setFullScreen(false);
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
      } catch (_) {}
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([]);
    }
    if (mounted) setState(() => _isFullscreen = false);
  }

  Future<void> _toggleFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (isFull) {
          await _exitFullscreen();
        } else {
          await _enterFullscreen();
        }
      } catch (_) {
        if (_isFullscreen) {
          await _exitFullscreen();
        } else {
          await _enterFullscreen();
        }
      }
      return;
    }
    if (_isFullscreen) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    if (DesktopWindowChrome.isDesktop) {
      Future.microtask(() async {
        try {
          if (await windowManager.isFullScreen()) {
            await windowManager.setFullScreen(false);
          }
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          }
        } catch (_) {}
      });
    } else {
      SystemChrome.setPreferredOrientations([]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    super.dispose();
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return MediaQuery.paddingOf(context).top + 8;
  }

  Widget _buildSourceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue),
      ),
      child: Text(
        widget.badgeLabel,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(8, _topBarTopPadding(context), 72, 16),
      child: Row(
        children: [
          iptvBackButton(
            context,
            onTap: () => Navigator.of(context).maybePop(),
            color: Colors.white,
            size: 26,
            focusNode: _backFocusNode,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.overlayTitle,
                ),
                if ((widget.subtitle ?? '').isNotEmpty)
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!_tvFocus()) return bar;
    return FocusScope(
      debugLabel: 'live-embed-chrome',
      child: FocusTraversalGroup(child: bar),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = widget.embedUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ForjaInAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(embedUrl),
              headers: {
                'User-Agent': _ua['User-Agent']!,
                'Referer': widget.referer,
                'Origin': widget.origin,
              },
            ),
            initialSettings: InAppWebViewSettings(
              userAgent: _ua['User-Agent'],
              domStorageEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              disableDefaultErrorPage: true,
              supportMultipleWindows: false,
              allowsAirPlayForMediaPlayback: true,
              allowsPictureInPictureMediaPlayback: true,
            ),
            onWebViewCreated: (controller) {
              controller.addJavaScriptHandler(
                handlerName: 'toggleFullscreen',
                callback: (_) {
                  unawaited(_toggleFullscreen());
                },
              );
            },
            onLoadStart: (_, _) => setState(() => _loading = true),
            onLoadStop: (ctrl, _) async {
              setState(() => _loading = false);
              try {
                await ctrl.evaluateJavascript(source: _autoplayJs);
                await ctrl.evaluateJavascript(source: _dblclickFullscreenJs);
              } catch (_) {}
              WidgetsBinding.instance.addPostFrameCallback((_) => _focusBack());
            },
            onEnterFullscreen: (_) => unawaited(_enterFullscreen()),
            onExitFullscreen: (_) => unawaited(_exitFullscreen()),
            shouldOverrideUrlLoading: (ctrl, action) async {
              final url = action.request.url?.toString() ?? '';
              final embedHost = Uri.tryParse(embedUrl)?.host ?? '';
              if (embedHost.isNotEmpty && !url.contains(embedHost)) {
                http
                    .get(
                      Uri.parse(url),
                      headers: {
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                            'AppleWebKit/537.36 (KHTML, like Gecko) '
                            'Chrome/122.0.0.0 Safari/537.36',
                        'Referer': embedUrl,
                      },
                    )
                    .catchError((_) => http.Response('', 200));
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (_loading)
            Center(
              child: CircularProgressIndicator(
                color: ForjaShellColors.sectionAccent,
              ),
            ),
          if (!_isFullscreen) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: _buildTopBar(),
              ),
            ),
            Positioned(
              top: _topBarTopPadding(context),
              right: 16,
              child: _buildSourceBadge(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Streamed stream sheet ────────────────────────────────────────────────────

class _StreamedStreamSheet extends StatelessWidget {
  final _StreamedMatch match;
  final List<_StreamedStream> streams;
  final void Function(_StreamedStream) onStreamSelected;

  const _StreamedStreamSheet({
    required this.match,
    required this.streams,
    required this.onStreamSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            match.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a stream:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...streams.map(
            (stream) => shellFocusableTap(
              context: context,
              onTap: () => onStreamSelected(stream),
              borderRadius: 12,
              navLeftAlways: true,
              tvTabId: 'live_matches',
              tvZone: ShellTvZone.row,
              child: ListTile(
                leading: Icon(
                  stream.hd ? Icons.hd_rounded : Icons.play_circle_outline,
                  color: ForjaShellColors.sectionAccent,
                ),
                title: Text(
                  stream.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streamed Match Card ──────────────────────────────────────────────────────

class _StreamedMatchCard extends StatefulWidget {
  final _StreamedMatch match;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;

  const _StreamedMatchCard({
    required this.match,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
  });

  @override
  State<_StreamedMatchCard> createState() => _StreamedMatchCardState();
}

class _StreamedMatchCardState extends State<_StreamedMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final hasSources = m.sources.isNotEmpty;
    final hasTeams = m.homeTeam != null && m.awayTeam != null;
    final canPlay = hasSources && m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active = canPlay &&
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            if (m.poster.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: _streamedImageUrl(m.poster),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasTeams) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamBadge(
                          badge: _streamedImageUrl(m.homeBadge ?? ''),
                          name: m.homeTeam!,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _TeamBadge(
                          badge: _streamedImageUrl(m.awayBadge ?? ''),
                          name: m.awayTeam!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    m.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: m.categoryLabel.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (m.isLive)
              const _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
              )
            else if (m.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(
                label: m.timeLabel,
                live: false,
              ),
            if (!hasSources)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Not yet available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: card,
    );
  }
}

// ─── Dami TV Match Card ───────────────────────────────────────────────────────

class _DamiTvMatchCard extends StatefulWidget {
  final _DamiTvStream stream;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  const _DamiTvMatchCard({
    required this.stream,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
  });

  @override
  State<_DamiTvMatchCard> createState() => _DamiTvMatchCardState();
}

class _DamiTvMatchCardState extends State<_DamiTvMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    final hasIframe = s.iframe.isNotEmpty;
    final hasTeams = s.homeTeam != null && s.awayTeam != null;
    final canPlay = hasIframe && s.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active = canPlay &&
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // poster background
            if (s.poster.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: s.poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // dark gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),
            // content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasTeams) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamBadge(badge: s.homeBadge, name: s.homeTeam!),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _TeamBadge(badge: s.awayBadge, name: s.awayTeam!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (s.league.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.league,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: s.categoryName.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (s.isLive)
              const _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
              )
            else if (s.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(
                label: s.timeLabel,
                live: false,
              ),
            // no iframe warning bottom
            if (!hasIframe)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Not yet available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: card,
    );
  }
}
