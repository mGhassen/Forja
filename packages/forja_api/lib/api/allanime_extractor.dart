import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' as pc;

/// Direct extractor for the allanime.day / allmanga.to API.
///
/// The episode endpoint is captcha-gated for normal POST requests, so we use
/// the same workaround as ani-cli:
///   * GET `…/api?variables=…&extensions=…` with a persistedQuery sha256Hash
///   * Origin/Referer = `https://youtu-chan.com`
/// The response carries an AES-256-CTR encrypted `tobeparsed` blob which is
/// decrypted in [_decryptTobeparsed].
///
/// Each `sourceUrl` is either a plaintext iframe URL or a `--{hex}` blob
/// where every byte is XOR'd with `0x38` to recover an `/apivtwo/clock?…`
/// path. That path is fetched (with `clock` → `clock.json`) and returns
/// `{links:[{link, hls?, mp4?, …}]}`.
class AllAnimeExtractor {
  static const String _api = 'https://api.allanime.day/api';
  static const String _refr = 'https://allmanga.to';
  static const String _ytChan = 'https://youtu-chan.com';
  static const String _clockHost = 'https://allanime.day';
  static const String _agent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0';

  // Persisted-query hash used by the official allmanga client. Required so
  // the episode endpoint doesn't 401 / NEED_CAPTCHA.
  static const String _episodeQueryHash =
      'd405d0edd690624b66baba3068e0edc3ac90f1597d898a1ec8db4e5c43c00fec';

  // AES key = SHA256("Xot36i3lK3:v1"); IV = first byte skipped, next 12 bytes,
  // then `00 00 00 02` (4-byte big-endian counter starting at 2).
  static final Uint8List _aesKey = Uint8List.fromList(
      crypto.sha256.convert(utf8.encode('Xot36i3lK3:v1')).bytes);

  /// Provider names actually exposed by allanime (see live API). The
  /// player-screen races them all in parallel. Match is case-insensitive
  /// exact against `sourceName`.
  static const List<String> knownProviders = [
    'Default', // wixmp HLS — usually best
    'S-mp4', // SharePoint MP4 — direct, very reliable
    'Yt-mp4', // tools.fast4speed.rsvp MP4
    'Luf-Mp4',
    'Uv-mp4',
  ];

  static const String _searchGql =
      'query(\$search: SearchInput \$limit: Int \$page: Int \$translationType: VaildTranslationTypeEnumType \$countryOrigin: VaildCountryOriginEnumType) { shows(search: \$search limit: \$limit page: \$page translationType: \$translationType countryOrigin: \$countryOrigin) { edges { _id name englishName availableEpisodes __typename } } }';

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  final Map<String, Future<String?>> _showIdCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _sourcesCache = {};

  Future<String?> _resolveShowId(List<String> titleCandidates, String cat) {
    final key = '$cat|${titleCandidates.join('|')}';
    return _showIdCache.putIfAbsent(key, () async {
      for (final raw in titleCandidates) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final id = await _searchOne(t, cat);
        if (id != null) return id;
      }
      return null;
    });
  }

  Future<String?> _searchOne(String query, String cat) async {
    try {
      final body = jsonEncode({
        'variables': {
          'search': {
            'allowAdult': false,
            'allowUnknown': false,
            'query': query,
          },
          'limit': 40,
          'page': 1,
          'translationType': cat == 'dub' ? 'dub' : 'sub',
          'countryOrigin': 'ALL',
        },
        'query': _searchGql,
      });
      final resp = await _post(_api, body, refr: _refr);
      if (resp == null) return null;
      final edges =
          ((resp['data']?['shows']?['edges']) as List?) ?? const [];
      if (edges.isEmpty) return null;

      final qLower = query.toLowerCase();
      Map<String, dynamic>? best;
      for (final e in edges) {
        if (e is! Map) continue;
        final name = (e['name'] ?? '').toString().toLowerCase();
        final eng = (e['englishName'] ?? '').toString().toLowerCase();
        if (name == qLower || eng == qLower) {
          best = e.cast<String, dynamic>();
          break;
        }
      }
      best ??= (edges.first as Map).cast<String, dynamic>();
      return best['_id']?.toString();
    } catch (e) {
      if (kDebugMode) debugPrint('[AllAnime] search "$query" failed: $e');
      return null;
    }
  }

  /// Fetches and decrypts the episode source list (cached per show/ep/cat).
  Future<List<Map<String, dynamic>>> _episodeSources(
      String showId, int episode, String cat) {
    final key = '$showId|$episode|$cat';
    return _sourcesCache.putIfAbsent(key, () async {
      try {
        final vars = jsonEncode({
          'showId': showId,
          'translationType': cat == 'dub' ? 'dub' : 'sub',
          'episodeString': '$episode',
        });
        final ext = jsonEncode({
          'persistedQuery': {
            'version': 1,
            'sha256Hash': _episodeQueryHash,
          }
        });
        final url = Uri.parse(
            '$_api?variables=${Uri.encodeQueryComponent(vars)}&extensions=${Uri.encodeQueryComponent(ext)}');

        final req = await _client.getUrl(url);
        req.headers
          ..set('User-Agent', _agent)
          ..set('Referer', _ytChan)
          ..set('Origin', _ytChan)
          ..set('Accept', 'application/json, text/plain, */*');
        final res = await req.close();
        if (res.statusCode != 200) {
          if (kDebugMode) {
            debugPrint('[AllAnime] episode HTTP ${res.statusCode}');
          }
          return const [];
        }
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body);

        final blob = (json['data']?['tobeparsed']) as String?;
        Map<String, dynamic>? episodeData;
        if (blob != null && blob.isNotEmpty) {
          final plain = _decryptTobeparsed(blob);
          if (plain == null) return const [];
          final decoded = jsonDecode(plain);
          episodeData = (decoded is Map ? decoded['episode'] : null)
              as Map<String, dynamic>?;
        } else {
          episodeData =
              (json['data']?['episode']) as Map<String, dynamic>?;
        }
        if (episodeData == null) return const [];

        final list = (episodeData['sourceUrls'] as List?) ?? const [];
        return list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);
      } catch (e) {
        if (kDebugMode) debugPrint('[AllAnime] episode-sources failed: $e');
        return const [];
      }
    });
  }

  Future<AllAnimeResult?> extractWithProvider({
    required List<String> titleCandidates,
    required int episodeNumber,
    required String category,
    required String provider,
  }) async {
    try {
      final showId = await _resolveShowId(titleCandidates, category);
      if (showId == null) return null;

      final sources = await _episodeSources(showId, episodeNumber, category);
      if (sources.isEmpty) return null;

      final wanted = provider.toLowerCase();
      final matches = sources
          .where((s) =>
              (s['sourceName'] ?? '').toString().toLowerCase() == wanted)
          .toList();
      if (matches.isEmpty) return null;

      for (final src in matches) {
        final raw = (src['sourceUrl'] ?? '').toString();
        if (raw.isEmpty) continue;

        // Plaintext iframes (ok.ru, gogo-play, mp4upload, …) — we don't have
        // extractors for those, so skip.
        if (!raw.startsWith('--')) continue;

        final decoded = _decodeXorPath(raw);
        if (decoded == null) continue;

        final result = await _resolveDecodedPath(decoded, provider);
        if (result != null) {
          if (kDebugMode) {
            debugPrint(
                '[AllAnime] OK provider=$provider ep=$episodeNumber cat=$category url=${result.url}');
          }
          return result;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AllAnime] $provider failed: $e');
      return null;
    }
  }

  /// XOR-decode a `--{hex pairs}` blob into a path string.
  String? _decodeXorPath(String raw) {
    var s = raw;
    if (s.startsWith('--')) s = s.substring(2);
    if (s.length < 2 || s.length.isOdd) return null;
    final out = StringBuffer();
    for (var i = 0; i + 1 < s.length; i += 2) {
      final byte = int.tryParse(s.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      out.writeCharCode(byte ^ 0x38);
    }
    return out.toString();
  }

  Future<AllAnimeResult?> _resolveDecodedPath(
      String path, String provider) async {
    var p = path;
    if (p.contains('/clock?') && !p.contains('/clock.json?')) {
      p = p.replaceFirst('/clock?', '/clock.json?');
    }
    final uri = p.startsWith('http')
        ? Uri.parse(p)
        : Uri.parse('$_clockHost$p');

    try {
      final req = await _client.getUrl(uri);
      req.headers
        ..set('User-Agent', _agent)
        ..set('Referer', '$_refr/')
        ..set('Origin', _refr)
        ..set('Accept', 'application/json, text/plain, */*');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      final links = (json is Map ? json['links'] as List? : null) ?? const [];
      if (links.isEmpty) return null;

      Map<String, dynamic>? hls;
      Map<String, dynamic>? mp4;
      for (final l in links) {
        if (l is! Map) continue;
        final m = l.cast<String, dynamic>();
        final link = (m['link'] ?? '').toString();
        if (link.isEmpty) continue;
        final isHls =
            m['hls'] == true || link.toLowerCase().contains('.m3u8');
        final isMp4 =
            m['mp4'] == true || link.toLowerCase().contains('.mp4');
        if (isHls && hls == null) hls = m;
        if (isMp4 && mp4 == null) mp4 = m;
      }
      final pick = hls ?? mp4 ?? (links.first as Map).cast<String, dynamic>();
      final url = (pick['link'] ?? '').toString();
      if (url.isEmpty) return null;

      final tracks = <AllAnimeTrack>[];
      final subs = pick['subtitles'];
      if (subs is List) {
        for (final t in subs) {
          if (t is! Map) continue;
          final f = (t['src'] ?? t['file'] ?? '').toString();
          if (f.isEmpty) continue;
          tracks.add(AllAnimeTrack(
            url: f,
            label: (t['label'] ?? t['lang'] ?? 'Unknown').toString(),
            isDefault: t['default'] == 'default' || t['default'] == true,
          ));
        }
      }

      // Most allanime CDNs require the allmanga.to referer to play.
      final referer = (pick['Referer'] as String?)?.trim().isNotEmpty == true
          ? pick['Referer'] as String
          : '$_refr/';
      final origin = Uri.tryParse(referer)?.origin ?? _refr;

      return AllAnimeResult(
        url: url,
        referer: referer,
        origin: origin,
        tracks: tracks,
        provider: provider,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AllAnime] resolve $uri failed: $e');
      return null;
    }
  }

  /// AES-256-CTR decrypt the `tobeparsed` blob.
  String? _decryptTobeparsed(String blob) {
    try {
      final raw = base64.decode(blob);
      if (raw.length < 13 + 16) return null;

      // IV: bytes 1..12 (skip first byte), then 4-byte big-endian counter = 2.
      final iv = Uint8List(16);
      for (var i = 0; i < 12; i++) {
        iv[i] = raw[1 + i];
      }
      iv[12] = 0;
      iv[13] = 0;
      iv[14] = 0;
      iv[15] = 2;

      final ctLen = raw.length - 13 - 16;
      if (ctLen <= 0) return null;
      final ct = Uint8List.sublistView(raw, 13, 13 + ctLen);

      final cipher = pc.CTRStreamCipher(pc.AESEngine())
        ..init(false, pc.ParametersWithIV(pc.KeyParameter(_aesKey), iv));
      final plain = cipher.process(ct);
      return utf8.decode(plain, allowMalformed: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[AllAnime] decrypt failed: $e');
      return null;
    }
  }

  Future<dynamic> _post(String url, String body,
      {required String refr}) async {
    final req = await _client.postUrl(Uri.parse(url));
    req.headers
      ..set('User-Agent', _agent)
      ..set('Referer', refr)
      ..set('Origin', refr)
      ..set('Content-Type', 'application/json')
      ..set('Accept', 'application/json, text/plain, */*');
    req.add(utf8.encode(body));
    final res = await req.close();
    if (res.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[AllAnime] POST $url HTTP ${res.statusCode}');
      }
      return null;
    }
    final txt = await res.transform(utf8.decoder).join();
    return jsonDecode(txt);
  }
}

class AllAnimeResult {
  final String url;
  final String referer;
  final String origin;
  final List<AllAnimeTrack> tracks;
  final String provider;

  const AllAnimeResult({
    required this.url,
    required this.referer,
    required this.origin,
    required this.tracks,
    required this.provider,
  });
}

class AllAnimeTrack {
  final String url;
  final String label;
  final bool isDefault;
  const AllAnimeTrack({
    required this.url,
    required this.label,
    this.isDefault = false,
  });
}
