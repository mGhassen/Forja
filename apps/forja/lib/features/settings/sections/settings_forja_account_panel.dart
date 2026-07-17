import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';

/// Forja cloud account (Supabase) — Settings → Accounts.
class SettingsForjaAccountPanel extends StatefulWidget {
  const SettingsForjaAccountPanel({super.key});

  @override
  State<SettingsForjaAccountPanel> createState() =>
      _SettingsForjaAccountPanelState();
}

class _SettingsForjaAccountPanelState extends State<SettingsForjaAccountPanel> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  int _domains = 0;
  List<SyncProfile> _profiles = const [];
  String? _activeProfileId;

  @override
  void initState() {
    super.initState();
    _refreshRemote();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshRemote() async {
    await ForjaSupabase.ensureInitialized();
    if (!SyncService.instance.isSignedIn) {
      if (mounted) {
        setState(() {
          _domains = 0;
          _profiles = const [];
          _activeProfileId = null;
        });
      }
      return;
    }
    final profiles = await SyncService.instance.listProfiles();
    final activeProfile = await SyncService.instance.activeProfile();
    final remote = await SyncService.instance.pullSettings();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfileId = activeProfile?.id;
      _domains = remote?.length ?? 0;
    });
  }

  Future<void> _selectProfile(String profileId) async {
    if (profileId == _activeProfileId || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await SyncDomainBridge.instance.prepareProfileSwitch();
    final selected = await SyncService.instance.selectProfile(profileId);
    if (selected) {
      await SyncDomainBridge.instance.pullAndMergeAll();
      if (mounted) ForjaToast.success('Profile switched');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _refreshRemote();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SyncService.instance.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(
        () =>
            _error = 'Sign-in failed. Check email/password or Supabase config.',
      );
      return;
    }
    ForjaToast.success('Signed in');
    _passwordCtrl.clear();
    await SyncDomainBridge.instance.pullAndMergeAll();
    await _refreshRemote();
    setState(() {});
  }

  Future<void> _signUp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SyncService.instance.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = 'Sign-up failed. Check Supabase Auth settings.');
      return;
    }
    ForjaToast.success('Account created');
    await SyncDomainBridge.instance.pullAndMergeAll();
    await _refreshRemote();
    setState(() {});
  }

  Future<void> _signOut() async {
    await SyncService.instance.signOut();
    if (!mounted) return;
    setState(() {
      _domains = 0;
      _profiles = const [];
      _activeProfileId = null;
    });
    ForjaToast.info('Signed out');
  }

  @override
  Widget build(BuildContext context) {
    if (!ForjaSupabase.isConfigured) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Cloud account is not configured in this build. '
          'Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
          style: TextStyle(color: ForjaShellColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final signedIn = SyncService.instance.isSignedIn;
    final email = SyncService.instance.userEmail;
    SyncProfile? activeProfile;
    for (final profile in _profiles) {
      if (profile.id == _activeProfileId) {
        activeProfile = profile;
        break;
      }
    }

    if (signedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ForjaProfileAvatar(
                avatarKey: activeProfile?.avatarKey ?? 'forge',
                name: activeProfile?.name ?? 'Profile',
                size: 58,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(activeProfile?.name ?? 'Profile'),
                  subtitle: Text(
                    '${email ?? 'Signed in'}\n'
                    '${_domains == 0 ? 'No settings domains synced yet' : '$_domains synced domain${_domains == 1 ? '' : 's'}'}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
          if (_profiles.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _activeProfileId,
              decoration: const InputDecoration(
                labelText: 'Active profile',
                isDense: true,
              ),
              items: [
                for (final profile in _profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    child: Text(profile.name),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) _selectProfile(value);
                    },
            ),
          if (_profiles.isNotEmpty) const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _signOut,
              child: const Text('Sign out'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            isDense: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: Text(_busy ? '…' : 'Sign in'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy ? null : _signUp,
              child: const Text('Create account'),
            ),
          ],
        ),
      ],
    );
  }
}
