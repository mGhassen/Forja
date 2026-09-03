import 'package:flutter/material.dart';
import 'package:forja/features/settings/sections/settings_iptv_portals_section.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

/// Addon detail for IPTV — portal export/import and a pointer to Playback
/// for IPTV-specific player prefs.
class SettingsIptvAddonSection extends StatelessWidget {
  const SettingsIptvAddonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsGroup(
          label: 'Portals',
          children: [SettingsIptvPortalsSection()],
        ),
        SettingsGroup(
          label: 'Player settings',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Text(
                'IPTV engine, EPG, quality, recovery, and buffer are under Settings → Playback.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
