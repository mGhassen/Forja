import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'kv.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static final ValueNotifier<int> addonChangeNotifier = ValueNotifier<int>(0);

  static const String _streamingModeKey = 'streaming_mode';
  static const String _playSourceTorrentKey = 'play_source_torrent_enabled';
  static const String _playSourceStremioKey = 'play_source_stremio_enabled';
  static const String _playSourceWebstreamingKey =
      'play_source_webstreaming_enabled';
  static const String _sortPreferenceKey = 'sort_preference';
  static const String _useDebridKey = 'use_debrid_for_streams';
  static const String _debridServiceKey = 'debrid_service';
  static const String _stremioAddonsKey = 'stremio_addons';
  static const String _externalPlayerKey = 'external_player';
  static const String _jackettBaseUrlKey = 'jackett_base_url';
  static const String _jackettApiKeyKey = 'jackett_api_key';
  static const String _prowlarrBaseUrlKey = 'prowlarr_base_url';
  static const String _prowlarrApiKeyKey = 'prowlarr_api_key';
  static const String _prowlarrTagIdsKey = 'prowlarr_tag_ids';
  static const String _themePresetKey = 'theme_preset';
  static const String _torrentCacheTypeKey = 'torrent_cache_type';
  static const String _torrentRamCacheMbKey = 'torrent_ram_cache_mb';
  static const String _torrentConnectionsLimitKey = 'torrent_connections_limit';
  static const String _subSizeKey = 'sub_size';
  static const String _subColorKey = 'sub_color';
  static const String _subBgOpacityKey = 'sub_bg_opacity';
  static const String _subBoldKey = 'sub_bold';
  static const String _subBottomPaddingKey = 'sub_bottom_padding';
  static const String _subFontKey = 'sub_font';
  static const String _preferredAudioLangKey = 'preferred_audio_lang';
  static const String _avoidUnsupportedAudioKey = 'avoid_unsupported_audio';
  static const String _iptvEpgEnabledKey = 'iptv_epg_enabled';

  static final ValueNotifier<bool> iptvEpgEnabledNotifier =
      ValueNotifier<bool>(true);

  Future<String> getPreferredAudioLanguage() async =>
      await kvGetString(_preferredAudioLangKey) ?? 'None';

  Future<void> setPreferredAudioLanguage(String v) async =>
      kvSetString(_preferredAudioLangKey, v);

  Future<bool> getAvoidUnsupportedAudio() async =>
      kvGetBool(_avoidUnsupportedAudioKey, fallback: true);

  Future<void> setAvoidUnsupportedAudio(bool v) async =>
      kvSetBool(_avoidUnsupportedAudioKey, v);

  Future<bool> isIptvEpgEnabled() async =>
      kvGetBool(_iptvEpgEnabledKey, fallback: true);

  Future<void> setIptvEpgEnabled(bool enabled) async {
    await kvSetBool(_iptvEpgEnabledKey, enabled);
    iptvEpgEnabledNotifier.value = enabled;
  }

  Future<double> getSubSize({bool isDesktop = false}) async =>
      kvGetDouble(_subSizeKey, fallback: isDesktop ? 44.0 : 24.0);

  Future<void> setSubSize(double v) async => kvSetDouble(_subSizeKey, v);

  Future<int> getSubColor() async =>
      kvGetInt(_subColorKey, fallback: 0xFFFFFFFF);

  Future<void> setSubColor(int v) async => kvSetInt(_subColorKey, v);

  Future<double> getSubBgOpacity() async =>
      kvGetDouble(_subBgOpacityKey, fallback: 0.67);

  Future<void> setSubBgOpacity(double v) async =>
      kvSetDouble(_subBgOpacityKey, v);

  Future<bool> getSubBold() async => kvGetBool(_subBoldKey, fallback: false);

  Future<void> setSubBold(bool v) async => kvSetBool(_subBoldKey, v);

  Future<double> getSubBottomPadding() async =>
      kvGetDouble(_subBottomPaddingKey, fallback: 24.0);

  Future<void> setSubBottomPadding(double v) async =>
      kvSetDouble(_subBottomPaddingKey, v);

  Future<String> getSubFont() async =>
      await kvGetString(_subFontKey) ?? 'Default';

  Future<void> setSubFont(String v) async => kvSetString(_subFontKey, v);

  Future<List<Map<String, dynamic>>> getStremioAddons() async =>
      kvGetMapList(_stremioAddonsKey);

  Future<void> saveStremioAddon(Map<String, dynamic> addon) async {
    final current = await getStremioAddons();
    current.removeWhere((a) => a['baseUrl'] == addon['baseUrl']);
    current.add(addon);
    await kvSetMapList(_stremioAddonsKey, current);
    addonChangeNotifier.value++;
  }

  Future<void> removeStremioAddon(String baseUrl) async {
    final current = await getStremioAddons();
    current.removeWhere((a) => a['baseUrl'] == baseUrl);
    await kvSetMapList(_stremioAddonsKey, current);
    addonChangeNotifier.value++;
  }

  Future<bool> isStreamingModeEnabled() async =>
      kvGetBool(_streamingModeKey, fallback: false);

  Future<void> setStreamingMode(bool enabled) async =>
      kvSetBool(_streamingModeKey, enabled);

  Future<bool> isPlaySourceTorrentEnabled() async =>
      kvGetBool(_playSourceTorrentKey, fallback: true);

  Future<void> setPlaySourceTorrentEnabled(bool enabled) async =>
      kvSetBool(_playSourceTorrentKey, enabled);

  Future<bool> isPlaySourceStremioEnabled() async =>
      kvGetBool(_playSourceStremioKey, fallback: true);

  Future<void> setPlaySourceStremioEnabled(bool enabled) async =>
      kvSetBool(_playSourceStremioKey, enabled);

  Future<bool> isPlaySourceWebstreamingEnabled() async =>
      kvGetBool(_playSourceWebstreamingKey, fallback: true);

  Future<void> setPlaySourceWebstreamingEnabled(bool enabled) async =>
      kvSetBool(_playSourceWebstreamingKey, enabled);

  static const String _streamProviderOrderKey = 'stream_provider_order';
  static const List<String> defaultStreamProviderOrder = <String>[
    'videasy',
    'vidlink',
    'vidsrc',
    'vixsrc',
    'vidnest',
    'service111477',
    'webstreamr',
  ];

  Future<List<String>> getStreamProviderOrder() async {
    final saved =
        await kvGetStringList(_streamProviderOrderKey, fallback: const []);
    if (saved.isEmpty) {
      return List<String>.from(defaultStreamProviderOrder);
    }
    final out = <String>[...saved];
    for (final k in defaultStreamProviderOrder) {
      if (!out.contains(k)) out.add(k);
    }
    return out;
  }

  static List<String> mergeProviderOrder(
    List<String> saved,
    Iterable<String> available,
  ) {
    final availSet = available.toSet();
    final out = <String>[];
    for (final k in saved) {
      if (availSet.contains(k) && !out.contains(k)) out.add(k);
    }
    for (final k in available) {
      if (!out.contains(k)) out.add(k);
    }
    return out;
  }

  Future<void> setStreamProviderOrder(List<String> order) async =>
      kvSetStringList(_streamProviderOrderKey, order);

  Future<String> getSortPreference() async =>
      await kvGetString(_sortPreferenceKey) ?? 'Seeders (High to Low)';

  Future<void> setSortPreference(String preference) async =>
      kvSetString(_sortPreferenceKey, preference);

  Future<bool> useDebridForStreams() async =>
      kvGetBool(_useDebridKey, fallback: false);

  Future<void> setUseDebridForStreams(bool enabled) async =>
      kvSetBool(_useDebridKey, enabled);

  Future<String> getDebridService() async =>
      await kvGetString(_debridServiceKey) ?? 'None';

  Future<void> setDebridService(String service) async =>
      kvSetString(_debridServiceKey, service);

  Future<String> getExternalPlayer() async =>
      await kvGetString(_externalPlayerKey) ?? 'Built-in Player';

  Future<void> setExternalPlayer(String player) async =>
      kvSetString(_externalPlayerKey, player);

  Future<String?> getJackettBaseUrl() async =>
      kvGetString(_jackettBaseUrlKey);

  Future<void> setJackettBaseUrl(String url) async {
    final normalized = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await kvSetString(_jackettBaseUrlKey, normalized);
  }

  Future<String?> getJackettApiKey() async => kvGetString(_jackettApiKeyKey);

  Future<void> setJackettApiKey(String apiKey) async =>
      kvSetString(_jackettApiKeyKey, apiKey);

  Future<bool> isJackettConfigured() async {
    final baseUrl = await getJackettBaseUrl();
    final apiKey = await getJackettApiKey();
    return baseUrl != null &&
        baseUrl.isNotEmpty &&
        apiKey != null &&
        apiKey.isNotEmpty;
  }

  Future<String?> getProwlarrBaseUrl() async =>
      kvGetString(_prowlarrBaseUrlKey);

  Future<void> setProwlarrBaseUrl(String url) async {
    final normalized = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await kvSetString(_prowlarrBaseUrlKey, normalized);
  }

  Future<String?> getProwlarrApiKey() async =>
      kvGetString(_prowlarrApiKeyKey);

  Future<void> setProwlarrApiKey(String apiKey) async =>
      kvSetString(_prowlarrApiKeyKey, apiKey);

  Future<bool> isProwlarrConfigured() async {
    final baseUrl = await getProwlarrBaseUrl();
    final apiKey = await getProwlarrApiKey();
    return baseUrl != null &&
        baseUrl.isNotEmpty &&
        apiKey != null &&
        apiKey.isNotEmpty;
  }

  Future<List<int>> getProwlarrTagIds() async {
    final stored =
        await kvGetStringList(_prowlarrTagIdsKey, fallback: const []);
    return stored
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id >= 0)
        .toList();
  }

  Future<void> setProwlarrTagIds(List<int> tagIds) async =>
      kvSetStringList(
        _prowlarrTagIdsKey,
        tagIds.map((id) => id.toString()).toList(),
      );

  Future<String> getTorrentCacheType() async =>
      await kvGetString(_torrentCacheTypeKey) ?? 'ram';

  Future<void> setTorrentCacheType(String type) async =>
      kvSetString(_torrentCacheTypeKey, type);

  Future<int> getTorrentRamCacheMb() async =>
      kvGetInt(_torrentRamCacheMbKey, fallback: 200);

  Future<void> setTorrentRamCacheMb(int mb) async =>
      kvSetInt(_torrentRamCacheMbKey, mb);

  Future<int> getTorrentConnectionsLimit() async =>
      kvGetInt(_torrentConnectionsLimitKey, fallback: 200);

  Future<void> setTorrentConnectionsLimit(int limit) async =>
      kvSetInt(_torrentConnectionsLimitKey, limit);

  Future<String> getThemePreset() async => 'forja';

  Future<void> setThemePreset(String preset) async {}

  static const String _navbarConfigKey = 'navbar_config';
  static const String _navbarKnownIdsKey = 'navbar_known_ids';
  static const String _navbarShell080Key = 'navbar_shell_080';
  static const String _navbarShell081Key = 'navbar_shell_081';
  static final ValueNotifier<int> navbarChangeNotifier = ValueNotifier<int>(0);

  /// Default visible tabs (settings appended in MainScreen).
  static const List<String> defaultVisibleNavIds = ['home', 'search', 'mylist'];

  static const List<String> allNavIds = [
    'home',
    'discover',
    'similar',
    'search',
    'mylist',
    'downloader',
    'magnet',
    'live_matches',
    'iptv',
    'audiobooks',
    'books',
    'music',
    'comics',
    'manga',
    'jellyfin',
    'anime',
    'anime_arabic',
    'asian_drama',
    'arabic',
  ];

  Future<List<String>> getNavbarConfig() async {
    if (!await kvHasKey(_navbarShell080Key)) {
      await kvSetStringList(_navbarConfigKey, const ['home', 'search']);
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
      await kvSetString(_navbarShell080Key, '1');
    }
    if (!await kvHasKey(_navbarShell081Key)) {
      final raw = await kvHasKey(_navbarConfigKey)
          ? await kvGetStringList(_navbarConfigKey, fallback: const [])
          : List<String>.from(defaultVisibleNavIds);
      final updated = raw.where((id) => allNavIds.contains(id)).toList();
      if (!updated.contains('mylist')) {
        final searchIdx = updated.indexOf('search');
        if (searchIdx >= 0) {
          updated.insert(searchIdx + 1, 'mylist');
        } else {
          updated.add('mylist');
        }
      }
      await kvSetStringList(_navbarConfigKey, updated);
      await kvSetString(_navbarShell081Key, '1');
    }
    if (!await kvHasKey(_navbarConfigKey)) {
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
      return List.from(defaultVisibleNavIds);
    }
    final raw =
        await kvGetStringList(_navbarConfigKey, fallback: const []);
    final filtered = raw.where((id) => allNavIds.contains(id)).toList();
    final known =
        (await kvGetStringList(_navbarKnownIdsKey, fallback: const []))
            .toSet();
    final newlyAdded = <String>[];
    for (var i = 0; i < allNavIds.length; i++) {
      final id = allNavIds[i];
      if (filtered.contains(id)) continue;
      if (known.contains(id)) continue;
      newlyAdded.add(id);
      var insertAt = filtered.length;
      for (var j = i - 1; j >= 0; j--) {
        final idx = filtered.indexOf(allNavIds[j]);
        if (idx >= 0) {
          insertAt = idx + 1;
          break;
        }
      }
      filtered.insert(insertAt, id);
    }
    if (newlyAdded.isNotEmpty || known.length != allNavIds.length) {
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
    }
    return filtered;
  }

  Future<void> setNavbarConfig(List<String> visibleIds) async {
    await kvSetStringList(_navbarConfigKey, visibleIds);
    await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
    navbarChangeNotifier.value++;
  }

  static const List<String> _secureKeys = [
    'rd_access_token',
    'rd_refresh_token',
    'rd_token_expiry',
    'rd_client_id',
    'rd_client_secret',
    'torbox_api_key',
    'trakt_access_token',
    'trakt_refresh_token',
    'trakt_expires_at',
  ];

  Future<Map<String, dynamic>> exportAllSettings() async {
    const secure = FlutterSecureStorage();
    final prefsMap = <String, dynamic>{};

    prefsMap[_streamingModeKey] =
        await kvGetBool(_streamingModeKey, fallback: false);
    prefsMap[_useDebridKey] = await kvGetBool(_useDebridKey, fallback: false);
    prefsMap[_playSourceTorrentKey] = await isPlaySourceTorrentEnabled();
    prefsMap[_playSourceStremioKey] = await isPlaySourceStremioEnabled();
    prefsMap[_playSourceWebstreamingKey] =
        await isPlaySourceWebstreamingEnabled();
    for (final key in [
      _sortPreferenceKey,
      _debridServiceKey,
      _externalPlayerKey,
      _jackettBaseUrlKey,
      _jackettApiKeyKey,
      _prowlarrBaseUrlKey,
      _prowlarrApiKeyKey,
      _torrentCacheTypeKey,
    ]) {
      final v = await kvGetString(key);
      if (v != null) prefsMap[key] = v;
    }
    prefsMap[_torrentRamCacheMbKey] =
        await kvGetInt(_torrentRamCacheMbKey, fallback: 200);
    prefsMap[_torrentConnectionsLimitKey] =
        await kvGetInt(_torrentConnectionsLimitKey, fallback: 200);
    prefsMap[_navbarConfigKey] =
        await kvGetStringList(_navbarConfigKey, fallback: const []);
    prefsMap[_prowlarrTagIdsKey] =
        await kvGetStringList(_prowlarrTagIdsKey, fallback: const []);
    final stremio = await getStremioAddons();
    if (stremio.isNotEmpty) {
      prefsMap[_stremioAddonsKey] = stremio.map(jsonEncode).toList();
    }
    final streamOrder = await kvGetStringList(
      _streamProviderOrderKey,
      fallback: const [],
    );
    if (streamOrder.isNotEmpty) {
      prefsMap[_streamProviderOrderKey] = streamOrder;
    }

    final secureMap = <String, String>{};
    for (final key in _secureKeys) {
      final v = await secure.read(key: key);
      if (v != null) secureMap[key] = v;
    }

    return {
      'shared_preferences': prefsMap,
      'secure_storage': secureMap,
      'export_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllSettings(Map<String, dynamic> data) async {
    const secure = FlutterSecureStorage();
    final prefsMap = data['shared_preferences'] as Map<String, dynamic>? ?? {};

    for (final key in [
      _streamingModeKey,
      _useDebridKey,
      _playSourceTorrentKey,
      _playSourceStremioKey,
      _playSourceWebstreamingKey,
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetBool(key, prefsMap[key] as bool);
      }
    }
    for (final key in [
      _sortPreferenceKey,
      _debridServiceKey,
      _externalPlayerKey,
      _jackettBaseUrlKey,
      _jackettApiKeyKey,
      _prowlarrBaseUrlKey,
      _prowlarrApiKeyKey,
      _torrentCacheTypeKey,
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetString(key, prefsMap[key] as String);
      }
    }
    if (prefsMap.containsKey(_torrentRamCacheMbKey)) {
      await kvSetInt(_torrentRamCacheMbKey, prefsMap[_torrentRamCacheMbKey] as int);
    }
    if (prefsMap.containsKey(_torrentConnectionsLimitKey)) {
      await kvSetInt(
        _torrentConnectionsLimitKey,
        prefsMap[_torrentConnectionsLimitKey] as int,
      );
    }
    if (prefsMap.containsKey(_navbarConfigKey)) {
      await kvSetStringList(
        _navbarConfigKey,
        (prefsMap[_navbarConfigKey] as List).cast<String>(),
      );
    }
    if (prefsMap.containsKey(_prowlarrTagIdsKey)) {
      await kvSetStringList(
        _prowlarrTagIdsKey,
        (prefsMap[_prowlarrTagIdsKey] as List).cast<String>(),
      );
    }
    if (prefsMap.containsKey(_stremioAddonsKey)) {
      final encoded = (prefsMap[_stremioAddonsKey] as List).cast<String>();
      await kvSetMapList(
        _stremioAddonsKey,
        encoded.map((s) => jsonDecode(s) as Map<String, dynamic>).toList(),
      );
    }
    if (prefsMap.containsKey(_streamProviderOrderKey)) {
      await kvSetStringList(
        _streamProviderOrderKey,
        (prefsMap[_streamProviderOrderKey] as List).cast<String>(),
      );
    }

    final secureMap = data['secure_storage'] as Map<String, dynamic>? ?? {};
    for (final key in _secureKeys) {
      if (secureMap.containsKey(key)) {
        await secure.write(key: key, value: secureMap[key] as String);
      }
    }

    addonChangeNotifier.value++;
    navbarChangeNotifier.value++;
  }
}
