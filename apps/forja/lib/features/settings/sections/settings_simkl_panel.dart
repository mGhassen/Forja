import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsSimklPanel extends StatefulWidget {
  const SettingsSimklPanel({super.key});

  @override
  State<SettingsSimklPanel> createState() => _SettingsSimklPanelState();
}

class _SettingsSimklPanelState extends State<SettingsSimklPanel> {
  final SimklService _service = SimklService();
  bool _isLoggedIn = false;
  String? _userCode;
  String? _verifyUrl;
  Timer? _pollTimer;
  bool _isSyncing = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final loggedIn = await _service.isLoggedIn();
    String? user;
    if (loggedIn) {
      final profile = await _service.getUserProfile();
      user = profile?['name']?.toString();
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _username = user;
    });
  }

  void _startLogin() async {
    final data = await _service.requestPin();
    if (data == null) {
      if (mounted) {
        ForjaToast.error('Failed to start Simkl login');
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl =
        data['verification_url']?.toString() ??
        'https://simkl.com/pin/$userCode';
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 900;

    setState(() {
      _userCode = userCode;
      _verifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    final uri = Uri.parse(verifyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ForjaToast.success('Code $userCode copied! Opening $verifyUrl...');
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: interval), (
      timer,
    ) async {
      final token = await _service.pollForToken(userCode);
      if (token != null) {
        timer.cancel();
        final profile = await _service.getUserProfile();
        final username = profile?['name']?.toString();
        if (mounted) {
          setState(() {
            _userCode = null;
            _verifyUrl = null;
            _isLoggedIn = true;
            _username = username;
          });
          ForjaToast.success(
            'Logged in to Simkl${username != null ? " as $username" : ""}!',
          );
        }
        _sync();
      }
    });

    Future.delayed(Duration(seconds: expiresIn), () {
      if (_pollTimer?.isActive ?? false) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _userCode = null;
            _verifyUrl = null;
          });
        }
      }
    });
  }

  void _logout() async {
    await _service.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _username = null;
      });
      ForjaToast.success('Logged out of Simkl');
    }
  }

  Future<void> _sync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final watchlistCount = await _service.importWatchlistToMyList();
      final episodesImported = await _service.importWatchedEpisodes();
      final exportedCount = await _service.exportMyListToWatchlist();
      final episodesExported = await _service.exportWatchedEpisodes();

      if (mounted) {
        ForjaToast.success(
          'Simkl sync done! Imported $watchlistCount watchlist, '
          '$episodesImported episodes. '
          'Exported $exportedCount watchlist, $episodesExported episodes.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Simkl sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
            'Sync your watchlist and watch history with Simkl',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isLoggedIn) ...[
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
                          'Simkl',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.sync,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _sync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Simkl'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_userCode != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Go to the URL below and enter this code:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _verifyUrl ?? 'https://simkl.com/pin',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for authorization...',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _startLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Simkl'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
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
