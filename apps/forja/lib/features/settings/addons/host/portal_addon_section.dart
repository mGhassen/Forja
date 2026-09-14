import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/host/portal_player_prefs.dart';

/// Addon detail for pack-contributed IPTV (`settings.addon: "iptv"`).
/// Portal fields render above via [PackAddonSettingsSection]; host keeps
/// live player prefs (engine / EPG / quality) under the same Addons page.
class SettingsPortalAddonSection extends StatelessWidget {
  const SettingsPortalAddonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPortalPlayerPrefs();
  }
}
