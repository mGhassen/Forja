import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:rust/rust.dart';

/// Redux-style async store for installed Stremio addons.
///
/// - [AsyncLoading] while reading cache / after invalidate
/// - [AsyncData] with the current list
/// - Rebuilds whenever [addonRevisionProvider] bumps (local install/remove,
///   cloud import into the device cache, etc.)
final stremioAddonsProvider =
    AsyncNotifierProvider<StremioAddonsNotifier, List<Map<String, dynamic>>>(
  StremioAddonsNotifier.new,
);

class StremioAddonsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Any SettingsService addon write bumps this → provider reloads.
    ref.watch(addonRevisionProvider);
    return SettingsService().getStremioAddons();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SettingsService().getStremioAddons(),
    );
  }
}
