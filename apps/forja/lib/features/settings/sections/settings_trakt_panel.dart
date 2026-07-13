import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Trakt login, sync, and stats — settings Accounts slice.
class SettingsTraktPanel extends StatefulWidget {
  const SettingsTraktPanel({super.key});

  @override
  State<SettingsTraktPanel> createState() => _SettingsTraktPanelState();
}

class _SettingsTraktPanelState extends State<SettingsTraktPanel> {
  final TraktService _trakt = TraktService();
  bool _isLoggedIn = false;
  String? _userCode;
  String? _verifyUrl;
  Timer? _pollTimer;
  bool _isSyncing = false;
  String? _username;
  Map<String, dynamic>? _stats;

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
    final loggedIn = await _trakt.isLoggedIn();
    String? user;
    Map<String, dynamic>? stats;
    if (loggedIn) {
      final profile = await _trakt.getUserProfile();
      user = profile?['user']?['username']?.toString() ??
          profile?['username']?.toString();
      stats = await _trakt.getUserStats();
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _username = user;
      _stats = stats;
    });
  }

  void _startLogin() async {
    final data = await _trakt.startDeviceAuth();
    if (data == null) {
      if (mounted) {
        ForjaToast.error('Failed to start Trakt login');
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl = data['verification_url'] as String;
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 600;
    final deviceCode = data['device_code'] as String;

    setState(() {
      _userCode = userCode;
      _verifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    // Auto-open the verification URL in the default browser
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
      final result = await _trakt.pollForToken(deviceCode);
      if (result == 'success') {
        timer.cancel();
        // Fetch username
        final profile = await _trakt.getUserProfile();
        final username =
            profile?['user']?['username']?.toString() ??
            profile?['username']?.toString();
        if (mounted) {
          setState(() {
            _userCode = null;
            _verifyUrl = null;
            _isLoggedIn = true;
            _username = username;
          });
          ForjaToast.success(
            'Logged in to Trakt${username != null ? " as $username" : ""}!',
          );
        }
        // Auto-sync after login
        _sync();
      } else if (result == 'expired' || result == 'denied') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _userCode = null;
            _verifyUrl = null;
          });
          ForjaToast.error(
            result == 'denied'
                ? 'Trakt login denied'
                : 'Code expired, try again',
          );
        }
      }
      // 'pending' → keep polling
    });

    // Expire timer
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
    await _trakt.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _username = null;
      });
      ForjaToast.success('Logged out of Trakt');
    }
  }

  Future<void> _sync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final watchlistCount = await _trakt.importWatchlistToMyList();
      final playbackCount = await _trakt.importPlaybackToWatchHistory();
      final episodesImported = await _trakt.importWatchedEpisodes();
      final exportedCount = await _trakt.exportMyListToWatchlist();
      final episodesExported = await _trakt.exportWatchedEpisodes();

      if (mounted) {
        ForjaToast.success(
          'Trakt sync done! Imported $watchlistCount watchlist, '
          '$playbackCount playback, $episodesImported episodes. '
          'Exported $exportedCount watchlist, $episodesExported episodes.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Trakt sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildStatsWidget() {
    final stats = _stats!;
    final movies = stats['movies'] as Map<String, dynamic>? ?? {};
    final episodes = stats['episodes'] as Map<String, dynamic>? ?? {};
    final moviesWatched = movies['watched'] as int? ?? 0;
    final moviesMinutes = movies['minutes'] as int? ?? 0;
    final epsWatched = episodes['watched'] as int? ?? 0;
    final epsMinutes = episodes['minutes'] as int? ?? 0;
    final totalHours = ((moviesMinutes + epsMinutes) / 60).round();

    Widget stat(IconData icon, String label, String value) {
      return Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat(Icons.movie_rounded, 'Movies', '$moviesWatched'),
          stat(Icons.tv_rounded, 'Episodes', '$epsWatched'),
          stat(Icons.schedule_rounded, 'Hours', '$totalHours'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync your watchlist and watch history with Trakt.tv',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          if (_isLoggedIn) ...[
            // ── Logged in ──
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
                          'Trakt.tv',
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

            // Stats
            if (_stats != null) ...[
              _buildStatsWidget(),
              const SizedBox(height: 12),
            ],

            // Sync button
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

            // Logout button
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Trakt'),
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
            // ── Polling — show code ──
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
                    _verifyUrl ?? 'https://trakt.tv/activate',
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
            // ── Not logged in ──
            ElevatedButton.icon(
              onPressed: _startLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Trakt'),
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
