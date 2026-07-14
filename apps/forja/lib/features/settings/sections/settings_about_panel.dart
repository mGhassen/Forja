import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/widgets/update_dialog.dart';

class SettingsAboutPanel extends StatefulWidget {
  const SettingsAboutPanel({super.key});

  @override
  State<SettingsAboutPanel> createState() => _SettingsAboutPanelState();
}

class _SettingsAboutPanelState extends State<SettingsAboutPanel> {
  bool _isChecking = false;
  final AppUpdaterService _updater = AppUpdaterService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check for new versions of Forja',
            style: TextStyle(
              fontSize: 13,
              color: ForjaShellColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: _isChecking ? 'Checking...' : 'Check for Updates',
            icon: Icons.system_update_rounded,
            busy: _isChecking,
            onPressed: _isChecking ? null : _checkForUpdates,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isChecking = true);

    try {
      final updateInfo = await _updater.checkForUpdates();

      if (mounted) {
        setState(() => _isChecking = false);

        if (updateInfo != null) {
          unawaited(UpdateDialog.show(context, updateInfo));
        } else {
          ForjaToast.success("You're running the latest version!");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ForjaToast.error('Failed to check for updates: $e');
      }
    }
  }
}
