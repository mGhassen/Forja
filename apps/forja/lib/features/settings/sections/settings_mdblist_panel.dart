import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

class SettingsMdblistPanel extends ConsumerStatefulWidget {
  const SettingsMdblistPanel({super.key});

  @override
  ConsumerState<SettingsMdblistPanel> createState() =>
      _SettingsMdblistPanelState();
}

class _SettingsMdblistPanelState extends ConsumerState<SettingsMdblistPanel> {
  final MdblistService _service = MdblistService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _hydrate(TrackerAccountStatus status) {
    _apiKeyController.text = status.apiKey ?? '';
    _hydrated = true;
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ForjaToast.warning('Please enter an API key');
      }
      return;
    }

    await _service.setApiKey(key);

    // Validate by fetching user info
    final info = await _service.getUserInfo();
    if (info != null) {
      ref.invalidate(mdblistStatusProvider);
      if (mounted) {
        final username = info['name']?.toString();
        ForjaToast.success(
          'MDBlist connected${username != null ? " as $username" : ""}!',
        );
      }
    } else {
      await _service.logout();
      ref.invalidate(mdblistStatusProvider);
      if (mounted) {
        ForjaToast.error('Invalid MDBlist API key');
      }
    }
  }

  void _logout() async {
    await _service.logout();
    _apiKeyController.clear();
    ref.invalidate(mdblistStatusProvider);
    if (mounted) {
      ForjaToast.success('MDBlist API key removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(mdblistStatusProvider).valueOrNull;
    final isConfigured = status?.loggedIn ?? false;
    final username = status?.username;
    if (status != null && !_hydrated) _hydrate(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more',
            style: TextStyle(
              fontSize: 13,
              color: ForjaShellColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (isConfigured) ...[
            SettingsStatusRow(
              title: 'Connected${username != null ? " as $username" : ""}',
              subtitle: 'MDBlist',
            ),
            const SizedBox(height: 12),
            SettingsFilledButton(
              label: 'Remove API Key',
              icon: Icons.logout,
              secondary: true,
              onPressed: _logout,
            ),
          ] else ...[
            SettingsTextField(
              controller: _apiKeyController,
              label: 'MDBlist API Key',
              hint: 'Paste your API key from mdblist.com',
              obscureText: true,
              onSubmitted: (_) => _saveApiKey(),
            ),
            const SizedBox(height: 14),
            SettingsFilledButton(
              label: 'Save API Key',
              icon: Icons.save,
              onPressed: _saveApiKey,
            ),
          ],
        ],
      ),
    );
  }

}
