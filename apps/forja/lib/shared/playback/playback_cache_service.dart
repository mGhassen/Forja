import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:rust/rust.dart';

/// User-triggered playback cache reset (settings).
abstract final class PlaybackCacheService {
  static Future<void> clearAll() async {
    await WebstreamingStreamCache.clearAll();
    if (PlatformPlayback.capabilities.localTorrentEngine) {
      try {
        await TorrentStreamService().clearCacheDirectory();
      } catch (_) {
        // Torrent engine may be idle; disk clear is best-effort.
      }
    }
  }
}
