import '../../debrid_http.dart';
import '../../secure_settings.dart';

export '../../debrid_http.dart' show DebridFile;

class DebridAuthException implements Exception {
  final String service;
  final Object cause;

  DebridAuthException(this.service, this.cause);

  @override
  String toString() => debridUserMessage(cause, service);
}

bool isDebridAuthFailure(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('bad_token') ||
      msg.contains('"error_code": 8') ||
      msg.contains('real-debrid not logged in') ||
      msg.contains('api key not set') ||
      msg.contains('invalid api key') ||
      msg.contains('invalid_api_key') ||
      msg.contains('unauthorized') ||
      msg.contains('access denied') ||
      msg.contains('authentication failed');
}

String debridUserMessage(Object error, String service) {
  if (isDebridAuthFailure(error)) {
    return '$service login failed. Check your API key in Settings → Debrid, '
        'or turn off "Use Debrid for Streams" to use the local torrent engine.';
  }
  final raw = error.toString();
  return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
}

class DebridApi {
  static final DebridApi _instance = DebridApi._internal();
  factory DebridApi() => _instance;
  DebridApi._internal();

  static var _migrationDone = false;

  Future<void> _ensureMigrated() async {
    if (_migrationDone) return;
    var allOk = true;
    for (final key in [
      SecureSettings.rdAccessToken,
      SecureSettings.rdRefreshToken,
      SecureSettings.rdTokenExpiry,
      SecureSettings.rdClientId,
      SecureSettings.rdClientSecret,
      SecureSettings.torboxApiKey,
      SecureSettings.alldebridApiKey,
      SecureSettings.premiumizeApiKey,
      SecureSettings.debridlinkApiKey,
    ]) {
      if (!await SecureSettings.migrateFromPrefs(key)) allOk = false;
    }
    // Retry on next open when Keychain was unavailable (e.g. macOS -34018).
    if (allOk) _migrationDone = true;
  }

  Future<String?> _safeRead(String key) async {
    await _ensureMigrated();
    try {
      final v = await SecureSettings.read(key);
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    await _ensureMigrated();
    await SecureSettings.write(key, value.trim());
  }

  Future<void> _safeDelete(String key) async {
    await _ensureMigrated();
    try {
      await SecureSettings.delete(key);
    } catch (_) {}
  }

  static const String _rdTokenKey = SecureSettings.rdAccessToken;

  Future<void> saveRDApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await logoutRD();
      return;
    }
    await _safeWrite(_rdTokenKey, trimmed);
  }

  Future<String?> getRDAccessToken() => _safeRead(_rdTokenKey);

  Future<Map<String, dynamic>?> verifyRDApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = await debridRequest({
        'action': 'verify_rd',
        'api_key': trimmed,
      });
      return decoded['user'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> logoutRD() async {
    for (final key in [
      _rdTokenKey,
      SecureSettings.rdRefreshToken,
      SecureSettings.rdTokenExpiry,
      SecureSettings.rdClientId,
      SecureSettings.rdClientSecret,
    ]) {
      await _safeDelete(key);
    }
  }

  Future<void> saveTorBoxKey(String key) async =>
      _safeWrite(SecureSettings.torboxApiKey, key.trim());

  Future<String?> getTorBoxKey() => _safeRead(SecureSettings.torboxApiKey);

  Future<void> saveAllDebridKey(String key) async =>
      _safeWrite(SecureSettings.alldebridApiKey, key.trim());

  Future<String?> getAllDebridKey() =>
      _safeRead(SecureSettings.alldebridApiKey);

  Future<void> savePremiumizeKey(String key) async =>
      _safeWrite(SecureSettings.premiumizeApiKey, key.trim());

  Future<String?> getPremiumizeKey() =>
      _safeRead(SecureSettings.premiumizeApiKey);

  Future<void> saveDebridLinkKey(String key) async =>
      _safeWrite(SecureSettings.debridlinkApiKey, key.trim());

  Future<String?> getDebridLinkKey() =>
      _safeRead(SecureSettings.debridlinkApiKey);

  Future<List<DebridFile>> _resolve(
    String service,
    String apiKey,
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final decoded = await debridRequest({
      'action': 'resolve',
      'service': service,
      'api_key': apiKey,
      'magnet': magnet,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
    });
    return parseDebridFiles(decoded);
  }

  Future<List<DebridFile>> resolveRealDebrid(
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final token = await getRDAccessToken();
    if (token == null) throw Exception('Real-Debrid not logged in');
    return _resolve(
      'Real-Debrid',
      token,
      magnet,
      season: season,
      episode: episode,
    );
  }

  Future<List<DebridFile>> resolveTorBox(
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final apiKey = await getTorBoxKey();
    if (apiKey == null) throw Exception('TorBox API Key not set');
    return _resolve('TorBox', apiKey, magnet, season: season, episode: episode);
  }

  Future<List<DebridFile>> resolveAllDebrid(
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final apiKey = await getAllDebridKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('AllDebrid API key not set');
    }
    return _resolve(
      'AllDebrid',
      apiKey,
      magnet,
      season: season,
      episode: episode,
    );
  }

  Future<List<DebridFile>> resolvePremiumize(
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final apiKey = await getPremiumizeKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Premiumize API key not set');
    }
    return _resolve(
      'Premiumize',
      apiKey,
      magnet,
      season: season,
      episode: episode,
    );
  }

  Future<List<DebridFile>> resolveDebridLink(
    String magnet, {
    int? season,
    int? episode,
  }) async {
    final apiKey = await getDebridLinkKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Debrid-Link API key not set');
    }
    return _resolve(
      'Debrid-Link',
      apiKey,
      magnet,
      season: season,
      episode: episode,
    );
  }

  Future<List<DebridFile>> resolveByService(
    String service,
    String magnet, {
    int? season,
    int? episode,
  }) {
    switch (service) {
      case 'Real-Debrid':
        return resolveRealDebrid(magnet, season: season, episode: episode);
      case 'TorBox':
        return resolveTorBox(magnet, season: season, episode: episode);
      case 'AllDebrid':
        return resolveAllDebrid(magnet, season: season, episode: episode);
      case 'Premiumize':
        return resolvePremiumize(magnet, season: season, episode: episode);
      case 'Debrid-Link':
        return resolveDebridLink(magnet, season: season, episode: episode);
      default:
        throw Exception('Unknown debrid service: $service');
    }
  }
}
