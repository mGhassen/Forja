import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'built_in_player_engine.dart';
import 'kv.dart';
import 'platform_defaults.dart';
import 'platform_profile.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static PlatformProfile _platformProfile = PlatformProfile.phone;

  static PlatformProfile get platformProfile => _platformProfile;

  static void configurePlatformProfile(PlatformProfile profile) {
    _platformProfile = profile;
  }

  /// Run headless WebView stream extractors on Android TV (issue 031 workaround).
  /// `true` = do not skip (dev testing). `false` = skip WebView sniffers on TV.
  static bool allowAndroidTvHeadlessWebViewExtractors = true;

  PlatformDefaults get _defaults => PlatformDefaults.forProfile(_platformProfile);

  static const String _platformDefaultsSeededKey = 'platform_defaults_seeded_v1';

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
  static const String _builtInPlayerEngineKey = 'built_in_player_engine';
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
  static const String _showTorrentStatsOverlayKey = 'show_torrent_stats_overlay';
  static const String _preferredAudioLangKey = 'preferred_audio_lang';
  static const String _avoidUnsupportedAudioKey = 'avoid_unsupported_audio';
  static const String _playerAutoServerKey = 'player_auto_server';
  static const String _playerAutoSourceKey = 'player_auto_source';
  static const String _playerAutoAudioKey = 'player_auto_audio';
  static const String _playerAutoSubtitleKey = 'player_auto_subtitle';
  static const String _iptvEpgEnabledKey = 'iptv_epg_enabled';
  static const String _maxPlaybackHeightKey = 'max_playback_height';

  /// User cap for stream scoring (0 = auto / no cap).
  static const Map<String, int> maxPlaybackHeightOptions = {
    'Auto': 0,
    '4K (2160p)': 2160,
    '1440p': 1440,
    '1080p': 1080,
    '720p': 720,
    '480p': 480,
  };

  static String maxPlaybackHeightLabel(int height) {
    for (final entry in maxPlaybackHeightOptions.entries) {
      if (entry.value == height) return entry.key;
    }
    return height > 0 ? '${height}p' : 'Auto';
  }

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

  Future<bool> getPlayerAutoServer() async =>
      kvGetBool(_playerAutoServerKey, fallback: true);

  Future<void> setPlayerAutoServer(bool v) async =>
      kvSetBool(_playerAutoServerKey, v);

  Future<bool> getPlayerAutoSource() async =>
      kvGetBool(_playerAutoSourceKey, fallback: true);

  Future<void> setPlayerAutoSource(bool v) async =>
      kvSetBool(_playerAutoSourceKey, v);

  Future<bool> getPlayerAutoAudio() async =>
      kvGetBool(_playerAutoAudioKey, fallback: true);

  Future<void> setPlayerAutoAudio(bool v) async =>
      kvSetBool(_playerAutoAudioKey, v);

  Future<bool> getPlayerAutoSubtitle() async =>
      kvGetBool(_playerAutoSubtitleKey, fallback: false);

  Future<void> setPlayerAutoSubtitle(bool v) async =>
      kvSetBool(_playerAutoSubtitleKey, v);

  Future<bool> isIptvEpgEnabled() async =>
      kvGetBool(_iptvEpgEnabledKey, fallback: _defaults.iptvEpgEnabled);

  Future<void> setIptvEpgEnabled(bool enabled) async {
    await kvSetBool(_iptvEpgEnabledKey, enabled);
    iptvEpgEnabledNotifier.value = enabled;
  }

  Future<int> getMaxPlaybackHeight() async =>
      await kvGetInt(_maxPlaybackHeightKey, fallback: 0);

  Future<void> setMaxPlaybackHeight(int height) async =>
      kvSetInt(_maxPlaybackHeightKey, height);

  Future<double> getSubSize({bool isDesktop = false}) async =>
      kvGetDouble(
        _subSizeKey,
        fallback: isDesktop ? 44.0 : _defaults.subSize,
      );

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
      kvGetDouble(_subBottomPaddingKey, fallback: _defaults.subBottomPadding);

  Future<void> setSubBottomPadding(double v) async =>
      kvSetDouble(_subBottomPaddingKey, v);

  Future<String> getSubFont() async =>
      await kvGetString(_subFontKey) ?? 'Default';

  Future<void> setSubFont(String v) async => kvSetString(_subFontKey, v);

  /// Desktop player: show live torrent stats card over the seek bar.
  /// Default off.
  Future<bool> getShowTorrentStatsOverlay() async =>
      kvGetBool(
        _showTorrentStatsOverlayKey,
        fallback: _defaults.showTorrentStatsOverlay,
      );

  Future<void> setShowTorrentStatsOverlay(bool v) async =>
      kvSetBool(_showTorrentStatsOverlayKey, v);

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
      kvGetBool(_playSourceTorrentKey, fallback: _defaults.playSourceTorrent);

  Future<void> setPlaySourceTorrentEnabled(bool enabled) async =>
      kvSetBool(_playSourceTorrentKey, enabled);

  Future<bool> isPlaySourceStremioEnabled() async =>
      kvGetBool(_playSourceStremioKey, fallback: _defaults.playSourceStremio);

  Future<void> setPlaySourceStremioEnabled(bool enabled) async =>
      kvSetBool(_playSourceStremioKey, enabled);

  Future<bool> isPlaySourceWebstreamingEnabled() async =>
      kvGetBool(
        _playSourceWebstreamingKey,
        fallback: _defaults.playSourceWebstreaming,
      );

  Future<void> setPlaySourceWebstreamingEnabled(bool enabled) async =>
      kvSetBool(_playSourceWebstreamingKey, enabled);

  static const String _streamProviderOrderKey = 'stream_provider_order';
  static const List<String> defaultStreamProviderOrder = <String>[
    'videasy',
    'vidlink',
    'vidsrc',
    'vixsrc',
    'vidnest',
    'vidfast',
    '2embed',
    'superembed',
    'autoembed',
    '111movies',
    'moviesapi',
    'smashystream',
    'primewire',
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

  static const String _animeProviderOrderKey = 'anime_provider_order';

  /// Default anime stream try-order. Kept in sync with
  /// `AnimeStreamProviders.defaultOrder` in the host app.
  static const List<String> defaultAnimeProviderOrder = <String>[
    'miruro:bee',
    'allanime:Default',
    'allanime:S-mp4',
    'megaplay',
    'vidwish',
    'miruro:zoro',
    'animerealms:hianime',
    'miruro:kiwi',
    'animerealms:animepahe',
    'allanime:Yt-mp4',
    'allanime:Luf-Mp4',
    'allanime:Uv-mp4',
    'miruro:ally',
    'animerealms:allmanga',
    'miruro:hop',
    'miruro:bonk',
    'animerealms:gogoanime',
    'miruro:moo',
    'animerealms:zencloud',
    'animerealms:animekai',
    'animerealms:animez',
    'animerealms:kickassanime',
    'animerealms:anizone',
    'animerealms:febbox',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'animerealms:hanime-tv',
    'watchhentai',
    'hentaini',
  ];

  Future<List<String>> getAnimeProviderOrder() async {
    final saved =
        await kvGetStringList(_animeProviderOrderKey, fallback: const []);
    if (saved.isEmpty) {
      return List<String>.from(defaultAnimeProviderOrder);
    }
    return mergeProviderOrder(saved, defaultAnimeProviderOrder);
  }

  Future<void> setAnimeProviderOrder(List<String> order) async =>
      kvSetStringList(_animeProviderOrderKey, order);

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

  Future<BuiltInPlayerEngine> getBuiltInPlayerEngine() async {
    final raw = await kvGetString(_builtInPlayerEngineKey);
    if (raw == null || raw.isEmpty) {
      return BuiltInPlayerEngine.platformDefault();
    }
    return BuiltInPlayerEngine.fromStorage(raw);
  }

  Future<void> setBuiltInPlayerEngine(BuiltInPlayerEngine engine) async =>
      kvSetString(_builtInPlayerEngineKey, engine.storageKey);

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
      kvGetInt(_torrentRamCacheMbKey, fallback: _defaults.torrentRamCacheMb);

  Future<void> setTorrentRamCacheMb(int mb) async =>
      kvSetInt(_torrentRamCacheMbKey, mb);

  Future<int> getTorrentConnectionsLimit() async =>
      kvGetInt(_torrentConnectionsLimitKey, fallback: 200);

  Future<void> setTorrentConnectionsLimit(int limit) async =>
      kvSetInt(_torrentConnectionsLimitKey, limit);

  Future<String> getThemePreset() async =>
      await kvGetString(_themePresetKey) ?? 'forja';

  Future<void> setThemePreset(String preset) async =>
      kvSetString(_themePresetKey, preset);

  static const String _navbarConfigKey = 'navbar_config';
  static const String _defaultNavTabKey = 'navbar_default_tab';
  static const String _navbarKnownIdsKey = 'navbar_known_ids';
  static const String _navbarShell080Key = 'navbar_shell_080';
  static const String _navbarShell081Key = 'navbar_shell_081';
  static const String _navbarShell084Key = 'navbar_shell_084';
  static const String _navbarShell085Key = 'navbar_shell_085';
  static const String _navbarShell086Key = 'navbar_shell_086';
  static const String _navbarShell087Key = 'navbar_shell_087';
  static const String _navbarShell088Key = 'navbar_shell_088';
  static final ValueNotifier<int> navbarChangeNotifier = ValueNotifier<int>(0);

  /// Default visible tabs (settings appended in MainScreen).
  static const List<String> defaultTvVisibleNavIds =
      PlatformDefaults.androidTvNavIds;

  static const List<String> defaultVisibleNavIds = [
    'home',
    'search',
    'asian_drama',
    'anime',
    'iptv',
    'live_matches',
    'mylist',
  ];

  static List<String> _migrateSearchFirstNavToHomeFirst(List<String> ids) {
    if (ids.length < 2 || ids[0] != 'search' || ids[1] != 'home') {
      return ids;
    }
    final migrated = List<String>.from(ids);
    migrated[0] = 'home';
    migrated[1] = 'search';
    return migrated;
  }

  /// Prior Android TV defaults — migrate to [PlatformDefaults.androidTvNavIds].
  static const List<List<String>> _legacyAndroidTvNavOrders = [
    ['home', 'search', 'anime', 'asian_drama', 'iptv', 'live_matches', 'mylist'],
    ['home', 'search', 'asian_drama', 'anime', 'iptv', 'live_matches', 'mylist'],
    ['search', 'home', 'anime', 'asian_drama', 'iptv', 'live_matches', 'mylist'],
  ];

  static bool _isLegacyAndroidTvNav(List<String> ids) {
    for (final legacy in _legacyAndroidTvNavOrders) {
      if (listEquals(ids, legacy)) return true;
    }
    return false;
  }

  static int initialShellTabIndex(
    List<String> visibleIds, {
    String? defaultTabId,
  }) {
    final preferred = defaultTabId ?? 'home';
    final preferredIdx = visibleIds.indexOf(preferred);
    if (preferredIdx >= 0) return preferredIdx;
    final homeIdx = visibleIds.indexOf('home');
    if (homeIdx >= 0) return homeIdx;
    return 0;
  }

  Future<String> getDefaultNavTab() async =>
      await kvGetString(_defaultNavTabKey) ?? 'home';

  Future<void> setDefaultNavTab(String tabId) async {
    await kvSetString(_defaultNavTabKey, tabId);
    navbarChangeNotifier.value++;
  }

  static bool _isLegacyDefaultNav(List<String> ids) {
    if (ids.length == 2) {
      return ids[0] == 'home' && ids[1] == 'search';
    }
    if (ids.length == 3) {
      return ids[0] == 'home' &&
          ids[1] == 'search' &&
          ids[2] == 'mylist';
    }
    return false;
  }

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

  Future<void> ensurePlatformDefaultsSeeded(PlatformProfile profile) async {
    configurePlatformProfile(profile);
    if (await kvHasKey(_platformDefaultsSeededKey)) return;

    final hasExistingConfig = await kvHasKey(_navbarConfigKey) ||
        await kvHasKey(_navbarShell080Key) ||
        await kvHasKey(_navbarShell081Key);

    if (!hasExistingConfig) {
      final defaults = PlatformDefaults.forProfile(profile);
      await kvSetStringList(
        _navbarConfigKey,
        List<String>.from(defaults.visibleNavIds),
      );
      await kvSetStringList(_navbarKnownIdsKey, List<String>.from(allNavIds));
      await kvSetString(_externalPlayerKey, defaults.externalPlayer);
      await kvSetDouble(_subSizeKey, defaults.subSize);
      await kvSetDouble(_subBottomPaddingKey, defaults.subBottomPadding);
      await kvSetBool(_iptvEpgEnabledKey, defaults.iptvEpgEnabled);
      await kvSetBool(_playSourceTorrentKey, defaults.playSourceTorrent);
      await kvSetBool(_playSourceStremioKey, defaults.playSourceStremio);
      await kvSetBool(
        _playSourceWebstreamingKey,
        defaults.playSourceWebstreaming,
      );
      await kvSetInt(_torrentRamCacheMbKey, defaults.torrentRamCacheMb);
      await kvSetBool(
        _showTorrentStatsOverlayKey,
        defaults.showTorrentStatsOverlay,
      );
      await kvSetString(_navbarShell080Key, '1');
      await kvSetString(_navbarShell081Key, '1');
      await kvSetString(_navbarShell084Key, '1');
      await kvSetString(_navbarShell085Key, '1');
      await kvSetString(_navbarShell086Key, '1');
      await kvSetString(_navbarShell087Key, '1');
      await kvSetString(_navbarShell088Key, '1');
    }

    await kvSetString(_platformDefaultsSeededKey, profile.name);
  }

  Future<List<String>> getNavbarConfig() async {
    final skipLegacyMigrations = await kvHasKey(_platformDefaultsSeededKey);

    if (!skipLegacyMigrations && !await kvHasKey(_navbarShell080Key)) {
      await kvSetStringList(_navbarConfigKey, const ['home', 'search']);
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
      await kvSetString(_navbarShell080Key, '1');
    }
    if (!skipLegacyMigrations && !await kvHasKey(_navbarShell081Key)) {
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
    if (!await kvHasKey(_navbarShell084Key)) {
      final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
      if (_isLegacyDefaultNav(raw)) {
        await kvSetStringList(
          _navbarConfigKey,
          List<String>.from(defaultVisibleNavIds),
        );
      }
      await kvSetString(_navbarShell084Key, '1');
    }
    if (!await kvHasKey(_navbarShell085Key)) {
      // Retired: shell 085 once moved TV nav to search-first. Home-first is
      // the default now; shell 086 migrates legacy search-first configs back.
      await kvSetString(_navbarShell085Key, '1');
    }
    if (!await kvHasKey(_navbarShell086Key)) {
      if (platformProfile == PlatformProfile.androidTv &&
          await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        if (raw.length >= 2 && raw[0] == 'search' && raw[1] == 'home') {
          await kvSetStringList(
            _navbarConfigKey,
            _migrateSearchFirstNavToHomeFirst(raw),
          );
        }
      }
      await kvSetString(_navbarShell086Key, '1');
    }
    if (!await kvHasKey(_navbarShell087Key)) {
      // Shell 086 only migrated Android TV; desktop/phone installs that kept
      // legacy search-first nav from shell 085 need the same home-first fix.
      if (await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        final migrated = _migrateSearchFirstNavToHomeFirst(raw);
        if (!listEquals(migrated, raw)) {
          await kvSetStringList(_navbarConfigKey, migrated);
        }
      }
      await kvSetString(_navbarShell087Key, '1');
    }
    if (!await kvHasKey(_navbarShell088Key)) {
      if (platformProfile == PlatformProfile.androidTv &&
          await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        if (_isLegacyAndroidTvNav(raw)) {
          await kvSetStringList(
            _navbarConfigKey,
            List<String>.from(PlatformDefaults.androidTvNavIds),
          );
        }
      }
      await kvSetString(_navbarShell088Key, '1');
    }
    if (!await kvHasKey(_navbarConfigKey)) {
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
      return List<String>.from(_defaults.visibleNavIds);
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
    final defaultTab = await kvGetString(_defaultNavTabKey);
    if (defaultTab != null) {
      prefsMap[_defaultNavTabKey] = defaultTab;
    }
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
    final animeOrder = await kvGetStringList(
      _animeProviderOrderKey,
      fallback: const [],
    );
    if (animeOrder.isNotEmpty) {
      prefsMap[_animeProviderOrderKey] = animeOrder;
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
    if (prefsMap.containsKey(_defaultNavTabKey)) {
      await kvSetString(
        _defaultNavTabKey,
        prefsMap[_defaultNavTabKey] as String,
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
    if (prefsMap.containsKey(_animeProviderOrderKey)) {
      await kvSetStringList(
        _animeProviderOrderKey,
        (prefsMap[_animeProviderOrderKey] as List).cast<String>(),
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
