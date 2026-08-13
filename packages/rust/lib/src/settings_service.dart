import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'built_in_player_engine.dart';
import 'catalog/stremio_addon_features.dart';
import 'kv.dart';
import 'platform_defaults.dart';
import 'platform_profile.dart';
import 'playback/torrent/torrent_search_providers.dart';
import 'secure_settings.dart';

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

  PlatformDefaults get _defaults =>
      PlatformDefaults.forProfile(_platformProfile);

  static const String _platformDefaultsSeededKey =
      'platform_defaults_seeded_v1';
  static const String _settingsSchemaKey = 'settings_schema_v2';

  static final ValueNotifier<int> addonChangeNotifier = ValueNotifier<int>(0);

  static const String _streamingModeKey = 'streaming_mode';
  static const String _playSourceTorrentKey = 'play_source_torrent_enabled';
  static const String _playSourceStremioKey = 'play_source_stremio_enabled';
  static const String _playSourceNuvioKey = 'play_source_nuvio_enabled';
  static const String _playSourceWebstreamingKey =
      'play_source_webstreaming_enabled';
  /// Device-local: first-time P2P disclaimer (torrent / Stremio / Nuvio).
  static const String _p2pStreamingAcknowledgedKey =
      'p2p_streaming_acknowledged';
  static const String _simpleStreamingResolveKey =
      'simple_streaming_resolve_enabled';
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';
  static const String _productAnalyticsEnabledKey =
      'product_analytics_enabled';
  static const String _sortPreferenceKey = 'sort_preference';
  static const String _enabledTorrentProvidersKey = 'enabled_torrent_providers';
  static const String _useDebridKey = 'use_debrid_for_streams';
  static const String _debridServiceKey = 'debrid_service';
  static const String _stremioAddonsKey = 'stremio_addons';
  static const String _externalPlayerKey = 'external_player';
  static const String _builtInPlayerEngineKey = 'built_in_player_engine';
  /// One-shot: flip seeded/legacy VOD+IPTV Exo → MediaKit (new Android default).
  static const String _builtInEngineMediaKitDefaultKey =
      'built_in_engine_mk_default_v1';
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
  static const String _showTorrentStatsOverlayKey =
      'show_torrent_stats_overlay';
  static const String _preferredAudioLangKey = 'preferred_audio_lang';
  static const String _preferredSubtitleLangKey = 'preferred_subtitle_lang';
  static const String _avoidUnsupportedAudioKey = 'avoid_unsupported_audio';
  static const String _playerAutoServerKey = 'player_auto_server';
  static const String _playerAutoSourceKey = 'player_auto_source';
  static const String _playerAutoAudioKey = 'player_auto_audio';
  static const String _playerAutoSubtitleKey = 'player_auto_subtitle';
  static const String _playerWebViewUseEmbedKey = 'player_webview_use_embed';
  static const String _autoNextEpisodeKey = 'auto_next_episode';
  static const String _legacyAutoNextKey = 'forja_auto_next';
  static const String _autoSkipIntroKey = 'auto_skip_intro';
  static const String _contentWarningsKey = 'content_warnings';
  /// Desktop Space / virtual-desktop switch → enter PiP (default off).
  static const String _autoPipOnDesktopSwitchKey = 'auto_pip_on_desktop_switch';
  /// Keep VOD/IPTV playing when the app leaves the foreground.
  /// Default: on desktop, off phone/Android TV ([PlatformDefaults.playInBackground]).
  static const String _playInBackgroundKey = 'play_in_background';
  /// One-shot: stop honoring cloud-polluted `play_in_background` on phone/TV.
  static const String _playInBackgroundDeviceLocalKey =
      'play_in_background_device_local_v1';
  static const String _iptvEpgEnabledKey = 'iptv_epg_enabled';
  /// IPTV live Exo only: 0 = full portal quality (default). Never auto-cap.
  static const String _iptvLiveMaxHeightKey = 'iptv_live_max_height';
  /// IPTV live auto-recovery: `buffered` | `stall` | `classic`.
  static const String _iptvLiveRecoveryModeKey = 'iptv_live_recovery_mode';
  /// Android TV MediaKit: ask the panel for a refresh matching stream fps
  /// (issue 150). Opt-in — default off so existing installs stay unchanged.
  static const String _iptvMatchDisplayRefreshKey = 'iptv_match_display_refresh';
  static const String _maxPlaybackHeightKey = 'max_playback_height';
  static const String _animeTitleLanguageKey = 'anime_title_language';

  /// Opt-in ceiling for IPTV **live** Exo adaptive variants. Default Auto = no cap.
  static const Map<String, int> iptvLiveMaxHeightOptions = {
    'Auto (full quality)': 0,
    '1080p': 1080,
    '720p': 720,
    '480p': 480,
  };

  static String iptvLiveMaxHeightLabel(int height) {
    for (final entry in iptvLiveMaxHeightOptions.entries) {
      if (entry.value == height) return entry.key;
    }
    return height > 0 ? '${height}p' : 'Auto (full quality)';
  }

  /// Default = buffer-aware reconnect (shipped in 1.3.170).
  static const String iptvLiveRecoveryBuffered = 'buffered';
  static const String iptvLiveRecoveryClassic = 'classic';
  /// Stable + reopen when buffering/freeze stalls with no playhead (test).
  static const String iptvLiveRecoveryStall = 'stall';

  static const String iptvLiveRecoveryStableLabel =
      'Stable — buffer-aware (1.3.170)';
  static const String iptvLiveRecoveryClassicLabel =
      'Classic — stall timers (1.3.114)';

  /// Policy dropdown only — stall reopen is a separate Stable toggle.
  static const Map<String, String> iptvLiveRecoveryModeOptions = {
    iptvLiveRecoveryStableLabel: iptvLiveRecoveryBuffered,
    iptvLiveRecoveryClassicLabel: iptvLiveRecoveryClassic,
  };

  /// Policy label for Settings dropdown (`stall` maps to Stable).
  static String iptvLiveRecoveryModeLabel(String stored) {
    if (normalizeIptvLiveRecoveryMode(stored) == iptvLiveRecoveryClassic) {
      return iptvLiveRecoveryClassicLabel;
    }
    return iptvLiveRecoveryStableLabel;
  }

  static bool iptvLiveRecoveryStallReopen(String stored) =>
      normalizeIptvLiveRecoveryMode(stored) == iptvLiveRecoveryStall;

  static String composeIptvLiveRecoveryMode({
    required bool classic,
    required bool stallReopen,
  }) {
    if (classic) return iptvLiveRecoveryClassic;
    if (stallReopen) return iptvLiveRecoveryStall;
    return iptvLiveRecoveryBuffered;
  }

  static String normalizeIptvLiveRecoveryMode(String? raw) {
    final v = (raw ?? iptvLiveRecoveryBuffered).trim().toLowerCase();
    if (v == iptvLiveRecoveryClassic) return iptvLiveRecoveryClassic;
    if (v == iptvLiveRecoveryStall) return iptvLiveRecoveryStall;
    return iptvLiveRecoveryBuffered;
  }

  /// Anime catalog display language (AniList). Default romaji.
  static const List<String> animeTitleLanguageOptions = [
    'Romaji',
    'English',
    'Native',
  ];

  /// Live value for [AnimeCard.displayTitle] (romaji / english / native).
  static final ValueNotifier<String> animeTitleLanguageNotifier =
      ValueNotifier<String>('romaji');

  /// Headless WebView sniff: iframe-wrap embed URLs vs load them directly.
  /// Always on — Source panel toggle removed; providers may still force direct.
  static final ValueNotifier<bool> playerWebViewUseEmbedNotifier =
      ValueNotifier<bool>(true);

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

  static final ValueNotifier<bool> iptvEpgEnabledNotifier = ValueNotifier<bool>(
    true,
  );

  /// Prefetch / live-sync for player episode panel + Settings.
  static final ValueNotifier<bool> autoNextEpisodeNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> autoSkipIntroNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<bool> contentWarningsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> autoPipOnDesktopSwitchNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> playInBackgroundNotifier =
      ValueNotifier<bool>(false);

  Future<String> getPreferredAudioLanguage() async =>
      await kvGetString(_preferredAudioLangKey) ?? 'None';

  Future<void> setPreferredAudioLanguage(String v) async =>
      kvSetString(_preferredAudioLangKey, v);

  /// Display name from [kTrackLanguageDisplayNames]. Default English.
  Future<String> getPreferredSubtitleLanguage() async =>
      await kvGetString(_preferredSubtitleLangKey) ?? 'English';

  Future<void> setPreferredSubtitleLanguage(String v) async =>
      kvSetString(_preferredSubtitleLangKey, v);

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

  /// When on, natural end of an episode starts the next one automatically.
  Future<bool> getAutoNextEpisode() async {
    final bool v;
    if (await kvHasKey(_autoNextEpisodeKey)) {
      v = await kvGetBool(_autoNextEpisodeKey, fallback: true);
    } else {
      // Legacy SharedPreferences migration key (facade.migrateSharedPrefs).
      v = await kvGetBool(_legacyAutoNextKey, fallback: true);
    }
    if (autoNextEpisodeNotifier.value != v) {
      autoNextEpisodeNotifier.value = v;
    }
    return v;
  }

  Future<void> setAutoNextEpisode(bool v) async {
    await kvSetBool(_autoNextEpisodeKey, v);
    autoNextEpisodeNotifier.value = v;
  }

  /// When on, seek past IntroDB intro/recap segments without tapping Skip.
  Future<bool> getAutoSkipIntro() async {
    final v = await kvGetBool(_autoSkipIntroKey, fallback: false);
    if (autoSkipIntroNotifier.value != v) {
      autoSkipIntroNotifier.value = v;
    }
    return v;
  }

  Future<void> setAutoSkipIntro(bool v) async {
    await kvSetBool(_autoSkipIntroKey, v);
    autoSkipIntroNotifier.value = v;
  }

  /// When on, show IMDb parents-guide overlay at playback start.
  Future<bool> getContentWarnings() async {
    final v = await kvGetBool(_contentWarningsKey, fallback: true);
    if (contentWarningsNotifier.value != v) {
      contentWarningsNotifier.value = v;
    }
    return v;
  }

  Future<void> setContentWarnings(bool v) async {
    await kvSetBool(_contentWarningsKey, v);
    contentWarningsNotifier.value = v;
  }

  /// When on (desktop), Space / virtual-desktop switch auto-enters PiP.
  Future<bool> getAutoPipOnDesktopSwitch() async {
    final v = await kvGetBool(_autoPipOnDesktopSwitchKey, fallback: false);
    if (autoPipOnDesktopSwitchNotifier.value != v) {
      autoPipOnDesktopSwitchNotifier.value = v;
    }
    return v;
  }

  Future<void> setAutoPipOnDesktopSwitch(bool v) async {
    await kvSetBool(_autoPipOnDesktopSwitchKey, v);
    autoPipOnDesktopSwitchNotifier.value = v;
  }

  /// When on, VOD/IPTV keep playing after the app leaves the foreground.
  /// Unset → [PlatformDefaults.playInBackground] (desktop on, phone/TV off).
  /// Device-local — not cloud-synced (desktop default on must not flip ATV).
  Future<bool> getPlayInBackground() async {
    final v = await kvGetBool(
      _playInBackgroundKey,
      fallback: _defaults.playInBackground,
    );
    if (playInBackgroundNotifier.value != v) {
      playInBackgroundNotifier.value = v;
    }
    return v;
  }

  Future<void> setPlayInBackground(bool v) async {
    await kvSetBool(_playInBackgroundKey, v);
    playInBackgroundNotifier.value = v;
  }

  /// Lifecycle gate: Android TV always pauses on background (process stays warm).
  /// Desktop/phone honor [playInBackgroundNotifier].
  static bool get keepsPlayingInBackground {
    if (platformProfile == PlatformProfile.androidTv) return false;
    return playInBackgroundNotifier.value;
  }

  Future<bool> getPlayerWebViewUseEmbed() async {
    // Embed mode is always on (Source panel toggle removed).
    const v = true;
    if (playerWebViewUseEmbedNotifier.value != v) {
      playerWebViewUseEmbedNotifier.value = v;
    }
    return v;
  }

  Future<void> setPlayerWebViewUseEmbed(bool v) async {
    await kvSetBool(_playerWebViewUseEmbedKey, v);
    // Effective mode stays on; persist is kept for forward-compat only.
    playerWebViewUseEmbedNotifier.value = true;
  }

  Future<bool> isIptvEpgEnabled() async =>
      kvGetBool(_iptvEpgEnabledKey, fallback: _defaults.iptvEpgEnabled);

  Future<void> setIptvEpgEnabled(bool enabled) async {
    await kvSetBool(_iptvEpgEnabledKey, enabled);
    iptvEpgEnabledNotifier.value = enabled;
  }

  /// IPTV live Exo max video height. `0` = no cap (full quality). Default `0`.
  Future<int> getIptvLiveMaxHeight() async =>
      await kvGetInt(_iptvLiveMaxHeightKey, fallback: 0);

  Future<void> setIptvLiveMaxHeight(int height) async =>
      kvSetInt(_iptvLiveMaxHeightKey, height < 0 ? 0 : height);

  /// IPTV live auto-recovery. Default [iptvLiveRecoveryBuffered] (1.3.170).
  Future<String> getIptvLiveRecoveryMode() async {
    return normalizeIptvLiveRecoveryMode(
      await kvGetString(_iptvLiveRecoveryModeKey),
    );
  }

  Future<void> setIptvLiveRecoveryMode(String mode) async {
    await kvSetString(
      _iptvLiveRecoveryModeKey,
      normalizeIptvLiveRecoveryMode(mode),
    );
  }

  /// Android TV MediaKit IPTV: match panel refresh to stream fps. Default off.
  Future<bool> getIptvMatchDisplayRefresh() async =>
      kvGetBool(_iptvMatchDisplayRefreshKey, fallback: false);

  Future<void> setIptvMatchDisplayRefresh(bool enabled) async =>
      kvSetBool(_iptvMatchDisplayRefreshKey, enabled);

  Future<int> getMaxPlaybackHeight() async =>
      await kvGetInt(_maxPlaybackHeightKey, fallback: 0);

  Future<void> setMaxPlaybackHeight(int height) async =>
      kvSetInt(_maxPlaybackHeightKey, height);

  /// AniList title language for anime hub / details / player chrome.
  /// Stored as `romaji` | `english` | `native`. Default romaji.
  Future<String> getAnimeTitleLanguage() async {
    final raw = (await kvGetString(_animeTitleLanguageKey) ?? 'romaji')
        .trim()
        .toLowerCase();
    final v = switch (raw) {
      'english' || 'native' || 'romaji' => raw,
      _ => 'romaji',
    };
    if (animeTitleLanguageNotifier.value != v) {
      animeTitleLanguageNotifier.value = v;
    }
    return v;
  }

  Future<void> setAnimeTitleLanguage(String language) async {
    final v = switch (language.trim().toLowerCase()) {
      'english' || 'native' || 'romaji' => language.trim().toLowerCase(),
      _ => 'romaji',
    };
    await kvSetString(_animeTitleLanguageKey, v);
    animeTitleLanguageNotifier.value = v;
  }

  static String animeTitleLanguageLabel(String stored) {
    return switch (stored.trim().toLowerCase()) {
      'english' => 'English',
      'native' => 'Native',
      _ => 'Romaji',
    };
  }

  static String animeTitleLanguageStored(String label) {
    return switch (label.trim().toLowerCase()) {
      'english' => 'english',
      'native' => 'native',
      _ => 'romaji',
    };
  }

  Future<double> getSubSize({bool isDesktop = false}) async =>
      kvGetDouble(_subSizeKey, fallback: isDesktop ? 44.0 : _defaults.subSize);

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
  Future<bool> getShowTorrentStatsOverlay() async => kvGetBool(
    _showTorrentStatsOverlayKey,
    fallback: _defaults.showTorrentStatsOverlay,
  );

  Future<void> setShowTorrentStatsOverlay(bool v) async =>
      kvSetBool(_showTorrentStatsOverlayKey, v);

  Future<List<Map<String, dynamic>>> getStremioAddons() async =>
      kvGetMapList(_stremioAddonsKey);

  /// Canonical addon host key — strips `/manifest.json` so lean sync URLs and
  /// installed baseUrls collapse to one row.
  static String normalizeStremioAddonBaseUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    u = u.replaceFirst(RegExp(r'^stremio://', caseSensitive: false), 'https://');
    u = u.replaceFirst(RegExp(r'/manifest\.json/?$', caseSensitive: false), '');
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> saveStremioAddon(
    Map<String, dynamic> addon, {
    bool notify = true,
  }) async {
    final normalized = Map<String, dynamic>.from(addon);
    final rawBase = normalized['baseUrl']?.toString() ?? '';
    final base = normalizeStremioAddonBaseUrl(rawBase);
    if (base.isEmpty) return;
    normalized['baseUrl'] = base;
    final manifest = normalized['manifest'];
    normalized['features'] = StremioAddonFeatures.normalize(
      normalized['features'],
      manifest: manifest is Map ? Map<String, dynamic>.from(manifest) : null,
    );

    final current = await getStremioAddons();
    current.removeWhere(
      (a) =>
          normalizeStremioAddonBaseUrl(a['baseUrl']?.toString() ?? '') == base,
    );
    current.add(normalized);
    await kvSetMapList(_stremioAddonsKey, current);
    if (notify) addonChangeNotifier.value++;
  }

  Future<void> removeStremioAddon(String baseUrl, {bool notify = true}) async {
    final base = normalizeStremioAddonBaseUrl(baseUrl);
    final current = await getStremioAddons();
    current.removeWhere(
      (a) =>
          normalizeStremioAddonBaseUrl(a['baseUrl']?.toString() ?? '') == base,
    );
    await kvSetMapList(_stremioAddonsKey, current);
    if (notify) addonChangeNotifier.value++;
  }

  Future<bool> isStreamingModeEnabled() async =>
      kvGetBool(_streamingModeKey, fallback: false);

  Future<void> setStreamingMode(bool enabled) async =>
      kvSetBool(_streamingModeKey, enabled);

  /// Bumped when Direct torrent / Stremio / Nuvio / Webstreaming toggles change.
  static final ValueNotifier<int> playSourceChangeNotifier =
      ValueNotifier<int>(0);

  /// Device-cache value for cloud sync / backup (not platform-gated).
  Future<bool> isPlaySourceTorrentStored() async =>
      kvGetBool(_playSourceTorrentKey, fallback: _defaults.playSourceTorrent);

  /// Effective for UI / playback — always off on Android TV.
  ///
  /// Paired ATV clients honor stored toggles via host
  /// `PlaySourceEffective` (desktop relay), not this getter.
  Future<bool> isPlaySourceTorrentEnabled() async {
    if (platformProfile == PlatformProfile.androidTv) return false;
    return isPlaySourceTorrentStored();
  }

  Future<void> setPlaySourceTorrentEnabled(bool enabled) async {
    await kvSetBool(_playSourceTorrentKey, enabled);
    playSourceChangeNotifier.value++;
  }

  /// Device-cache value for cloud sync / backup (not platform-gated).
  Future<bool> isPlaySourceStremioStored() async =>
      kvGetBool(_playSourceStremioKey, fallback: _defaults.playSourceStremio);

  /// Effective for UI / playback — always off on Android TV.
  /// Paired ATV: see `PlaySourceEffective` on the host.
  Future<bool> isPlaySourceStremioEnabled() async {
    if (platformProfile == PlatformProfile.androidTv) return false;
    return isPlaySourceStremioStored();
  }

  Future<void> setPlaySourceStremioEnabled(bool enabled) async {
    await kvSetBool(_playSourceStremioKey, enabled);
    playSourceChangeNotifier.value++;
  }

  /// Device-cache value for cloud sync / backup (not platform-gated).
  /// Legacy installs (no key) follow stored Direct torrent.
  Future<bool> isPlaySourceNuvioStored() async {
    if (await kvHasKey(_playSourceNuvioKey)) {
      return kvGetBool(
        _playSourceNuvioKey,
        fallback: _defaults.playSourceNuvio,
      );
    }
    return isPlaySourceTorrentStored();
  }

  /// Effective for UI / playback — always off on Android TV.
  /// Paired ATV: see `PlaySourceEffective` on the host.
  Future<bool> isPlaySourceNuvioEnabled() async {
    if (platformProfile == PlatformProfile.androidTv) return false;
    return isPlaySourceNuvioStored();
  }

  Future<void> setPlaySourceNuvioEnabled(bool enabled) async {
    await kvSetBool(_playSourceNuvioKey, enabled);
    playSourceChangeNotifier.value++;
  }

  Future<bool> isPlaySourceWebstreamingEnabled() async => kvGetBool(
    _playSourceWebstreamingKey,
    fallback: _defaults.playSourceWebstreaming,
  );

  Future<void> setPlaySourceWebstreamingEnabled(bool enabled) async {
    await kvSetBool(_playSourceWebstreamingKey, enabled);
    playSourceChangeNotifier.value++;
  }

  /// Once per device — not cloud-synced. Gates the P2P disclaimer dialog.
  Future<bool> isP2pStreamingAcknowledged() async =>
      kvGetBool(_p2pStreamingAcknowledgedKey, fallback: false);

  Future<void> setP2pStreamingAcknowledged(bool acknowledged) async =>
      kvSetBool(_p2pStreamingAcknowledgedKey, acknowledged);

  /// Experimental: provider → filter → probe → open once (RFC-038).
  /// On by default; Off = production race / player failover path.
  Future<bool> isSimpleStreamingResolveEnabled() async =>
      kvGetBool(_simpleStreamingResolveKey, fallback: true);

  Future<void> setSimpleStreamingResolveEnabled(bool enabled) async =>
      kvSetBool(_simpleStreamingResolveKey, enabled);

  /// Opt-in crash reporting to Sentry (RFC-043). Default off.
  Future<bool> isCrashReportingEnabled() async =>
      kvGetBool(_crashReportingEnabledKey, fallback: false);

  Future<void> setCrashReportingEnabled(bool enabled) async =>
      kvSetBool(_crashReportingEnabledKey, enabled);

  // --- In-app update auto-check (RFC-015 R15-A08 / R15-A09) ---
  static const String _updateLastCheckAtKey = 'update_last_check_at';
  static const String _updateDismissedVersionKey = 'update_dismissed_version';
  static const String _updateAutoCheckEnabledKey = 'update_auto_check_enabled';

  /// ISO8601 of the last auto/manual network update check, or null.
  Future<DateTime?> getUpdateLastCheckAt() async {
    final raw = await kvGetString(_updateLastCheckAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setUpdateLastCheckAt(DateTime at) async =>
      kvSetString(_updateLastCheckAtKey, at.toUtc().toIso8601String());

  /// Version the user skipped ("Later" / "Skip for now"). Null = none.
  Future<String?> getUpdateDismissedVersion() async {
    final raw = await kvGetString(_updateDismissedVersionKey);
    if (raw == null || raw.isEmpty) return null;
    return raw.trim();
  }

  Future<void> setUpdateDismissedVersion(String? version) async {
    final v = version?.trim() ?? '';
    // Empty string = cleared (getUpdateDismissedVersion treats empty as null).
    await kvSetString(_updateDismissedVersionKey, v);
  }

  /// When false, in-session auto-check is off (manual Settings check still works).
  Future<bool> isUpdateAutoCheckEnabled() async =>
      kvGetBool(_updateAutoCheckEnabledKey, fallback: true);

  Future<void> setUpdateAutoCheckEnabled(bool enabled) async =>
      kvSetBool(_updateAutoCheckEnabledKey, enabled);

  /// Opt-in product analytics to PostHog (RFC-043). Default off.
  Future<bool> isProductAnalyticsEnabled() async =>
      kvGetBool(_productAnalyticsEnabledKey, fallback: false);

  Future<void> setProductAnalyticsEnabled(bool enabled) async =>
      kvSetBool(_productAnalyticsEnabledKey, enabled);

  static const String _streamProviderOrderKey = 'stream_provider_order';
  static const List<String> defaultStreamProviderOrder = <String>[
    'videasy',
    'vidlink',
    'vidsrc',
    'vidsrcwin',
    'vixsrc',
    'vidnest',
    'vidzee',
    'vidrock',
    'vidfast',
    '2embed',
    'autoembed',
    'vidlove',
    'vidsrcsbs',
    '111movies',
    'moviesapi',
    'vidapi',
    'service111477',
    'webstreamr',
  ];

  Future<List<String>> getStreamProviderOrder() async {
    final saved = await kvGetStringList(
      _streamProviderOrderKey,
      fallback: const [],
    );
    if (saved.isEmpty) {
      return List<String>.from(defaultStreamProviderOrder);
    }
    // Drop provider IDs retired from the built-in registry; otherwise an old
    // persisted order can keep removed providers visible after an upgrade.
    final available = defaultStreamProviderOrder.toSet();
    final out = <String>[
      for (final id in saved)
        if (available.contains(id)) id,
    ];
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
    'megaplay',
    'anikoto',
    'vidnest:hianime',
    'vidnest:animepahe',
    'allanime:Default',
    'allanime:Yt-mp4',
    'allanime:S-mp4',
    'allanime:Luf-Mp4',
    'vidlink',
    'miruro:bee',
    'miruro:zoro',
    'miruro:kiwi',
    'miruro:ally',
    'miruro:hop',
    'miruro:bonk',
    'miruro:moo',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'watchhentai',
    'hentaini',
  ];

  /// Pre-1.2.x default (Miruro CF first). Exact match → migrate to Megaplay-first.
  static const List<String> _legacyAnimeProviderOrder = <String>[
    'miruro:bee',
    'allanime:Default',
    'allanime:Yt-mp4',
    'allanime:S-mp4',
    'allanime:Luf-Mp4',
    'vidnest:hianime',
    'vidnest:animepahe',
    'megaplay',
    'vidwish',
    'miruro:zoro',
    'miruro:kiwi',
    'miruro:ally',
    'miruro:hop',
    'miruro:bonk',
    'miruro:moo',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'watchhentai',
    'hentaini',
  ];

  Future<List<String>> getAnimeProviderOrder() async {
    final saved = await kvGetStringList(
      _animeProviderOrderKey,
      fallback: const [],
    );
    if (saved.isEmpty) {
      return List<String>.from(defaultAnimeProviderOrder);
    }
    // Uncustomized installs still have the Miruro-first list — migrate once so
    // Auto doesn't sit on CF WebView before Megaplay can start.
    if (_listEquals(saved, _legacyAnimeProviderOrder)) {
      await setAnimeProviderOrder(defaultAnimeProviderOrder);
      return List<String>.from(defaultAnimeProviderOrder);
    }
    // Vidwish aliased megaplay.buzz — drop from saved Tries lists.
    final cleaned = [
      for (final k in saved)
        if (k != 'vidwish') k,
    ];
    if (cleaned.length != saved.length) {
      final merged = mergeProviderOrder(cleaned, defaultAnimeProviderOrder);
      await setAnimeProviderOrder(merged);
      return merged;
    }
    return mergeProviderOrder(saved, defaultAnimeProviderOrder);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> setAnimeProviderOrder(List<String> order) async =>
      kvSetStringList(_animeProviderOrderKey, order);

  static const String _asianDramaProviderOrderKey =
      'asian_drama_provider_order';

  /// Asian Drama is intentionally single-host. KissKH aliases share the
  /// client's rate limit, so probing/failover across them can cause a ban.
  static const List<String> defaultAsianDramaProviderOrder = <String>[
    'kisskh.nl',
  ];

  Future<List<String>> getAsianDramaProviderOrder() async {
    return List<String>.from(defaultAsianDramaProviderOrder);
  }

  Future<void> setAsianDramaProviderOrder(List<String> order) async =>
      kvSetStringList(_asianDramaProviderOrderKey, order);

  Future<String> getSortPreference() async =>
      await kvGetString(_sortPreferenceKey) ?? 'Seeders (High to Low)';

  Future<void> setSortPreference(String preference) async =>
      kvSetString(_sortPreferenceKey, preference);

  /// Enabled builtin torrent search provider ids. Default: all known providers.
  Future<List<String>> getEnabledTorrentProviders() async {
    final raw = await kvGetString(_enabledTorrentProvidersKey);
    if (raw == null || raw.trim().isEmpty) {
      return List<String>.from(TorrentSearchProviders.all);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final ids = decoded
            .map((e) => e.toString())
            .where((id) => TorrentSearchProviders.all.contains(id))
            .toList();
        if (ids.isNotEmpty) return ids;
      }
    } catch (_) {}
    return List<String>.from(TorrentSearchProviders.all);
  }

  Future<void> setEnabledTorrentProviders(List<String> ids) async {
    final filtered = ids
        .where((id) => TorrentSearchProviders.all.contains(id))
        .toList();
    await kvSetString(_enabledTorrentProvidersKey, jsonEncode(filtered));
  }

  Future<void> setTorrentProviderEnabled(String id, bool enabled) async {
    if (!TorrentSearchProviders.all.contains(id)) return;
    final current = await getEnabledTorrentProviders();
    if (enabled) {
      if (!current.contains(id)) current.add(id);
    } else {
      current.remove(id);
    }
    await setEnabledTorrentProviders(current);
  }

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

  /// Built-in engine for [context]. Surfaces are independent — unset uses
  /// [BuiltInPlayerEngine.defaultForContext] (no cross-surface inherit).
  Future<BuiltInPlayerEngine> getBuiltInPlayerEngine({
    BuiltInPlayerContext context = BuiltInPlayerContext.vod,
  }) async {
    final raw = await kvGetString(context.storageKey);
    if (raw != null && raw.isNotEmpty) {
      return BuiltInPlayerEngine.fromStorage(raw);
    }
    return BuiltInPlayerEngine.defaultForContext(context);
  }

  /// Seeded Android installs wrote ExoPlayer as the VOD default. Flip VOD and
  /// IPTV once to MediaKit; Live is already MediaKit-by-default and untouched.
  /// Users who re-pick Exo after this migration keep that choice.
  Future<void> _migrateBuiltInEngineDefaultToMediaKit() async {
    if (await kvHasKey(_builtInEngineMediaKitDefaultKey)) return;
    for (final ctx in const [
      BuiltInPlayerContext.vod,
      BuiltInPlayerContext.iptv,
    ]) {
      final raw = await kvGetString(ctx.storageKey);
      if (raw == BuiltInPlayerEngine.exoPlayer.storageKey) {
        await kvSetString(
          ctx.storageKey,
          BuiltInPlayerEngine.mediaKit.storageKey,
        );
      }
    }
    await kvSetString(_builtInEngineMediaKitDefaultKey, '1');
  }

  Future<void> setBuiltInPlayerEngine(
    BuiltInPlayerEngine engine, {
    BuiltInPlayerContext context = BuiltInPlayerContext.vod,
  }) async =>
      kvSetString(context.storageKey, engine.storageKey);

  Future<String?> getJackettBaseUrl() async => kvGetString(_jackettBaseUrlKey);

  Future<void> setJackettBaseUrl(String url) async {
    final normalized = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await kvSetString(_jackettBaseUrlKey, normalized);
  }

  Future<String?> getJackettApiKey() async {
    await ensureCanonicalSettingsMigrated();
    final v = await SecureSettings.read(SecureSettings.jackettApiKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setJackettApiKey(String apiKey) async {
    await ensureCanonicalSettingsMigrated();
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await SecureSettings.delete(SecureSettings.jackettApiKey);
    } else {
      await SecureSettings.write(SecureSettings.jackettApiKey, trimmed);
    }
  }

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

  Future<String?> getProwlarrApiKey() async {
    await ensureCanonicalSettingsMigrated();
    final v = await SecureSettings.read(SecureSettings.prowlarrApiKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setProwlarrApiKey(String apiKey) async {
    await ensureCanonicalSettingsMigrated();
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await SecureSettings.delete(SecureSettings.prowlarrApiKey);
    } else {
      await SecureSettings.write(SecureSettings.prowlarrApiKey, trimmed);
    }
  }

  Future<bool> isProwlarrConfigured() async {
    final baseUrl = await getProwlarrBaseUrl();
    final apiKey = await getProwlarrApiKey();
    return baseUrl != null &&
        baseUrl.isNotEmpty &&
        apiKey != null &&
        apiKey.isNotEmpty;
  }

  Future<List<int>> getProwlarrTagIds() async {
    final stored = await kvGetStringList(
      _prowlarrTagIdsKey,
      fallback: const [],
    );
    return stored
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id >= 0)
        .toList();
  }

  Future<void> setProwlarrTagIds(List<int> tagIds) async => kvSetStringList(
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
  static const String _navbarShell089Key = 'navbar_shell_089';
  static const String _navbarShell090Key = 'navbar_shell_090';
  static const String _navbarShell091Key = 'navbar_shell_091';
  static final ValueNotifier<int> navbarChangeNotifier = ValueNotifier<int>(0);

  /// Default visible tabs (settings appended in MainScreen).
  static const List<String> defaultTvVisibleNavIds =
      PlatformDefaults.androidTvNavIds;

  static const List<String> defaultVisibleNavIds =
      PlatformDefaults.defaultNavIds;

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
    [
      'home',
      'search',
      'anime',
      'asian_drama',
      'iptv',
      'live_matches',
      'mylist',
    ],
    [
      'home',
      'search',
      'asian_drama',
      'anime',
      'iptv',
      'live_matches',
      'mylist',
    ],
    [
      'search',
      'home',
      'anime',
      'asian_drama',
      'iptv',
      'live_matches',
      'mylist',
    ],
  ];

  static bool _isLegacyAndroidTvNav(List<String> ids) {
    for (final legacy in _legacyAndroidTvNavOrders) {
      if (listEquals(ids, legacy)) return true;
    }
    return false;
  }

  static bool _isLegacyPlatformDefaultNav(List<String> ids) =>
      _isLegacyDefaultNav(ids) || _isLegacyAndroidTvNav(ids);

  /// Interim default from shell 089 before Asian Drama was ordered ahead of Anime.
  static const List<String> _legacyAnimeBeforeAsianDramaNavIds = [
    'search',
    'home',
    'anime',
    'asian_drama',
    'iptv',
    'live_matches',
    'mylist',
  ];

  /// Default before Search was withheld from the shell (shell 090 era).
  static const List<String> _legacySearchInDefaultNavIds = [
    'search',
    'home',
    'asian_drama',
    'anime',
    'iptv',
    'live_matches',
    'mylist',
  ];

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
      return ids[0] == 'home' && ids[1] == 'search' && ids[2] == 'mylist';
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

  /// One-shot migration for schema v2: indexer API keys → secure storage.
  Future<void> ensureCanonicalSettingsMigrated() async {
    if (await kvHasKey(_settingsSchemaKey)) return;
    try {
      final ok =
          await SecureSettings.migrateFromKv(SecureSettings.jackettApiKey) &&
          await SecureSettings.migrateFromKv(_jackettApiKeyKey) &&
          await SecureSettings.migrateFromKv(SecureSettings.prowlarrApiKey) &&
          await SecureSettings.migrateFromKv(_prowlarrApiKeyKey);
      if (!ok) {
        debugPrint(
          '[SettingsService] canonical migration deferred: Keychain unavailable',
        );
        return;
      }
      await kvSetString(_settingsSchemaKey, '2');
    } catch (e) {
      debugPrint('[SettingsService] canonical migration deferred: $e');
    }
  }

  /// Reset phone/TV `play_in_background` after it was wrongly cloud-synced from
  /// desktop (default on). Desktop keeps its stored value.
  Future<void> _migratePlayInBackgroundDeviceLocal() async {
    if (await kvHasKey(_playInBackgroundDeviceLocalKey)) return;
    if (platformProfile != PlatformProfile.desktop) {
      final defaults = PlatformDefaults.forProfile(platformProfile);
      await kvSetBool(_playInBackgroundKey, defaults.playInBackground);
      playInBackgroundNotifier.value = defaults.playInBackground;
    }
    await kvSetString(_playInBackgroundDeviceLocalKey, '1');
  }

  Future<void> ensurePlatformDefaultsSeeded(PlatformProfile profile) async {
    configurePlatformProfile(profile);
    await ensureCanonicalSettingsMigrated();
    await _migrateBuiltInEngineDefaultToMediaKit();
    await _migratePlayInBackgroundDeviceLocal();
    if (await kvHasKey(_platformDefaultsSeededKey)) return;

    final hasExistingConfig =
        await kvHasKey(_navbarConfigKey) ||
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
      await kvSetString(
        _builtInPlayerEngineKey,
        defaults.builtInPlayerEngine.storageKey,
      );
      await kvSetDouble(_subSizeKey, defaults.subSize);
      await kvSetDouble(_subBottomPaddingKey, defaults.subBottomPadding);
      await kvSetBool(_iptvEpgEnabledKey, defaults.iptvEpgEnabled);
      await kvSetBool(_playSourceTorrentKey, defaults.playSourceTorrent);
      await kvSetBool(_playSourceStremioKey, defaults.playSourceStremio);
      await kvSetBool(_playSourceNuvioKey, defaults.playSourceNuvio);
      await kvSetBool(
        _playSourceWebstreamingKey,
        defaults.playSourceWebstreaming,
      );
      await kvSetInt(_torrentRamCacheMbKey, defaults.torrentRamCacheMb);
      await kvSetBool(
        _showTorrentStatsOverlayKey,
        defaults.showTorrentStatsOverlay,
      );
      await kvSetBool(_playInBackgroundKey, defaults.playInBackground);
      await kvSetString(_navbarShell080Key, '1');
      await kvSetString(_navbarShell081Key, '1');
      await kvSetString(_navbarShell084Key, '1');
      await kvSetString(_navbarShell085Key, '1');
      await kvSetString(_navbarShell086Key, '1');
      await kvSetString(_navbarShell087Key, '1');
      await kvSetString(_navbarShell088Key, '1');
      await kvSetString(_navbarShell089Key, '1');
      await kvSetString(_navbarShell090Key, '1');
      await kvSetString(_navbarShell091Key, '1');
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
    if (!await kvHasKey(_navbarShell089Key)) {
      if (await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        if (_isLegacyPlatformDefaultNav(raw)) {
          await kvSetStringList(
            _navbarConfigKey,
            List<String>.from(defaultVisibleNavIds),
          );
        }
      }
      await kvSetString(_navbarShell089Key, '1');
    }
    if (!await kvHasKey(_navbarShell090Key)) {
      if (await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        if (listEquals(raw, _legacyAnimeBeforeAsianDramaNavIds)) {
          await kvSetStringList(
            _navbarConfigKey,
            List<String>.from(defaultVisibleNavIds),
          );
        }
      }
      await kvSetString(_navbarShell090Key, '1');
    }
    if (!await kvHasKey(_navbarShell091Key)) {
      if (await kvHasKey(_navbarConfigKey)) {
        final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
        if (listEquals(raw, _legacySearchInDefaultNavIds)) {
          await kvSetStringList(
            _navbarConfigKey,
            List<String>.from(defaultVisibleNavIds),
          );
        }
      }
      await kvSetString(_navbarShell091Key, '1');
    }
    if (!await kvHasKey(_navbarConfigKey)) {
      await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
      return List<String>.from(_defaults.visibleNavIds);
    }
    final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
    final filtered = raw.where((id) => allNavIds.contains(id)).toList();
    final known = (await kvGetStringList(
      _navbarKnownIdsKey,
      fallback: const [],
    )).toSet();
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

  Future<void> setNavbarConfig(
    List<String> visibleIds, {
    bool notify = true,
  }) async {
    await kvSetStringList(_navbarConfigKey, visibleIds);
    await kvSetStringList(_navbarKnownIdsKey, List.from(allNavIds));
    if (notify) navbarChangeNotifier.value++;
  }

  static const List<String> _secureKeys = [
    SecureSettings.rdAccessToken,
    SecureSettings.rdRefreshToken,
    SecureSettings.rdTokenExpiry,
    SecureSettings.rdClientId,
    SecureSettings.rdClientSecret,
    SecureSettings.torboxApiKey,
    SecureSettings.alldebridApiKey,
    SecureSettings.premiumizeApiKey,
    SecureSettings.debridlinkApiKey,
    SecureSettings.jackettApiKey,
    SecureSettings.prowlarrApiKey,
    SecureSettings.webstreamrMfpPassword,
    SecureSettings.webstreamrTmdbToken,
    SecureSettings.iptvPortalPasswords,
    'trakt_access_token',
    'trakt_refresh_token',
    'trakt_expires_at',
    'simkl_access_token',
    'mdblist_api_key',
  ];

  Future<Map<String, dynamic>> exportAllSettings() async {
    await ensureCanonicalSettingsMigrated();
    final prefsMap = <String, dynamic>{};

    prefsMap[_streamingModeKey] = await kvGetBool(
      _streamingModeKey,
      fallback: false,
    );
    prefsMap[_useDebridKey] = await kvGetBool(_useDebridKey, fallback: false);
    prefsMap[_playSourceTorrentKey] = await isPlaySourceTorrentStored();
    prefsMap[_playSourceStremioKey] = await isPlaySourceStremioStored();
    prefsMap[_playSourceNuvioKey] = await isPlaySourceNuvioStored();
    prefsMap[_playSourceWebstreamingKey] =
        await isPlaySourceWebstreamingEnabled();
    prefsMap[_p2pStreamingAcknowledgedKey] =
        await isP2pStreamingAcknowledged();
    for (final key in [
      _sortPreferenceKey,
      _enabledTorrentProvidersKey,
      _debridServiceKey,
      _externalPlayerKey,
      _jackettBaseUrlKey,
      _prowlarrBaseUrlKey,
      _torrentCacheTypeKey,
    ]) {
      final v = await kvGetString(key);
      if (v != null && v.isNotEmpty) prefsMap[key] = v;
    }
    prefsMap[_torrentRamCacheMbKey] = await kvGetInt(
      _torrentRamCacheMbKey,
      fallback: 200,
    );
    prefsMap[_torrentConnectionsLimitKey] = await kvGetInt(
      _torrentConnectionsLimitKey,
      fallback: 200,
    );
    prefsMap[_navbarConfigKey] = await kvGetStringList(
      _navbarConfigKey,
      fallback: const [],
    );
    final defaultTab = await kvGetString(_defaultNavTabKey);
    if (defaultTab != null) {
      prefsMap[_defaultNavTabKey] = defaultTab;
    }
    prefsMap[_prowlarrTagIdsKey] = await kvGetStringList(
      _prowlarrTagIdsKey,
      fallback: const [],
    );
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
    final asianDramaOrder = await kvGetStringList(
      _asianDramaProviderOrderKey,
      fallback: const [],
    );
    if (asianDramaOrder.isNotEmpty) {
      prefsMap[_asianDramaProviderOrderKey] = asianDramaOrder;
    }
    final nuvioRaw = await kvGetString('nuvio_addons_v1');
    if (nuvioRaw != null && nuvioRaw.isNotEmpty) {
      prefsMap['nuvio_addons_v1'] = nuvioRaw;
    }
    for (final key in [
      'webstreamr_country_codes',
      'webstreamr_disabled_extractors',
      'webstreamr_excluded_resolutions',
    ]) {
      final list = await kvGetStringList(key, fallback: const []);
      if (list.isNotEmpty) prefsMap[key] = list;
    }
    for (final key in ['webstreamr_mfp_url', 'webstreamr_flare_url']) {
      final v = await kvGetString(key);
      if (v != null && v.isNotEmpty) prefsMap[key] = v;
    }

    // Prefer SecureSettings.read so Keychain misses still pick up legacy prefs
    // (e.g. macOS -34018 before keychain-access-groups is present).
    final secureMap = <String, String>{};
    for (final key in _secureKeys) {
      try {
        final v = await SecureSettings.read(key);
        if (v != null && v.isNotEmpty) secureMap[key] = v;
      } catch (e) {
        debugPrint('[SettingsService] export skipped secure key ($key): $e');
      }
    }

    return {
      'shared_preferences': prefsMap,
      'secure_storage': secureMap,
      'export_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllSettings(Map<String, dynamic> data) async {
    await ensureCanonicalSettingsMigrated();
    final prefsMap = data['shared_preferences'] as Map<String, dynamic>? ?? {};

    for (final key in [
      _streamingModeKey,
      _useDebridKey,
      _playSourceTorrentKey,
      _playSourceStremioKey,
      _playSourceNuvioKey,
      _playSourceWebstreamingKey,
      _p2pStreamingAcknowledgedKey,
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetBool(key, prefsMap[key] as bool);
      }
    }
    for (final key in [
      _sortPreferenceKey,
      _enabledTorrentProvidersKey,
      _debridServiceKey,
      _externalPlayerKey,
      _jackettBaseUrlKey,
      _prowlarrBaseUrlKey,
      _torrentCacheTypeKey,
      'webstreamr_mfp_url',
      'webstreamr_flare_url',
      'nuvio_addons_v1',
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetString(key, prefsMap[key] as String);
      }
    }
    if (prefsMap.containsKey(_torrentRamCacheMbKey)) {
      await kvSetInt(
        _torrentRamCacheMbKey,
        prefsMap[_torrentRamCacheMbKey] as int,
      );
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
    if (prefsMap.containsKey(_asianDramaProviderOrderKey)) {
      await kvSetStringList(
        _asianDramaProviderOrderKey,
        (prefsMap[_asianDramaProviderOrderKey] as List).cast<String>(),
      );
    }
    for (final key in [
      'webstreamr_country_codes',
      'webstreamr_disabled_extractors',
      'webstreamr_excluded_resolutions',
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetStringList(key, (prefsMap[key] as List).cast<String>());
      }
    }

    final secureMap = data['secure_storage'] as Map<String, dynamic>? ?? {};
    for (final key in _secureKeys) {
      if (secureMap.containsKey(key)) {
        await SecureSettings.write(key, secureMap[key] as String);
      }
    }
    // Legacy exports put Jackett/Prowlarr keys in the non-secure map.
    if (prefsMap.containsKey(_jackettApiKeyKey)) {
      await setJackettApiKey(prefsMap[_jackettApiKeyKey] as String);
    }
    if (prefsMap.containsKey(_prowlarrApiKeyKey)) {
      await setProwlarrApiKey(prefsMap[_prowlarrApiKeyKey] as String);
    }

    addonChangeNotifier.value++;
    navbarChangeNotifier.value++;
    playSourceChangeNotifier.value++;
  }
}
