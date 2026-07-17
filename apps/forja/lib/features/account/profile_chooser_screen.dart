import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';

class ProfileChooserScreen extends StatefulWidget {
  const ProfileChooserScreen({
    super.key,
    required this.onProfileSelected,
    this.onSignOut,
    this.showBack = false,
  });

  final VoidCallback onProfileSelected;
  final VoidCallback? onSignOut;
  final bool showBack;

  @override
  State<ProfileChooserScreen> createState() => _ProfileChooserScreenState();
}

class _ProfileChooserScreenState extends State<ProfileChooserScreen> {
  List<SyncProfile> _profiles = const [];
  String? _activeProfileId;
  String? _selectingProfileId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final profiles = await SyncService.instance.listProfiles();
    final active = await SyncService.instance.activeProfile();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfileId = active?.id;
      _loading = false;
      if (profiles.isEmpty) {
        _error = 'No profiles were found for this account.';
      }
    });
  }

  Future<void> _select(SyncProfile profile) async {
    if (_selectingProfileId != null) return;
    setState(() {
      _selectingProfileId = profile.id;
      _error = null;
    });
    try {
      final selected = await SyncService.instance.selectProfile(profile.id);
      if (!selected) {
        throw StateError('The profile is no longer available.');
      }
      await SyncDomainBridge.instance.pullAndMergeAll();
      if (!mounted) return;
      widget.onProfileSelected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectingProfileId = null;
        _error =
            'Could not open this profile. Check your connection and retry.';
      });
    }
  }

  Future<void> _signOut() async {
    if (_selectingProfileId != null) return;
    await SyncService.instance.signOut();
    if (!mounted) return;
    widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: widget.showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: ForjaShellColors.textPrimary,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  const Text(
                    'Who’s watching?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose the profile whose settings you want on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 28,
                          runSpacing: 28,
                          children: [
                            for (final profile in _profiles)
                              _ProfileChoice(
                                profile: profile,
                                active: profile.id == _activeProfileId,
                                busy: profile.id == _selectingProfileId,
                                enabled: _selectingProfileId == null,
                                onTap: () => _select(profile),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _selectingProfileId == null ? _load : null,
                      child: const Text('Retry'),
                    ),
                  ],
                  const Spacer(),
                  if (widget.onSignOut != null)
                    TextButton(
                      onPressed: _selectingProfileId == null ? _signOut : null,
                      child: const Text('Use another account'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileChoice extends StatefulWidget {
  const _ProfileChoice({
    required this.profile,
    required this.active,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final SyncProfile profile;
  final bool active;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ProfileChoice> createState() => _ProfileChoiceState();
}

class _ProfileChoiceState extends State<_ProfileChoice> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _focused;
    return FocusableActionDetector(
      enabled: widget.enabled,
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: highlighted ? 1.06 : 1,
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 132,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ForjaProfileAvatar(
                      avatarKey: widget.profile.avatarKey,
                      name: widget.profile.name,
                      size: 112,
                      selected: highlighted || widget.active,
                    ),
                    if (widget.busy)
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: highlighted
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                    fontSize: 15,
                    fontWeight: widget.active
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
