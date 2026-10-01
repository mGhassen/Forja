import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';

final simklServiceProvider = Provider<SimklService>((ref) => SimklService());

@immutable
class ExternalListsGate {
  const ExternalListsGate({required this.simklLoggedIn});

  final bool simklLoggedIn;
}

final externalListsGateProvider = FutureProvider.autoDispose<ExternalListsGate>(
  (ref) async {
    final simkl = ref.watch(simklServiceProvider);
    return ExternalListsGate(simklLoggedIn: await simkl.isLoggedIn());
  },
);

final simklWatchlistProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      status,
    ) async {
      final gate = await ref.watch(externalListsGateProvider.future);
      if (!gate.simklLoggedIn) return const [];
      return ref.watch(simklServiceProvider).getWatchlistStatus(status);
    });
