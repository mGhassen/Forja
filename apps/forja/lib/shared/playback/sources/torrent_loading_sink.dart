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

TorrentLoadingStatus initialTorrentResolveStatus({String? debridLabel}) {
  return torrentLoadingStatusGeneric(
    playbackResolveLabel(debridLabel: debridLabel),
    hint: playbackSourceHint(debridLabel: debridLabel),
  );
}

TorrentLoadingStatus initialStremioTorrentResolveStatus({
  required PlaybackProfile profile,
  String? debridLabel,
}) {
  return torrentLoadingStatusGeneric(
    stremioResolveLoadingMessage(
      profile: profile,
      debridLabel: debridLabel,
    ),
    hint: playbackSourceHint(debridLabel: debridLabel),
  );
}
