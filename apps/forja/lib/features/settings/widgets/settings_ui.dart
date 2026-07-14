import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Category row in the Settings hub list / sidebar.
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? ForjaShellColors.chipSelectedBg
        : Colors.transparent;
    final border = selected
        ? ForjaShellColors.chipSelectedBorder
        : Colors.transparent;
    final iconColor =
        selected ? ForjaShellColors.brandGreen : ForjaShellColors.iconMuted;
    final titleColor =
        selected ? ForjaShellColors.textPrimary : ForjaShellColors.textSecondary;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SettingsTokens.categoryTileRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ForjaShellColors.sectionIconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
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
                    fontSize: SettingsTokens.categoryTitleSize,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!SettingsTokens.useSplitLayout(context))
            const Icon(
              Icons.chevron_right_rounded,
              color: ForjaShellColors.iconMuted,
              size: 22,
            ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: child,
    );
  }
}

/// Labeled block of settings rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.label,
    required this.children,
  });

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SettingsTokens.groupSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                label!.toUpperCase(),
                style: const TextStyle(
                  color: ForjaShellColors.brandGreen,
                  fontSize: SettingsTokens.groupLabelSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: ForjaShellColors.surfaceElevated,
              borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
              border: Border.all(color: ForjaShellColors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: ForjaShellColors.borderSubtle,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable detail page chrome (title + constrained body).
class SettingsPageScaffold extends StatefulWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsTokens.pagePadding,
              8,
              SettingsTokens.pagePadding,
              4,
            ),
            child: Row(
              children: [
                if (widget.showBack)
                  IconButton(
                    tooltip: 'Back',
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: ForjaShellColors.textPrimary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: SettingsTokens.pageTitleSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  SettingsTokens.pagePadding,
                  8,
                  SettingsTokens.pagePadding,
                  48,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: SettingsTokens.detailMaxWidth,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle row used inside [SettingsGroup].
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ForjaShellColors.brandGreen,
          ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: () => onChanged(!value),
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Dropdown select row used inside [SettingsGroup].
class SettingsSelectRow extends StatelessWidget {
  const SettingsSelectRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ForjaShellColors.sectionIconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ForjaShellColors.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: ForjaShellColors.cinematic.menuSurface,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ForjaShellColors.brandGreen,
                  size: 20,
                ),
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                items: options
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: () {},
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Tappable action / navigation row.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.destructive = false,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? const Color(0xFFF87171)
        : ForjaShellColors.textPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ForjaShellColors.brandGreen,
              ),
            )
          else
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ForjaShellColors.iconMuted,
                ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: busy ? null : onTap,
      scaleOnFocus: 1.0,
      navLeftAlways: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Primary / secondary text button styled for settings.
class SettingsFilledButton extends StatelessWidget {
  const SettingsFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bg = secondary
        ? ForjaShellColors.sectionIconBg
        : ForjaShellColors.brandGreen;
    final fg = secondary
        ? ForjaShellColors.textPrimary
        : const Color(0xFF0A0A0A);

    return SizedBox(
      height: 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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

/// Styled confirm dialog for settings destructive / overwrite actions.
Future<bool> showSettingsConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        title,
        style: const TextStyle(color: ForjaShellColors.textPrimary),
      ),
      content: Text(
        body,
        style: const TextStyle(color: ForjaShellColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: ForjaShellColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive
                  ? const Color(0xFFF87171)
                  : ForjaShellColors.brandGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
