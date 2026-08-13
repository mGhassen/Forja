import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsSimklPanel extends ConsumerStatefulWidget {
  const SettingsSimklPanel({super.key});

  @override
  ConsumerState<SettingsSimklPanel> createState() =>
      _SettingsSimklPanelState();
}

class _SettingsSimklPanelState extends ConsumerState<SettingsSimklPanel> {
  final SimklService _service = SimklService();
  String? _userCode;
  String? _verifyUrl;
  Timer? _pollTimer;
  bool _isSyncing = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startLogin() async {
    if (!SimklService.isConfigured) {
      if (mounted) {
        ForjaToast.error('Simkl login isn’t available in this build');
      }
      return;
    }
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
          });
          ref.invalidate(simklStatusProvider);
          ForjaToast.success(
            'Logged in to Simkl${username != null ? " as $username" : ""}!',
          );
        }
        if (mounted) await _sync();
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
    ref.invalidate(simklStatusProvider);
    ref.invalidate(externalListsGateProvider);
    ref.invalidate(simklWatchlistProvider);
    if (mounted) {
      ForjaToast.success('Logged out of Simkl');
    }
  }

  Future<void> _sync() async {
    if (_isSyncing || !mounted) return;
    final mode = await showSimklSyncModeDialog(context);
    if (!mounted) return;

    setState(() => _isSyncing = true);
    try {
      final SimklSyncResult result;
      if (mode == null) {
        result = await _service.syncHistoryOnly();
      } else {
        result = await _service.syncWithMode(mode);
      }
      ref.invalidate(externalListsGateProvider);
      ref.invalidate(simklWatchlistProvider);
      if (mounted) {
        ForjaToast.success(
          _syncToast(result),
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

  String _syncToast(SimklSyncResult r) {
    final modeLabel = switch (r.mode) {
      null => 'History only',
      SimklListSyncMode.keepLocal => 'Kept local',
      SimklListSyncMode.useSimkl => 'Used Simkl',
      SimklListSyncMode.merge => 'Merged',
    };
    return '$modeLabel · list ↑${r.watchlistExported} ↓${r.watchlistImported}, '
        'progress ${r.watchingImported}, movies ${r.moviesImported}, '
        'eps ↑${r.episodesExported} ↓${r.episodesImported}';
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(simklStatusProvider).valueOrNull;
    final isLoggedIn = status?.loggedIn ?? false;
    final username = status?.username;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sync your watchlist and watch history with Simkl',
            style: TextStyle(
              fontSize: 13,
              color: ForjaShellColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (isLoggedIn) ...[
            SettingsStatusRow(
              title: 'Connected${username != null ? " as $username" : ""}',
              subtitle: 'Simkl',
            ),
            const SizedBox(height: 12),
            SettingsFilledButton(
              label: _isSyncing ? 'Syncing...' : 'Sync Now',
              icon: Icons.sync,
              busy: _isSyncing,
              onPressed: _isSyncing ? null : _sync,
            ),
            const SizedBox(height: 10),
            SettingsFilledButton(
              label: 'Logout from Simkl',
              icon: Icons.logout,
              secondary: true,
              onPressed: _logout,
            ),
          ] else if (_userCode != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Text(
                    'Go to the URL below and enter this code:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ForjaShellColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: ForjaShellColors.brandGreen,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _verifyUrl ?? 'https://simkl.com/pin',
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    color: ForjaShellColors.brandGreen,
                    backgroundColor: ForjaShellColors.borderSubtle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for authorization...',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SettingsFilledButton(
              label: 'Login with Simkl',
              icon: Icons.login,
              secondary: true,
              onPressed: _startLogin,
            ),
          ],
        ],
      ),
    );
  }
}

Future<SimklListSyncMode?> showSimklSyncModeDialog(BuildContext context) async {
  const labels = <String, SimklListSyncMode>{
    'Keep local': SimklListSyncMode.keepLocal,
    'Use Simkl': SimklListSyncMode.useSimkl,
    'Merge': SimklListSyncMode.merge,
  };
  final picked = await showSettingsSelectDialog(
    context: context,
    title: 'How should lists sync?',
    value: 'Merge',
    options: labels.keys.toList(),
  );
  if (picked == null) return null;
  return labels[picked];
}
