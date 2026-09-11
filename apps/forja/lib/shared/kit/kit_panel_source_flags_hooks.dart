import 'package:forja/shared/kit/kit_sources.dart';

/// Settings wires playback toggles → [KitPanelSourceFlags] (RFC-095).
abstract final class KitPanelSourceFlagsHooks {
  KitPanelSourceFlagsHooks._();

  /// Warm prefs before first paint (`ref` is host WidgetRef / Ref).
  static Future<void> Function(Object ref)? warm;

  /// Watch flags for rebuild (`ref` is host WidgetRef).
  static KitPanelSourceFlags? Function(Object ref)? watch;

  static void clear() {
    warm = null;
    watch = null;
  }
}
