import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime_arabic/catalog/anime_arabic_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/services/app_update_download_storage.dart';
import 'package:forja/shared/services/app_update_download_service.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:forja/shared/utils/webview_cleanup.dart';
import 'package:rust/rust.dart';

/// Settings-driven clears for caches and local viewing data.
///
/// Does **not** touch tokens, My List, provider order prefs, or account keys.
abstract final class SettingsDataCleaner {
  /// Webstreaming + anime stream extracts + torrent temp + 111477 seek cache.
  static Future<void> clearStreamCaches() async {
    await WebstreamingStreamCache.clearAll();
    await AnimeService().clearStreamCaches();
    if (PlatformPlayback.capabilities.localTorrentEngine) {
      try {
        await TorrentStreamService().clearCacheDirectory();
      } catch (_) {}
    }
    try {
      await purge111477Cache();
    } catch (_) {}
  }

  /// Poster disk cache + in-memory images + WebView extract caches.
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

  /// In-app update installers saved on desktop (.dmg / .exe / AppImage).
  static Future<void> clearDownloadedUpdates() async {
    if (AppUpdateDownloadService.instance.isDownloading) {
      throw StateError('An update is currently downloading');
    }
    await AppUpdateDownloadStorage.clearDownloadedFiles();
  }

  /// Learned provider reliability (Settings Score / Auto nudge).
  static Future<void> clearProviderScores() async {
    await ProviderScoreMemory.clearAll();
    ProviderScoreProbeSync.clearSession();
  }

  /// Continue watching across Home + Anime + Asian Drama + Anime Arabic.
  static Future<void> clearContinueWatching() async {
    await WatchHistoryService().clearAll();
    await AnimeService().clearWatchHistory();
    await KissKhService().clearWatchHistory();
    await AnimeArabicService().clearWatchHistory();
  }

  /// Local episode "watched" checkmarks only (Trakt/Simkl cloud unchanged).
  static Future<void> clearWatchedEpisodes() async {
    await EpisodeWatchedService().clearAll();
  }
}
