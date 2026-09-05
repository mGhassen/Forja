import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

export 'package:forja/shared/playback/torrent_loading_sink.dart';

enum StreamLoadingKind { direct, torrent }

/// Active fullscreen stream-loading overlay (at most one).
StreamLoadingSession? _activeStreamLoadingSession;

bool get isStreamLoadingOverlayActive => _activeStreamLoadingSession != null;

/// Holds notifiers + dialog context for one resolve wait.
class StreamLoadingSession {
  StreamLoadingSession({
    required this.movie,
    required this.kindNotifier,
    required this.messageNotifier,
    required this.torrentStatusNotifier,
    required this.probeNotifier,
    required this.fadeOutNotifier,
    required this.failureNotifier,
    this.subtitle,
    this.recheckBanner,
    this.showReloadButton = false,
    this.reloadLabel = 'Search again',
    this.reloadHint = 'That saved link is no longer working',
    this.onReload,
    this.onManualCheckProvider,
  });

  final Movie movie;
  final ValueNotifier<StreamLoadingKind> kindNotifier;
  final ValueNotifier<String> messageNotifier;
  final ValueNotifier<TorrentLoadingStatus?> torrentStatusNotifier;
  final ValueNotifier<List<StreamProviderProbe>> probeNotifier;
  final ValueNotifier<bool> fadeOutNotifier;
  final ValueNotifier<ResolveFailure?> failureNotifier;
  final String? subtitle;
  final String? recheckBanner;
  final bool showReloadButton;
  final String reloadLabel;
  final String reloadHint;
  final VoidCallback? onReload;
  final ValueChanged<String>? onManualCheckProvider;

  BuildContext? dialogContext;
  var cancelled = false;

  void setKind(StreamLoadingKind kind) => kindNotifier.value = kind;

  List<ChangeNotifier> get notifiers => [
        kindNotifier,
        messageNotifier,
        torrentStatusNotifier,
        probeNotifier,
        fadeOutNotifier,
        failureNotifier,
      ];
}

/// Opens the cinematic fullscreen loading overlay.
StreamLoadingSession showStreamLoadingOverlay(
  BuildContext context, {
  required Movie movie,
  StreamLoadingKind kind = StreamLoadingKind.direct,
  String initialMessage = 'Finding servers…',
  TorrentLoadingStatus? initialTorrentStatus,
  String? subtitle,
  String? recheckBanner,
  bool showReloadButton = false,
  String reloadLabel = 'Search again',
  String reloadHint = 'That saved link is no longer working',
  VoidCallback? onReload,
  VoidCallback? onCancel,
  ValueChanged<String>? onManualCheckProvider,
}) {
  final session = StreamLoadingSession(
    movie: movie,
    kindNotifier: ValueNotifier(kind),
    messageNotifier: ValueNotifier(initialMessage),
    torrentStatusNotifier: ValueNotifier(initialTorrentStatus),
    probeNotifier: ValueNotifier(const []),
    fadeOutNotifier: ValueNotifier(false),
    failureNotifier: ValueNotifier(null),
    subtitle: subtitle,
    recheckBanner: recheckBanner,
    showReloadButton: showReloadButton,
    reloadLabel: reloadLabel,
    reloadHint: reloadHint,
    onReload: onReload,
    onManualCheckProvider: onManualCheckProvider,
  );

  _activeStreamLoadingSession = session;

  void cancel() {
    session.cancelled = true;
    onCancel?.call();
    dismissStreamLoading(session);
  }

  showLoadingOverlayDialog(
    context,
    builder: (dialogContext) {
      session.dialogContext = dialogContext;
      return LoadingOverlay(
        movie: movie,
        kindNotifier: session.kindNotifier,
        messageNotifier: session.messageNotifier,
        torrentStatusNotifier: session.torrentStatusNotifier,
        providerProbesNotifier: session.probeNotifier,
        fadeOutNotifier: session.fadeOutNotifier,
        failureNotifier: session.failureNotifier,
        subtitle: subtitle,
        recheckBanner: recheckBanner,
        showReloadButton: showReloadButton,
        reloadLabel: reloadLabel,
        reloadHint: reloadHint,
        onReload: onReload,
        onCancel: cancel,
        onManualCheckProvider: onManualCheckProvider,
      );
    },
  );

  return session;
}

void dismissStreamLoading(StreamLoadingSession session) {
  if (identical(_activeStreamLoadingSession, session)) {
    _activeStreamLoadingSession = null;
  }
  final ctx = session.dialogContext;
  session.dialogContext = null;
  if (ctx != null && ctx.mounted) {
    dismissLoadingOverlayRoute(ctx);
  }
}

void disposeStreamLoadingNotifiers(StreamLoadingSession session) {
  disposeLoadingOverlayNotifiers(session.notifiers);
}

void finishStreamLoadingSession(StreamLoadingSession session) {
  if (identical(_activeStreamLoadingSession, session)) {
    _activeStreamLoadingSession = null;
  }
  session.dialogContext = null;
  disposeStreamLoadingNotifiers(session);
}

Movie movieForStreamLoading({Movie? movie, required String title}) {
  return movie ??
      Movie(
        id: 0,
        title: title,
        posterPath: '',
        backdropPath: '',
        voteAverage: 0,
        releaseDate: '',
      );
}

Future<T?> crossfadeStreamLoadingToPlayer<T>({
  required StreamLoadingSession session,
  Future<void> Function()? beforeFade,
  required Future<T?> Function() openPlayer,
}) async {
  final ctx = session.dialogContext;
  if (ctx != null && ctx.mounted) {
    return crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: ctx,
      fadeOutNotifier: session.fadeOutNotifier,
      beforeFade: beforeFade,
      openPlayer: openPlayer,
    );
  }
  return openPlayer();
}

Future<T?> runWithStreamLoadingOverlay<T>({
  required BuildContext context,
  required Movie movie,
  StreamLoadingKind kind = StreamLoadingKind.direct,
  String initialMessage = 'Finding servers…',
  TorrentLoadingStatus? initialTorrentStatus,
  String? subtitle,
  VoidCallback? onCancel,
  required Future<T?> Function(StreamLoadingSession session) action,
}) async {
  final session = showStreamLoadingOverlay(
    context,
    movie: movie,
    kind: kind,
    initialMessage: initialMessage,
    initialTorrentStatus: initialTorrentStatus,
    subtitle: subtitle,
    onCancel: onCancel,
  );
  await Future<void>.delayed(Duration.zero);
  try {
    if (session.cancelled || !context.mounted) return null;
    return await action(session);
  } finally {
    dismissStreamLoading(session);
    disposeStreamLoadingNotifiers(session);
  }
}
