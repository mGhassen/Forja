import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';

/// Sources panel list-fetch busy must stay on [playerSourcesSessionProvider].
/// Driving [playerResolveStatusProvider] paints player-center "Loading sources…".
void main() {
  test('panel session busy leaves resolve status idle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(playerSourcesSessionProvider.notifier).mutate((s) {
      s.isSearchingTorrents = true;
      s.isFetchingStremio = true;
      s.isFetchingNuvio = true;
    });

    final session =
        container.read(playerSourcesSessionProvider.notifier).session;
    expect(session.isBusy, isTrue);
    expect(
      container.read(playerResolveStatusProvider).status,
      PlayerResolveStatus.idle,
    );
  });

  test('resolve loading is only via PlayerResolveNotifier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(playerResolveStatusProvider.notifier).setLoading('vidlink');
    expect(
      container.read(playerResolveStatusProvider).status,
      PlayerResolveStatus.loading,
    );
    expect(container.read(playerResolveStatusProvider).providerId, 'vidlink');
  });
}
