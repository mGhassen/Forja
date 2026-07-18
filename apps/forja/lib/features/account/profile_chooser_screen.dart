import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/profile_engine_warm.dart';
import 'package:forja/features/account/profile_switch_splash.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ProfileChooserMode { choose, manage }

/// Opens the Netflix-style Who's watching / Manage profiles flow fullscreen.
Future<bool> presentProfileChooser(
  BuildContext context, {
  ProfileChooserMode initialMode = ProfileChooserMode.choose,
  bool prepareCurrentOnSwitch = true,
  bool allowSignOut = false,
  bool closeIfAlreadyActive = false,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => ProfileChooserScreen(
        showBack: true,
        initialMode: initialMode,
        prepareCurrentOnSwitch: prepareCurrentOnSwitch,
        closeIfAlreadyActive: closeIfAlreadyActive,
        onProfileSelected: () => Navigator.of(context).pop(true),
        onSignOut: allowSignOut
            ? () {
                Navigator.of(context).pop(false);
              }
            : null,
      ),
    ),
  );
  return result == true;
}

/// Netflix-style profile picker: Who's watching? + Manage profiles.
class ProfileChooserScreen extends StatefulWidget {
  const ProfileChooserScreen({
    super.key,
    required this.onProfileSelected,
    this.onSignOut,
    this.showBack = false,
    this.initialMode = ProfileChooserMode.choose,
    this.prepareCurrentOnSwitch = false,
    this.closeIfAlreadyActive = false,
  });

  final VoidCallback onProfileSelected;
  final VoidCallback? onSignOut;
  final bool showBack;
  final ProfileChooserMode initialMode;

  /// Mid-session switches: push outgoing profile + show [ProfileSwitchSplash].
  /// Fresh sign-in / cold-start: false → silent select+pull, then caller splash.
  final bool prepareCurrentOnSwitch;

  /// When re-opening Who's watching, tapping the current profile just closes.
  final bool closeIfAlreadyActive;

  @override
  State<ProfileChooserScreen> createState() => _ProfileChooserScreenState();
}

enum _Screen { choose, manage, create, edit }

class _ProfileChooserScreenState extends State<ProfileChooserScreen> {
  List<SyncProfile> _profiles = const [];
  String? _activeProfileId;
  String? _editingId;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  late _Screen _screen;

  final _nameCtrl = TextEditingController();
  String _avatarKey = 'forge';

  @override
  void initState() {
    super.initState();
    _screen = widget.initialMode == ProfileChooserMode.manage
        ? _Screen.manage
        : _Screen.choose;
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool openCreateWhenEmpty = true}) async {
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
      if (profiles.isEmpty && openCreateWhenEmpty) {
        _screen = _Screen.create;
        _editingId = null;
        _nameCtrl.text = '';
        _avatarKey = forjaProfileAvatarKeys.first;
      }
    });
  }

  Future<void> _select(SyncProfile profile, {Rect? originRect}) async {
    if (_busy) return;
    if (widget.closeIfAlreadyActive && profile.id == _activeProfileId) {
      widget.onProfileSelected();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // Fresh sign-in / cold-start: activate + pull, then continue to intro splash.
    // Profile-switch animation is mid-session only (prepareCurrentOnSwitch).
    if (!widget.prepareCurrentOnSwitch) {
      try {
        final selected =
            await SyncService.instance.selectProfile(profile.id);
        if (!selected) {
          throw StateError('Profile unavailable');
        }
        await SyncDomainBridge.instance.pullAndMergeAll();
        // Intro splash will warm again (idempotent). Prefetch so BootNeeds
        // matches this profile before SplashScreen mounts.
        final needs = await BootNeeds.resolve();
        await ProfileEngineWarm.warm(
          needs,
          startTorrent: false,
          reason: 'cold-profile',
        );
        if (!mounted) return;
        widget.onProfileSelected();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              'Could not open this profile. Check your connection and retry.';
        });
      }
      return;
    }

    // Map avatar globals into the overlay space the fullscreen splash uses.
    Rect? splashOrigin = originRect;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (originRect != null &&
        overlayBox != null &&
        overlayBox.hasSize &&
        overlayBox.attached) {
      final localTopLeft = overlayBox.globalToLocal(originRect.topLeft);
      splashOrigin = localTopLeft & originRect.size;
    }

    final ok = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProfileSwitchSplash(
          profile: profile,
          originRect: splashOrigin,
          prepareCurrent: true,
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      widget.onProfileSelected();
      return;
    }
    setState(() {
      _busy = false;
      _error =
          'Could not open this profile. Check your connection and retry.';
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    SyncDomainBridge.instance.cancelPendingPushes();
    await SyncService.instance.signOut();
    if (!mounted) return;
    widget.onSignOut?.call();
  }

  void _beginCreate() {
    final keys = forjaProfileAvatarKeys;
    setState(() {
      _screen = _Screen.create;
      _editingId = null;
      _nameCtrl.text = '';
      _avatarKey = keys[_profiles.length % keys.length];
      _error = null;
    });
  }

  void _beginEdit(SyncProfile profile) {
    setState(() {
      _screen = _Screen.edit;
      _editingId = profile.id;
      _nameCtrl.text = profile.name;
      _avatarKey = normalizeForjaAvatarKey(profile.avatarKey);
      _error = null;
    });
  }

  Future<void> _saveEditor() async {
    if (_busy) return;
    final creatingFirst = _screen == _Screen.create && _profiles.isEmpty;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_screen == _Screen.create) {
        final profile = await SyncService.instance.createProfile(
          name: _nameCtrl.text,
          avatarKey: _avatarKey,
        );
        if (!mounted) return;
        if (creatingFirst) {
          setState(() => _busy = false);
          await _select(profile);
          return;
        }
      } else if (_editingId != null) {
        await SyncService.instance.updateProfile(
          profileId: _editingId!,
          name: _nameCtrl.text,
          avatarKey: _avatarKey,
        );
      }
      if (!mounted) return;
      setState(() {
        _screen = _Screen.manage;
        _editingId = null;
        _busy = false;
      });
      await _load(openCreateWhenEmpty: false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save profile.';
      });
    }
  }

  Future<void> _deleteEditing() async {
    if (_busy || _editingId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SyncService.instance.deleteProfile(_editingId!);
      if (!mounted) return;
      setState(() {
        _screen = _Screen.manage;
        _editingId = null;
        _busy = false;
      });
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not delete profile.';
      });
    }
  }

  /// Sits below macOS traffic lights (and desktop caption), not beside them.
  static double _backTopInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final chromeTop = DesktopWindowChrome.isDesktop
        ? DesktopWindowChrome.topInset(context)
        : 0.0;
    return math.max(safeTop, chromeTop) + (DesktopWindowChrome.isDesktop ? 8 : 10);
  }

  @override
  Widget build(BuildContext context) {
    final showChromeBack = widget.showBack &&
        (_screen == _Screen.choose || _screen == _Screen.manage);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          SafeArea(
            child: _screen == _Screen.create || _screen == _Screen.edit
                ? _ProfileEditor(
                    title: _screen == _Screen.create
                        ? (_profiles.isEmpty
                            ? 'Create your profile'
                            : 'Add profile')
                        : 'Edit profile',
                    nameController: _nameCtrl,
                    avatarKey: _avatarKey,
                    saving: _busy,
                    canDelete: _screen == _Screen.edit && _profiles.length > 1,
                    canCancel: _profiles.isNotEmpty || _screen == _Screen.edit,
                    error: _error,
                    onAvatarChange: (key) => setState(() => _avatarKey = key),
                    onSave: _saveEditor,
                    onDelete: _deleteEditing,
                    onCancel: () => setState(() {
                      _screen = _profiles.isEmpty
                          ? _Screen.choose
                          : _Screen.manage;
                      _editingId = null;
                      _error = null;
                    }),
                  )
                : _buildChooserBody(),
          ),
          DesktopWindowChrome.overlayDragStrip(),
          if (showChromeBack)
            Positioned(
              top: _backTopInset(context),
              left: 12,
              child: ShellBackIconButton(
                icon: Icons.arrow_back_rounded,
                size: 28,
                tooltip: 'Back',
                onTap: () {
                  if (_busy) return;
                  Navigator.of(context).maybePop();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChooserBody() {
    final managing = _screen == _Screen.manage;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                managing ? 'Manage profiles' : 'Who’s watching?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _profiles.isEmpty
                    ? 'Create a profile to sync settings on this device.'
                    : managing
                        ? 'Edit a profile or add a new one.'
                        : 'Choose the profile whose settings you want on this device.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                            managing: managing,
                            enabled: !_busy,
                            onTap: (originRect) {
                              if (managing) {
                                _beginEdit(profile);
                              } else {
                                _select(profile, originRect: originRect);
                              }
                            },
                          ),
                        if (managing || _profiles.isEmpty)
                          _AddProfileTile(
                            enabled: !_busy,
                            onTap: _beginCreate,
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
                  onPressed: _busy
                      ? null
                      : () => _load(openCreateWhenEmpty: false),
                  child: const Text('Retry'),
                ),
              ],
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_profiles.isNotEmpty)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _screen = managing
                                    ? _Screen.choose
                                    : _Screen.manage;
                                _error = null;
                              }),
                      child: Text(managing ? 'Done' : 'Manage profiles'),
                    ),
                  if (widget.showBack && _profiles.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              ShellBus.requestTab.value = 'settings';
                              Navigator.of(context).pop(false);
                            },
                      child: const Text('Account settings'),
                    ),
                  if (widget.onSignOut != null)
                    TextButton(
                      onPressed: _busy ? null : _signOut,
                      child: const Text('Use another account'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileTile extends StatefulWidget {
  const _AddProfileTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AddProfileTile> createState() => _AddProfileTileState();
}

class _AddProfileTileState extends State<_AddProfileTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: widget.enabled,
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
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
          scale: _hovered ? 1.06 : 1,
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 132,
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.5),
                    border: Border.all(
                      color: _hovered
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 56,
                    color: _hovered
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add profile',
                  style: TextStyle(
                    color: _hovered
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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

class _ProfileChoice extends StatefulWidget {
  const _ProfileChoice({
    required this.profile,
    required this.active,
    required this.managing,
    required this.enabled,
    required this.onTap,
  });

  final SyncProfile profile;
  final bool active;
  final bool managing;
  final bool enabled;
  final void Function(Rect? avatarOrigin) onTap;

  @override
  State<_ProfileChoice> createState() => _ProfileChoiceState();
}

class _ProfileChoiceState extends State<_ProfileChoice> {
  final GlobalKey _avatarKey = GlobalKey();
  bool _hovered = false;
  bool _focused = false;

  Rect? _avatarOriginRect() {
    final box = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onTap(_avatarOriginRect());
  }

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
            _handleTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.enabled ? _handleTap : null,
        child: AnimatedScale(
          scale: highlighted ? 1.06 : 1,
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 132,
            child: Column(
              children: [
                KeyedSubtree(
                  key: _avatarKey,
                  child: ForjaProfileAvatar(
                    avatarKey: widget.profile.avatarKey,
                    name: widget.profile.name,
                    size: 112,
                    selected: highlighted ||
                        (!widget.managing && widget.active),
                    editing: widget.managing,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: highlighted || (!widget.managing && widget.active)
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.textSecondary,
                    fontSize: 15,
                    fontWeight: (!widget.managing && widget.active)
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

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.title,
    required this.nameController,
    required this.avatarKey,
    required this.saving,
    required this.canDelete,
    this.canCancel = true,
    required this.error,
    required this.onAvatarChange,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  final String title;
  final TextEditingController nameController;
  final String avatarKey;
  final bool saving;
  final bool canDelete;
  final bool canCancel;
  final String? error;
  final ValueChanged<String> onAvatarChange;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onName);
  }

  @override
  void didUpdateWidget(covariant _ProfileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nameController != widget.nameController) {
      oldWidget.nameController.removeListener(_onName);
      widget.nameController.addListener(_onName);
    }
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onName);
    super.dispose();
  }

  void _onName() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final name = widget.nameController.text.trim();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: ForjaShellColors.borderSubtle),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ForjaProfileAvatar(
                    avatarKey: widget.avatarKey,
                    name: name.isEmpty ? 'New profile' : name,
                    size: 140,
                    selected: true,
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: widget.nameController,
                          autofocus: true,
                          maxLength: 40,
                          enabled: !widget.saving,
                          decoration: const InputDecoration(
                            labelText: 'Profile name',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'CHOOSE AN AVATAR',
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final category in forjaProfileAvatarCategories) ...[
                          Text(
                            category.label,
                            style: const TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final key in category.keys)
                                GestureDetector(
                                  onTap: widget.saving
                                      ? null
                                      : () => widget.onAvatarChange(key),
                                  child: ForjaProfileAvatar(
                                    avatarKey: key,
                                    name: key,
                                    size: 56,
                                    selected: key == widget.avatarKey,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        widget.saving || name.isEmpty ? null : widget.onSave,
                    child: Text(widget.saving ? 'Saving…' : 'Save profile'),
                  ),
                  if (widget.canCancel)
                    OutlinedButton(
                      onPressed: widget.saving ? null : widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  if (widget.canDelete)
                    TextButton(
                      onPressed: widget.saving ? null : widget.onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Delete profile'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
