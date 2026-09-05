import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two quick-action cards: official ForjaHQ install + Community Packs browse.
///
/// Always D-pad focusable. Pass [installFocusNode] / [browseFocusNode] from
/// onboarding; Settings leaves them null and owns nodes internally with
/// [shellFocusableTap] settings-zone metadata.
class ForjaPackChoiceCards extends StatefulWidget {
  const ForjaPackChoiceCards({
    super.key,
    required this.onInstallOfficial,
    required this.onBrowseCommunity,
    this.installFocusNode,
    this.browseFocusNode,
    this.compact = false,
    this.communitySubtitle,
    this.autofocusInstall = false,
    this.settingsTvFocus = false,
  });

  final VoidCallback onInstallOfficial;
  final VoidCallback onBrowseCommunity;
  final FocusNode? installFocusNode;
  final FocusNode? browseFocusNode;
  final bool compact;
  final String? communitySubtitle;
  final bool autofocusInstall;

  /// When true (Settings → Forja Packs), register in the settings TV focus graph.
  final bool settingsTvFocus;

  @override
  State<ForjaPackChoiceCards> createState() => _ForjaPackChoiceCardsState();
}

class _ForjaPackChoiceCardsState extends State<ForjaPackChoiceCards> {
  FocusNode? _ownedInstall;
  FocusNode? _ownedBrowse;

  FocusNode get _installNode =>
      widget.installFocusNode ??
      (_ownedInstall ??= FocusNode(debugLabel: 'forja_pack_choice_install'));

  FocusNode get _browseNode =>
      widget.browseFocusNode ??
      (_ownedBrowse ??= FocusNode(debugLabel: 'forja_pack_choice_browse'));

  @override
  void dispose() {
    _ownedInstall?.dispose();
    _ownedBrowse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.compact ? 10.0 : 14.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ForjaPackChoiceCard(
            focusNode: _installNode,
            autofocus: widget.autofocusInstall,
            compact: widget.compact,
            settingsTvFocus: widget.settingsTvFocus,
            tvItemIndex: 0,
            icon: Icons.inventory_2_rounded,
            title: 'Official packs',
            subtitle: widget.compact
                ? 'Choose which ForjaHQ packs to install'
                : 'Best experience — install the ForjaHQ bundle',
            accent: true,
            onTap: widget.onInstallOfficial,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: ForjaPackChoiceCard(
            focusNode: _browseNode,
            compact: widget.compact,
            settingsTvFocus: widget.settingsTvFocus,
            tvItemIndex: 1,
            icon: Icons.public_rounded,
            title: 'Community Packs',
            subtitle: widget.communitySubtitle ??
                (widget.compact
                    ? 'Browse packs on the web'
                    : 'Browse and pick packs on the web'),
            onTap: widget.onBrowseCommunity,
          ),
        ),
      ],
    );
  }
}

class ForjaPackChoiceCard extends StatelessWidget {
  const ForjaPackChoiceCard({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
    this.autofocus = false,
    this.compact = false,
    this.settingsTvFocus = false,
    this.tvItemIndex,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final bool autofocus;
  final bool compact;
  final bool settingsTvFocus;
  final int? tvItemIndex;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 12.0 : 16.0;
    final minHeight = compact ? 112.0 : 168.0;
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
        : const EdgeInsets.fromLTRB(18, 20, 18, 18);
    final iconSize = compact ? 22.0 : 32.0;
    final titleSize = compact ? 13.0 : 16.0;
    final subSize = compact ? 11.0 : 13.0;

    Widget card({required bool focused}) {
      final borderColor = accent
          ? ForjaShellColors.brandGreen.withValues(
              alpha: focused ? 0.95 : 0.55,
            )
          : ForjaShellColors.borderSubtle.withValues(
              alpha: focused ? 0.95 : 0.7,
            );
      return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: pad,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: focused ? 0.42 : 0.28),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: focused ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: accent
                  ? ForjaShellColors.brandGreen
                  : ForjaShellColors.textPrimary,
            ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: ForjaShellColors.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                color: ForjaShellColors.textSecondary,
                fontSize: subSize,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final body = AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) => card(focused: focusNode.hasFocus),
    );

    if (settingsTvFocus) {
      return shellFocusableTap(
        context: context,
        focusNode: focusNode,
        autoFocus: autofocus,
        onTap: onTap,
        borderRadius: radius,
        scaleOnFocus: compact ? 1.01 : 1.02,
        showFocusBorder: true,
        showFocusFill: false,
        showFocusRail: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.settings,
        tvItemIndex: tvItemIndex,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: body,
      );
    }

    return FocusableControl(
      focusNode: focusNode,
      autoFocus: autofocus,
      onTap: onTap,
      borderRadius: radius,
      scaleOnFocus: compact ? 1.01 : 1.02,
      showFocusBorder: true,
      showFocusFill: false,
      child: body,
    );
  }
}
