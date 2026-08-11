import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/shared/sync/sync.dart';

/// Resolves which Settings categories / rows are visible for the active profile.
final settingsVisibilityProvider =
    FutureProvider<SettingsVisibility>((ref) async {
  ref.watch(navbarRevisionProvider);
  ref.watch(playSourceRevisionProvider);
  ref.watch(accountFeaturesRevisionProvider);
  return SettingsVisibility.resolve();
});
