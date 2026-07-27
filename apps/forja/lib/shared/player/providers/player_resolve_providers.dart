import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// For [StatefulWidget] players (desktop/mobile) that are not yet
/// [ConsumerStatefulWidget] — reads the same autoDispose notifier.
PlayerResolveNotifier readPlayerResolve(BuildContext context) {
  return ProviderScope.containerOf(context)
      .read(playerResolveStatusProvider.notifier);
}
