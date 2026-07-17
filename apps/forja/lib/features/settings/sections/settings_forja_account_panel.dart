import 'package:flutter/material.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Forja cloud account (Supabase) — Settings → Profile & account.
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
  bool _webBusy = false;
  String? _error;
  int _domains = 0;
  List<SyncProfile> _profiles = const [];
  String? _activeProfileId;

  @override
  void initState() {
    super.initState();
    SyncService.instance.identityRevision.addListener(_onIdentity);
    _refreshRemote();
  }

  @override
  void dispose() {
    SyncService.instance.identityRevision.removeListener(_onIdentity);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onIdentity() {
    if (mounted) _refreshRemote();
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
    final remote = await SyncService.instance.pullProfileSettings();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfileId = activeProfile?.id;
      _domains = remote == null ? 0 : remote.keys.length;
    });
  }

  Future<void> _openChooser({
    ProfileChooserMode mode = ProfileChooserMode.choose,
  }) async {
    final switched = await presentProfileChooser(
      context,
      initialMode: mode,
      prepareCurrentOnSwitch: true,
      allowSignOut: false,
    );
    if (!mounted) return;
    if (switched) {
      ForjaToast.success('Profile ready');
    }
    await _refreshRemote();
    setState(() {});
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
    _passwordCtrl.clear();
    await presentProfileChooser(
      context,
      prepareCurrentOnSwitch: false,
    );
    if (!mounted) return;
    await _refreshRemote();
    setState(() {});
  }

  Future<void> _webLogin() async {
    setState(() {
      _webBusy = true;
      _error = null;
    });
    try {
      final response = await SyncService.instance.signInWithBrowser();
      if (!mounted) return;
      if (response.session == null) {
        setState(() => _error = 'Web login did not complete.');
        return;
      }
      await presentProfileChooser(
        context,
        prepareCurrentOnSwitch: false,
      );
      if (!mounted) return;
      await _refreshRemote();
      setState(() {});
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not finish web login. Check that the portal is reachable.',
      );
    } finally {
      if (mounted) setState(() => _webBusy = false);
    }
  }

  Future<void> _openSignup() async {
    final uri = DesktopBrowserAuth.signupUri();
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open the signup page.');
    }
  }

  Future<void> _signOut() async {
    SyncDomainBridge.instance.cancelPendingPushes();
    await SyncService.instance.signOut();
    if (!mounted) return;
    setState(() {
      _domains = 0;
      _profiles = const [];
      _activeProfileId = null;
    });
  }

  bool get _locked => _busy || _webBusy;

  @override
  Widget build(BuildContext context) {
    if (!ForjaSupabase.isConfigured) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Cloud account is not configured in this build. '
          'Pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY via --dart-define.',
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
                    '${_domains == 0 ? 'No cloud settings synced yet' : '$_domains setting section${_domains == 1 ? '' : 's'} in cloud'}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _openChooser(),
                child: const Text('Who’s watching?'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openChooser(mode: ProfileChooserMode.manage),
                child: const Text('Manage profiles'),
              ),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out'),
              ),
            ],
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
          enabled: !_locked,
          decoration: const InputDecoration(labelText: 'Email', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          enabled: !_locked,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _locked ? null : _signIn,
              child: Text(_busy ? '…' : 'Sign in'),
            ),
            OutlinedButton.icon(
              onPressed: _locked ? null : _webLogin,
              icon: Icon(
                _webBusy
                    ? Icons.hourglass_top_rounded
                    : Icons.open_in_browser_rounded,
                size: 16,
              ),
              label: Text(_webBusy ? 'Waiting…' : 'Web login'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _locked ? null : _openSignup,
            child: const Text('Create an account on the web →'),
          ),
        ),
      ],
    );
  }
}
