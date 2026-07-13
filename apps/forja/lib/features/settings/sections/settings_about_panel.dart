import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check for new versions of Forja',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkForUpdates,
              icon: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.system_update_rounded),
              label: Text(
                _isChecking ? 'Checking...' : 'Check for Updates',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
