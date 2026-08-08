import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

// ── Playback ───────────────────────────────────────────────────────────────

@immutable
class SettingsPlaybackSnapshot {
  const SettingsPlaybackSnapshot({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceWebstreaming,
    required this.simpleStreamingResolve,
    required this.builtInEngine,
    required this.streamProviderOrder,
    required this.animeProviderOrder,
    required this.preferredAudioLang,
    required this.avoidUnsupportedAudio,
    required this.autoNextEpisode,
    required this.autoSkipIntro,
    required this.autoPipOnDesktopSwitch,
    required this.playInBackground,
    required this.iptvEpgEnabled,
    required this.iptvLiveMaxHeightLabel,
    required this.iptvLiveRecoveryModeLabel,
    required this.iptvMatchDisplayRefresh,
    required this.maxPlaybackHeightLabel,
    required this.animeTitleLanguageLabel,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceWebstreaming;
  final bool simpleStreamingResolve;
  final BuiltInPlayerEngine builtInEngine;
  final List<String> streamProviderOrder;
  final List<String> animeProviderOrder;
  final String preferredAudioLang;
  final bool avoidUnsupportedAudio;
  final bool autoNextEpisode;
  final bool autoSkipIntro;
  final bool autoPipOnDesktopSwitch;
  final bool playInBackground;
  final bool iptvEpgEnabled;
  final String iptvLiveMaxHeightLabel;
  final String iptvLiveRecoveryModeLabel;
  final bool iptvMatchDisplayRefresh;
  final String maxPlaybackHeightLabel;
  final String animeTitleLanguageLabel;

  SettingsPlaybackSnapshot copyWith({
    bool? playSourceTorrent,
    bool? playSourceStremio,
    bool? playSourceNuvio,
    bool? playSourceWebstreaming,
    bool? simpleStreamingResolve,
    BuiltInPlayerEngine? builtInEngine,
    List<String>? streamProviderOrder,
    List<String>? animeProviderOrder,
    String? preferredAudioLang,
    bool? avoidUnsupportedAudio,
    bool? autoNextEpisode,
    bool? autoSkipIntro,
    bool? autoPipOnDesktopSwitch,
    bool? playInBackground,
    bool? iptvEpgEnabled,
    String? iptvLiveMaxHeightLabel,
    String? iptvLiveRecoveryModeLabel,
    bool? iptvMatchDisplayRefresh,
    String? maxPlaybackHeightLabel,
    String? animeTitleLanguageLabel,
  }) {
    return SettingsPlaybackSnapshot(
      playSourceTorrent: playSourceTorrent ?? this.playSourceTorrent,
      playSourceStremio: playSourceStremio ?? this.playSourceStremio,
      playSourceNuvio: playSourceNuvio ?? this.playSourceNuvio,
      playSourceWebstreaming:
          playSourceWebstreaming ?? this.playSourceWebstreaming,
      simpleStreamingResolve:
          simpleStreamingResolve ?? this.simpleStreamingResolve,
      builtInEngine: builtInEngine ?? this.builtInEngine,
      streamProviderOrder: streamProviderOrder ?? this.streamProviderOrder,
      animeProviderOrder: animeProviderOrder ?? this.animeProviderOrder,
      preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
      avoidUnsupportedAudio:
          avoidUnsupportedAudio ?? this.avoidUnsupportedAudio,
      autoNextEpisode: autoNextEpisode ?? this.autoNextEpisode,
      autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
      autoPipOnDesktopSwitch:
          autoPipOnDesktopSwitch ?? this.autoPipOnDesktopSwitch,
      playInBackground: playInBackground ?? this.playInBackground,
      iptvEpgEnabled: iptvEpgEnabled ?? this.iptvEpgEnabled,
      iptvLiveMaxHeightLabel:
          iptvLiveMaxHeightLabel ?? this.iptvLiveMaxHeightLabel,
      iptvLiveRecoveryModeLabel:
          iptvLiveRecoveryModeLabel ?? this.iptvLiveRecoveryModeLabel,
      iptvMatchDisplayRefresh:
          iptvMatchDisplayRefresh ?? this.iptvMatchDisplayRefresh,
      maxPlaybackHeightLabel:
          maxPlaybackHeightLabel ?? this.maxPlaybackHeightLabel,
      animeTitleLanguageLabel:
          animeTitleLanguageLabel ?? this.animeTitleLanguageLabel,
    );
  }
}

final settingsPlaybackProvider =
    AsyncNotifierProvider<SettingsPlaybackNotifier, SettingsPlaybackSnapshot>(
  SettingsPlaybackNotifier.new,
);

class SettingsPlaybackNotifier
    extends AsyncNotifier<SettingsPlaybackSnapshot> {
  @override
  Future<SettingsPlaybackSnapshot> build() async {
    ref.watch(playSourceRevisionProvider);
    return _load();
  }

  Future<SettingsPlaybackSnapshot> _load() async {
    final s = SettingsService();
    final preferredAudio = await s.getPreferredAudioLanguage();
    final iptvEpgEnabled = await s.isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = iptvEpgEnabled;
    final lanReady = await PlaySourceEffective.lanDesktopReady();
    return SettingsPlaybackSnapshot(
      playSourceTorrent: await PlaySourceEffective.torrent(s, lanReady),
      playSourceStremio: await PlaySourceEffective.stremio(s, lanReady),
      playSourceNuvio: await PlaySourceEffective.nuvio(s, lanReady),
      playSourceWebstreaming: await s.isPlaySourceWebstreamingEnabled(),
      simpleStreamingResolve: await s.isSimpleStreamingResolveEnabled(),
      builtInEngine: await s.getBuiltInPlayerEngine(),
      streamProviderOrder: await s.getStreamProviderOrder(),
      animeProviderOrder: await s.getAnimeProviderOrder(),
      preferredAudioLang: kTrackLanguageDisplayNames.contains(preferredAudio)
          ? preferredAudio
          : 'None',
      avoidUnsupportedAudio: await s.getAvoidUnsupportedAudio(),
      autoNextEpisode: await s.getAutoNextEpisode(),
      autoSkipIntro: await s.getAutoSkipIntro(),
      autoPipOnDesktopSwitch: await s.getAutoPipOnDesktopSwitch(),
      playInBackground: await s.getPlayInBackground(),
      iptvEpgEnabled: iptvEpgEnabled,
      iptvLiveMaxHeightLabel: SettingsService.iptvLiveMaxHeightLabel(
        await s.getIptvLiveMaxHeight(),
      ),
      iptvLiveRecoveryModeLabel: SettingsService.iptvLiveRecoveryModeLabel(
        await s.getIptvLiveRecoveryMode(),
      ),
      iptvMatchDisplayRefresh: await s.getIptvMatchDisplayRefresh(),
      maxPlaybackHeightLabel: SettingsService.maxPlaybackHeightLabel(
        await s.getMaxPlaybackHeight(),
      ),
      animeTitleLanguageLabel: SettingsService.animeTitleLanguageLabel(
        await s.getAnimeTitleLanguage(),
      ),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void _patch(SettingsPlaybackSnapshot next) {
    state = AsyncData(next);
  }

  Future<void> patch(
    SettingsPlaybackSnapshot Function(SettingsPlaybackSnapshot) fn,
  ) async {
    final cur = state.value;
    if (cur == null) return;
    _patch(fn(cur));
  }
}

// ── Torrent search / engine ────────────────────────────────────────────────

@immutable
class SettingsTorrentSnapshot {
  const SettingsTorrentSnapshot({
    required this.sortPreference,
    required this.cacheType,
    required this.ramCacheMb,
    required this.connectionsLimit,
    required this.enabledProviders,
  });

  final String sortPreference;
  final String cacheType;
  final int ramCacheMb;
  final int connectionsLimit;
  final List<String> enabledProviders;

  SettingsTorrentSnapshot copyWith({
    String? sortPreference,
    String? cacheType,
    int? ramCacheMb,
    int? connectionsLimit,
    List<String>? enabledProviders,
  }) {
    return SettingsTorrentSnapshot(
      sortPreference: sortPreference ?? this.sortPreference,
      cacheType: cacheType ?? this.cacheType,
      ramCacheMb: ramCacheMb ?? this.ramCacheMb,
      connectionsLimit: connectionsLimit ?? this.connectionsLimit,
      enabledProviders: enabledProviders ?? this.enabledProviders,
    );
  }
}

final settingsTorrentProvider =
    AsyncNotifierProvider<SettingsTorrentNotifier, SettingsTorrentSnapshot>(
  SettingsTorrentNotifier.new,
);

class SettingsTorrentNotifier extends AsyncNotifier<SettingsTorrentSnapshot> {
  @override
  Future<SettingsTorrentSnapshot> build() async {
    final s = SettingsService();
    return SettingsTorrentSnapshot(
      sortPreference: await s.getSortPreference(),
      cacheType: await s.getTorrentCacheType(),
      ramCacheMb: await s.getTorrentRamCacheMb(),
      connectionsLimit: await s.getTorrentConnectionsLimit(),
      enabledProviders: await s.getEnabledTorrentProviders(),
    );
  }

  void patch(SettingsTorrentSnapshot Function(SettingsTorrentSnapshot) fn) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(fn(cur));
  }
}

// ── Debrid ─────────────────────────────────────────────────────────────────

@immutable
class SettingsDebridSnapshot {
  const SettingsDebridSnapshot({
    required this.useDebrid,
    required this.service,
    required this.torboxKey,
    required this.alldebridKey,
    required this.premiumizeKey,
    required this.debridlinkKey,
    required this.isRDLoggedIn,
  });

  final bool useDebrid;
  final String service;
  final String torboxKey;
  final String alldebridKey;
  final String premiumizeKey;
  final String debridlinkKey;
  final bool isRDLoggedIn;

  SettingsDebridSnapshot copyWith({
    bool? useDebrid,
    String? service,
    String? torboxKey,
    String? alldebridKey,
    String? premiumizeKey,
    String? debridlinkKey,
    bool? isRDLoggedIn,
  }) {
    return SettingsDebridSnapshot(
      useDebrid: useDebrid ?? this.useDebrid,
      service: service ?? this.service,
      torboxKey: torboxKey ?? this.torboxKey,
      alldebridKey: alldebridKey ?? this.alldebridKey,
      premiumizeKey: premiumizeKey ?? this.premiumizeKey,
      debridlinkKey: debridlinkKey ?? this.debridlinkKey,
      isRDLoggedIn: isRDLoggedIn ?? this.isRDLoggedIn,
    );
  }
}

final settingsDebridProvider =
    AsyncNotifierProvider<SettingsDebridNotifier, SettingsDebridSnapshot>(
  SettingsDebridNotifier.new,
);

class SettingsDebridNotifier extends AsyncNotifier<SettingsDebridSnapshot> {
  @override
  Future<SettingsDebridSnapshot> build() => _load();

  Future<SettingsDebridSnapshot> _load() async {
    final s = SettingsService();
    final d = DebridApi();
    return SettingsDebridSnapshot(
      useDebrid: await s.useDebridForStreams(),
      service: await s.getDebridService(),
      torboxKey: await d.getTorBoxKey() ?? '',
      alldebridKey: await d.getAllDebridKey() ?? '',
      premiumizeKey: await d.getPremiumizeKey() ?? '',
      debridlinkKey: await d.getDebridLinkKey() ?? '',
      isRDLoggedIn: await d.getRDAccessToken() != null,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void patch(SettingsDebridSnapshot Function(SettingsDebridSnapshot) fn) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(fn(cur));
  }
}

// ── WebStreamr ─────────────────────────────────────────────────────────────

@immutable
class SettingsWebstreamrSnapshot {
  const SettingsWebstreamrSnapshot({
    required this.enabledCountries,
    required this.disabledExtractors,
    required this.excludedResolutions,
    required this.mfpUrl,
    required this.mfpPwd,
    required this.flareUrl,
    required this.tmdbTok,
  });

  final Set<String> enabledCountries;
  final Set<String> disabledExtractors;
  final Set<String> excludedResolutions;
  final String mfpUrl;
  final String mfpPwd;
  final String flareUrl;
  final String tmdbTok;
}

final settingsWebstreamrProvider = AsyncNotifierProvider<
    SettingsWebstreamrNotifier, SettingsWebstreamrSnapshot>(
  SettingsWebstreamrNotifier.new,
);

class SettingsWebstreamrNotifier
    extends AsyncNotifier<SettingsWebstreamrSnapshot> {
  @override
  Future<SettingsWebstreamrSnapshot> build() async {
    return SettingsWebstreamrSnapshot(
      enabledCountries: (await WebStreamrSettings.getEnabledCountryCodes())
          .toSet(),
      disabledExtractors:
          (await WebStreamrSettings.getDisabledExtractors()).toSet(),
      excludedResolutions:
          (await WebStreamrSettings.getExcludedResolutions()).toSet(),
      mfpUrl: await WebStreamrSettings.getMediaFlowProxyUrl() ?? '',
      mfpPwd: await WebStreamrSettings.getMediaFlowProxyPassword() ?? '',
      flareUrl: await WebStreamrSettings.getFlareSolverrUrl() ?? '',
      tmdbTok: await WebStreamrSettings.getTmdbAccessToken() ?? '',
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

// ── Features / navigation ──────────────────────────────────────────────────

@immutable
class SettingsNavigationSnapshot {
  const SettingsNavigationSnapshot({
    required this.visible,
    required this.order,
    required this.defaultTab,
  });

  final List<String> visible;
  final List<String> order;
  final String defaultTab;
}

final settingsNavigationProvider = AsyncNotifierProvider<
    SettingsNavigationNotifier, SettingsNavigationSnapshot>(
  SettingsNavigationNotifier.new,
);

class SettingsNavigationNotifier
    extends AsyncNotifier<SettingsNavigationSnapshot> {
  @override
  Future<SettingsNavigationSnapshot> build() async {
    ref.watch(navbarRevisionProvider);
    return _load();
  }

  Future<SettingsNavigationSnapshot> _load() async {
    final s = SettingsService();
    var navVisible = await s.getNavbarConfig();
    final defaultNavTab = await s.getDefaultNavTab();
    final allIds = SettingsService.allNavIds
        .where((id) => !temporarilyHiddenNavIds.contains(id))
        .toList();
    navVisible.removeWhere(temporarilyHiddenNavIds.contains);
    final hidden = allIds.where((id) => !navVisible.contains(id)).toList();
    var navOrder = [...navVisible, ...hidden];
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      navOrder = navOrder
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
      navVisible.removeWhere(
        (id) => PlatformPlayback.torrentNavIds.contains(id),
      );
    }
    final startup = <String>[];
    final seen = <String>{};
    for (final id in navOrder) {
      if (navVisible.contains(id) && seen.add(id)) startup.add(id);
    }
    if (!startup.contains('settings')) startup.add('settings');
    final resolved = startup.contains(defaultNavTab)
        ? defaultNavTab
        : (startup.isNotEmpty ? startup.first : 'settings');
    if (resolved != defaultNavTab) {
      await s.setDefaultNavTab(resolved);
    }
    return SettingsNavigationSnapshot(
      visible: navVisible,
      order: navOrder,
      defaultTab: resolved,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

// ── Indexers + Nuvio ───────────────────────────────────────────────────────

@immutable
class SettingsIndexerSnapshot {
  const SettingsIndexerSnapshot({
    required this.jackettUrl,
    required this.jackettApiKey,
    required this.prowlarrUrl,
    required this.prowlarrApiKey,
    required this.prowlarrSelectedTagIds,
  });

  final String jackettUrl;
  final String jackettApiKey;
  final String prowlarrUrl;
  final String prowlarrApiKey;
  final Set<int> prowlarrSelectedTagIds;
}

final settingsIndexerProvider =
    AsyncNotifierProvider<SettingsIndexerNotifier, SettingsIndexerSnapshot>(
  SettingsIndexerNotifier.new,
);

class SettingsIndexerNotifier extends AsyncNotifier<SettingsIndexerSnapshot> {
  @override
  Future<SettingsIndexerSnapshot> build() async {
    final s = SettingsService();
    return SettingsIndexerSnapshot(
      jackettUrl: await s.getJackettBaseUrl() ?? '',
      jackettApiKey: await s.getJackettApiKey() ?? '',
      prowlarrUrl: await s.getProwlarrBaseUrl() ?? '',
      prowlarrApiKey: await s.getProwlarrApiKey() ?? '',
      prowlarrSelectedTagIds: (await s.getProwlarrTagIds()).toSet(),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final nuvioAddonsProvider =
    AsyncNotifierProvider<NuvioAddonsNotifier, List<NuvioAddon>>(
  NuvioAddonsNotifier.new,
);

class NuvioAddonsNotifier extends AsyncNotifier<List<NuvioAddon>> {
  @override
  Future<List<NuvioAddon>> build() async {
    final n = NuvioService.changeNotifier;
    void listener() => ref.invalidateSelf();
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return NuvioService.instance.listUserAddons();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => NuvioService.instance.listUserAddons(),
    );
  }
}

// ── Tracker account status ─────────────────────────────────────────────────

@immutable
class TrackerAccountStatus {
  const TrackerAccountStatus({
    required this.loggedIn,
    this.username,
    this.stats,
    this.apiKey,
  });

  final bool loggedIn;
  final String? username;
  final Map<String, dynamic>? stats;
  final String? apiKey;
}

final traktStatusProvider =
    FutureProvider.autoDispose<TrackerAccountStatus>((ref) async {
  final trakt = TraktService();
  final loggedIn = await trakt.isLoggedIn();
  if (!loggedIn) return const TrackerAccountStatus(loggedIn: false);
  final profile = await trakt.getUserProfile();
  final user = profile?['user']?['username']?.toString() ??
      profile?['username']?.toString();
  final stats = await trakt.getUserStats();
  return TrackerAccountStatus(loggedIn: true, username: user, stats: stats);
});

final simklStatusProvider =
    FutureProvider.autoDispose<TrackerAccountStatus>((ref) async {
  final simkl = SimklService();
  final loggedIn = await simkl.isLoggedIn();
  if (!loggedIn) return const TrackerAccountStatus(loggedIn: false);
  final profile = await simkl.getUserProfile();
  final name = profile?['user']?['name']?.toString() ??
      profile?['name']?.toString();
  return TrackerAccountStatus(loggedIn: true, username: name);
});

final mdblistStatusProvider =
    FutureProvider.autoDispose<TrackerAccountStatus>((ref) async {
  final mdblist = MdblistService();
  final configured = await mdblist.isConfigured();
  if (!configured) return const TrackerAccountStatus(loggedIn: false);
  final key = await mdblist.getApiKey();
  final info = await mdblist.getUserInfo();
  final name = info?['name']?.toString();
  return TrackerAccountStatus(
    loggedIn: true,
    username: name,
    apiKey: key,
  );
});

// ── About telemetry / keychain ─────────────────────────────────────────────

final crashReportingEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return SettingsService().isCrashReportingEnabled();
});

final productAnalyticsEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return SettingsService().isProductAnalyticsEnabled();
});

final macOsKeychainEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  await ForjaPlatformSecureStore.ensureConsentLoaded();
  return ForjaPlatformSecureStore.usesKeychain;
});
