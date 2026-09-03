import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/sections/settings_iptv_player_prefs.dart';
import 'package:forja/features/settings/sections/settings_iptv_portals_section.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// Addon detail for IPTV — portals + live player prefs (incl. admin TV rows).
class SettingsIptvAddonSection extends StatelessWidget {
  const SettingsIptvAddonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Portals',
          children: [SettingsIptvPortalsSection()],
        ),
        SettingsIptvPlayerPrefs(),
      ],
    );
  }
}
