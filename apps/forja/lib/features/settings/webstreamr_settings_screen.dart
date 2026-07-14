import 'package:flutter/material.dart';
import 'package:forja/features/settings/sections/settings_webstreamr_section.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';

/// Standalone route for WebStreamr settings (deep links / legacy callers).
/// Prefer the Settings hub category [SettingsCategoryId.webstreamr].
class WebStreamrSettingsScreen extends StatelessWidget {
  const WebStreamrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SettingsPageScaffold(
        title: 'WebStreamr',
        showBack: true,
        child: SettingsWebstreamrSection(),
      ),
    );
  }
}
