import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
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
    final iconColor =
        selected ? ForjaShellColors.brandGreen : ForjaShellColors.iconMuted;
    final titleColor =
        selected ? ForjaShellColors.textPrimary : ForjaShellColors.textSecondary;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? ForjaShellColors.inkHover
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: selected ? ForjaShellColors.brandGreen : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: SettingsTokens.categoryTitleSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// Flat labeled section of settings rows — no card box, hairline row dividers.
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
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 2,
                    color: ForjaShellColors.brandGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label!.toUpperCase(),
                    style: const TextStyle(
                      color: ForjaShellColors.brandGreen,
                      fontSize: SettingsTokens.groupLabelSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: ForjaShellColors.borderSubtle.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                children[i],
              ],
            ],
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
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  /// When false, [child] fills the remaining height (no outer scroll).
  final bool scrollable;

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
            child: widget.scrollable
                ? Scrollbar(
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
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsTokens.pagePadding,
                      8,
                      SettingsTokens.pagePadding,
                      16,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth
                            .clamp(0.0, SettingsTokens.detailMaxWidth)
                            .toDouble();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: width,
                            height: constraints.maxHeight,
                            child: widget.child,
                          ),
                        );
                      },
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
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

/// Settings action button — thin wrapper over the shared [ForjaButton].
///
/// Hugs its label and left-aligns by default (never full-width in a stretch
/// column). Pass `expand: true` only when a caller explicitly wants a
/// width-filling button (e.g. inside a `Row`/`Expanded`).
///
/// `secondary: true` uses the neutral tone; otherwise the brand-green primary.
class SettingsFilledButton extends StatelessWidget {
  const SettingsFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool secondary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = ForjaButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      busy: busy,
      expand: expand,
      height: 36,
      variant: secondary
          ? ForjaButtonVariant.neutral
          : ForjaButtonVariant.primary,
    );
    if (expand) return button;
    return Align(alignment: Alignment.centerRight, child: button);
  }
}

/// Flat underline text field — no filled box.
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: ForjaShellColors.textPrimary,
        fontSize: 14,
      ),
      cursorColor: ForjaShellColors.brandGreen,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        floatingLabelStyle: const TextStyle(color: ForjaShellColors.brandGreen),
        labelStyle: const TextStyle(color: ForjaShellColors.textSecondary),
        hintStyle: TextStyle(
          color: ForjaShellColors.textSecondary.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.only(top: 18, bottom: 10),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.brandGreen, width: 2),
        ),
      ),
    );
  }
}

/// Flat connected/status line — icon + title + subtitle, no box.
class SettingsStatusRow extends StatelessWidget {
  const SettingsStatusRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.check_circle_rounded,
    this.iconColor = ForjaShellColors.brandGreen,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Credits + version pinned to the bottom of the wide-settings sidebar.
class SettingsSidebarFooter extends StatelessWidget {
  const SettingsSidebarFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: ForjaShellColors.textSecondary,
                  ),
                  children: const [
                    TextSpan(text: 'Made with '),
                    TextSpan(text: '❤️'),
                    TextSpan(text: ' by '),
                    TextSpan(
                      text: 'Schmenka',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppVersionLabel(
                prefix: 'v',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary.withValues(
                    alpha: 0.85,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
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
