import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shared/sync/providers/account_features_provider.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';
import 'package:rust/rust.dart';

// ── Playback ───────────────────────────────────────────────────────────────

@immutable
class SettingsPlaybackSnapshot {
  const SettingsPlaybackSnapshot({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceEngine,
    required this.playSourceEngineAutoStart,
    required this.p2pAcknowledged,
    required this.simpleStreamingResolve,
    required this.builtInEngine,
    required this.builtInEngineIptv,
    required this.streamProviderOrder,
    required this.disabledStreamProviders,
    required this.animeProviderOrder,
    required this.disabledAnimeProviders,
    required this.asianDramaProviderOrder,
    required this.disabledAsianDramaProviders,
    required this.preferredAudioLang,
    required this.preferredSubtitleLang,
    required this.avoidUnsupportedAudio,
    required this.autoNextEpisode,
    required this.autoSkipIntro,
    required this.contentWarnings,
    required this.autoPipOnDesktopSwitch,
    required this.playInBackground,
    required this.iptvEpgEnabled,
    required this.iptvLiveMaxHeightLabel,
    required this.iptvLiveRecoveryModeLabel,
    required this.iptvLiveRecoveryStallReopen,
    required this.iptvMatchDisplayRefresh,
    required this.iptvLiveBufferSecsLabel,
    required this.maxPlaybackHeightLabel,
    required this.animeTitleLanguageLabel,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceEngine;
  final bool playSourceEngineAutoStart;
  final bool p2pAcknowledged;
  final bool simpleStreamingResolve;
  final BuiltInPlayerEngine builtInEngine;
  final BuiltInPlayerEngine builtInEngineIptv;
  final List<String> streamProviderOrder;
  final List<String> disabledStreamProviders;
  final List<String> animeProviderOrder;
  final List<String> disabledAnimeProviders;
  final List<String> asianDramaProviderOrder;
  final List<String> disabledAsianDramaProviders;
  final String preferredAudioLang;
  final String preferredSubtitleLang;
  final bool avoidUnsupportedAudio;
  final bool autoNextEpisode;
  final bool autoSkipIntro;
  final bool contentWarnings;
  final bool autoPipOnDesktopSwitch;
  final bool playInBackground;
  final bool iptvEpgEnabled;
  final String iptvLiveMaxHeightLabel;
  final String iptvLiveRecoveryModeLabel;
  final bool iptvLiveRecoveryStallReopen;
  final bool iptvMatchDisplayRefresh;
  final String iptvLiveBufferSecsLabel;
  final String maxPlaybackHeightLabel;
  final String animeTitleLanguageLabel;

  SettingsPlaybackSnapshot copyWith({
    bool? playSourceTorrent,
    bool? playSourceStremio,
    bool? playSourceNuvio,
    bool? playSourceEngine,
    bool? playSourceEngineAutoStart,
    bool? p2pAcknowledged,
    bool? simpleStreamingResolve,
    BuiltInPlayerEngine? builtInEngine,
    BuiltInPlayerEngine? builtInEngineIptv,
    List<String>? streamProviderOrder,
    List<String>? disabledStreamProviders,
    List<String>? animeProviderOrder,
    List<String>? disabledAnimeProviders,
    List<String>? asianDramaProviderOrder,
    List<String>? disabledAsianDramaProviders,
    String? preferredAudioLang,
    String? preferredSubtitleLang,
    bool? avoidUnsupportedAudio,
    bool? autoNextEpisode,
    bool? autoSkipIntro,
    bool? contentWarnings,
    bool? autoPipOnDesktopSwitch,
    bool? playInBackground,
    bool? iptvEpgEnabled,
    String? iptvLiveMaxHeightLabel,
    String? iptvLiveRecoveryModeLabel,
    bool? iptvLiveRecoveryStallReopen,
    bool? iptvMatchDisplayRefresh,
    String? iptvLiveBufferSecsLabel,
    String? maxPlaybackHeightLabel,
    String? animeTitleLanguageLabel,
  }) {
    return SettingsPlaybackSnapshot(
      playSourceTorrent: playSourceTorrent ?? this.playSourceTorrent,
      playSourceStremio: playSourceStremio ?? this.playSourceStremio,
      playSourceNuvio: playSourceNuvio ?? this.playSourceNuvio,
      playSourceEngine: playSourceEngine ?? this.playSourceEngine,
      playSourceEngineAutoStart:
          playSourceEngineAutoStart ?? this.playSourceEngineAutoStart,
      p2pAcknowledged: p2pAcknowledged ?? this.p2pAcknowledged,
      simpleStreamingResolve:
          simpleStreamingResolve ?? this.simpleStreamingResolve,
      builtInEngine: builtInEngine ?? this.builtInEngine,
      builtInEngineIptv: builtInEngineIptv ?? this.builtInEngineIptv,
      streamProviderOrder: streamProviderOrder ?? this.streamProviderOrder,
      disabledStreamProviders:
          disabledStreamProviders ?? this.disabledStreamProviders,
      animeProviderOrder: animeProviderOrder ?? this.animeProviderOrder,
      disabledAnimeProviders:
          disabledAnimeProviders ?? this.disabledAnimeProviders,
      asianDramaProviderOrder:
          asianDramaProviderOrder ?? this.asianDramaProviderOrder,
      disabledAsianDramaProviders:
          disabledAsianDramaProviders ?? this.disabledAsianDramaProviders,
      preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
      preferredSubtitleLang:
          preferredSubtitleLang ?? this.preferredSubtitleLang,
      avoidUnsupportedAudio:
          avoidUnsupportedAudio ?? this.avoidUnsupportedAudio,
      autoNextEpisode: autoNextEpisode ?? this.autoNextEpisode,
      autoSkipIntro: autoSkipIntro ?? this.autoSkipIntro,
      contentWarnings: contentWarnings ?? this.contentWarnings,
      autoPipOnDesktopSwitch:
          autoPipOnDesktopSwitch ?? this.autoPipOnDesktopSwitch,
      playInBackground: playInBackground ?? this.playInBackground,
      iptvEpgEnabled: iptvEpgEnabled ?? this.iptvEpgEnabled,
      iptvLiveMaxHeightLabel:
          iptvLiveMaxHeightLabel ?? this.iptvLiveMaxHeightLabel,
      iptvLiveRecoveryModeLabel:
          iptvLiveRecoveryModeLabel ?? this.iptvLiveRecoveryModeLabel,
      iptvLiveRecoveryStallReopen:
          iptvLiveRecoveryStallReopen ?? this.iptvLiveRecoveryStallReopen,
      iptvMatchDisplayRefresh:
          iptvMatchDisplayRefresh ?? this.iptvMatchDisplayRefresh,
      iptvLiveBufferSecsLabel:
          iptvLiveBufferSecsLabel ?? this.iptvLiveBufferSecsLabel,
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

class SettingsPlaybackNotifier extends AsyncNotifier<SettingsPlaybackSnapshot> {
  @override
  Future<SettingsPlaybackSnapshot> build() async {
    ref.watch(playSourceRevisionProvider);
    ref.watch(accountFeaturesRevisionProvider);
    return _load();
  }

  Future<SettingsPlaybackSnapshot> _load() async {
    final s = SettingsService();
    final preferredAudio = await s.getPreferredAudioLanguage();
    final preferredSubtitle = await s.getPreferredSubtitleLanguage();
    final iptvEpgEnabled = await s.isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = iptvEpgEnabled;
    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final recoveryMode = await s.getIptvLiveRecoveryMode();
    return SettingsPlaybackSnapshot(
      playSourceTorrent: await PlaySourceEffective.torrent(s, lanReady),
      playSourceStremio: await PlaySourceEffective.stremio(s, lanReady),
      playSourceNuvio: await PlaySourceEffective.nuvio(s, lanReady),
      playSourceEngine: await PlaySourceEffective.engine(s, lanReady),
      playSourceEngineAutoStart: await s.isPlaySourceEngineAutoStartEnabled(),
      p2pAcknowledged: await s.isP2pStreamingAcknowledged(),
      simpleStreamingResolve: await s.isSimpleStreamingResolveEnabled(),
      builtInEngine: await s.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.vod,
      ),
      builtInEngineIptv: await s.getBuiltInPlayerEngine(
        context: BuiltInPlayerContext.iptv,
      ),
      streamProviderOrder: await s.getStreamProviderOrder(),
      disabledStreamProviders: await s.getDisabledStreamProviders(),
      animeProviderOrder: await s.getAnimeProviderOrder(),
      disabledAnimeProviders: await s.getDisabledAnimeProviders(),
      asianDramaProviderOrder: await s.getAsianDramaProviderOrder(),
      disabledAsianDramaProviders: await s.getDisabledAsianDramaProviders(),
      preferredAudioLang: kTrackLanguageDisplayNames.contains(preferredAudio)
          ? preferredAudio
          : 'None',
      preferredSubtitleLang:
          kTrackLanguageDisplayNames.contains(preferredSubtitle)
              ? preferredSubtitle
              : 'English',
      avoidUnsupportedAudio: await s.getAvoidUnsupportedAudio(),
      autoNextEpisode: await s.getAutoNextEpisode(),
      autoSkipIntro: await s.getAutoSkipIntro(),
      contentWarnings: await s.getContentWarnings(),
      autoPipOnDesktopSwitch: await s.getAutoPipOnDesktopSwitch(),
      playInBackground: await s.getPlayInBackground(),
      iptvEpgEnabled: iptvEpgEnabled,
      iptvLiveMaxHeightLabel: SettingsService.iptvLiveMaxHeightLabel(
        await s.getIptvLiveMaxHeight(),
      ),
      iptvLiveRecoveryModeLabel: SettingsService.iptvLiveRecoveryModeLabel(
        recoveryMode,
      ),
      iptvLiveRecoveryStallReopen: SettingsService.iptvLiveRecoveryStallReopen(
        recoveryMode,
      ),
      iptvMatchDisplayRefresh: await s.getIptvMatchDisplayRefresh(),
      iptvLiveBufferSecsLabel: SettingsService.iptvLiveBufferSecsLabel(
        await s.getIptvLiveBufferSecs(),
      ),
      maxPlaybackHeightLabel: SettingsService.maxPlaybackHeightLabel(
        await s.getMaxPlaybackHeight(),
      ),
      animeTitleLanguageLabel: SettingsService.animeTitleLanguageLabel(
        await s.getAnimeTitleLanguage(),
      ),
    );
  }

  Future<void> reload() async {
    final previous = state;
    state = const AsyncLoading<SettingsPlaybackSnapshot>().copyWithPrevious(
      previous,
    );
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
    required this.diskCacheGb,
    required this.connectionsLimit,
    required this.enabledProviders,
  });

  final String sortPreference;
  final int diskCacheGb;
  final int connectionsLimit;
  final List<String> enabledProviders;

  SettingsTorrentSnapshot copyWith({
    String? sortPreference,
    int? diskCacheGb,
    int? connectionsLimit,
    List<String>? enabledProviders,
  }) {
    return SettingsTorrentSnapshot(
      sortPreference: sortPreference ?? this.sortPreference,
      diskCacheGb: diskCacheGb ?? this.diskCacheGb,
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
    void onPluginsChanged() => ref.invalidateSelf();
    PluginRegistry.changeNotifier.addListener(onPluginsChanged);
    ref.onDispose(
      () => PluginRegistry.changeNotifier.removeListener(onPluginsChanged),
    );

    await syncTorrentSearchCatalog();
    final s = SettingsService();
    return SettingsTorrentSnapshot(
      sortPreference: await s.getSortPreference(),
      diskCacheGb: await s.getTorrentDiskCacheGb(),
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
    final previous = state;
    state = const AsyncLoading<SettingsDebridSnapshot>().copyWithPrevious(
      previous,
    );
    state = await AsyncValue.guard(_load);
  }

  void patch(SettingsDebridSnapshot Function(SettingsDebridSnapshot) fn) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(fn(cur));
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsNavigationSnapshot &&
        other.defaultTab == defaultTab &&
        listEquals(other.visible, visible) &&
        listEquals(other.order, order);
  }

  @override
  int get hashCode =>
      Object.hash(defaultTab, Object.hashAll(visible), Object.hashAll(order));
}

final settingsNavigationProvider =
    AsyncNotifierProvider<
      SettingsNavigationNotifier,
      SettingsNavigationSnapshot
    >(SettingsNavigationNotifier.new);

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
        .where((id) => !archivedNavIds.contains(id))
        .where(PluginNavRegistry.isContributed)
        .toList();
    navVisible.removeWhere(archivedNavIds.contains);
    navVisible.removeWhere((id) => !PluginNavRegistry.isContributed(id));
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
    final previous = state;
    state = const AsyncLoading<SettingsNavigationSnapshot>().copyWithPrevious(
      previous,
    );
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
    final previous = state;
    state = const AsyncLoading<SettingsIndexerSnapshot>().copyWithPrevious(
      previous,
    );
    state = await AsyncValue.guard(build);
  }
}

final nuvioAddonsProvider =
    AsyncNotifierProvider<NuvioAddonsNotifier, List<NuvioAddon>>(
      NuvioAddonsNotifier.new,
    );

final enginePacksProvider =
    AsyncNotifierProvider<EnginePacksNotifier, List<EnginePack>>(
      EnginePacksNotifier.new,
    );

class EnginePacksNotifier extends AsyncNotifier<List<EnginePack>> {
  @override
  Future<List<EnginePack>> build() async {
    final n = EngineService.changeNotifier;
    void listener() => ref.invalidateSelf();
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return EngineService.instance.listUserPacks();
  }

  Future<void> reload() async {
    final previous = state;
    state = const AsyncLoading<List<EnginePack>>().copyWithPrevious(previous);
    state = await AsyncValue.guard(
      () => EngineService.instance.listUserPacks(),
    );
  }
}

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
    final previous = state;
    state = const AsyncLoading<List<NuvioAddon>>().copyWithPrevious(previous);
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

final simklStatusProvider = FutureProvider.autoDispose<TrackerAccountStatus>((
  ref,
) async {
  final simkl = SimklService();
  final loggedIn = await simkl.isLoggedIn();
  if (!loggedIn) return const TrackerAccountStatus(loggedIn: false);
  final profile = await simkl.getUserProfile();
  final name =
      profile?['user']?['name']?.toString() ?? profile?['name']?.toString();
  return TrackerAccountStatus(loggedIn: true, username: name);
});

final mdblistStatusProvider = FutureProvider.autoDispose<TrackerAccountStatus>((
  ref,
) async {
  final mdblist = MdblistService();
  final configured = await mdblist.isConfigured();
  if (!configured) return const TrackerAccountStatus(loggedIn: false);
  final key = await mdblist.getApiKey();
  final info = await mdblist.getUserInfo();
  final name = info?['name']?.toString();
  return TrackerAccountStatus(loggedIn: true, username: name, apiKey: key);
});

// ── About telemetry / keychain ─────────────────────────────────────────────

final crashReportingEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  return SettingsService().isCrashReportingEnabled();
});

final productAnalyticsEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  return SettingsService().isProductAnalyticsEnabled();
});

final macOsKeychainEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  await ForjaPlatformSecureStore.ensureConsentLoaded();
  return ForjaPlatformSecureStore.usesKeychain;
});
