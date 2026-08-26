import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/lan_p2p_required_dialog.dart';
import 'package:rust/rust.dart';

import 'lan_playback_router.dart';
import 'lan_prefs.dart';

/// True when this magnet / infoHash may start. Direct HTTP must not call this.
///
/// Unpaired / desktop-offline ATV (no local engine) shows a pair dialog.
Future<bool> ensureLanP2pPlayback(
  BuildContext context, {
  bool? useDebrid,
  String? debridService,
}) async {
  final settings = SettingsService();
  final prefs = settings.debridPlaybackPrefs();
  final use = useDebrid ?? prefs.useDebrid;
  final service = use
      ? (debridService ?? prefs.service)
      : 'None';
  if (use && service != 'None') return true;
  final decision = await LanPlaybackRouter.routeTorrent(
    PlatformPlayback.capabilities,
  );
  if (decision == LanRouteDecision.desktopServes ||
      decision == LanRouteDecision.localEngine) {
    return true;
  }
  if (!context.mounted) return false;
  final neverPaired = !await LanPrefs.instance.isPaired;
  if (!context.mounted) return false;
  await showLanP2pRequiredDialog(context, neverPaired: neverPaired);
  return false;
}
