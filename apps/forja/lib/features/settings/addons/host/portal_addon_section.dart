import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/host/portal_player_prefs.dart';

/// Addon detail for pack-contributed IPTV (`settings.addon: "iptv"`).
/// Host live player prefs (engine / EPG / quality). Portals are managed in
/// the IPTV hub side panel, not Settings.
class SettingsPortalAddonSection extends StatelessWidget {
  const SettingsPortalAddonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPortalPlayerPrefs();
  }
}
