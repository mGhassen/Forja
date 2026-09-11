import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/pack_capabilities.dart';
import 'package:forja/shared/shell/kit_search_screen.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';

/// Open hub Search — same entry for top-bar and Cmd+F (when not already overlay).
///
/// Pack capability [PackCapabilities.hostSearch] → shared host Search
/// overlay (structured TMDB + addons). Otherwise pack `search` via
/// [KitSearchScreen].
Future<void> openCatalogSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) async {
  final found = await PluginRegistry.instance.findPlugin(pluginId);
  final plugin = found?.plugin;
  if (plugin == null || !plugin.hasCapability(PackCapabilities.search)) {
    return;
  }
  if (!context.mounted) return;

  if (plugin.hasCapability(PackCapabilities.hostSearch)) {
    await AppRouter.openSearch(context);
    return;
  }

  pushShellRoute(
    context,
    AppRouter.slideShellRoute(
      (_) => KitSearchScreen(
        pluginId: pluginId,
        tabId: tabId,
        hintText: hintText,
        structuredSearch: plugin.hasCapability(
          PackCapabilities.structuredSearch,
        ),
        applyChromeFilters: plugin.hasCapability(
          PackCapabilities.filters,
        ),
      ),
    ),
  );
}

/// @deprecated Use [openCatalogSearch].
Future<void> openKitSearch(
  BuildContext context, {
  required String pluginId,
  required String tabId,
  required String hintText,
}) =>
    openCatalogSearch(
      context,
      pluginId: pluginId,
      tabId: tabId,
      hintText: hintText,
    );
