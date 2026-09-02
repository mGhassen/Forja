import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// Wire [resolveMagnetForPlayback] / [resolveStremioStream] into a notifier.
void Function(TorrentLoadingStatus status) torrentLoadingStatusSink(
  ValueNotifier<TorrentLoadingStatus?> notifier, {
  bool Function()? cancelled,
}) {
  return (TorrentLoadingStatus status) {
    if (cancelled?.call() ?? false) return;
    notifier.value = status;
  };
}

TorrentLoadingStatus initialTorrentResolveStatus({
  required bool useDebrid,
  required String debridService,
}) {
  final localEngine = !useDebrid || debridService == 'None';
  return torrentLoadingStatusGeneric(
    playbackResolveLabel(useDebrid: useDebrid, debridService: debridService),
    hint: localEngine
        ? 'Playback opens once ~256 KB from the start of the file is ready.'
        : playbackSourceHint(useDebrid: useDebrid, debridService: debridService),
  );
}

TorrentLoadingStatus initialStremioTorrentResolveStatus({
  required PlaybackProfile profile,
  required bool useDebrid,
  required String debridService,
}) {
  final localEngine = !useDebrid || debridService == 'None';
  return torrentLoadingStatusGeneric(
    stremioResolveLoadingMessage(
      profile: profile,
      useDebrid: useDebrid,
      debridService: debridService,
    ),
    hint: localEngine
        ? 'Playback opens once ~256 KB from the start of the file is ready.'
        : playbackSourceHint(useDebrid: useDebrid, debridService: debridService),
  );
}
