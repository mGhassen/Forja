import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';

final traktServiceProvider = Provider<TraktService>((ref) => TraktService());
final mdblistServiceProvider = Provider<MdblistService>((ref) => MdblistService());

@immutable
class ExternalListsGate {
  const ExternalListsGate({
    required this.traktLoggedIn,
    required this.mdblistConfigured,
  });

  final bool traktLoggedIn;
  final bool mdblistConfigured;
}

final externalListsGateProvider =
    FutureProvider.autoDispose<ExternalListsGate>((ref) async {
  final trakt = ref.watch(traktServiceProvider);
  final mdblist = ref.watch(mdblistServiceProvider);
  return ExternalListsGate(
    traktLoggedIn: await trakt.isLoggedIn(),
    mdblistConfigured: await mdblist.isConfigured(),
  );
});

final traktUserListsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gate = await ref.watch(externalListsGateProvider.future);
  if (!gate.traktLoggedIn) return const [];
  return ref.watch(traktServiceProvider).getUserLists();
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
