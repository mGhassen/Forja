import 'package:shared_preferences/shared_preferences.dart';

import 'kv.dart';
import 'secure_settings.dart';

/// Persistent settings for the local WebStreamr port.
///
/// Non-secret prefs live in Rust KV (`forja_engine_store.json`).
/// MFP password and TMDB token live in [SecureSettings].
class WebStreamrSettings {
  static const _kCountryCodes = 'webstreamr_country_codes';
  static const _kMfpUrl = 'webstreamr_mfp_url';
  static const _kFlareUrl = 'webstreamr_flare_url';
  static const _kDisabledExtractors = 'webstreamr_disabled_extractors';
  static const _kExcludedResolutions = 'webstreamr_excluded_resolutions';
  static const _kMigratedKey = 'webstreamr_settings_kv_v1';

  /// Default country set when nothing is saved yet. Enables EVERY supported
  /// CC so foreign-language sources (DE/FR/IT/ES/AL/RU/...) light up
  /// out-of-the-box. Users can still narrow the list in Settings.
  static List<String> get defaultCountryCodes =>
      <String>['multi', ...allCountryCodes];

  /// All supported country codes (the WebStreamr CountryCode enum minus
  /// `multi` which is always on).
  static const allCountryCodes = <String>[
    'al', 'ar', 'bg', 'bl', 'cs', 'de', 'el', 'en', 'es', 'et', 'fa', 'fr',
    'gu', 'he', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'kn', 'ko', 'lt', 'lv',
    'ml', 'mr', 'mx', 'nl', 'no', 'pa', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl',
    'sr', 'ta', 'te', 'th', 'tr', 'uk', 'vi', 'zh',
  ];

  /// All extractor ids in the local pipeline (excluding `external` which is
  /// the catch-all and shouldn't be disabled).
  static const allExtractorIds = <String>[
    'doodstream', 'dropload', 'fastream', 'filelions', 'filemoon', 'fsst',
    'hubcloud', 'hubdrive', 'kinoger', 'lulustream', 'mixdrop', 'rgshows',
    'savefiles', 'streamembed', 'streamtape', 'supervideo', 'uqload',
    'vidora', 'vidsrc', 'vixsrc', 'voe', 'youtube',
  ];

  static const allResolutions = <String>['360p', '480p', '720p', '1080p', '4k'];

  static Future<void> _ensureMigrated() async {
    if (await kvHasKey(_kMigratedKey)) return;
    final p = await SharedPreferences.getInstance();

    final countries = p.getStringList(_kCountryCodes);
    if (countries != null) {
      await kvSetStringList(_kCountryCodes, countries);
      await p.remove(_kCountryCodes);
    }
    for (final key in [_kMfpUrl, _kFlareUrl]) {
      final v = p.getString(key);
      if (v != null && v.isNotEmpty) {
        await kvSetString(key, v);
        await p.remove(key);
      }
    }
    for (final key in [_kDisabledExtractors, _kExcludedResolutions]) {
      final list = p.getStringList(key);
      if (list != null) {
        await kvSetStringList(key, list);
        await p.remove(key);
      }
    }

    await SecureSettings.migrateFromPrefs(SecureSettings.webstreamrMfpPassword);
    // Legacy prefs used the same key strings.
    await SecureSettings.migrateFromPrefs('webstreamr_mfp_password');
    await SecureSettings.migrateFromPrefs(SecureSettings.webstreamrTmdbToken);
    await SecureSettings.migrateFromPrefs('webstreamr_tmdb_token');

    await kvSetString(_kMigratedKey, '1');
  }

  static Future<List<String>> getEnabledCountryCodes() async {
    await _ensureMigrated();
    if (!await kvHasKey(_kCountryCodes)) {
      return List.of(defaultCountryCodes);
    }
    return kvGetStringList(_kCountryCodes, fallback: defaultCountryCodes);
  }

  static Future<void> setEnabledCountryCodes(List<String> codes) async {
    await _ensureMigrated();
    await kvSetStringList(_kCountryCodes, codes);
  }

  static Future<String?> getMediaFlowProxyUrl() async {
    await _ensureMigrated();
    final v = await kvGetString(_kMfpUrl);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> setMediaFlowProxyUrl(String? v) async {
    await _ensureMigrated();
    await kvSetString(_kMfpUrl, v == null || v.isEmpty ? '' : v);
  }

  static Future<String?> getMediaFlowProxyPassword() async {
    await _ensureMigrated();
    return SecureSettings.read(SecureSettings.webstreamrMfpPassword);
  }

  static Future<void> setMediaFlowProxyPassword(String? v) async {
    await _ensureMigrated();
    if (v == null || v.isEmpty) {
      await SecureSettings.delete(SecureSettings.webstreamrMfpPassword);
    } else {
      await SecureSettings.write(SecureSettings.webstreamrMfpPassword, v);
    }
  }

  static Future<String?> getFlareSolverrUrl() async {
    await _ensureMigrated();
    final v = await kvGetString(_kFlareUrl);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> setFlareSolverrUrl(String? v) async {
    await _ensureMigrated();
    await kvSetString(_kFlareUrl, v == null || v.isEmpty ? '' : v);
  }

  static Future<List<String>> getDisabledExtractors() async {
    await _ensureMigrated();
    return kvGetStringList(_kDisabledExtractors, fallback: const []);
  }

  static Future<void> setDisabledExtractors(List<String> ids) async {
    await _ensureMigrated();
    await kvSetStringList(_kDisabledExtractors, ids);
  }

  static Future<List<String>> getExcludedResolutions() async {
    await _ensureMigrated();
    return kvGetStringList(_kExcludedResolutions, fallback: const []);
  }

  static Future<void> setExcludedResolutions(List<String> res) async {
    await _ensureMigrated();
    await kvSetStringList(_kExcludedResolutions, res);
  }

  /// Config map for [get_streams_json] / ResolverEngine (countries, MFP, filters).
  static Future<Map<String, String>> buildResolveConfig() async {
    final config = <String, String>{};
    for (final cc in await getEnabledCountryCodes()) {
      config[cc] = 'on';
    }
    config['multi'] = 'on';

    final mfpUrl = await getMediaFlowProxyUrl();
    final mfpPwd = await getMediaFlowProxyPassword();
    if (mfpUrl != null && mfpUrl.isNotEmpty) {
      config['mediaFlowProxyUrl'] = mfpUrl;
      if (mfpPwd != null) config['mediaFlowProxyPassword'] = mfpPwd;
    }

    for (final exId in await getDisabledExtractors()) {
      config['disableExtractor_$exId'] = 'on';
    }
    for (final res in await getExcludedResolutions()) {
      config['excludeResolution_$res'] = 'on';
    }
    return config;
  }

  static Future<String?> getTmdbAccessToken() async {
    await _ensureMigrated();
    return SecureSettings.read(SecureSettings.webstreamrTmdbToken);
  }

  static Future<void> setTmdbAccessToken(String? v) async {
    await _ensureMigrated();
    if (v == null || v.isEmpty) {
      await SecureSettings.delete(SecureSettings.webstreamrTmdbToken);
    } else {
      await SecureSettings.write(SecureSettings.webstreamrTmdbToken, v);
    }
  }
}
