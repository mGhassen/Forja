import 'package:flutter/widgets.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';

/// Props-only health probe surface for kit resolve panels (RFC-095).
abstract class KitUrlHealthProbe implements Listenable {
  bool? healthFor(String key);
  void remember(String key, bool ok);
  Future<bool> checkNow(String key, String url);
  void dispose();
}

typedef KitUrlHealthProbeFactory = KitUrlHealthProbe Function({
  void Function(String key, bool ok)? onResult,
});

typedef KitResolveTabLoader = Future<List<KitSourcesRow>> Function(
  Map<String, dynamic> legacyRow,
  String tabId, {
  KitUrlHealthProbe? healthProbe,
  void Function(List<KitSourcesRow> rows)? onPartial,
  bool force,
});

typedef KitResolvePlayHandler = Future<void> Function(
  BuildContext context,
  KitSourcesRow row, {
  required String title,
});

/// Feature registers loaders/play/health — foundation kit stays generic (RFC-095 D).
abstract final class KitResolveStreamsHooks {
  KitResolveStreamsHooks._();

  static KitResolveTabLoader? loadTab;
  static KitResolvePlayHandler? playRow;
  static KitUrlHealthProbeFactory? createHealthProbe;

  static void clear() {
    loadTab = null;
    playRow = null;
    createHealthProbe = null;
  }
}
