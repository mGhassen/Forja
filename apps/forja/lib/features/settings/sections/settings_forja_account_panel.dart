import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/account/device_link_connect_view.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/features/account/tv_account_link_screen.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Passkey type is @experimental.
// ignore_for_file: experimental_member_use

/// Forja cloud account (Supabase) - Settings → Profile & account.
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
  bool _passkeyBusy = false;
  String? _error;
  int _domains = 0;
  List<SyncProfile> _profiles = const [];
  String? _activeProfileId;
  Completer<void>? _webCancel;
  String? _captchaToken;
  int _captchaKey = 0;
  List<Passkey> _passkeys = const [];
  bool _passkeysLoading = false;
  /// False until the active profile row is loaded - never paint a stale profile.
  bool _profileReady = false;
  /// Set when a signed-in profile fetch fails (timeout / network).
  String? _profileLoadError;
  int _refreshGen = 0;
  bool _deviceLinkActive = false;

  @override
  void initState() {
    super.initState();
    SyncService.instance.identityRevision.addListener(_onIdentity);
    _refreshRemote();
  }

  @override
  void dispose() {
    // Do not cancel web login on dispose - leaving Settings mid-handoff used
    // to abort after the browser already closed on ok:true.
    SyncService.instance.identityRevision.removeListener(_onIdentity);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _clearProfileUi() {
    _domains = 0;
    _profiles = const [];
    _activeProfileId = null;
    _passkeys = const [];
    _profileReady = false;
    _profileLoadError = null;
  }

  void _onIdentity() {
    if (!mounted) return;
    // Drop previous profile immediately - async refresh must not flash it.
    setState(_clearProfileUi);
    _refreshRemote();
  }

  Future<void> _refreshRemote() async {
    final gen = ++_refreshGen;
    await ForjaSupabase.ensureInitialized();
    if (!mounted || gen != _refreshGen) return;
    if (!SyncService.instance.isSignedIn) {
      setState(_clearProfileUi);
      return;
    }
    try {
      final profiles = await SyncService.instance.listProfiles();
      final activeProfile = await SyncService.instance.activeProfile(
        profiles: profiles,
      );
      final remote = await SyncService.instance.pullProfileSettings();
      List<Passkey> passkeys = const [];
      if (ForjaPasskeys.supported) {
        try {
          passkeys = await SyncService.instance.listPasskeys();
        } catch (_) {
          passkeys = const [];
        }
      }
      if (!mounted || gen != _refreshGen) return;
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeProfile?.id;
        _domains = remote == null ? 0 : remote.keys.length;
        _passkeys = passkeys;
        _profileReady = activeProfile != null;
        _profileLoadError = null;
      });
    } catch (e) {
      if (!mounted || gen != _refreshGen) return;
      final message = e is SyncProfileFetchException
          ? e.message
          : 'Could not load profile. Check your connection and retry.';
      setState(() {
        // Do not keep a stale Synced hero after a failed refresh.
        _profileReady = false;
        _profiles = const [];
        _activeProfileId = null;
        _domains = 0;
        _profileLoadError = message;
      });
    }
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
    if (ForjaCaptcha.isConfigured &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(() => _error = 'Complete the captcha check, then try again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SyncService.instance.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      captchaToken: _captchaToken,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() {
        _error =
            'Sign-in failed. Check email/password, captcha, or Supabase config.';
        _captchaToken = null;
        _captchaKey++;
      });
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

  Future<void> _passkeyLogin() async {
    if (!ForjaPasskeys.supported) return;
    if (ForjaCaptcha.isConfigured &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(() => _error = 'Complete the captcha check, then try again.');
      return;
    }
    setState(() {
      _passkeyBusy = true;
      _error = null;
    });
    try {
      final response = await SyncService.instance.signInWithPasskey(
        captchaToken: _captchaToken,
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() => _error = 'Passkey sign-in did not complete.');
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
      setState(() {
        _error = e.message;
        _captchaToken = null;
        _captchaKey++;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Settings] passkey sign-in failed: $e');
      setState(() {
        _error = ForjaPasskeys.userMessage(e);
        _captchaToken = null;
        _captchaKey++;
      });
    } finally {
      if (mounted) setState(() => _passkeyBusy = false);
    }
  }

  Future<void> _addPasskey() async {
    if (!ForjaPasskeys.supported) return;
    setState(() {
      _passkeysLoading = true;
      _error = null;
    });
    try {
      await SyncService.instance.registerPasskey();
      await _refreshRemote();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Settings] register passkey failed: $e');
      setState(() => _error = ForjaPasskeys.userMessage(e));
    } finally {
      if (mounted) setState(() => _passkeysLoading = false);
    }
  }

  Future<void> _removePasskey(String passkeyId) async {
    setState(() {
      _passkeysLoading = true;
      _error = null;
    });
    try {
      await SyncService.instance.deletePasskey(passkeyId);
      await _refreshRemote();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Settings] delete passkey failed: $e');
      setState(() => _error = ForjaPasskeys.userMessage(e));
    } finally {
      if (mounted) setState(() => _passkeysLoading = false);
    }
  }

  Future<void> _onDeviceLinkAuthenticated() async {
    if (!mounted) return;
    setState(() => _deviceLinkActive = false);
    await presentProfileChooser(
      context,
      prepareCurrentOnSwitch: false,
    );
    if (!mounted) return;
    await _refreshRemote();
    setState(() {});
  }

  Future<void> _tvDeviceLink() async {
    setState(() => _error = null);
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TvAccountLinkScreen(
          onAuthenticated: () => Navigator.of(context).pop(true),
          onContinueAsGuest: () => Navigator.of(context).pop(false),
        ),
      ),
    );
    if (!mounted || linked != true) return;
    await presentProfileChooser(
      context,
      prepareCurrentOnSwitch: false,
    );
    if (!mounted) return;
    await _refreshRemote();
    setState(() {});
  }

  Future<void> _webLogin() async {
    final cancel = Completer<void>();
    _webCancel = cancel;
    setState(() {
      _webBusy = true;
      _error = null;
    });
    try {
      final response = await SyncService.instance.signInWithBrowser(
        cancel: cancel.future,
      );
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
      if (e.message == 'Web login cancelled.') {
        setState(() => _error = null);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not finish web login. Check that the portal is reachable.',
      );
    } finally {
      _webCancel = null;
      if (mounted) setState(() => _webBusy = false);
    }
  }

  void _cancelWebLogin() {
    final cancel = _webCancel;
    if (cancel == null || cancel.isCompleted) return;
    cancel.complete();
  }

  Future<void> _openSignup() async {
    final uri = DesktopBrowserAuth.signupUri();
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open the signup page.');
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    // Invalidate in-flight profile load so it cannot paint signed-in chrome
    // after local session clear.
    _refreshGen++;
    setState(() {
      _busy = true;
      _error = null;
      _profileLoadError = null;
    });
    SyncDomainBridge.instance.cancelPendingPushes();
    try {
      await SyncService.instance.signOut();
    } finally {
      // Always drop signed-in chrome — session may already be local-cleared
      // even when remote revoke threw (DNS / TLS).
      if (mounted) {
        setState(() {
          _clearProfileUi();
          _busy = false;
        });
      }
    }
  }

  bool get _formLocked => _busy || _webBusy || _passkeyBusy;
  bool get _passwordLocked => _busy || _passkeyBusy;
  bool get _captchaReady =>
      !ForjaCaptcha.isConfigured ||
      (_captchaToken != null && _captchaToken!.isNotEmpty);
  bool get _canSubmitPassword => !_formLocked && _captchaReady;
  bool get _canSubmitPasskey =>
      ForjaPasskeys.supported && !_formLocked && _captchaReady;

  @override
  Widget build(BuildContext context) {
    if (!ForjaSupabase.isConfigured) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
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
    if (_profileReady && _activeProfileId != null) {
      for (final profile in _profiles) {
        if (profile.id == _activeProfileId) {
          activeProfile = profile;
          break;
        }
      }
    }

    if (signedIn) {
      // Loading OR load-failed: always keep Sign out reachable. Never spinner-only
      // — refresh can hang on DNS while gotrue keeps "Refresh already pending".
      if (!_profileReady || activeProfile == null) {
        final loading = _profileLoadError == null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsGroup(
                label: 'Account',
                children: [
                  SettingsStatusRow(
                    title: email ?? 'Signed in',
                    subtitle: loading
                        ? 'Loading cloud profile…'
                        : 'Cloud profile could not load. Retry, or sign out to '
                            'clear this session on the device.',
                    icon: loading
                        ? Icons.cloud_sync_rounded
                        : Icons.cloud_off_rounded,
                    iconColor: ForjaShellColors.iconMuted,
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(2, 8, 2, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                      child: Text(
                        _profileLoadError!,
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (!loading)
                    SettingsActionRow(
                      title: 'Retry',
                      subtitle: 'Reload profiles from the cloud',
                      leading: const Icon(
                        Icons.refresh_rounded,
                        color: ForjaShellColors.iconMuted,
                        size: 22,
                      ),
                      onTap: _busy ? null : () => unawaited(_refreshRemote()),
                      trailing: const SizedBox.shrink(),
                    ),
                  SettingsActionRow(
                    title: 'Sign out',
                    subtitle:
                        'Clear the session on this device even if the network '
                        'is down',
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFF87171),
                      size: 22,
                    ),
                    destructive: true,
                    onTap: _busy ? null : () => unawaited(_signOut()),
                    trailing: const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return _SignedInAccountBody(
        activeProfile: activeProfile,
        email: email,
        domains: _domains,
        busy: _busy || _passkeysLoading,
        passkeys: ForjaPasskeys.supported ? _passkeys : null,
        onOpenChooser: () => _openChooser(),
        onSignOut: _signOut,
        onAddPasskey: _addPasskey,
        onRemovePasskey: _removePasskey,
        error: _error,
      );
    }

    return _SignedOutAccountBody(
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      formLocked: _formLocked,
      passwordLocked: _passwordLocked,
      canSubmitPassword: _canSubmitPassword,
      canSubmitPasskey: _canSubmitPasskey,
      showPasskey: ForjaPasskeys.supported,
      androidTv: PlatformInfo.isAndroidTv,
      desktop: PlatformInfo.isDesktop,
      deviceLinkActive: _deviceLinkActive,
      busy: _busy,
      passkeyBusy: _passkeyBusy,
      webBusy: _webBusy,
      error: _error,
      captchaKey: _captchaKey,
      onCaptchaToken: (token) {
        if (!mounted) return;
        setState(() => _captchaToken = token);
      },
      onSignIn: _signIn,
      onPasskeyLogin: _passkeyLogin,
      onWebLogin: _webLogin,
      onCancelWebLogin: _cancelWebLogin,
      onTvDeviceLink: _tvDeviceLink,
      onOpenSignup: _openSignup,
      onStartDeviceLink: () => setState(() => _deviceLinkActive = true),
      onCancelDeviceLink: () => setState(() => _deviceLinkActive = false),
      onDeviceLinkAuthenticated: () => unawaited(_onDeviceLinkAuthenticated()),
    );
  }
}

class _SignedInAccountBody extends StatelessWidget {
  const _SignedInAccountBody({
    required this.activeProfile,
    required this.email,
    required this.domains,
    required this.busy,
    required this.passkeys,
    required this.onOpenChooser,
    required this.onSignOut,
    required this.onAddPasskey,
    required this.onRemovePasskey,
    this.error,
  });

  final SyncProfile activeProfile;
  final String? email;
  final int domains;
  final bool busy;
  /// Null when passkeys are unsupported on this platform.
  final List<Passkey>? passkeys;
  final VoidCallback onOpenChooser;
  final VoidCallback onSignOut;
  final VoidCallback onAddPasskey;
  final ValueChanged<String> onRemovePasskey;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final syncSubtitle = domains == 0
        ? 'No cloud settings synced yet - changes will upload as you use Forja'
        : '$domains setting section${domains == 1 ? '' : 's'} synced to this profile';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActiveProfileStage(
          name: activeProfile.name,
          avatarKey: activeProfile.avatarKey,
          onTap: busy ? null : onOpenChooser,
        ),
        const SizedBox(height: 8),
        SettingsGroup(
          label: 'Cloud sync',
          children: [
            SettingsStatusRow(
              title: domains == 0 ? 'Signed in · waiting for sync' : 'Synced',
              subtitle: syncSubtitle,
              icon: domains == 0
                  ? Icons.cloud_queue_rounded
                  : Icons.cloud_done_rounded,
            ),
          ],
        ),
        if (passkeys != null)
          SettingsGroup(
            label: 'Passkeys',
            children: [
              SettingsActionRow(
                title: busy ? 'Waiting for authenticator…' : 'Add passkey',
                subtitle:
                    'Touch ID, Windows Hello, or a security key for this account',
                leading: const Icon(
                  Icons.fingerprint_rounded,
                  color: ForjaShellColors.iconMuted,
                  size: 22,
                ),
                onTap: busy ? null : onAddPasskey,
              ),
              if (passkeys!.isEmpty)
                const SettingsStatusRow(
                  title: 'No passkeys yet',
                  subtitle: 'Add one to sign in without a password',
                  icon: Icons.key_off_rounded,
                  iconColor: ForjaShellColors.iconMuted,
                )
              else
                for (final passkey in passkeys!)
                  SettingsActionRow(
                    title: passkey.friendlyName ?? 'Passkey',
                    subtitle: 'Added ${_formatPasskeyDate(passkey.createdAt)}',
                    leading: const Icon(
                      Icons.key_rounded,
                      color: ForjaShellColors.iconMuted,
                      size: 22,
                    ),
                    trailing: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFF87171),
                      size: 20,
                    ),
                    onTap: busy ? null : () => onRemovePasskey(passkey.id),
                  ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        SettingsGroup(
          label: 'Account',
          children: [
            SettingsStatusRow(
              title: email ?? 'Signed in',
              subtitle: 'Forja cloud account shared with the web portal',
              icon: Icons.mail_outline_rounded,
              iconColor: ForjaShellColors.iconMuted,
            ),
            SettingsActionRow(
              title: 'Sign out',
              subtitle: 'Returns to the sign-in screen on this device',
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFF87171),
                size: 22,
              ),
              destructive: true,
              onTap: busy ? null : onSignOut,
              trailing: const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatPasskeyDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

/// Cinematic active-profile hero - large avatar, name, “Watching now”.
class _ActiveProfileStage extends StatelessWidget {
  const _ActiveProfileStage({
    required this.name,
    required this.avatarKey,
    required this.onTap,
  });

  final String name;
  final String avatarKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Soft brand wash - atmosphere without a card box.
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ForjaShellColors.brandGreen.withValues(alpha: 0.22),
                      ForjaShellColors.brandGreen.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              ForjaProfileAvatar(
                avatarKey: avatarKey,
                name: name,
                size: 88,
                selected: true,
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ForjaShellColors.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          ForjaShellColors.brandGreen.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    'WATCHING NOW',
                    style: TextStyle(
                      color: ForjaShellColors.brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  onTap == null
                      ? 'Active profile on this device'
                      : 'Tap to switch who’s watching',
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: ForjaShellColors.iconMuted,
              size: 28,
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

class _SignedOutAccountBody extends StatelessWidget {
  const _SignedOutAccountBody({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.formLocked,
    required this.passwordLocked,
    required this.canSubmitPassword,
    required this.canSubmitPasskey,
    required this.showPasskey,
    required this.androidTv,
    required this.desktop,
    required this.deviceLinkActive,
    required this.busy,
    required this.passkeyBusy,
    required this.webBusy,
    required this.error,
    required this.captchaKey,
    required this.onCaptchaToken,
    required this.onSignIn,
    required this.onPasskeyLogin,
    required this.onWebLogin,
    required this.onCancelWebLogin,
    required this.onTvDeviceLink,
    required this.onOpenSignup,
    required this.onStartDeviceLink,
    required this.onCancelDeviceLink,
    required this.onDeviceLinkAuthenticated,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool formLocked;
  final bool passwordLocked;
  final bool canSubmitPassword;
  final bool canSubmitPasskey;
  final bool showPasskey;
  final bool androidTv;
  final bool desktop;
  final bool deviceLinkActive;
  final bool busy;
  final bool passkeyBusy;
  final bool webBusy;
  final String? error;
  final int captchaKey;
  final ValueChanged<String?> onCaptchaToken;
  final VoidCallback onSignIn;
  final VoidCallback onPasskeyLogin;
  final VoidCallback onWebLogin;
  final VoidCallback onCancelWebLogin;
  final VoidCallback onTvDeviceLink;
  final VoidCallback onOpenSignup;
  final VoidCallback onStartDeviceLink;
  final VoidCallback onCancelDeviceLink;
  final VoidCallback onDeviceLinkAuthenticated;

  @override
  Widget build(BuildContext context) {
    if (androidTv) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 4, 2, 4),
            child: Text(
              'Link your Forja account with a code or QR on the portal. '
              'You can keep using Forja without an account.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          SettingsGroup(
            label: 'Sign in',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ForjaButton.primary(
                      label: 'Link with code or QR',
                      icon: Icons.tv_rounded,
                      onPressed: formLocked ? null : onTvDeviceLink,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsGroup(
            label: 'New here?',
            children: [
              SettingsActionRow(
                title: 'Create an account on the web',
                subtitle: 'Use a phone or computer - then link this TV',
                leading: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: ForjaShellColors.iconMuted,
                  size: 22,
                ),
                onTap: formLocked ? null : onOpenSignup,
              ),
            ],
          ),
        ],
      );
    }

    if (desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!deviceLinkActive)
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 4, 2, 4),
              child: Text(
                'Sign in to sync profiles and settings across devices. '
                'You can keep using Forja without an account.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          SettingsGroup(
            label: 'Sign in',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!deviceLinkActive) ...[
                      Text(
                        'Sign in with your phone or computer in under a minute.',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ForjaButton.primary(
                        label: 'Sign in',
                        icon: Icons.link_rounded,
                        onPressed: formLocked ? null : onStartDeviceLink,
                      ),
                    ] else
                      DeviceLinkConnectView(
                        compact: true,
                        onBack: onCancelDeviceLink,
                        onAuthenticated: onDeviceLinkAuthenticated,
                      ),
                  ],
                ),
              ),
            ],
          ),
          SettingsGroup(
            label: 'New here?',
            children: [
              SettingsActionRow(
                title: 'Create an account on the web',
                subtitle: 'Opens the Forja portal in your browser',
                leading: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: ForjaShellColors.iconMuted,
                  size: 22,
                ),
                onTap: formLocked ? null : onOpenSignup,
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: Text(
            'Sign in to sync profiles and settings across devices. '
            'You can keep using Forja without an account.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        SettingsGroup(
          label: 'Sign in',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsTextField(
                    controller: emailCtrl,
                    label: 'Email',
                    hint: 'you@example.com',
                    enabled: !formLocked,
                  ),
                  const SizedBox(height: 4),
                  SettingsTextField(
                    controller: passwordCtrl,
                    label: 'Password',
                    obscureText: true,
                    enabled: !formLocked,
                    onSubmitted:
                        canSubmitPassword ? (_) => onSignIn() : null,
                  ),
                  if (ForjaCaptcha.isConfigured)
                    IgnorePointer(
                      ignoring: formLocked,
                      child: Opacity(
                        opacity: formLocked ? 0.55 : 1,
                        child: TurnstileCaptcha(
                          key: ValueKey(captchaKey),
                          topPadding: 10,
                          onToken: onCaptchaToken,
                        ),
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ForjaButton.primary(
                        label: busy ? 'Signing in…' : 'Sign in',
                        icon: Icons.login_rounded,
                        busy: busy,
                        onPressed: canSubmitPassword ? onSignIn : null,
                      ),
                      if (showPasskey)
                        ForjaButton(
                          label: passkeyBusy
                              ? 'Waiting…'
                              : 'Sign in with passkey',
                          icon: Icons.fingerprint_rounded,
                          busy: passkeyBusy,
                          onPressed: canSubmitPasskey ? onPasskeyLogin : null,
                        ),
                      ForjaButton(
                        label: webBusy ? 'Cancel web login' : 'Web login',
                        icon: webBusy
                            ? Icons.close_rounded
                            : Icons.language_rounded,
                        onPressed: passwordLocked
                            ? null
                            : (webBusy ? onCancelWebLogin : onWebLogin),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'New here?',
          children: [
            SettingsActionRow(
              title: 'Create an account on the web',
              subtitle: 'Opens the Forja portal in your browser',
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: ForjaShellColors.iconMuted,
                size: 22,
              ),
              onTap: formLocked ? null : onOpenSignup,
            ),
          ],
        ),
      ],
    );
  }
}
