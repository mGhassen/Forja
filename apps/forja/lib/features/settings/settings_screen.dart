import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/widgets/settings_hub_scaffold.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Settings tab — RFC-033 category hub; RFC-024 R24-A13: local prefs only.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedId = SettingsCategoryId.playback;

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('settings');
    super.dispose();
  }

  void _onSelect(String id) {
    if (SettingsTokens.useSplitLayout(context)) {
      setState(() => _selectedId = id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsCategoryPage(categoryId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsHubScaffold(
      selectedId: _selectedId,
      onSelect: _onSelect,
    );
  }
}
