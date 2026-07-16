import 'dart:async';

import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_store.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:rust/rust.dart';

/// Export/import sync domains between local stores and Supabase `user_settings`.
class SyncDomainBridge {
  SyncDomainBridge._();
  static final SyncDomainBridge instance = SyncDomainBridge._();

  static const _domainIptv = 'iptv';
  static const _domainPreferences = 'preferences';
  static const _domainProviders = 'providers';
  static const _domainStremio = 'stremio';

  final _settings = SettingsService();
  final Map<String, Timer> _pushTimers = {};

  /// Persist the current profile before changing the device-local selection.
  Future<void> prepareProfileSwitch() async {
    for (final timer in _pushTimers.values) {
      timer.cancel();
    }
    _pushTimers.clear();
    await pushAllLocal();
  }

  Future<void> pullAndMergeAll() async {
    if (!SyncService.instance.isSignedIn) return;
    final remote = await SyncService.instance.pullSettings();

    const domains = [
      _domainIptv,
      _domainPreferences,
      _domainProviders,
      _domainStremio,
    ];

    if (remote == null || remote.isEmpty) {
      await pushAllLocal();
      return;
    }

    for (final domain in domains) {
      final wrapper = remote[domain];
      if (wrapper is Map && wrapper.containsKey('payload')) {
        await _applyDomain(
          domain,
          Map<String, dynamic>.from(wrapper['payload'] as Map? ?? const {}),
        );
      } else {
        await _pushDomainNow(domain);
      }
    }
  }

  Future<void> pushAllLocal() async {
    if (!SyncService.instance.isSignedIn) return;
    await SyncService.instance.pushSettings({
      _domainIptv: await exportIptv(),
      _domainPreferences: await exportPreferences(),
      _domainProviders: await exportProviders(),
      _domainStremio: await exportStremio(),
    });
  }

  void schedulePush(String domain) {
    if (!SyncService.instance.isSignedIn) return;
    _pushTimers[domain]?.cancel();
    _pushTimers[domain] = Timer(const Duration(seconds: 3), () {
      unawaited(_pushDomainNow(domain));
    });
  }

  Future<void> _pushDomainNow(String domain) async {
    if (!SyncService.instance.isSignedIn) return;
    final payload = switch (domain) {
      _domainIptv => await exportIptv(),
      _domainPreferences => await exportPreferences(),
      _domainProviders => await exportProviders(),
      _domainStremio => await exportStremio(),
      _ => null,
    };
    if (payload == null) return;
    await SyncService.instance.pushDomain(domain, payload);
  }

  Future<void> _applyDomain(String domain, Map<String, dynamic> payload) async {
    switch (domain) {
      case _domainIptv:
        await importIptv(payload);
      case _domainPreferences:
        await importPreferences(payload);
      case _domainProviders:
        await importProviders(payload);
      case _domainStremio:
        await importStremio(payload);
    }
  }

  Future<Map<String, dynamic>> exportIptv() async {
    final portals = await IptvStore.load();
    final favorites = await IptvStore.loadFavorites();
    final m3u = await M3uStore.loadAll();
    return {
      'portals': portals
          .map(
            (v) => {
              'url': v.portal.url,
              'username': v.portal.username,
              'password': v.portal.password,
              'source': v.portal.source,
              'label': v.label,
              'name': v.name,
              'expiry': v.expiry,
              'max': v.maxConnections,
              'active': v.activeConnections,
            },
          )
          .toList(),
      'favoriteKeys': favorites.toList(),
      'm3uPlaylists': m3u.map((p) => p.toJson()).toList(),
    };
  }

  Future<void> importIptv(Map<String, dynamic> payload) async {
    final rawPortals = payload['portals'] as List? ?? const [];
    final portals = rawPortals.map((e) {
      final o = Map<String, dynamic>.from(e as Map);
      return VerifiedPortal(
        portal: IptvPortal(
          url: o['url'] as String? ?? '',
          username: o['username'] as String? ?? '',
          password: o['password'] as String? ?? '',
          source: o['source'] as String? ?? '',
        ),
        label: o['label'] as String? ?? '',
        name: o['name'] as String? ?? '',
        expiry: o['expiry'] as String? ?? '',
        maxConnections: o['max'] as String? ?? '1',
        activeConnections: o['active'] as String? ?? '0',
      );
    }).toList();
    await IptvStore.save(portals);

    final favRaw = payload['favoriteKeys'] as List? ?? const [];
    await IptvStore.saveFavorites(
      favRaw.map((e) => e.toString()).toSet(),
    );

    final m3uRaw = payload['m3uPlaylists'] as List? ?? const [];
    final playlists = m3uRaw
        .map((e) => M3uPlaylist.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await M3uStore.saveAll(playlists);
  }

  Future<Map<String, dynamic>> exportPreferences() async {
    return {
      'play_source_torrent_enabled':
          await _settings.isPlaySourceTorrentEnabled(),
      'play_source_stremio_enabled': await _settings.isPlaySourceStremioEnabled(),
      'play_source_webstreaming_enabled':
          await _settings.isPlaySourceWebstreamingEnabled(),
      'preferred_audio_lang': await _settings.getPreferredAudioLanguage(),
      'avoid_unsupported_audio': await _settings.getAvoidUnsupportedAudio(),
      'auto_next_episode': await _settings.getAutoNextEpisode(),
      'auto_skip_intro': await _settings.getAutoSkipIntro(),
      'iptv_epg_enabled': await _settings.isIptvEpgEnabled(),
      'max_playback_height': await _settings.getMaxPlaybackHeight(),
    };
  }

  Future<void> importPreferences(Map<String, dynamic> payload) async {
    if (payload.containsKey('play_source_torrent_enabled')) {
      await _settings.setPlaySourceTorrentEnabled(
        payload['play_source_torrent_enabled'] as bool,
      );
    }
    if (payload.containsKey('play_source_stremio_enabled')) {
      await _settings.setPlaySourceStremioEnabled(
        payload['play_source_stremio_enabled'] as bool,
      );
    }
    if (payload.containsKey('play_source_webstreaming_enabled')) {
      await _settings.setPlaySourceWebstreamingEnabled(
        payload['play_source_webstreaming_enabled'] as bool,
      );
    }
    if (payload.containsKey('preferred_audio_lang')) {
      await _settings.setPreferredAudioLanguage(
        payload['preferred_audio_lang'] as String,
      );
    }
    if (payload.containsKey('avoid_unsupported_audio')) {
      await _settings.setAvoidUnsupportedAudio(
        payload['avoid_unsupported_audio'] as bool,
      );
    }
    if (payload.containsKey('auto_next_episode')) {
      await _settings.setAutoNextEpisode(payload['auto_next_episode'] as bool);
    }
    if (payload.containsKey('auto_skip_intro')) {
      await _settings.setAutoSkipIntro(payload['auto_skip_intro'] as bool);
    }
    if (payload.containsKey('iptv_epg_enabled')) {
      await _settings.setIptvEpgEnabled(payload['iptv_epg_enabled'] as bool);
    }
    if (payload.containsKey('max_playback_height')) {
      await _settings.setMaxPlaybackHeight(
        (payload['max_playback_height'] as num).toInt(),
      );
    }
  }

  Future<Map<String, dynamic>> exportProviders() async {
    return {
      'stream_provider_order': await _settings.getStreamProviderOrder(),
      'anime_provider_order': await _settings.getAnimeProviderOrder(),
      'asian_drama_provider_order':
          await _settings.getAsianDramaProviderOrder(),
    };
  }

  Future<void> importProviders(Map<String, dynamic> payload) async {
    if (payload['stream_provider_order'] is List) {
      await _settings.setStreamProviderOrder(
        (payload['stream_provider_order'] as List).cast<String>(),
      );
    }
    if (payload['anime_provider_order'] is List) {
      await _settings.setAnimeProviderOrder(
        (payload['anime_provider_order'] as List).cast<String>(),
      );
    }
    if (payload['asian_drama_provider_order'] is List) {
      await _settings.setAsianDramaProviderOrder(
        (payload['asian_drama_provider_order'] as List).cast<String>(),
      );
    }
  }

  Future<Map<String, dynamic>> exportStremio() async {
    return {'addons': await _settings.getStremioAddons()};
  }

  Future<void> importStremio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final remoteUrls = <String>{
      for (final raw in addons)
        if ((raw as Map)['baseUrl'] is String) (raw)['baseUrl'] as String,
    };
    final current = await _settings.getStremioAddons();
    for (final addon in current) {
      final baseUrl = addon['baseUrl'] as String? ?? '';
      if (baseUrl.isNotEmpty && !remoteUrls.contains(baseUrl)) {
        await _settings.removeStremioAddon(baseUrl);
      }
    }
    for (final raw in addons) {
      final addon = Map<String, dynamic>.from(raw as Map);
      final baseUrl = addon['baseUrl'] as String? ?? '';
      if (baseUrl.isEmpty) continue;
      await _settings.saveStremioAddon(addon);
    }
  }
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

void schedulePreferencesSyncPush() => SyncDomainBridge.instance
    .schedulePush(SyncDomainBridge._domainPreferences);

void scheduleProvidersSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainProviders);

void scheduleStremioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainStremio);
