import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// One chip in [AccountRail] — props only, no vault / auth knowledge.
@immutable
class AccountRailItem {
  const AccountRailItem({
    required this.userId,
    required this.label,
    this.needsSignIn = false,
  });

  final String userId;
  final String label;

  /// Refresh token rejected — the chip says so and switching asks to sign in.
  final bool needsSignIn;
}

/// Row of accounts remembered on this device (RFC-124).
///
/// D-pad / keyboard focus only highlights a chip; OK / Enter / click runs
/// [onSwitch] (or [onRemove] while [managing]). The row is its own
/// [FocusTraversalGroup] so ← / → stay inside it.
class AccountRail extends StatelessWidget {
  const AccountRail({
    super.key,
    required this.accounts,
    required this.activeUserId,
    required this.onSwitch,
    this.onAdd,
    this.onRemove,
    this.managing = false,
    this.enabled = true,
    this.addLabel = 'Add account',
    this.switchPrefix,
  });

  final List<AccountRailItem> accounts;
  final String? activeUserId;
  final ValueChanged<String> onSwitch;

  /// When null the "Add account" chip is not shown (cap reached / no sign-in
  /// path on this screen).
  final VoidCallback? onAdd;
  final ValueChanged<String>? onRemove;
  final bool managing;
  final bool enabled;
  final String addLabel;

  /// Chip prefix such as "Continue as" on the cold-start gate.
  final String? switchPrefix;

  static const String removeLabel = 'Remove from this device';
  static const String activeLabel = 'Active';
  static const String needsSignInLabel = 'Sign in again';

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty && onAdd == null) return const SizedBox.shrink();
    final gap = SettingsTokens.categoryChipGapOf(context);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final account in accounts)
            _AccountChip(
              key: ValueKey('account-chip-${account.userId}'),
              item: account,
              active: account.userId == activeUserId,
              managing: managing,
              prefix: switchPrefix,
              onTap: !enabled
                  ? null
                  : managing
                  ? (onRemove == null || account.userId == activeUserId
                        ? null
                        : () => onRemove!(account.userId))
                  : () => onSwitch(account.userId),
            ),
          if (onAdd != null && !managing)
            _AccountChip(
              key: const ValueKey('account-chip-add'),
              item: AccountRailItem(userId: '', label: addLabel),
              active: false,
              managing: false,
              icon: Icons.person_add_alt_1_rounded,
              onTap: enabled ? onAdd : null,
            ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatefulWidget {
  const _AccountChip({
    super.key,
    required this.item,
    required this.active,
    required this.managing,
    required this.onTap,
    this.prefix,
    this.icon,
  });

  final AccountRailItem item;
  final bool active;
  final bool managing;
  final VoidCallback? onTap;
  final String? prefix;
  final IconData? icon;

  @override
  State<_AccountChip> createState() => _AccountChipState();
}

class _AccountChipState extends State<_AccountChip> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  String? get _status {
    if (widget.active) return AccountRail.activeLabel;
    if (widget.managing) return AccountRail.removeLabel;
    if (widget.item.needsSignIn) return AccountRail.needsSignInLabel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final pad = SettingsTokens.categoryChipPadOf(context);
    final avatarSize = SettingsTokens.iconButtonIconSizeOf(context);
    final labelSize = SettingsTokens.typeSizeOf(context, 14);
    final statusSize = SettingsTokens.typeSizeOf(context, 11.5);
    final label = widget.prefix == null || widget.managing
        ? widget.item.label
        : '${widget.prefix} ${widget.item.label}';
    final initial = widget.item.label.isEmpty
        ? '?'
        : widget.item.label.substring(0, 1).toUpperCase();
    final status = _status;

    return ExcludeFocus(
      excluding: !enabled,
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: SettingsTokens.groupRadius,
        scaleOnFocus: 1.0,
        showFocusBorder: true,
        showFocusFill: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final highlighted =
                enabled &&
                ShellInputPolicy.interactiveActive(
                  ShellScope.inputPolicyOf(context),
                  hovered: _hoveredN.value,
                  focused: _focused,
                  context: context,
                );
            final fg = highlighted || widget.active
                ? ForjaShellColors.textPrimary
                : ForjaShellColors.textSecondary;
            return AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 120),
              child: Container(
                padding: pad,
                decoration: BoxDecoration(
                  color: widget.active
                      ? ForjaShellColors.chipSelectedBg
                      : ForjaShellColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(
                    SettingsTokens.groupRadius,
                  ),
                  border: Border.all(
                    color: widget.active
                        ? ForjaShellColors.chipSelectedBorder
                        : ForjaShellColors.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.managing
                            ? ForjaShellColors.sectionIconBg
                            : ForjaShellColors.brandGreen.withValues(
                                alpha: widget.active ? 0.9 : 0.55,
                              ),
                      ),
                      child: widget.icon != null || widget.managing
                          ? Icon(
                              widget.managing
                                  ? Icons.close_rounded
                                  : widget.icon,
                              size: avatarSize * 0.62,
                              color: widget.managing
                                  ? ForjaShellColors.textPrimary
                                  : ForjaShellColors.bgDark,
                            )
                          : Text(
                              initial,
                              style: TextStyle(
                                color: ForjaShellColors.bgDark,
                                fontSize: avatarSize * 0.55,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: labelSize,
                            fontWeight: highlighted
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (status != null)
                          Text(
                            status,
                            style: TextStyle(
                              color: widget.item.needsSignIn && !widget.managing
                                  ? ForjaShellColors.upcomingMuted
                                  : ForjaShellColors.textSecondary,
                              fontSize: statusSize,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
