import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opaque catalog chip (`all` / plugin id / `stremio:…`) for the live feed.
final kitFeedCatalogFilterProvider = StateProvider<String>((ref) => 'all');

/// Pack horizon menu token (opaque). Empty until the pack default / user pick.
final kitFeedHorizonPrefProvider = StateProvider<String>((ref) => '');

/// Pack View menu (`list` / `cards`) **per hub plugin**. Empty = use `kit.list.style`.
/// Keyed so Live Sports View never changes My List / Home grid.
final kitListStyleOverrideProvider =
    StateProvider.family<String, String>((ref, pluginId) => '');
