import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/data/cache_data_section.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

class SettingsDataPageBody extends StatefulWidget {
  const SettingsDataPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  State<SettingsDataPageBody> createState() => _SettingsDataPageBodyState();
}

class _SettingsDataPageBodyState extends State<SettingsDataPageBody> {
  final SettingsService _settings = SettingsService();
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportSettings() async {
    setState(() => _isExporting = true);
    try {
      final data = await _settings.exportAllSettings();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'forja_settings_$timestamp.json';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );

      if (result == null) {
        // User cancelled the save dialog.
        return;
      }

      // Desktop saveFile returns a path; write explicitly (sandbox needs
      // com.apple.security.files.user-selected.read-write on macOS).
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(result).writeAsString(jsonStr);
      }

      if (mounted) {
        ForjaToast.success('Settings exported');
      }
    } catch (e, st) {
      debugPrint('[SettingsData] export failed: $e\n$st');
      if (mounted) ForjaToast.error('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Settings',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final String jsonStr;
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (mounted) ForjaToast.error('Could not read file.');
      return;
    }

    if (!mounted) return;

    final confirm = await showSettingsConfirmDialog(
      context: context,
      title: 'Import Settings',
      body:
          'This overwrites your current settings, including addons, API keys, and preferences. Continue?',
      confirmLabel: 'Import',
      destructive: true,
    );
    if (!confirm) return;

    setState(() => _isImporting = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      await _settings.importAllSettings(data);
      if (mounted) ForjaToast.success('Settings imported');
    } catch (e) {
      if (mounted) ForjaToast.error('Import failed: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Backup',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Export or import all your settings, addons, API keys, and preferences as a JSON file.',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.9,
                      ),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SettingsFilledButton(
                        label: 'Import',
                        icon: Icons.download_rounded,
                        secondary: true,
                        busy: _isImporting,
                        onPressed: _importSettings,
                      ),
                      const SizedBox(width: 12),
                      SettingsFilledButton(
                        label: 'Export',
                        icon: Icons.upload_rounded,
                        busy: _isExporting,
                        onPressed: _exportSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.visibility.showIptvSettings)
        SettingsCacheDataSection(
          showIptvPortalCache: widget.visibility.showIptvSettings,
        ),
      ],
    );
  }
}
