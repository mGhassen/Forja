/// Effective play-source toggles for hub details Sources chrome (RFC-095).
class KitPanelSourceFlags {
  const KitPanelSourceFlags({
    required this.torrent,
    required this.stremio,
    required this.nuvio,
    required this.engine,
  });

  final bool torrent;
  final bool stremio;
  final bool nuvio;
  final bool engine;
}

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
