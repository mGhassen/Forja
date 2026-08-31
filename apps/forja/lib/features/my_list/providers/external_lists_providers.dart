import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';

final mdblistServiceProvider = Provider<MdblistService>(
  (ref) => MdblistService(),
);
final simklServiceProvider = Provider<SimklService>((ref) => SimklService());

@immutable
class ExternalListsGate {
  const ExternalListsGate({
    required this.mdblistConfigured,
    required this.simklLoggedIn,
  });

  final bool mdblistConfigured;
  final bool simklLoggedIn;
}

final externalListsGateProvider = FutureProvider.autoDispose<ExternalListsGate>(
  (ref) async {
    final mdblist = ref.watch(mdblistServiceProvider);
    final simkl = ref.watch(simklServiceProvider);
    return ExternalListsGate(
      mdblistConfigured: await mdblist.isConfigured(),
      simklLoggedIn: await simkl.isLoggedIn(),
    );
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

final mdblistUserListsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final gate = await ref.watch(externalListsGateProvider.future);
      if (!gate.mdblistConfigured) return const [];
      return ref.watch(mdblistServiceProvider).getUserLists();
    });

final mdblistTopListsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final gate = await ref.watch(externalListsGateProvider.future);
      if (!gate.mdblistConfigured) return const [];
      return ref.watch(mdblistServiceProvider).getTopLists();
    });
