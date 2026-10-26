import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/account/tv_account_link_screen.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shared/navigation/shell_back_icon_button.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Fullscreen account switch / add / remove (same role as Who's watching).
Future<bool> presentAccountChooser(BuildContext context) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          DesktopWindowChrome.wrapShell(child: const AccountChooserScreen()),
    ),
  );
  return result == true;
}

class AccountChooserScreen extends StatefulWidget {
  const AccountChooserScreen({super.key});

  @override
  State<AccountChooserScreen> createState() => _AccountChooserScreenState();
}

class _AccountChooserScreenState extends State<AccountChooserScreen> {
  List<DeviceAccountSession> _accounts = const [];
  bool _busy = false;
  String? _error;

  /// Portal-style two-step remove: first tap arms, Yes commits.
  String? _confirmRemoveUserId;

  String? get _activeUserId => SyncService.instance.userId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final accounts = await SyncService.instance.listDeviceAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _confirmRemoveUserId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load saved accounts.');
    }
  }

  Future<void> _switchTo(String userId) async {
    if (_busy || userId == _activeUserId) {
      if (userId == _activeUserId && mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _confirmRemoveUserId = null;
    });
    SyncDomainBridge.instance.cancelPendingPushes();
    try {
      final ok = await SyncService.instance.switchAccount(userId);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = 'Could not switch account. Sign in again for that user.';
          _busy = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addViaQr() async {
    if (_busy) return;
    if (_accounts.length >= SyncService.maxDeviceAccounts) {
      setState(() {
        _error =
            'Maximum of ${SyncService.maxDeviceAccounts} accounts on this device.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _confirmRemoveUserId = null;
    });
    SyncDomainBridge.instance.cancelPendingPushes();
    final previous = await SyncService.instance.prepareAddAccount();
    if (!mounted) {
      await SyncService.instance.completeAddAccount(
        previous: previous,
        success: false,
      );
      return;
    }
    try {
      final linked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => TvAccountLinkScreen(
            allowContinueAsGuest: false,
            onAuthenticated: () => Navigator.of(context).pop(true),
            onContinueAsGuest: () => Navigator.of(context).pop(false),
          ),
        ),
      );
      final success = linked == true && SyncService.instance.isSignedIn;
      await SyncService.instance.completeAddAccount(
        previous: previous,
        success: success,
      );
      if (!mounted) return;
      if (!success) {
        await _reload();
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      await SyncService.instance.completeAddAccount(
        previous: previous,
        success: false,
      );
      if (!mounted) return;
      setState(() => _error = 'Could not add account. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _armRemove(String userId) {
    if (_busy) return;
    setState(() => _confirmRemoveUserId = userId);
  }

  void _cancelRemove() {
    setState(() => _confirmRemoveUserId = null);
  }

  Future<void> _commitRemove(String userId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _confirmRemoveUserId = null;
    });
    try {
      await SyncService.instance.removeDeviceAccount(userId);
      if (!mounted) return;
      if (!SyncService.instance.isSignedIn) {
        Navigator.of(context).pop(true);
        return;
      }
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _confirmRemoveUserId = null;
    });
    SyncDomainBridge.instance.cancelPendingPushes();
    try {
      await SyncService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _activeUserId;
    final atCap = _accounts.length >= SyncService.maxDeviceAccounts;
    DeviceAccountSession? active;
    final others = <DeviceAccountSession>[];
    for (final a in _accounts) {
      if (a.userId == activeId) {
        active = a;
      } else {
        others.add(a);
      }
    }
    final activeEmail = active?.email.isNotEmpty == true
        ? active!.email
        : (SyncService.instance.userEmail ?? 'Signed in');
    final addEnabled = !_busy && !atCap;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ShellBackIconButton(
          icon: Icons.arrow_back_rounded,
          size: 28,
          tooltip: 'Back',
          onTap: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Accounts',
          style: TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: SettingsTokens.typeSizeOf(context, 18),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth * 0.4;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              // Always on — desktop arrow keys / gamepad need the same graph as TV.
              child: TvOverlayScope(
                debugLabel: 'account-chooser',
                enabled: true,
                autofocusFirst: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
                  children: [
                    Text(
                      'Who’s signed in?',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: SettingsTokens.typeSizeOf(context, 28),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Switch accounts on this device, or add another with QR / code.',
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: SettingsTokens.typeSizeOf(context, 14),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: const Color(0xFFF87171),
                            fontSize: SettingsTokens.typeSizeOf(context, 13),
                          ),
                        ),
                      ),
                    SettingsGroup(
                      label: 'Active',
                      children: [
                        SettingsStatusRow(
                          title: activeEmail,
                          subtitle: 'Active now',
                          icon: Icons.check_circle_rounded,
                          iconColor: ForjaShellColors.brandGreen,
                        ),
                      ],
                    ),
                    if (others.isNotEmpty)
                      SettingsGroup(
                        label: 'Other accounts',
                        children: [
                          for (final account in others)
                            _OtherAccountFocusRow(
                              email: account.email.isEmpty
                                  ? account.userId
                                  : account.email,
                              confirming:
                                  _confirmRemoveUserId == account.userId,
                              busy: _busy,
                              onSwitch: () =>
                                  unawaited(_switchTo(account.userId)),
                              onArmRemove: () => _armRemove(account.userId),
                              onConfirmRemove: () =>
                                  unawaited(_commitRemove(account.userId)),
                              onCancelRemove: _cancelRemove,
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ChooserCta(
                            label: 'Add account',
                            icon: Icons.qr_code_2_rounded,
                            autofocus: true,
                            enabled: addEnabled,
                            tone: _ChooserCtaTone.primary,
                            onTap: () => unawaited(_addViaQr()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ChooserCta(
                            label: 'Sign out',
                            icon: Icons.logout_rounded,
                            enabled: !_busy,
                            tone: _ChooserCtaTone.danger,
                            onTap: () => unawaited(_signOut()),
                          ),
                        ),
                      ],
                    ),
                    if (atCap) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Maximum of ${SyncService.maxDeviceAccounts} accounts on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: SettingsTokens.typeSizeOf(context, 12.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ChooserCtaTone { primary, danger }

/// Big CTA — [FocusableControl] so D-pad / arrows land here (not TextButton).
class _ChooserCta extends StatefulWidget {
  const _ChooserCta({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tone,
    this.enabled = true,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final _ChooserCtaTone tone;
  final bool enabled;
  final bool autofocus;

  @override
  State<_ChooserCta> createState() => _ChooserCtaState();
}

class _ChooserCtaState extends State<_ChooserCta> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = widget.tone == _ChooserCtaTone.danger;
    final restBorder = danger
        ? const Color(0xFFF87171)
        : ForjaShellColors.ghostBorder;
    final restFg = danger
        ? const Color(0xFFF87171)
        : ForjaShellColors.textPrimary;

    return ExcludeFocus(
      excluding: !widget.enabled,
      child: FocusableControl(
        autoFocus: widget.autofocus && widget.enabled,
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: SettingsTokens.categoryTileRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) {
          if (_hoveredN.value == h) return;
          _hoveredN.value = h;
        },
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final engaged =
                widget.enabled &&
                ShellInputPolicy.interactiveActive(
                  ShellScope.inputPolicyOf(context),
                  hovered: _hoveredN.value,
                  focused: _focused,
                  context: context,
                );
            final fg = engaged
                ? (danger
                      ? const Color(0xFFFCA5A5)
                      : ForjaShellColors.brandGreen)
                : restFg;
            final border = engaged
                ? (danger
                      ? const Color(0xFFFCA5A5)
                      : ForjaShellColors.brandGreen)
                : restBorder;
            final fill = engaged
                ? (danger
                      ? const Color(0xFFF87171).withValues(alpha: 0.12)
                      : ForjaShellColors.brandGreen.withValues(alpha: 0.12))
                : Colors.white.withValues(alpha: 0.03);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 52,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(
                  SettingsTokens.categoryTileRadius,
                ),
                border: Border.all(color: border, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Other-account row: switch on the rail; X / Yes / No nested inside the same
/// hover strip (portal-style [allowNestedFocus] + Right → action).
class _OtherAccountFocusRow extends StatefulWidget {
  const _OtherAccountFocusRow({
    required this.email,
    required this.confirming,
    required this.busy,
    required this.onSwitch,
    required this.onArmRemove,
    required this.onConfirmRemove,
    required this.onCancelRemove,
  });

  final String email;
  final bool confirming;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback onArmRemove;
  final VoidCallback onConfirmRemove;
  final VoidCallback onCancelRemove;

  @override
  State<_OtherAccountFocusRow> createState() => _OtherAccountFocusRowState();
}

class _OtherAccountFocusRowState extends State<_OtherAccountFocusRow> {
  final FocusNode _rowFocus = FocusNode(debugLabel: 'account_row');
  final FocusNode _removeFocus = FocusNode(debugLabel: 'account_remove');
  final FocusNode _yesFocus = FocusNode(debugLabel: 'account_remove_yes');
  final FocusNode _noFocus = FocusNode(debugLabel: 'account_remove_no');

  @override
  void didUpdateWidget(covariant _OtherAccountFocusRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.confirming && widget.confirming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _yesFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _rowFocus.dispose();
    _removeFocus.dispose();
    _yesFocus.dispose();
    _noFocus.dispose();
    super.dispose();
  }

  void _focusAction(FocusNode node) {
    if (!node.canRequestFocus) return;
    node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = SettingsTokens.iconButtonIconSizeOf(context);
    final title = widget.confirming ? 'Remove this account?' : widget.email;
    final subtitle = widget.confirming ? widget.email : 'Tap to switch';
    final titleColor = widget.confirming
        ? const Color(0xFFF87171)
        : ForjaShellColors.textPrimary;

    return FocusableControl(
      focusNode: _rowFocus,
      allowNestedFocus: true,
      onTap: widget.busy || widget.confirming ? null : widget.onSwitch,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      showFocusBorder: false,
      showFocusFill: false,
      onRightEdge: widget.busy
          ? null
          : () => _focusAction(widget.confirming ? _yesFocus : _removeFocus),
      child: Padding(
        padding: SettingsTokens.rowPaddingOf(context),
        child: Row(
          children: [
            Icon(
              widget.confirming
                  ? Icons.delete_outline_rounded
                  : Icons.account_circle_outlined,
              color: widget.confirming
                  ? const Color(0xFFF87171)
                  : ForjaShellColors.iconMuted,
              size: iconSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: SettingsTokens.typeSizeOf(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: SettingsTokens.rowTitleSubtitleGapOf(context),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: SettingsTokens.typeSizeOf(context, 12),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ForjaShellColors.brandGreen,
                ),
              )
            else if (widget.confirming) ...[
              _GlyphAction(
                focusNode: _yesFocus,
                icon: Icons.check_rounded,
                restColor: const Color(0xFFEF4444),
                tooltip: 'Yes',
                onTap: widget.onConfirmRemove,
                onLeftEdge: () => _focusAction(_rowFocus),
                onRightEdge: () => _focusAction(_noFocus),
              ),
              _GlyphAction(
                focusNode: _noFocus,
                icon: Icons.close_rounded,
                restColor: ForjaShellColors.iconMuted,
                tooltip: 'No',
                onTap: widget.onCancelRemove,
                onLeftEdge: () => _focusAction(_yesFocus),
              ),
            ] else
              _GlyphAction(
                focusNode: _removeFocus,
                icon: Icons.close_rounded,
                restColor: ForjaShellColors.iconMuted,
                tooltip: 'Remove from this device',
                onTap: widget.onArmRemove,
                onLeftEdge: () => _focusAction(_rowFocus),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only action: hover/focus → green glyph, no fill/box.
class _GlyphAction extends StatefulWidget {
  const _GlyphAction({
    required this.focusNode,
    required this.icon,
    required this.restColor,
    required this.tooltip,
    required this.onTap,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final FocusNode focusNode;
  final IconData icon;
  final Color restColor;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_GlyphAction> createState() => _GlyphActionState();
}

class _GlyphActionState extends State<_GlyphAction> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = SettingsTokens.iconButtonIconSizeOf(context);
    return Tooltip(
      message: widget.tooltip,
      child: FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: 1.0,
        showFocusBorder: false,
        showFocusFill: false,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) {
          if (_hoveredN.value == h) return;
          _hoveredN.value = h;
        },
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final engaged = ShellInputPolicy.interactiveActive(
              ShellScope.inputPolicyOf(context),
              hovered: _hoveredN.value,
              focused: _focused,
              context: context,
            );
            return SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                widget.icon,
                size: size,
                color: engaged ? ForjaShellColors.brandGreen : widget.restColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
