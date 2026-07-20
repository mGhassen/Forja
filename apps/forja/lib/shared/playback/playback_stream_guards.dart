/// URL / provider guards for direct-stream playback and disk cache.
library;

import 'dart:convert';

import 'package:rust/rust.dart';

/// True for built-in webstreaming extractors (Videasy, VidSrc, …).
///
/// [StreamProviderDisplay] labels also cover playback *modes* (`stremio_direct`,
/// `amri`, `torrent`) — those must stay out of the green-Play cache.
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

/// A magnet / torrent link — NOT a direct HTTP(S) stream.
bool isTorrentStreamUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') ||
      u.contains('urn:btih:') ||
      u.endsWith('.torrent');
}

/// JWT `exp` from a compact JWS (payload only — no signature verify).
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
/// can still hold them — reject before open / cache write.
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

/// Placeholder / relative URLs must never ship in webstreaming session or disk cache.
bool isUnplayableCachedStreamUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return true;
  if (isTorrentStreamUrl(u)) return true;
  final lower = u.toLowerCase();
  if (lower.contains('demo-video')) return true;
  if (u.startsWith('/') && !u.startsWith('//')) return true;
  if (!u.contains('://')) return true;
  // Loopback play URLs (111477 seek proxy, torrent localhost, …) are session-
  // local — caching or scoring them as catalog streams marks "stream down"
  // when the port dies, while a manual catalog-URL check still passes.
  final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
  if (host == '127.0.0.1' || host == 'localhost') return true;
  if (isStreamUrlTokenExpired(u)) return true;
  return false;
}
