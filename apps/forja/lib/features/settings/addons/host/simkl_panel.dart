import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/store/external_list_providers.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

const _kNoSync = 'No sync';
const _kModeLabels = <String, SimklListSyncMode>{
  'Keep local': SimklListSyncMode.keepLocal,
  'Use Simkl': SimklListSyncMode.useSimkl,
  'Merge': SimklListSyncMode.merge,
  'Merge + delete': SimklListSyncMode.mergeWithDeletion,
};

class SettingsSimklPanel extends ConsumerStatefulWidget {
  const SettingsSimklPanel({super.key});

  @override
  ConsumerState<SettingsSimklPanel> createState() => _SettingsSimklPanelState();
}

class _SettingsSimklPanelState extends ConsumerState<SettingsSimklPanel> {
  final SimklService _service = SimklService();
  String? _userCode;
  String? _verifyUrl;
  Timer? _pollTimer;
  bool _isSyncing = false;
  bool _autoSyncLists = false;
  SimklListSyncMode? _listSyncMode;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final auto = await _service.getAutoSyncLists();
    final mode = await _service.getListSyncMode();
    if (!mounted) return;
    setState(() {
      _autoSyncLists = auto;
      _listSyncMode = mode;
      _prefsLoaded = true;
    });
  }

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
      ForjaToast.success('Code $userCode copied. Opening $verifyUrl…');
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
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
        // Prefer saved dropdown mode — no chooser dialog.
        if (mounted && await _service.getListSyncMode() != null) {
          await _sync();
        }
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

  Future<void> _onModePicked(String? label) async {
    if (label == null) return;
    if (label == _kNoSync) {
      await _service.setListSyncMode(null);
      if (_autoSyncLists) {
        await _service.setAutoSyncLists(false);
      }
      if (mounted) {
        setState(() {
          _listSyncMode = null;
          _autoSyncLists = false;
        });
      }
      return;
    }
    final mode = _kModeLabels[label];
    if (mode == null) return;
    await _service.setListSyncMode(mode);
    if (mounted) setState(() => _listSyncMode = mode);
  }

  Future<void> _sync() async {
    if (_isSyncing || !mounted) return;
    final mode = _listSyncMode ?? await _service.getListSyncMode();
    if (mode == null) {
      ForjaToast.error('Pick how lists sync first');
      return;
    }

    setState(() => _isSyncing = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final result = await _service.syncWithMode(mode);
      ref.invalidate(externalListsGateProvider);
      // Wipe EngineCache feed + bump listFeedEpoch so My List reloads
      // (Riverpod-only invalidate left the hub on a stale composed feed).
      invalidateListHubFeeds(container);
      if (mounted) {
        setState(() => _listSyncMode = mode);
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

  Future<void> _onAutoSyncChanged(bool enabled) async {
    if (enabled) {
      final mode = _listSyncMode ?? await _service.getListSyncMode();
      if (mode == null) {
        if (mounted) {
          ForjaToast.error('Pick how lists sync first');
        }
        return;
      }
      await _service.setAutoSyncLists(true);
      if (mounted) setState(() => _autoSyncLists = true);
      return;
    }
    await _service.setAutoSyncLists(false);
    if (mounted) setState(() => _autoSyncLists = false);
  }

  String _modeLabel(SimklListSyncMode? mode) => switch (mode) {
    SimklListSyncMode.keepLocal => 'Keep local',
    SimklListSyncMode.useSimkl => 'Use Simkl',
    SimklListSyncMode.merge => 'Merge',
    SimklListSyncMode.mergeWithDeletion => 'Merge + delete',
    null => _kNoSync,
  };

  String _syncToast(SimklSyncResult r) {
    final modeLabel = switch (r.mode) {
      SimklListSyncMode.keepLocal => 'Kept local',
      SimklListSyncMode.useSimkl => 'Used Simkl',
      SimklListSyncMode.merge => 'Merged',
      SimklListSyncMode.mergeWithDeletion => 'Merged + deleted',
      null => 'Synced',
    };
    final removed = r.watchlistRemoved > 0 ? ' −${r.watchlistRemoved}' : '';
    return '$modeLabel · list ↑${r.watchlistExported} ↓${r.watchlistImported}'
        '$removed, '
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
          Text(
            'Sync your watchlist and watch history with Simkl',
            style: TextStyle(
              fontSize: SettingsTokens.typeSizeOf(context, 13),
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
            if (_prefsLoaded) ...[
              SettingsSelectRow(
                title: 'How should lists sync?',
                subtitle: SimklService.listAutoSyncFeatureEnabled
                    ? 'Saved for Sync Now and Auto sync on My List'
                    : 'Saved for Sync Now',
                value: _modeLabel(_listSyncMode),
                options: [..._kModeLabels.keys, _kNoSync],
                onChanged: _isSyncing ? (_) {} : _onModePicked,
              ),
              if (SimklService.listAutoSyncFeatureEnabled) ...[
                const SizedBox(height: 8),
                SettingsToggleRow(
                  title: 'Auto sync lists on My List',
                  subtitle:
                      'When you open My List, sync with ${_modeLabel(_listSyncMode)} '
                      'and refresh the cached library',
                  value: _autoSyncLists,
                  onChanged: _isSyncing ? (_) {} : _onAutoSyncChanged,
                  enabled: !_isSyncing && _listSyncMode != null,
                ),
              ],
              const SizedBox(height: 12),
            ],
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
                    style: TextStyle(
                      fontSize: SettingsTokens.typeSizeOf(context, 36),
                      fontWeight: FontWeight.bold,
                      color: ForjaShellColors.brandGreen,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _verifyUrl ?? 'https://simkl.com/pin',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: SettingsTokens.typeSizeOf(context, 13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    color: ForjaShellColors.brandGreen,
                    backgroundColor: ForjaShellColors.borderSubtle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for authorization...',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: SettingsTokens.typeSizeOf(context, 11),
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
