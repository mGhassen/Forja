import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isConfigured) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected${_username != null ? " as $_username" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'MDBlist',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Remove API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'MDBlist API Key',
                hintText: 'Paste your API key from mdblist.com',
                labelStyle: const TextStyle(color: Colors.white54),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveApiKey,
              icon: const Icon(Icons.save),
              label: const Text('Save API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
