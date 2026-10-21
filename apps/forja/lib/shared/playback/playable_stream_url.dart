import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:rust/rust.dart';

export 'package:rust/rust.dart'
    show
        PlayableStreamFileRoots,
        UnsupportedStreamAddressException,
        assertPlayableStreamUrl,
        isLoopbackStreamUrl,
        isPlayableStreamUrl;

/// Registers the downloads folder as the only `file://` root players accept.
///
/// Called at boot and after the user picks a custom downloads folder. Safe to
/// call repeatedly; keeps the previous root when resolution fails.
Future<void> registerDownloadsAsPlayableFileRoot() async {
  try {
    final root = await DownloadPathHelper.getDownloadsDirectoryPath();
    if (root.trim().isEmpty) return;
    PlayableStreamFileRoots.add(root);
  } catch (_) {
    // Offline library unavailable on this device — leave roots as they are.
  }
}
