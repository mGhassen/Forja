import 'package:flutter/widgets.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

/// Host-registered open handlers for pack `open.surface` values.
///
/// Foundation routes only; product surfaces (e.g. `live`) register at boot.
typedef MetaSurfaceOpenHandler = void Function(
  BuildContext context,
  MetaItem item,
);

abstract final class MetaSurfaceOpen {
  MetaSurfaceOpen._();

  static final Map<String, MetaSurfaceOpenHandler> _handlers = {};

  static void register(String surface, MetaSurfaceOpenHandler handler) {
    final key = surface.trim();
    if (key.isEmpty) return;
    _handlers[key] = handler;
  }

  static void unregister(String surface) {
    _handlers.remove(surface.trim());
  }

  static MetaSurfaceOpenHandler? resolve(String surface) =>
      _handlers[surface.trim()];

  @visibleForTesting
  static void debugReset() => _handlers.clear();
}
