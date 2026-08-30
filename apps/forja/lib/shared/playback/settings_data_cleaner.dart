import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:forja/features/anime_arabic/catalog/anime_arabic_service.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/playback/anime_playback_embeds.dart';
import 'package:forja/shared/services/app_update_download_storage.dart';
import 'package:forja/shared/services/app_update_download_service.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/utils/webview_cleanup.dart';
import 'package:rust/rust.dart';

/// Settings-driven clears for caches and local viewing data.
abstract final class SettingsDataCleaner {
  static Future<void> clearStreamCaches() async {
    await clearLegacyAnimeStreamPrefs();
    if (PlatformPlayback.capabilities.localTorrentEngine) {
      try {
        await TorrentStreamService().clearCacheDirectory();
      } catch (_) {}
    }
    try {
      await purge111477Cache();
    } catch (_) {}
  }

  static Future<void> clearIptvPortalCaches() async {
    await IptvAliveStore.clearAll();
    await IptvChannelResultsStore.clearAll();
    await IptvCatalogDiskStore.clearAll();
  }

  static Future<void> clearImageAndWebViewCaches() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    try {
      await WebViewCleanup.cleanupWebView2Cache();
    } catch (_) {}
  }

  static Future<void> clearDownloadedUpdates() async {
    final download = AppUpdateDownloadService.instance;
    if (download.isDownloading) {
      throw StateError('An update is currently downloading');
    }
    final trackedPath = download.state.value.filePath;
    if (trackedPath != null) {
      try {
        final tracked = File(trackedPath);
        if (await tracked.exists()) {
          await tracked.delete();
        }
      } catch (_) {}
    }
    await AppUpdateDownloadStorage.clearDownloadedFiles();
    download.resetAfterCacheClear();
  }

  static Future<void> clearProviderScores() async {
    await ProviderScoreMemory.clearAll();
    ProviderScoreProbeSync.clearSession();
  }

  static Future<void> clearContinueWatching() async {
    await WatchHistoryService().clearAll();
    final plugins = await PluginNavRegistry.listHubPlugins(requireEnabled: false);
    for (final plugin in plugins) {
      await CatalogWatchHistory.clear(plugin.id);
    }
    await AnimeArabicService().clearWatchHistory();
  }

  static Future<void> clearWatchedEpisodes() async {
    await EpisodeWatchedService().clearAll();
  }
}
