import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Source-list / server resolve lifecycle for built-in players.
///
/// **R47-A20:** High-frequency playback ticks (position, buffered, volume) stay
/// on local [ValueNotifier] + [ValueListenableBuilder] in player screens — not
/// migrated to Riverpod.
enum PlayerResolveStatus { idle, loading, ready, error }

@immutable
class PlayerResolveState {
  const PlayerResolveState({
    this.status = PlayerResolveStatus.idle,
    this.providerId,
    this.message,
  });

  final PlayerResolveStatus status;
  final String? providerId;
  final String? message;

  PlayerResolveState copyWith({
    PlayerResolveStatus? status,
    String? providerId,
    String? message,
  }) {
    return PlayerResolveState(
      status: status ?? this.status,
      providerId: providerId ?? this.providerId,
      message: message ?? this.message,
    );
  }
}

class PlayerResolveNotifier extends AutoDisposeNotifier<PlayerResolveState> {
  @override
  PlayerResolveState build() => const PlayerResolveState();

  void setIdle() => state = const PlayerResolveState();

  void setLoading(String providerId) {
    state = PlayerResolveState(
      status: PlayerResolveStatus.loading,
      providerId: providerId,
    );
  }

  void setReady() {
    state = state.copyWith(status: PlayerResolveStatus.ready);
  }

  void setError(String message) {
    state = PlayerResolveState(
      status: PlayerResolveStatus.error,
      providerId: state.providerId,
      message: message,
    );
  }
}

/// Per-player-session resolve status (autoDispose when the player route pops).
final playerResolveStatusProvider =
    NotifierProvider.autoDispose<PlayerResolveNotifier, PlayerResolveState>(
  PlayerResolveNotifier.new,
);

/// In-player Sources panel async bag (torrent / Stremio / Nuvio fetch flags).
///
/// Position/buffered ticks stay on [ValueNotifier] (R47-A20). Panel chrome
/// filters stay local to [PlayerSourcesPanel].
class PlayerSourcesSession {
  bool isSearchingTorrents = false;
  bool isFetchingStremio = false;
  bool isFetchingNuvio = false;
  List<TorrentResult> torrents = [];
  List<dynamic> stremioStreams = [];
  List<Map<String, dynamic>> nuvioStreams = [];
  String? errorMessage;

  bool get isBusy =>
      isSearchingTorrents || isFetchingStremio || isFetchingNuvio;
}

class PlayerSourcesSessionNotifier extends AutoDisposeNotifier<int> {
  late final PlayerSourcesSession session;

  @override
  int build() {
    session = PlayerSourcesSession();
    return 0;
  }

  void bump() => state++;

  void mutate(void Function(PlayerSourcesSession s) fn) {
    fn(session);
    bump();
  }
}

final playerSourcesSessionProvider =
    NotifierProvider.autoDispose<PlayerSourcesSessionNotifier, int>(
  PlayerSourcesSessionNotifier.new,
);

PlayerSourcesSession watchPlayerSourcesSession(WidgetRef ref) {
  ref.watch(playerSourcesSessionProvider);
  return ref.read(playerSourcesSessionProvider.notifier).session;
}

/// For legacy call sites that are not yet [ConsumerStatefulWidget].
PlayerResolveNotifier readPlayerResolve(BuildContext context) {
  return ProviderScope.containerOf(context)
      .read(playerResolveStatusProvider.notifier);
}
