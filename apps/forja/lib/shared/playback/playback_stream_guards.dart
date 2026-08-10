/// URL / provider guards for direct-stream playback and disk cache.
library;

import 'dart:convert';

import 'package:forja/shared/extractors/providers/vidnest/vidnest_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrcwin/profile.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:rust/rust.dart';

/// True for built-in webstreaming extractors (Videasy, VidSrc, …).
///
/// [StreamProviderDisplay] labels also cover playback *modes* (`stremio_direct`,
/// `amri`, `torrent`) - those must stay out of the green-Play cache.
bool isWebStreamProviderId(String sourceId) {
  if (sourceId.isEmpty) return false;
  if (sourceId.startsWith('nuvio:')) return false;
  if (isCatalogSourcesMode(sourceId)) return false;
  final id = StreamProviderDisplay.canonicalId(sourceId);
  if (StreamProviders.providers.containsKey(id)) return true;
  // Display-profile aliases that are still web extractors (e.g. kisskh).
  return StreamProviderDisplay.hasProfile(id);
}

/// True for playback modes that use the torrent/Stremio **Sources** right panel
/// (not the layers webstreaming server picker).
bool isCatalogSourcesMode(String? providerId) {
  if (providerId == null || providerId.isEmpty) return false;
  if (providerId.startsWith('nuvio:')) return true;
  const modes = {'stremio_direct', 'amri', 'torrent'};
  return modes.contains(StreamProviderDisplay.canonicalId(providerId));
}

/// A magnet / torrent link - NOT a direct HTTP(S) stream.
bool isTorrentStreamUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') ||
      u.contains('urn:btih:') ||
      u.endsWith('.torrent');
}

/// JWT `exp` from a compact JWS (payload only - no signature verify).
int? jwtExpiryUnix(String jwt) {
  final parts = jwt.split('.');
  if (parts.length < 2) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final map = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (map is! Map) return null;
    final exp = map['exp'];
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
    return null;
  } catch (_) {
    return null;
  }
}

/// True when `?token=` JWT is expired or within [skew] of expiry.
///
/// CloudStream / tokenized HLS URLs die at JWT `exp` while session/disk cache
/// can still hold them - reject before open / cache write.
bool isStreamUrlTokenExpired(
  String url, {
  Duration skew = const Duration(minutes: 2),
  DateTime? now,
}) {
  final token = Uri.tryParse(url.trim())?.queryParameters['token'];
  if (token == null || token.isEmpty) return false;
  final exp = jwtExpiryUnix(token);
  if (exp == null) return false;
  final deadline = DateTime.fromMillisecondsSinceEpoch(
    exp * 1000,
    isUtc: true,
  ).subtract(skew);
  return !(now ?? DateTime.now()).toUtc().isBefore(deadline);
}

/// Session-local loopback play endpoints (HLS strip proxy, torrent stream, …).
///
/// These are valid to open in the player but must not be written to catalog
/// stream caches as if they were durable CDN URLs.
bool isLocalLoopbackPlayUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
  final p = uri.path;
  if (p.contains('/hls-proxy')) return true;
  if (p.contains('/jellyfin-stream')) return true;
  if (p.contains('/toky-proxy')) return true;
  if (p.contains('/comic-proxy')) return true;
  if (p.contains('/subtitlecat-translate')) return true;
  if (p.startsWith('/proxy')) return true;
  // librqbit HTTP piece server
  if (p.contains('/torrents/') && p.contains('/stream/')) return true;
  return false;
}

/// Placeholder / relative URLs must never ship in webstreaming session or disk cache.
bool isUnplayableCachedStreamUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return true;
  if (isTorrentStreamUrl(u)) return true;
  final lower = u.toLowerCase();
  if (lower.contains('demo-video')) return true;
  if (u.startsWith('/') && !u.startsWith('//')) return true;
  if (!u.contains('://')) return true;
  // Unknown loopback is session junk; known engine proxies / torrent streams
  // are playable (hls-proxy strip=png, jellyfin, librqbit, …).
  final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
  if (host == '127.0.0.1' || host == 'localhost') {
    return !isLocalLoopbackPlayUrl(u);
  }
  if (isStreamUrlTokenExpired(u)) return true;
  return false;
}

/// Catalog URL inside a local `/hls-proxy?url=…` play endpoint, if any.
String? hlsProxyTargetUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (!uri.path.contains('/hls-proxy')) return null;
  final target = uri.queryParameters['url']?.trim() ?? '';
  return target.isEmpty ? null : target;
}

/// Durable catalog identity for Source panel / session cache - never loopback.
String? durableStreamCatalogUrl({
  String? catalogUrl,
  String? sourceUrl,
  String? playUrl,
}) {
  final play = playUrl?.trim();
  for (final candidate in <String?>[
    catalogUrl,
    sourceUrl,
    if (play != null && play.isNotEmpty) hlsProxyTargetUrl(play),
    play,
  ]) {
    final u = candidate?.trim() ?? '';
    if (u.isEmpty) continue;
    final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
    if (host == '127.0.0.1' || host == 'localhost') continue;
    if (isLocalLoopbackPlayUrl(u)) continue;
    return u;
  }
  return null;
}

/// Whether [source] is the row currently playing (catalog or play URL).
bool streamSourceMatchesPlaying(
  StreamSource source, {
  String? playUrl,
  String? catalogUrl,
}) {
  final play = playUrl?.trim() ?? '';
  final catalog = catalogUrl?.trim() ?? '';
  final url = source.url.trim();
  final sourceCatalog = source.catalogUrl?.trim() ?? '';
  final playTarget = play.isEmpty ? '' : (hlsProxyTargetUrl(play) ?? '');
  final urlTarget = url.isEmpty ? '' : (hlsProxyTargetUrl(url) ?? '');

  bool hit(String a, String b) => a.isNotEmpty && b.isNotEmpty && a == b;

  // Direct / catalog identity.
  if (hit(url, play) || hit(url, catalog)) return true;
  if (hit(sourceCatalog, play) || hit(sourceCatalog, catalog)) return true;
  // Proxy play URL ↔ catalog row (PNG-strip / hls-proxy).
  if (hit(url, playTarget) || hit(sourceCatalog, playTarget)) return true;
  if (hit(urlTarget, catalog) || hit(urlTarget, playTarget)) return true;
  return false;
}

/// True when [title] matches Videasy Servers-tab mirror labels (`Yoru · …`).
///
/// Used to reject Videasy API rows that were wrongly cached under another
/// server (VSEmbed / VidLink / …) after a shared-sniff race.
bool hasVideasyMirrorTitle(String title) {
  return _titleMatchesAnyLabel(title, VideasyExtractor.serverChipLabels);
}

/// True when [title] matches VidNest API mirror labels (`Gama · …`).
bool hasVidnestMirrorTitle(String title) {
  return _titleMatchesAnyLabel(title, VidnestExtractor.serverDisplayNames);
}

/// True when [title] matches VidSrc.win chip labels (`Alpha · …`).
bool hasVidsrcwinMirrorTitle(String title) {
  return _titleMatchesAnyLabel(title, vidsrcwinExtractProfile.serverChipLabels);
}

bool _titleMatchesAnyLabel(String title, Iterable<String> labels) {
  final t = title.trim();
  if (t.isEmpty) return false;
  for (final label in labels) {
    final l = label.trim();
    if (l.isEmpty) continue;
    if (t == l ||
        t.startsWith('$l ·') ||
        t.startsWith('$l -') ||
        t.startsWith('$l ')) {
      return true;
    }
  }
  return false;
}

/// True when [title] is clearly another provider's row (display name or
/// mirror chips) - catches restamped/null providerId cache poison.
bool hasForeignProviderTitle(String bucketId, String title) {
  final want = StreamProviderDisplay.canonicalId(bucketId);
  if (want.isEmpty) return false;
  final t = title.trim();
  if (t.isEmpty) return false;

  if (want != 'videasy' && hasVideasyMirrorTitle(t)) return true;
  if (want != 'vidnest' && hasVidnestMirrorTitle(t)) return true;
  if (want != 'vidsrcwin' && hasVidsrcwinMirrorTitle(t)) return true;

  for (final id in StreamProviderDisplay.labeledProviderIds) {
    final other = StreamProviderDisplay.canonicalId(id);
    if (other.isEmpty || other == want) continue;
    // Modes / non-stream labels are not mirror titles.
    if (isCatalogSourcesMode(other)) continue;
    final label = StreamProviderDisplay.playerLabel(other);
    if (_titleMatchesAnyLabel(t, [label])) return true;
  }
  return false;
}

bool _providerIdsCompatible(String bucketId, String sourceId) {
  final want = StreamProviderDisplay.canonicalId(bucketId);
  final got = StreamProviderDisplay.canonicalId(sourceId);
  if (want == got) return true;
  // Nuvio pipes: `nuvio:vidsrc` sources may carry either form.
  if (want.startsWith('nuvio:') && got == want.split(':').last) return true;
  if (got.startsWith('nuvio:') && want == got.split(':').last) return true;
  return false;
}

/// Whether [source] may appear under the Sources panel row for [providerId].
bool sourceBelongsToProvider(String providerId, StreamSource source) {
  final want = StreamProviderDisplay.canonicalId(providerId);
  if (want.isEmpty) return true;

  final raw = source.providerId?.trim();
  if (raw != null && raw.isNotEmpty) {
    if (!_providerIdsCompatible(want, raw)) return false;
  }

  // After host ingest, providerId is often restamped to the requested server
  // while the foreign title survives - never show those under another server.
  if (hasForeignProviderTitle(want, source.title)) return false;
  return true;
}

/// Keep only rows that belong to [providerId]; stamp [providerId] on survivors.
List<StreamSource> sourcesOwnedByProvider(
  String providerId,
  List<StreamSource> sources,
) {
  final want = providerId.trim();
  if (want.isEmpty || sources.isEmpty) return sources;
  final out = <StreamSource>[];
  for (final s in sources) {
    if (!sourceBelongsToProvider(want, s)) continue;
    final pid = s.providerId?.trim();
    if (pid == null || pid.isEmpty) {
      out.add(s.copyWith(providerId: want));
    } else {
      out.add(s);
    }
  }
  return out;
}

/// Panel / session list for a server - never prefer a short live list over a
/// fuller cache (selecting a stream must not wipe sibling mirrors).
List<StreamSource> preferFullerProviderSources({
  required String providerId,
  List<StreamSource>? live,
  List<StreamSource>? cached,
}) {
  final a = sourcesOwnedByProvider(
    providerId,
    live == null || live.isEmpty ? const [] : dedupeStreamSources(live),
  );
  final b = sourcesOwnedByProvider(
    providerId,
    cached == null || cached.isEmpty ? const [] : dedupeStreamSources(cached),
  );
  if (b.length > a.length) return b;
  if (a.isNotEmpty) return a;
  return b;
}
