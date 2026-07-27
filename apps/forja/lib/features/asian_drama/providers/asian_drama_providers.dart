import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';

final kissKhServiceProvider = Provider<KissKhService>((ref) => KissKhService());

/// Primary KissKH hub feed load.
final asianDramaFeedProvider =
    FutureProvider.autoDispose<KdramaHomeFeed>((ref) async {
  final service = ref.watch(kissKhServiceProvider);
  return service.getHome();
});
