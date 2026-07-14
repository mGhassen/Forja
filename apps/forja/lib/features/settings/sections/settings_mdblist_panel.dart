import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

class SettingsMdblistPanel extends StatefulWidget {
  const SettingsMdblistPanel({super.key});

  @override
  State<SettingsMdblistPanel> createState() => _SettingsMdblistPanelState();
}

class _SettingsMdblistPanelState extends State<SettingsMdblistPanel> {
  final MdblistService _service = MdblistService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isConfigured = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final configured = await _service.isConfigured();
    String? user;
    final key = await _service.getApiKey();
    if (configured) {
      final info = await _service.getUserInfo();
      user = info?['name']?.toString();
    }
    if (!mounted) return;
    setState(() {
      _isConfigured = configured;
      _username = user;
      _apiKeyController.text = key ?? '';
    });
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
      if (mounted) {
        setState(() {
          _isConfigured = true;
          _username = info['name']?.toString();
        });
        ForjaToast.success(
          'MDBlist connected${_username != null ? " as $_username" : ""}!',
        );
      }
    } else {
      await _service.logout();
      if (mounted) {
        setState(() {
          _isConfigured = false;
          _username = null;
        });
        ForjaToast.error('Invalid MDBlist API key');
      }
    }
  }

  void _logout() async {
    await _service.logout();
    if (mounted) {
      setState(() {
        _isConfigured = false;
        _username = null;
        _apiKeyController.clear();
      });
      ForjaToast.success('MDBlist API key removed');
    }
  }

  @override
  Widget build(BuildContext context) {
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

          if (_isConfigured) ...[
            SettingsStatusRow(
              title: 'Connected${_username != null ? " as $_username" : ""}',
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
