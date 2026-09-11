import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opaque catalog chip (`all` / plugin id / `stremio:…`) for the live feed.
final kitFeedCatalogFilterProvider = StateProvider<String>((ref) => 'all');

/// Pack horizon menu token (`airing|1h`, `both|24h`, …).
final kitFeedHorizonPrefProvider = StateProvider<String>((ref) => 'airing|1h');

/// Pack View menu (`list` / `cards`). Empty = use `kit.list.style`.
final kitListStyleOverrideProvider = StateProvider<String>((ref) => '');
