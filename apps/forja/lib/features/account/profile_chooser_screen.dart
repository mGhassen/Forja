import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/features/account/profile_chooser_metrics.dart';
import 'package:forja/features/account/profile_switch_splash.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
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
      // Fullscreen covers MainScreen's caption - wrap again for Win/Linux.
      builder: (context) => DesktopWindowChrome.wrapShell(
        child: ProfileChooserScreen(
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
    ),
  );
  return result == true;
}

/// Netflix-style profile picker: Who's watching? + Manage profiles.
class ProfileChooserScreen extends ConsumerStatefulWidget {
  const ProfileChooserScreen({
    super.key,
    required this.onProfileSelected,
    this.onSignOut,
    this.showBack = false,
    this.initialMode = ProfileChooserMode.choose,
    this.prepareCurrentOnSwitch = false,
    this.closeIfAlreadyActive = false,
    this.useLogoIntroSplash = false,
  });

  final VoidCallback onProfileSelected;
  final VoidCallback? onSignOut;
  final bool showBack;
  final ProfileChooserMode initialMode;

  /// Mid-session: push outgoing profile before loading the next.
  final bool prepareCurrentOnSwitch;

  /// When re-opening Who's watching, tapping the current profile just closes.
  final bool closeIfAlreadyActive;

  /// When true: select + merge only, then [onProfileSelected] (caller shows
  /// logo [SplashScreen]). Default false: show [ProfileSwitchSplash] first
  /// (cold sign-in and mid-session switches).
  final bool useLogoIntroSplash;

  @override
  ConsumerState<ProfileChooserScreen> createState() =>
      _ProfileChooserScreenState();
}

enum _Screen { choose, manage, create, edit }

class _ProfileChooserScreenState extends ConsumerState<ProfileChooserScreen> {
  String? _editingId;
  String? _error;
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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<SyncProfile> get _profiles =>
      ref.read(syncProfilesProvider).valueOrNull?.profiles ?? const [];

  String? get _activeProfileId =>
      ref.read(syncProfilesProvider).valueOrNull?.activeProfileId;

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

    if (widget.useLogoIntroSplash) {
      final ok = await _activateProfileForIntroSplash(profile);
      if (!mounted) return;
      if (ok) {
        widget.onProfileSelected();
        return;
      }
      setState(() {
        _busy = false;
        _error =
            'Could not open this profile. Check your connection and retry.';
      });
      return;
    }

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
          prepareCurrent: widget.prepareCurrentOnSwitch,
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

  /// Cold sign-in: bind the profile + merge settings only. Engine/catalog
  /// warm happens on the logo intro splash that follows.
  Future<bool> _activateProfileForIntroSplash(SyncProfile profile) async {
    try {
      final selected = await SyncService.instance.selectProfile(profile.id);
      if (!selected) return false;
      await ref
          .read(profileSettingsSyncProvider.notifier)
          .pullAndMergeForProfileSwitch();
      BootCache.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    SyncDomainBridge.instance.cancelPendingPushes();
    await SyncService.instance.signOut();
    if (!mounted) return;
    widget.onSignOut?.call();
  }

  void _beginCreate() {
    if (_profiles.length >= SyncService.maxProfilesPerAccount) {
      setState(() {
        _error = 'Maximum of 5 profiles per account.';
      });
      return;
    }
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
        // Push the outgoing profile before createProfile flips the active id.
        if (_activeProfileId != null) {
          await SyncDomainBridge.instance.prepareProfileSwitch();
        }
        final profile = await SyncService.instance.createProfile(
          name: _nameCtrl.text,
          avatarKey: _avatarKey,
        );
        // New profile must not inherit the previous profile's local prefs.
        await SyncDomainBridge.instance.seedNewProfileDefaults();
        if (!mounted) return;
        await ref.read(syncProfilesProvider.notifier).reload();
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
        if (!mounted) return;
        await ref.read(syncProfilesProvider.notifier).reload();
      }
      if (!mounted) return;
      setState(() {
        _screen = _Screen.manage;
        _editingId = null;
        _busy = false;
      });
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
      await ref.read(syncProfilesProvider.notifier).reload();
      if (!mounted) return;
      setState(() {
        _screen = _Screen.manage;
        _editingId = null;
        _busy = false;
      });
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

  /// Clears macOS traffic lights (MediaQuery top from [wrapShell]); Win/Linux
  /// caption sits above this screen so padding is already 0.
  static double _backTopInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return safeTop + (DesktopWindowChrome.isDesktop ? 8 : 10);
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(syncProfilesProvider);
    final snap = profilesAsync.valueOrNull;
    final profiles = snap?.profiles ?? const <SyncProfile>[];
    final activeProfileId = snap?.activeProfileId;
    final loading = profilesAsync.isLoading && !profilesAsync.hasValue;
    final loadError = profilesAsync.hasError
        ? (profilesAsync.error is SyncProfileFetchException
            ? (profilesAsync.error as SyncProfileFetchException).message
            : 'Could not load profiles. Check your connection and retry.')
        : null;
    final error = _error ?? loadError;

    // Cold sign-in / last profile deleted - jump straight into profile
    // creation. Mutating fields here (not via setState) is safe: we are
    // already mid-build and the widget tree below reflects the new screen.
    if (snap != null &&
        snap.profiles.isEmpty &&
        (_screen == _Screen.choose || _screen == _Screen.manage)) {
      _screen = _Screen.create;
      _editingId = null;
      _nameCtrl.text = '';
      _avatarKey = forjaProfileAvatarKeys.first;
    }

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
                        ? (profiles.isEmpty
                            ? 'Create your profile'
                            : 'Add profile')
                        : 'Edit profile',
                    nameController: _nameCtrl,
                    avatarKey: _avatarKey,
                    saving: _busy,
                    canDelete: _screen == _Screen.edit && profiles.length > 1,
                    canCancel: profiles.isNotEmpty || _screen == _Screen.edit,
                    error: _error,
                    onAvatarChange: (key) => setState(() => _avatarKey = key),
                    onSave: _saveEditor,
                    onDelete: _deleteEditing,
                    onCancel: () => setState(() {
                      _screen = profiles.isEmpty
                          ? _Screen.choose
                          : _Screen.manage;
                      _editingId = null;
                      _error = null;
                    }),
                  )
                : _buildChooserBody(profiles, activeProfileId, loading, error),
          ),
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

  Widget _buildChooserBody(
    List<SyncProfile> profiles,
    String? activeProfileId,
    bool loading,
    String? error,
  ) {
    final managing = _screen == _Screen.manage;
    final activeIndex = profiles.indexWhere((p) => p.id == activeProfileId);
    final autofocusIndex = activeIndex >= 0 ? activeIndex : 0;
    final showAdd = (managing || profiles.isEmpty) &&
        profiles.length < SyncService.maxProfilesPerAccount;
    final metrics = ProfileChooserMetrics.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return TvOverlayScope(
          debugLabel: 'profile-chooser',
          autofocusFirst: false,
          child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.horizontalPadding,
                vertical: metrics.verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: math.max(
                    0,
                    constraints.maxHeight - metrics.verticalPadding * 2,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          managing ? 'Manage profiles' : 'Who’s watching?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ForjaShellColors.textPrimary,
                            fontSize: metrics.titleFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: metrics.isTv ? 8 : 12),
                        Text(
                          loading
                              ? 'Loading profiles…'
                              : error != null
                                  ? 'Could not load who’s watching right now.'
                                  : profiles.isEmpty
                                      ? 'Create a profile to sync settings on this device.'
                                      : managing
                                          ? 'Edit a profile or add a new one.'
                                          : 'Choose the profile whose settings you want on this device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: metrics.subtitleFontSize,
                          ),
                        ),
                        SizedBox(height: metrics.sectionGap),
                        if (loading)
                          Padding(
                            padding: EdgeInsets.all(metrics.isTv ? 28 : 48),
                            child: const CircularProgressIndicator(),
                          )
                        else if (error != null && profiles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ChooserAction(
                                  autofocus: true,
                                  label: 'Retry',
                                  primary: true,
                                  onTap: _busy
                                      ? null
                                      : () => ref
                                          .read(syncProfilesProvider.notifier)
                                          .reload(),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: metrics.tileSpacing,
                            runSpacing: metrics.tileSpacing,
                            children: [
                              for (var i = 0; i < profiles.length; i++)
                                _ProfileChoice(
                                  profile: profiles[i],
                                  metrics: metrics,
                                  active: profiles[i].id == activeProfileId,
                                  managing: managing,
                                  enabled: !_busy,
                                  autofocus: !_busy && i == autofocusIndex,
                                  onTap: (originRect) {
                                    final profile = profiles[i];
                                    if (managing) {
                                      _beginEdit(profile);
                                    } else {
                                      _select(profile, originRect: originRect);
                                    }
                                  },
                                ),
                              if (showAdd)
                                _AddProfileTile(
                                  metrics: metrics,
                                  enabled: !_busy,
                                  autofocus: !_busy && profiles.isEmpty,
                                  onTap: _beginCreate,
                                ),
                            ],
                          ),
                        if (error != null && profiles.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ChooserAction(
                            label: 'Retry',
                            primary: true,
                            onTap: _busy
                                ? null
                                : () => ref
                                    .read(syncProfilesProvider.notifier)
                                    .reload(),
                          ),
                        ],
                        SizedBox(height: metrics.sectionGap),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (profiles.isNotEmpty)
                              _ChooserAction(
                                label: managing ? 'Done' : 'Manage profiles',
                                onTap: _busy
                                    ? null
                                    : () => setState(() {
                                          _screen = managing
                                              ? _Screen.choose
                                              : _Screen.manage;
                                          _error = null;
                                        }),
                              ),
                            if (widget.showBack && profiles.isNotEmpty)
                              _ChooserAction(
                                label: 'Account settings',
                                onTap: _busy
                                    ? null
                                    : () {
                                        ShellBus.requestTab.value = 'settings';
                                        Navigator.of(context).pop(false);
                                      },
                              ),
                            if (widget.onSignOut != null)
                              _ChooserAction(
                                label: 'Use another account',
                                onTap: _busy ? null : _signOut,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        );
      },
    );
  }
}

/// TV/desktop action under Who’s watching - D-pad via [FocusableControl].
/// Plain text link: hover/focus scales + bolds - no outline border.
class _ChooserAction extends StatefulWidget {
  const _ChooserAction({
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool primary;

  @override
  State<_ChooserAction> createState() => _ChooserActionState();
}

class _ChooserActionState extends State<_ChooserAction> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && (_focused || _hovered);
    final fg = widget.primary
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.textPrimary;
    return ExcludeFocus(
      excluding: !enabled,
      child: FocusableControl(
        autoFocus: widget.autofocus && enabled,
        onTap: widget.onTap,
        borderRadius: 8,
        scaleOnFocus: 1.06,
        showFocusBorder: false,
        showFocusFill: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              widget.label,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProfileTile extends StatefulWidget {
  const _AddProfileTile({
    required this.metrics,
    required this.enabled,
    required this.onTap,
    this.autofocus = false,
  });

  final ProfileChooserMetrics metrics;
  final bool enabled;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_AddProfileTile> createState() => _AddProfileTileState();
}

class _AddProfileTileState extends State<_AddProfileTile> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || _hovered;
    final m = widget.metrics;
    return ExcludeFocus(
      excluding: !widget.enabled,
      child: FocusableControl(
        autoFocus: widget.autofocus && widget.enabled,
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: 8,
        scaleOnFocus: 1.06,
        showFocusBorder: false,
        showFocusFill: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: SizedBox(
          width: m.tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: m.avatarSize,
                height: m.avatarSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.5),
                  border: Border.all(
                    color: highlighted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: m.avatarSize * 0.5,
                  color: highlighted
                      ? ForjaShellColors.textPrimary
                      : ForjaShellColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add profile',
                style: TextStyle(
                  color: highlighted
                      ? ForjaShellColors.textPrimary
                      : ForjaShellColors.textSecondary,
                  fontSize: m.isTv ? 13 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileChoice extends StatefulWidget {
  const _ProfileChoice({
    required this.profile,
    required this.metrics,
    required this.active,
    required this.managing,
    required this.enabled,
    required this.onTap,
    this.autofocus = false,
  });

  final SyncProfile profile;
  final ProfileChooserMetrics metrics;
  final bool active;
  final bool managing;
  final bool enabled;
  final bool autofocus;
  final void Function(Rect? avatarOrigin) onTap;

  @override
  State<_ProfileChoice> createState() => _ProfileChoiceState();
}

class _ProfileChoiceState extends State<_ProfileChoice> {
  final GlobalKey _avatarKey = GlobalKey();
  bool _focused = false;
  bool _hovered = false;

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
    final highlighted = _focused || _hovered;
    final selected = highlighted || (!widget.managing && widget.active);
    final m = widget.metrics;
    return ExcludeFocus(
      excluding: !widget.enabled,
      child: FocusableControl(
        autoFocus: widget.autofocus && widget.enabled,
        onTap: widget.enabled ? _handleTap : null,
        borderRadius: 8,
        scaleOnFocus: 1.06,
        // Avatar [ForjaProfileAvatar.selected] is the hover/focus cue -
        // never a tile-wide FocusableControl ring around name + avatar.
        showFocusBorder: false,
        showFocusFill: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: SizedBox(
          width: m.tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: _avatarKey,
                child: ForjaProfileAvatar(
                  avatarKey: widget.profile.avatarKey,
                  name: widget.profile.name,
                  size: m.avatarSize,
                  selected: selected,
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
                  color: selected
                      ? ForjaShellColors.textPrimary
                      : ForjaShellColors.textSecondary,
                  fontSize: m.isTv ? 13 : 15,
                  fontWeight: (!widget.managing && widget.active)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
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
