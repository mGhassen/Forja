import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/sections/settings_iptv_player_prefs.dart';

/// Addon detail for IPTV — pack settings (portal fields) render above via
/// [PackAddonSettingsSection]; host keeps live player prefs only.
class SettingsIptvAddonSection extends StatelessWidget {
  const SettingsIptvAddonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsIptvPlayerPrefs();
  }
}
