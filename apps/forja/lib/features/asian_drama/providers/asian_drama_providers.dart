import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';

final kissKhServiceProvider = Provider<KissKhService>((ref) => KissKhService());

/// Primary KissKH hub feed load.
final asianDramaFeedProvider =
    FutureProvider.autoDispose<KdramaHomeFeed>((ref) async {
  final service = ref.watch(kissKhServiceProvider);
  return service.getHome();
});

class AsianDramaDetailsBundle {
  const AsianDramaDetailsBundle({
    required this.details,
    required this.progress,
  });

  final KdramaDetails details;
  final Map<String, dynamic>? progress;
}

/// KissKH details + watch progress for one drama id.
final asianDramaDetailsProvider = FutureProvider.autoDispose
    .family<AsianDramaDetailsBundle, int>((ref, dramaId) async {
  final service = ref.watch(kissKhServiceProvider);
  final results = await Future.wait([
    service.getDetails(dramaId),
    service.getProgress(dramaId),
  ]);
  return AsianDramaDetailsBundle(
    details: results[0] as KdramaDetails,
    progress: results[1] as Map<String, dynamic>?,
  );
});
