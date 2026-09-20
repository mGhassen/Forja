/// Registry so category → can focus the channel tile in front of the rail.
///
/// Host/pack must not invent product focus — the painted channel grid registers
/// itself while mounted.
abstract final class CatalogChannelGridFocus {
  CatalogChannelGridFocus._();

  static bool Function({double? categoryGlobalY})? _focusInFront;

  static void register(bool Function({double? categoryGlobalY}) focus) {
    _focusInFront = focus;
  }

  static void unregister(bool Function({double? categoryGlobalY}) focus) {
    if (identical(_focusInFront, focus)) _focusInFront = null;
  }

  /// Focus the channel that sits in front of [categoryGlobalY] (or the first
  /// visible tile when Y is null).
  static bool focusInFront({double? categoryGlobalY}) {
    return _focusInFront?.call(categoryGlobalY: categoryGlobalY) ?? false;
  }
}
