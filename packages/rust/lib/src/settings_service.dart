import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'built_in_player_engine.dart';
import 'catalog/stremio_addon_features.dart';
import 'kv.dart';
import 'platform_defaults.dart';
import 'platform_profile.dart';
import 'secure_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  bool? _cachedUseDebridForStreams;
  String? _cachedDebridService;

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
  static const String _playSourceEngineKey = 'play_source_engine_enabled';
  /// Green Play races enabled Forja plugins when Webstreaming is off.
  static const String _playSourceEngineAutoStartKey =
      'play_source_engine_auto_start';
  static const String _playSourceWebstreamingKey =
      'play_source_webstreaming_enabled';
  /// Device-local: first-time P2P disclaimer (torrent / Stremio / Nuvio).
  static const String _p2pStreamingAcknowledgedKey =
      'p2p_streaming_acknowledged';
  /// One-shot: ATV used to seed torrent/Stremio/Nuvio off; turn them on.
  static const String _atvCatalogPlaySourcesKey = 'atv_catalog_play_sources_v1';
  static const String _simpleStreamingResolveKey =
      'simple_streaming_resolve_enabled';
  /// Live Matches stream resolve: `sniff` (embed WebView) | `engine` (Forja plugins).
  static const String _liveStreamResolveKey = 'live_stream_resolve';
  static const String liveStreamResolveSniff = 'sniff';
  static const String liveStreamResolveEngine = 'engine';
  static const String liveStreamResolveSniffLabel = 'Sniff (embed player)';
  static const String liveStreamResolveEngineLabel = 'Engine (native player)';
  static const Map<String, String> liveStreamResolveOptions = {
    liveStreamResolveSniffLabel: liveStreamResolveSniff,
    liveStreamResolveEngineLabel: liveStreamResolveEngine,
  };
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';
  static const String _productAnalyticsEnabledKey =
      'product_analytics_enabled';
  static const String _sortPreferenceKey = 'sort_preference';
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
  static const String _flareSolverrUrlKey = 'flare_solverr_url';
  static const String _themePresetKey = 'theme_preset';
  static const String _torrentDiskCacheGbKey = 'torrent_disk_cache_gb';
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
  /// IPTV live auto-recovery: `auto` | `buffered` | `stall` | `classic`.
  static const String _iptvLiveRecoveryModeKey = 'iptv_live_recovery_mode';
  /// One-shot: old defaults (`stall` / unset / `buffered`) → `auto`.
  /// v2 also covers installs that v1 left on `buffered` after marking migrated.
  static const String _iptvLiveRecoveryMigratedToAutoKey =
      'iptv_live_recovery_migrated_auto_v2';
  /// Android TV MediaKit: ask the panel for a refresh matching stream fps
  /// (issue 150). Default on; Settings toggle is admin-only.
  static const String _iptvMatchDisplayRefreshKey = 'iptv_match_display_refresh';
  /// Android TV MediaKit live demuxer cushion (seconds). `0` = Auto by height.
  /// Admin-only; max 30. Pairs with demuxer-max-bytes tiers (issue 150).
  static const String _iptvLiveBufferSecsKey = 'iptv_live_buffer_secs';
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

  /// ATV MediaKit live buffer cushion. `0` = height tier (HD 15 / FHD 20 / UHD 30).
  static const Map<String, int> iptvLiveBufferSecsOptions = {
    'Auto (by resolution)': 0,
    '15 seconds': 15,
    '20 seconds': 20,
    '30 seconds': 30,
  };

  static String iptvLiveBufferSecsLabel(int secs) {
    final n = normalizeIptvLiveBufferSecs(secs);
    for (final entry in iptvLiveBufferSecsOptions.entries) {
      if (entry.value == n) return entry.key;
    }
    return 'Auto (by resolution)';
  }

  /// Allowed values: `0` (Auto), `15`, `20`, `30`. Anything else → Auto.
  static int normalizeIptvLiveBufferSecs(int? raw) {
    if (raw == null || raw <= 0) return 0;
    if (raw == 15 || raw == 20 || raw == 30) return raw;
    return 0;
  }

  /// Demuxer profile for a manual seconds override (matches ATV height tiers).
  ///
  /// Call only when [normalizeIptvLiveBufferSecs] returned 15 / 20 / 30.
  static ({int cacheSecs, int readaheadSecs, int demuxerMaxBytes, String tier})
      iptvLiveBufferProfileForSecs(int secs) {
    switch (normalizeIptvLiveBufferSecs(secs)) {
      case 15:
        return (
          cacheSecs: 15,
          readaheadSecs: 10,
          demuxerMaxBytes: 48 * 1024 * 1024,
          tier: 'manual-15s',
        );
      case 20:
        return (
          cacheSecs: 20,
          readaheadSecs: 15,
          demuxerMaxBytes: 96 * 1024 * 1024,
          tier: 'manual-20s',
        );
      case 30:
        return (
          cacheSecs: 30,
          readaheadSecs: 20,
          demuxerMaxBytes: 150000000,
          tier: 'manual-30s',
        );
      default:
        return (
          cacheSecs: 20,
          readaheadSecs: 15,
          demuxerMaxBytes: 96 * 1024 * 1024,
          tier: 'manual-20s',
        );
    }
  }

  /// Stable without stall reopen — hold while demuxer cushion / paint is alive.
  static const String iptvLiveRecoveryBuffered = 'buffered';
  static const String iptvLiveRecoveryClassic = 'classic';
  /// Stable + reopen when buffering/freeze stalls with no playhead (manual).
  static const String iptvLiveRecoveryStall = 'stall';
  /// Default — player manages stall reopen per live source kind.
  static const String iptvLiveRecoveryAuto = 'auto';

  static const String iptvLiveRecoveryAutoLabel = 'Auto';
  static const String iptvLiveRecoveryStableLabel = 'Stable — buffer-aware';
  static const String iptvLiveRecoveryClassicLabel = 'Classic — stall timers';

  /// Policy dropdown — Auto | Stable | Classic. Stall reopen is Stable-only.
  static const Map<String, String> iptvLiveRecoveryModeOptions = {
    iptvLiveRecoveryAutoLabel: iptvLiveRecoveryAuto,
    iptvLiveRecoveryStableLabel: iptvLiveRecoveryBuffered,
    iptvLiveRecoveryClassicLabel: iptvLiveRecoveryClassic,
  };

  /// Policy label for Settings dropdown (`stall` / `buffered` → Stable).
  static String iptvLiveRecoveryModeLabel(String stored) {
    final n = normalizeIptvLiveRecoveryMode(stored);
    if (n == iptvLiveRecoveryAuto) return iptvLiveRecoveryAutoLabel;
    if (n == iptvLiveRecoveryClassic) return iptvLiveRecoveryClassicLabel;
    return iptvLiveRecoveryStableLabel;
  }

  static bool iptvLiveRecoveryStallReopen(String stored) =>
      normalizeIptvLiveRecoveryMode(stored) == iptvLiveRecoveryStall;

  static bool iptvLiveRecoveryIsAuto(String stored) =>
      normalizeIptvLiveRecoveryMode(stored) == iptvLiveRecoveryAuto;

  static String composeIptvLiveRecoveryMode({
    required bool classic,
    required bool stallReopen,
    bool auto = false,
  }) {
    if (auto) return iptvLiveRecoveryAuto;
    if (classic) return iptvLiveRecoveryClassic;
    if (stallReopen) return iptvLiveRecoveryStall;
    return iptvLiveRecoveryBuffered;
  }

  static String normalizeIptvLiveRecoveryMode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return iptvLiveRecoveryAuto;
    final v = raw.trim().toLowerCase();
    if (v == iptvLiveRecoveryAuto) return iptvLiveRecoveryAuto;
    if (v == iptvLiveRecoveryClassic) return iptvLiveRecoveryClassic;
    if (v == iptvLiveRecoveryStall) return iptvLiveRecoveryStall;
    if (v == iptvLiveRecoveryBuffered) return iptvLiveRecoveryBuffered;
    return iptvLiveRecoveryAuto;
  }

  /// Resolve Settings value for the current live open.
  ///
  /// Auto **manages stall** per source:
  /// - Xtream (continuity proxy): Stable + stall reopen — VO freeze can leave
  ///   a full demuxer while the picture is dead on ATV MediaKit.
  /// - Stalker / Stremio / liveEngine: Stable without stall — playhead often
  ///   sits at 0 and stall reopen false-triggers, wiping a healthy cushion.
  static String resolveIptvLiveRecoveryMode(
    String stored, {
    String? liveSourceKind,
  }) {
    final n = normalizeIptvLiveRecoveryMode(stored);
    if (n != iptvLiveRecoveryAuto) return n;
    switch (liveSourceKind) {
      case 'iptvXtream':
        return iptvLiveRecoveryStall;
      case 'iptvStalker':
      case 'stremio':
      case 'liveEngine':
        return iptvLiveRecoveryBuffered;
      default:
        // Untagged open — prefer cushion hold (Stalker mis-tag was issue 208).
        return iptvLiveRecoveryBuffered;
    }
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

  /// IPTV live auto-recovery. Default [iptvLiveRecoveryAuto].
  ///
  /// One-shot upgrade to Auto: unset, old default `stall`, and `buffered`
  /// (Stable without stall — often from turning stall off under the old UI).
  /// Classic is left alone. After migrate, an explicit Stable / stall choice
  /// is kept.
  Future<String> getIptvLiveRecoveryMode() async {
    await _migrateIptvLiveRecoveryToAutoIfNeeded();
    return normalizeIptvLiveRecoveryMode(
      await kvGetString(_iptvLiveRecoveryModeKey),
    );
  }

  Future<void> _migrateIptvLiveRecoveryToAutoIfNeeded() async {
    if (await kvGetBool(_iptvLiveRecoveryMigratedToAutoKey, fallback: false)) {
      return;
    }
    final raw = (await kvGetString(_iptvLiveRecoveryModeKey) ?? '')
        .trim()
        .toLowerCase();
    // Promote unset / stall / buffered. Leave Classic and Auto alone.
    if (raw != iptvLiveRecoveryClassic && raw != iptvLiveRecoveryAuto) {
      await kvSetString(_iptvLiveRecoveryModeKey, iptvLiveRecoveryAuto);
    }
    await kvSetBool(_iptvLiveRecoveryMigratedToAutoKey, true);
  }

  Future<void> setIptvLiveRecoveryMode(String mode) async {
    await kvSetString(
      _iptvLiveRecoveryModeKey,
      normalizeIptvLiveRecoveryMode(mode),
    );
  }

  /// Android TV MediaKit IPTV: match panel refresh to stream fps. Default on.
  Future<bool> getIptvMatchDisplayRefresh() async =>
      kvGetBool(_iptvMatchDisplayRefreshKey, fallback: true);

  Future<void> setIptvMatchDisplayRefresh(bool enabled) async =>
      kvSetBool(_iptvMatchDisplayRefreshKey, enabled);

  /// Android TV MediaKit live demuxer cushion seconds. `0` = Auto by resolution.
  Future<int> getIptvLiveBufferSecs() async => normalizeIptvLiveBufferSecs(
        await kvGetInt(_iptvLiveBufferSecsKey, fallback: 0),
      );

  Future<void> setIptvLiveBufferSecs(int secs) async =>
      kvSetInt(_iptvLiveBufferSecsKey, normalizeIptvLiveBufferSecs(secs));

  Future<int> getMaxPlaybackHeight() async =>
      await kvGetInt(_maxPlaybackHeightKey, fallback: 2160);

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

  /// True when a Stremio addon row is Torrentio (host or manifest name).
  static bool isTorrentioStremioAddon(Map<String, dynamic> addon) {
    final base =
        normalizeStremioAddonBaseUrl(addon['baseUrl']?.toString() ?? '')
            .toLowerCase();
    if (base.contains('torrentio')) return true;
    final name = (addon['name'] ?? '').toString().toLowerCase();
    if (name.contains('torrentio')) return true;
    final manifest = addon['manifest'];
    if (manifest is Map) {
      final manifestName = manifest['name']?.toString().toLowerCase() ?? '';
      if (manifestName.contains('torrentio')) return true;
    }
    return false;
  }

  /// Installed Stremio Torrentio base (incl. `/sort=…` path config), if any.
  Future<String?> resolveTorrentioStremioAddonBase() async {
    final addons = await getStremioAddons();
    for (final addon in addons) {
      if (addon['enabled'] == false) continue;
      final base = normalizeStremioAddonBaseUrl(
        addon['baseUrl']?.toString() ?? '',
      );
      if (base.isEmpty) continue;
      if (isTorrentioStremioAddon(addon)) return base;
    }
    return null;
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
    normalized['enabled'] = StremioAddonFeatures.normalizeEnabled(
      normalized['enabled'],
    );

    final current = await getStremioAddons();
    final idx = current.indexWhere(
      (a) =>
          normalizeStremioAddonBaseUrl(a['baseUrl']?.toString() ?? '') == base,
    );
    if (idx >= 0) {
      current[idx] = normalized;
    } else {
      current.add(normalized);
    }
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

  /// Effective for UI / playback. Android TV magnets still need a paired
  /// desktop at play time — this toggle only shows Sources.
  Future<bool> isPlaySourceTorrentEnabled() async => isPlaySourceTorrentStored();

  Future<void> setPlaySourceTorrentEnabled(bool enabled) async {
    if (await isPlaySourceTorrentStored() == enabled) return;
    await kvSetBool(_playSourceTorrentKey, enabled);
    playSourceChangeNotifier.value++;
  }

  /// Device-cache value for cloud sync / backup (not platform-gated).
  Future<bool> isPlaySourceStremioStored() async =>
      kvGetBool(_playSourceStremioKey, fallback: _defaults.playSourceStremio);

  /// Effective for UI / playback. ATV HTTP streams play locally; magnets
  /// need a paired desktop at play time.
  Future<bool> isPlaySourceStremioEnabled() async => isPlaySourceStremioStored();

  Future<void> setPlaySourceStremioEnabled(bool enabled) async {
    if (await isPlaySourceStremioStored() == enabled) return;
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

  /// Effective for UI / playback. ATV HTTP streams play locally; magnets
  /// need a paired desktop at play time.
  Future<bool> isPlaySourceNuvioEnabled() async => isPlaySourceNuvioStored();

  Future<void> setPlaySourceNuvioEnabled(bool enabled) async {
    if (await isPlaySourceNuvioStored() == enabled) return;
    await kvSetBool(_playSourceNuvioKey, enabled);
    playSourceChangeNotifier.value++;
  }

  Future<bool> isPlaySourceEngineStored() async {
    if (await kvHasKey(_playSourceEngineKey)) {
      return kvGetBool(
        _playSourceEngineKey,
        fallback: _defaults.playSourceEngine,
      );
    }
    return _defaults.playSourceEngine;
  }

  Future<bool> isPlaySourceEngineEnabled() async => isPlaySourceEngineStored();

  Future<void> setPlaySourceEngineEnabled(bool enabled) async {
    if (await isPlaySourceEngineStored() == enabled) return;
    await kvSetBool(_playSourceEngineKey, enabled);
    playSourceChangeNotifier.value++;
  }

  /// When Forja is on and Webstreaming is off: green Play races all enabled
  /// Forja HTTP plugins and opens the first stream. Default on.
  Future<bool> isPlaySourceEngineAutoStartEnabled() async => kvGetBool(
    _playSourceEngineAutoStartKey,
    fallback: true,
  );

  Future<void> setPlaySourceEngineAutoStartEnabled(bool enabled) async {
    if (await isPlaySourceEngineAutoStartEnabled() == enabled) return;
    await kvSetBool(_playSourceEngineAutoStartKey, enabled);
    playSourceChangeNotifier.value++;
  }

  Future<bool> isPlaySourceWebstreamingEnabled() async => kvGetBool(
    _playSourceWebstreamingKey,
    fallback: _defaults.playSourceWebstreaming,
  );

  Future<void> setPlaySourceWebstreamingEnabled(bool enabled) async {
    if (await isPlaySourceWebstreamingEnabled() == enabled) return;
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

  static String normalizeLiveStreamResolve(String? raw) {
    final v = (raw ?? liveStreamResolveEngine).trim().toLowerCase();
    if (v == liveStreamResolveSniff) return liveStreamResolveSniff;
    return liveStreamResolveEngine;
  }

  static String liveStreamResolveLabel(String stored) =>
      normalizeLiveStreamResolve(stored) == liveStreamResolveEngine
      ? liveStreamResolveEngineLabel
      : liveStreamResolveSniffLabel;

  /// Live Matches: Engine = Forja live plugins (default); Sniff = embed WebView (admin).
  Future<String> getLiveStreamResolveMode() async =>
      normalizeLiveStreamResolve(await kvGetString(_liveStreamResolveKey));

  Future<bool> isLiveStreamResolveEngine() async =>
      (await getLiveStreamResolveMode()) == liveStreamResolveEngine;

  Future<void> setLiveStreamResolveMode(String mode) async => kvSetString(
    _liveStreamResolveKey,
    normalizeLiveStreamResolve(mode),
  );

  /// Crash reporting to Sentry (RFC-043). Default on; Settings → About for everyone.
  Future<bool> isCrashReportingEnabled() async =>
      kvGetBool(_crashReportingEnabledKey, fallback: true);

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

  /// Product analytics to PostHog (RFC-043). Default on; Settings → About for everyone.
  Future<bool> isProductAnalyticsEnabled() async =>
      kvGetBool(_productAnalyticsEnabledKey, fallback: true);

  Future<void> setProductAnalyticsEnabled(bool enabled) async =>
      kvSetBool(_productAnalyticsEnabledKey, enabled);

  static const String _streamProviderOrderKey = 'stream_provider_order';
  static const List<String> defaultStreamProviderOrder = <String>[];

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

  static const String _disabledStreamProvidersKey =
      'disabled_stream_providers';

  Future<List<String>> getDisabledStreamProviders() async =>
      kvGetStringList(_disabledStreamProvidersKey, fallback: const []);

  Future<void> setDisabledStreamProviders(List<String> ids) async =>
      kvSetStringList(_disabledStreamProvidersKey, ids);

  /// Try-order for Auto resolve — full order minus disabled rows.
  Future<List<String>> getEnabledStreamProviderOrder() async {
    final order = await getStreamProviderOrder();
    final off = (await getDisabledStreamProviders()).toSet();
    return [for (final id in order) if (!off.contains(id)) id];
  }

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

  static const String _disabledAnimeProvidersKey = 'disabled_anime_providers';

  Future<List<String>> getDisabledAnimeProviders() async =>
      kvGetStringList(_disabledAnimeProvidersKey, fallback: const []);

  Future<void> setDisabledAnimeProviders(List<String> ids) async =>
      kvSetStringList(_disabledAnimeProvidersKey, ids);

  Future<List<String>> getEnabledAnimeProviderOrder() async {
    final order = await getAnimeProviderOrder();
    final off = (await getDisabledAnimeProviders()).toSet();
    return [for (final id in order) if (!off.contains(id)) id];
  }

  static const String _asianDramaProviderOrderKey =
      'asian_drama_provider_order';

  static const String _disabledAsianDramaProvidersKey =
      'disabled_asian_drama_providers';

  static const List<String> asianDramaMirrorHosts = <String>[
    'kisskh.co',
    'kisskh.nl',
    'kisskh.ovh',
    'kisskh.la',
    'kisskh.do',
    'kisskh.is',
    'kisskh.id',
  ];

  /// Full KissKH mirror list order (Settings UI). Enabled subset drives playback.
  static const List<String> defaultAsianDramaProviderOrder =
      asianDramaMirrorHosts;

  Future<List<String>> getAsianDramaProviderOrder() async {
    final raw = await kvGetStringList(
      _asianDramaProviderOrderKey,
      fallback: const [],
    );
    final normalized = [
      for (final id in raw)
        if (asianDramaMirrorHosts.contains(_normalizeAsianDramaMirrorId(id)))
          _normalizeAsianDramaMirrorId(id),
    ];
    if (normalized.isEmpty) {
      return _migrateAsianDramaProviderOrder(const []);
    }
    final disabled = await getDisabledAsianDramaProviders();
    if (disabled.isEmpty && normalized.length < asianDramaMirrorHosts.length) {
      return _migrateAsianDramaProviderOrder(normalized);
    }
    return mergeProviderOrder(normalized, asianDramaMirrorHosts);
  }

  String _normalizeAsianDramaMirrorId(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty || v == 'kisskh') return 'kisskh.co';
    return v;
  }

  /// Older builds stored enabled-only mirrors; expand to full list + disabled key.
  Future<List<String>> _migrateAsianDramaProviderOrder(
    List<String> normalized,
  ) async {
    final disabled = await getDisabledAsianDramaProviders();
    if (disabled.isEmpty &&
        normalized.isNotEmpty &&
        normalized.length < asianDramaMirrorHosts.length) {
      final enabled = normalized.toSet();
      final off = [
        for (final host in asianDramaMirrorHosts)
          if (!enabled.contains(host)) host,
      ];
      await setDisabledAsianDramaProviders(off);
      final full = mergeProviderOrder(normalized, asianDramaMirrorHosts);
      await setAsianDramaProviderOrder(full);
      return full;
    }
    if (normalized.isEmpty) {
      final full = List<String>.from(asianDramaMirrorHosts);
      final off = [
        for (final host in asianDramaMirrorHosts)
          if (host != 'kisskh.co') host,
      ];
      await setDisabledAsianDramaProviders(off);
      await setAsianDramaProviderOrder(full);
      return full;
    }
    return mergeProviderOrder(normalized, asianDramaMirrorHosts);
  }

  Future<List<String>> getDisabledAsianDramaProviders() async =>
      kvGetStringList(_disabledAsianDramaProvidersKey, fallback: const []);

  Future<void> setDisabledAsianDramaProviders(List<String> ids) async =>
      kvSetStringList(_disabledAsianDramaProvidersKey, ids);

  /// Enabled KissKH mirrors in user order (first = active). No auto-failover.
  Future<List<String>> getEnabledAsianDramaProviderOrder() async {
    final order = await getAsianDramaProviderOrder();
    final off = (await getDisabledAsianDramaProviders()).toSet();
    return [
      for (final id in order)
        if (!off.contains(id)) id,
    ];
  }

  Future<void> setAsianDramaProviderOrder(List<String> order) async =>
      kvSetStringList(_asianDramaProviderOrderKey, order);

  Future<String> getSortPreference() async =>
      await kvGetString(_sortPreferenceKey) ?? 'Seeders (High to Low)';

  Future<void> setSortPreference(String preference) async =>
      kvSetString(_sortPreferenceKey, preference);

  Future<bool> useDebridForStreams() async => useDebridForStreamsSync();

  /// Sync — storage is sync under the hood; memoized after first read.
  bool useDebridForStreamsSync() {
    final cached = _cachedUseDebridForStreams;
    if (cached != null) return cached;
    final v = kvGetBoolSync(_useDebridKey, fallback: false);
    _cachedUseDebridForStreams = v;
    return v;
  }

  Future<void> setUseDebridForStreams(bool enabled) async {
    _cachedUseDebridForStreams = enabled;
    await kvSetBool(_useDebridKey, enabled);
  }

  Future<String> getDebridService() async {
    // Off → no service read.
    if (!useDebridForStreamsSync()) return 'None';
    return getDebridServiceSync();
  }

  String getDebridServiceSync() {
    final cached = _cachedDebridService;
    if (cached != null) return cached;
    final v = kvGetStringSync(_debridServiceKey) ?? 'None';
    _cachedDebridService = v;
    return v;
  }

  /// Play-path snapshot: when debrid is off, skips the service key entirely.
  ({bool useDebrid, String service}) debridPlaybackPrefs() {
    final use = useDebridForStreamsSync();
    if (!use) return (useDebrid: false, service: 'None');
    return (useDebrid: true, service: getDebridServiceSync());
  }

  Future<void> setDebridService(String service) async {
    _cachedDebridService = service;
    await kvSetString(_debridServiceKey, service);
  }

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

  /// FlareSolverr / Byparr base (`http://host:8191`) for Cloudflare indexers.
  Future<String?> getFlareSolverrUrl() async =>
      kvGetString(_flareSolverrUrlKey);

  Future<void> setFlareSolverrUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    await kvSetString(_flareSolverrUrlKey, normalized);
  }

  static const int minTorrentDiskCacheGb = 1;
  static const int maxTorrentDiskCacheGb = 16;

  Future<int> getTorrentDiskCacheGb() async {
    final gb = await kvGetInt(
      _torrentDiskCacheGbKey,
      fallback: _defaults.torrentDiskCacheGb,
    );
    return gb.clamp(minTorrentDiskCacheGb, maxTorrentDiskCacheGb);
  }

  Future<void> setTorrentDiskCacheGb(int gb) async => kvSetInt(
    _torrentDiskCacheGbKey,
    gb.clamp(minTorrentDiskCacheGb, maxTorrentDiskCacheGb),
  );

  Future<int> getTorrentConnectionsLimit() async =>
      kvGetInt(_torrentConnectionsLimitKey, fallback: 200);

  Future<void> setTorrentConnectionsLimit(int limit) async =>
      kvSetInt(_torrentConnectionsLimitKey, limit);

  Future<String> getThemePreset() async =>
      await kvGetString(_themePresetKey) ?? 'forja';

  Future<void> setThemePreset(String preset) async =>
      kvSetString(_themePresetKey, preset);

  static const String _navbarConfigKey = 'navbar_config';
  static const String _navbarTabOrderKey = 'navbar_tab_order';
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

  /// Serializes navbar KV writes / RMW so rapid Addons toggles (ATV OK) cannot
  /// lose updates — e.g. IPTV then Live Sports both read `[]` and the second
  /// write leaves only `live_matches` (issue 224).
  static Future<void> _navbarExclusiveTail = Future<void>.value();

  static Future<T> _withNavbarExclusive<T>(Future<T> Function() op) {
    final done = Completer<T>();
    _navbarExclusiveTail = _navbarExclusiveTail.then((_) async {
      try {
        done.complete(await op());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  /// Default visible tabs (settings appended in MainScreen).
  static const List<String> defaultTvVisibleNavIds =
      PlatformDefaults.androidTvNavIds;

  static const List<String> defaultVisibleNavIds =
      PlatformDefaults.defaultNavIds;

  /// Pre–RFC-081 first-run rail (hub pack tab ids baked into platform defaults).
  /// Legacy shell migrations rewrite *to* this list — never to host-only defaults
  /// — so upgrades do not strip Home / Anime / … from untouched installs.
  static const List<String> _legacyPackSeededDefaultNavIds = [
    'home',
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

  /// Prior Android TV defaults — migrate to [_legacyPackSeededDefaultNavIds].
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
    if (await getDefaultNavTab() == tabId) return;
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

  /// Host tabs gated by Settings → Addons. Never auto-insert on first-seen —
  /// only Features / Addons toggles may show them.
  static const Set<String> addonGatedNavIds = {
    'iptv',
    'live_matches',
  };

  /// Host / archived shell ids only. Catalog hub tab ids register via
  /// [registerExtraNavIds] when packs contribute `nav` — never list VOD hubs
  /// here or fresh-install [navbar_known_ids] blocks first-seen auto-show.
  /// [live_matches] is host core (RFC-084), same class as [iptv].
  static const List<String> _baseAllNavIds = [
    'discover',
    'similar',
    'search',
    'downloader',
    'magnet',
    'iptv',
    'live_matches',
    'audiobooks',
    'books',
    'music',
    'comics',
    'manga',
    'jellyfin',
  ];

  static final List<String> _extraNavIds = [];

  /// Built-in tabs plus any hub `tabId`s registered from catalog plugins (A13).
  static List<String> get allNavIds => [
        ..._baseAllNavIds,
        ..._extraNavIds,
      ];

  /// Catalog hubs may mint new shell tab ids — keep them in navbar known set.
  static void registerExtraNavIds(Iterable<String> ids) {
    for (final id in ids) {
      final t = id.trim();
      if (t.isEmpty) continue;
      if (_baseAllNavIds.contains(t) || _extraNavIds.contains(t)) continue;
      _extraNavIds.add(t);
    }
  }

  /// After hubs pack refresh: mark new tab ids known; auto-show hubs the user
  /// has never seen (same insert rules as [getNavbarConfig]).
  ///
  /// [notify] false when Features is already rebuilding from the same refresh
  /// (avoids cancelling `settingsNavigationProvider` mid-load — issue 222).
  Future<void> ensureNavIdsKnown({
    required List<String> allHubIds,
    bool notify = true,
  }) async {
    return _withNavbarExclusive(() async {
      registerExtraNavIds(allHubIds);
      final known = (await kvGetStringList(
        _navbarKnownIdsKey,
        fallback: const [],
      )).toSet();
      final visible = await kvHasKey(_navbarConfigKey)
          ? await kvGetStringList(_navbarConfigKey, fallback: const [])
          : List<String>.from(defaultVisibleNavIds);
      var changed = false;
      for (final id in allHubIds) {
        if (known.contains(id)) continue;
        known.add(id);
        changed = true;
        if (!visible.contains(id)) {
          visible.add(id);
        }
      }
      if (!changed &&
          known.containsAll(allNavIds) &&
          known.containsAll(allHubIds)) {
        return;
      }
      await kvSetStringList(_navbarKnownIdsKey, {
        ...known,
        ...allNavIds,
      }.toList());
      if (await kvHasKey(_navbarConfigKey)) {
        final prev = await kvGetStringList(_navbarConfigKey, fallback: const []);
        await kvSetStringList(_navbarConfigKey, visible);
        // Features / rail watch this — without a bump, pack install can leave
        // Settings → Features stuck on Settings-only until a manual reopen.
        if (notify && !listEquals(prev, visible)) {
          navbarChangeNotifier.value++;
        }
      }
    });
  }

  /// Re-insert active hub tabs missing from the visible navbar — recovery after
  /// a premature empty-hub sync during lean boot.
  ///
  /// No-op if any [activeHubIds] tab is already visible (intentional Features
  /// hide / partial config — not a full strip). Callers pass VOD hub ids only
  /// (not Addons-gated `iptv` / `live_matches`).
  Future<void> ensureActiveDefaultHubsVisible({
    required Set<String> activeHubIds,
    bool notify = true,
  }) async {
    if (activeHubIds.isEmpty) return;
    return _withNavbarExclusive(() async {
      if (!await kvHasKey(_navbarConfigKey)) return;
      final visible = await kvGetStringList(_navbarConfigKey, fallback: const []);
      if (visible.any(activeHubIds.contains)) return;

      // Keep any stored host tabs, then restore stripped VOD hubs, then the rest.
      final ordered = <String>[
        for (final id in visible)
          if (!activeHubIds.contains(id)) id,
        for (final id in activeHubIds)
          if (!visible.contains(id)) id,
      ];
      if (listEquals(visible, ordered)) return;
      await kvSetStringList(_navbarConfigKey, ordered);
      if (notify) navbarChangeNotifier.value++;
    });
  }

  /// Drop hub tabs whose pack/plugin is off from the visible navbar.
  ///
  /// [knownHubIds] = all catalog hub tab ids the shell knows about.
  /// [activeHubIds] = hubs currently contributed by an enabled pack+plugin.
  Future<void> syncActiveHubNavIds({
    required Set<String> activeHubIds,
    required Set<String> knownHubIds,
    bool notify = true,
  }) async {
    return _withNavbarExclusive(() async {
      if (!await kvHasKey(_navbarConfigKey)) return;
      final raw = await kvGetStringList(_navbarConfigKey, fallback: const []);
      final next = raw
          .where((id) => !knownHubIds.contains(id) || activeHubIds.contains(id))
          .toList();
      if (listEquals(raw, next)) return;
      await kvSetStringList(_navbarConfigKey, next);
      final defaultTab = await getDefaultNavTab();
      if (knownHubIds.contains(defaultTab) &&
          !activeHubIds.contains(defaultTab)) {
        final fallback = next.isNotEmpty ? next.first : 'settings';
        await kvSetString(_defaultNavTabKey, fallback);
      }
      if (notify) navbarChangeNotifier.value++;
    });
  }

  /// RMW add/remove one tab under the navbar exclusive lock (issue 224).
  Future<List<String>> setNavbarTabVisible(String navId, bool visible) {
    return _withNavbarExclusive(() async {
      final nav = await getNavbarConfig();
      final updated = visible
          ? [...nav, if (!nav.contains(navId)) navId]
          : nav.where((id) => id != navId).toList();
      await _setNavbarConfigUnlocked(updated);
      return updated;
    });
  }

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

  /// Older ATV seeds may lack Forja. Ensure engine is on; other play sources
  /// stay at stored / platform defaults (Forja-only first run).
  Future<void> _migrateAtvCatalogPlaySources() async {
    if (await kvHasKey(_atvCatalogPlaySourcesKey)) return;
    if (platformProfile == PlatformProfile.androidTv) {
      await kvSetBool(_playSourceEngineKey, true);
      playSourceChangeNotifier.value++;
    }
    await kvSetString(_atvCatalogPlaySourcesKey, '1');
  }

  static const _webstreamrPurgedKey = 'webstreamr_settings_purged_v1';

  static const _retiredWebstreamrKvKeys = <String>[
    'webstreamr_country_codes',
    'webstreamr_mfp_url',
    'webstreamr_flare_url',
    'webstreamr_disabled_extractors',
    'webstreamr_excluded_resolutions',
  ];

  Future<void> _purgeRetiredWebstreamrSettings() async {
    if (await kvHasKey(_webstreamrPurgedKey)) return;
    for (final key in _retiredWebstreamrKvKeys) {
      if (await kvHasKey(key)) {
        await kvSetString(key, '');
        await kvSetStringList(key, const []);
      }
    }
    for (final key in SecureSettings.retiredSecureKeys) {
      try {
        await SecureSettings.delete(key);
      } catch (e) {
        debugPrint('[SettingsService] webstreamr secure purge skipped ($key): $e');
      }
    }
    await kvSetString(_webstreamrPurgedKey, '1');
  }

  Future<void> ensurePlatformDefaultsSeeded(PlatformProfile profile) async {
    configurePlatformProfile(profile);
    await ensureCanonicalSettingsMigrated();
    await _purgeRetiredWebstreamrSettings();
    await _migrateBuiltInEngineDefaultToMediaKit();
    await _migratePlayInBackgroundDeviceLocal();
    await _migrateAtvCatalogPlaySources();
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
      await kvSetBool(_playSourceEngineKey, defaults.playSourceEngine);
      await kvSetBool(
        _playSourceWebstreamingKey,
        defaults.playSourceWebstreaming,
      );
      await kvSetInt(_torrentDiskCacheGbKey, defaults.torrentDiskCacheGb);
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
          List<String>.from(_legacyPackSeededDefaultNavIds),
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
            List<String>.from(_legacyPackSeededDefaultNavIds),
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
            List<String>.from(_legacyPackSeededDefaultNavIds),
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
            List<String>.from(_legacyPackSeededDefaultNavIds),
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
            List<String>.from(_legacyPackSeededDefaultNavIds),
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
    // Keep stored ids even before pack [registerExtraNavIds] (hub tabs). Host
    // [allNavIds] is for auto-insert of new builtins + Features order only.
    final filtered = raw
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final known = (await kvGetStringList(
      _navbarKnownIdsKey,
      fallback: const [],
    )).toSet();
    final newlyAdded = <String>[];
    for (var i = 0; i < allNavIds.length; i++) {
      final id = allNavIds[i];
      if (filtered.contains(id)) continue;
      if (known.contains(id)) continue;
      // Addons-gated host tabs stay off until the user enables them.
      if (addonGatedNavIds.contains(id)) continue;
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
    if (newlyAdded.isNotEmpty || allNavIds.any((id) => !known.contains(id))) {
      await kvSetStringList(_navbarKnownIdsKey, {
        ...known,
        ...allNavIds,
      }.toList());
    }
    return filtered;
  }

  /// Full tab order for Settings → Features (visible + hidden). Shell nav still
  /// uses [getNavbarConfig] for visible-only order.
  Future<List<String>> getNavbarTabOrder() async {
    final visible = await getNavbarConfig();
    if (!await kvHasKey(_navbarTabOrderKey)) {
      final hidden = allNavIds.where((id) => !visible.contains(id)).toList();
      return [...visible, ...hidden];
    }
    final stored = await kvGetStringList(
      _navbarTabOrderKey,
      fallback: const [],
    );
    return _mergeNavbarTabOrder(stored, allNavIds);
  }

  static List<String> _mergeNavbarTabOrder(
    List<String> stored,
    List<String> allIds,
  ) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in stored) {
      if (!allIds.contains(id) || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
    }
    for (final id in allIds) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  Future<void> setNavbarConfig(
    List<String> visibleIds, {
    List<String>? tabOrder,
    bool notify = true,
  }) {
    return _withNavbarExclusive(
      () => _setNavbarConfigUnlocked(
        visibleIds,
        tabOrder: tabOrder,
        notify: notify,
      ),
    );
  }

  Future<void> _setNavbarConfigUnlocked(
    List<String> visibleIds, {
    List<String>? tabOrder,
    bool notify = true,
  }) async {
    final raw = await kvHasKey(_navbarConfigKey)
        ? await kvGetStringList(_navbarConfigKey, fallback: const [])
        : null;
    final unchanged = raw != null && listEquals(raw, visibleIds);
    await kvSetStringList(_navbarConfigKey, visibleIds);
    final known = (await kvGetStringList(
      _navbarKnownIdsKey,
      fallback: const [],
    )).toSet();
    await kvSetStringList(_navbarKnownIdsKey, {
      ...known,
      ...allNavIds,
      ...visibleIds,
    }.toList());
    if (tabOrder != null) {
      await kvSetStringList(
        _navbarTabOrderKey,
        _mergeNavbarTabOrder(tabOrder, allNavIds),
      );
    }
    if (notify && !unchanged) navbarChangeNotifier.value++;
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
    ...SecureSettings.retiredSecureKeys,
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
    prefsMap[_playSourceEngineKey] = await isPlaySourceEngineStored();
    prefsMap[_playSourceEngineAutoStartKey] =
        await isPlaySourceEngineAutoStartEnabled();
    prefsMap[_playSourceWebstreamingKey] =
        await isPlaySourceWebstreamingEnabled();
    prefsMap[_p2pStreamingAcknowledgedKey] =
        await isP2pStreamingAcknowledged();
    for (final key in [
      _sortPreferenceKey,
      _debridServiceKey,
      _externalPlayerKey,
      _jackettBaseUrlKey,
      _prowlarrBaseUrlKey,
    ]) {
      final v = await kvGetString(key);
      if (v != null && v.isNotEmpty) prefsMap[key] = v;
    }
    prefsMap[_torrentDiskCacheGbKey] = await getTorrentDiskCacheGb();
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
      _playSourceEngineKey,
      _playSourceEngineAutoStartKey,
      _playSourceWebstreamingKey,
      _p2pStreamingAcknowledgedKey,
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
      _prowlarrBaseUrlKey,
      'nuvio_addons_v1',
    ]) {
      if (prefsMap.containsKey(key)) {
        await kvSetString(key, prefsMap[key] as String);
      }
    }
    if (prefsMap.containsKey(_torrentDiskCacheGbKey)) {
      await kvSetInt(
        _torrentDiskCacheGbKey,
        prefsMap[_torrentDiskCacheGbKey] as int,
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
