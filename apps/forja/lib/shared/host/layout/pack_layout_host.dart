import 'package:flutter/material.dart';

import 'package:forja/shared/host/layout/kit/kit_shell.dart';

/// Sole allowed root mount for pack catalog layout (RFC-109 Wave 1).
///
/// Host is capability-only: this widget has **zero product branches**. Packs
/// own layout JSON; foundation owns paint. Wave 1 still extends [KitShell] so
/// [ShellTabRefresh] / MainScreen [GlobalKey] keep working while `kit_*` paint
/// moves out of `shared/shell`.
///
/// Do not add hub / Live Sports / IPTV / My List branches here. When layout
/// paint lives in `forja_foundation`, replace the [KitShell] implementation —
/// keep this as the only `apps/forja` entry packs mount through.
///
/// Async tab→plugin resolve still uses [KitShellLoader]; prefer constructing
/// [PackLayoutHost] directly when [pluginId] is already known (nav refresh).
class PackLayoutHost extends KitShell {
  const PackLayoutHost({
    super.key,
    required super.pluginId,
    super.tabId,
    super.packSourceUrl,
    super.hostLayout,
  });
}
