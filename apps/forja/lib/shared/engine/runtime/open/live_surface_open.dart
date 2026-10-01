import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/live_schedule_chrome.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// `open.surface: live` → switch to pack [tabId] from open payload (opaque).
abstract final class LiveSurfaceOpen {
  LiveSurfaceOpen._();

  static const surface = 'live';

  /// Opaque list source id live schedule packs may declare.
  static const listSourceId = 'live_schedule';

  static String? pendingOpenEntryId;
  static bool _registered = false;

  static void ensureRegistered() {
    if (!_registered) {
      _registered = true;
      MetaSurfaceOpen.register(surface, openFromMeta);
    }
    // Idempotent — re-bind after hot restart / wipe recovery.
    registerLiveScheduleChromeHooks();
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final open = item.open;
    final id = (open?.id ?? item.id).trim();
    pendingOpenEntryId = id.isEmpty ? null : id;
    final tab = (open?.extraString('tabId') ?? '').trim();
    if (tab.isEmpty) return;
    ShellBus.requestTab.value = tab;
  }

  static String? takePendingOpenEntryId() {
    final id = pendingOpenEntryId;
    pendingOpenEntryId = null;
    return id;
  }

  @visibleForTesting
  static void debugReset() {
    _registered = false;
    pendingOpenEntryId = null;
    MetaSurfaceOpen.unregister(surface);
    clearLiveScheduleChromeHooks();
  }
}
